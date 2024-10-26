#
# Build functions
#

# Resize and reformat images
function buildImages() {
  h2 "Resize and reformat images"
  docker compose \
    -f "${PROJECT_DIR}/Deployment/docker-compose.yml" \
    --env-file "${PROJECT_DIR}/.env" \
    up \
    ${dockerComposeBuildParameter} \
    --exit-code-from imagetool \
    imagetool
}

# Build a binary incremental
function buildIncrementalBinary() {
  buildImages
  h2 "Build a binary incremental"
  local dockerComposeBuildParameter=${1}
  RUNTIME_IMAGE="" docker compose \
      -f "${PROJECT_DIR}/Deployment/docker-compose.yml" \
      --env-file "${PROJECT_DIR}/.env" \
      run --rm \
      ${dockerComposeBuildParameter} \
      build
}

# Build a production release
function buildRelease() {
  buildImages
  h2 "Build a fresh production release"
  local TAG=${1:-${TAG}}
  local FILE=${TAG##*:}
  "${PROJECT_DIR}/Deployment/Release/build.sh" --tag "${TAG}"
  docker save -o "${PROJECT_DIR}/Deployment/Release/uitsmijter-${FILE}.tar" ${TAG}
}

# Helper to trigger a release build if not present
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

# Build a helm package
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

function buildRuntime() {
  h2 "Build uitsmijter runtime"
  local TAG=${1:-${TAG}}
  RUNTIME_IMAGE=${TAG} docker compose \
    -f "${PROJECT_DIR}/Deployment/docker-compose.yml" \
    --env-file "${SCRIPT_DIR}/.env" \
    build \
    run
}
