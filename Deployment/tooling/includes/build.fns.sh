#
# Build functions
#
# This file contains functions for building Uitsmijter in various configurations,
# including development builds, production releases, Helm packages, and Docker images.
#

# Resize and reformat image assets for the project
# Parameters: None (uses dockerComposeBuildParameter from environment)
# Returns: Exit code from imagetool container
# Side effects: Processes images in the project using Docker Compose
# Use case: Optimize and prepare image assets before building
function buildImages() {
  h2 "Resize and reformat images"
  docker compose \
    -f "${PROJECT_DIR}/Deployment/build-compose.yml" \
    --env-file "${PROJECT_DIR}/.env" \
    up \
    ${dockerComposeBuildParameter} \
    --exit-code-from imagetool \
    imagetool
}

# Build Uitsmijter binary using incremental compilation (faster for development)
# Parameters:
#   $1: dockerComposeBuildParameter - Additional docker compose flags (optional)
# Returns: Exit code from build container
# Side effects: Resizes and reformats image assets first, then compiles Swift code incrementally
# Environment variables:
#   - SUPPRESS_PACKAGE_WARNINGS: Set to suppress Swift package warnings
# Use case: Fast development builds that reuse previous compilation artifacts
function buildIncrementalBinary() {
  buildImages
  h2 "Build a binary incremental"
  local dockerComposeBuildParameter=${1}
  SUPPRESS_PACKAGE_WARNINGS="${SUPPRESS_PACKAGE_WARNINGS}" \
  RUNTIME_IMAGE="" docker compose \
      -f "${PROJECT_DIR}/Deployment/build-compose.yml" \
      --env-file "${PROJECT_DIR}/.env" \
      run --rm \
      ${dockerComposeBuildParameter} \
      build
}

# Build a production-ready release image from scratch
# Parameters:
#   $1: TAG - Docker image tag to use (default: ${TAG} from environment)
# Returns: None
# Side effects: Builds images, creates release binary, saves Docker image as tar file
# Output: Creates uitsmijter-${FILE}.tar in Deployment/Release/
# Use case: Creating production releases for deployment
function buildRelease() {
  buildImages
  h2 "Build a fresh production release"
  local TAG=${1:-${TAG}}
  local FILE=${TAG##*:}
  "${PROJECT_DIR}/Deployment/Release/build.sh" --tag "${TAG}"
  docker save -o "${PROJECT_DIR}/Deployment/Release/uitsmijter-${FILE}.tar" ${TAG}
}

# Build a release if the Docker image doesn't already exist, or build dirty version
# Parameters:
#   $1: TAG - Docker image tag to check/build (default: ${TAG} from environment)
# Returns: None
# Side effects: May build release or dirty version depending on USE_DIRTY and image existence
# Use case: Ensure release image is available before running tests or deployments
# Note: If USE_DIRTY is set, creates a fast incremental build for local testing only
function buildReleaseIfNotPresent() {
  local TAG=${1:-${TAG}}

  if [ -n "${USE_DIRTY}" ]; then
    echo ""
    echoBox "${SYMBOL_WARNING} BUILD A RELEASE WITH A DIRTY VERSION!! USE THIS FOR LOCAL TESTING ONLY" "!"
    buildIncrementalBinary ""

    mkdir -p ${PROJECT_DIR}/Deployment/Runtime/dirty
    cp -r ${PROJECT_DIR}/{Public,Resources} ${PROJECT_DIR}/Deployment/Runtime/dirty
    cp ${PROJECT_DIR}/Deployment/Release/Linux/Uitsmijter ${PROJECT_DIR}/Deployment/Runtime/dirty
    cp  ${PROJECT_DIR}/Deployment/Runtime/entrypoint.sh ${PROJECT_DIR}/Deployment/Runtime/dirty/entrypoint.sh
    buildRuntime "${TAG}"
    rm -rf ${PROJECT_DIR}/Deployment/Runtime/dirty

    return
  fi

  if [ "$(docker images -q --filter=reference="${TAG}" | wc -l )" -eq "0" ]; then
    buildRelease "${TAG}"
  fi
}

# Build Helm chart packages for Kubernetes deployment
# Parameters: None (uses GIT_TAG, GIT_BRANCH, BUILD_NUMBER from environment)
# Returns: None
# Side effects: Removes old .tgz files, creates new Helm packages in Deployment/Release/
# Version logic:
#   - Uses GIT_TAG if available, otherwise GIT_BRANCH
#   - Converts "release-X" to "rc-X" for release candidates
#   - Strips "ce-" and "ee-" prefixes
#   - Adds "-rcN" suffix for release candidates using BUILD_NUMBER
# Output: Creates .tgz files for all Helm charts in Deployment/helm/
# Use case: Packaging Helm charts for distribution and deployment
function buildHelm() {
  h2 "Build helm packages"
  local version=${GIT_TAG}
  if [ -z "${version}" ]; then
    version=${GIT_BRANCH}
    version=${version/release-/rc-}
  fi
  local appversion=${version}
  version=${version/ce-/}
  version=${version/ee-/}
  if [[ "${version}" == rc-* ]]; then
    version=${version/rc-/}
    version=${version}-rc${BUILD_NUMBER:-0}
  fi

  echo "build version ${version}"
  if ls "${PROJECT_DIR}/Deployment/Release/"*.tgz >/dev/null 2>&1; then
    rm "${PROJECT_DIR}/Deployment/Release/"*.tgz
  fi

  for package in "${PROJECT_DIR}/Deployment/helm/"*; do
    helm package "${package}" \
      --version "${version}" \
      --app-version "${appversion}" \
      --destination "${PROJECT_DIR}/Deployment/Release"
  done
}

# Build the Uitsmijter runtime Docker image
# Parameters:
#   $1: TAG - Docker image tag for the runtime (default: ${TAG} from environment)
# Returns: Exit code from docker compose build
# Side effects: Builds Docker runtime image using docker compose
# Use case: Creating the final runtime container image with Uitsmijter binary
function buildRuntime() {
  h2 "Build uitsmijter runtime"
  local TAG=${1:-${TAG}}
  RUNTIME_IMAGE=${TAG} docker compose \
    -f "${PROJECT_DIR}/Deployment/build-compose.yml" \
    --env-file "${SCRIPT_DIR}/.env" \
    build \
    run
}
