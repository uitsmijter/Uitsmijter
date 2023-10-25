#
# Test functions
#

include "test.var.sh"

# Run unit tests
function unitTests() {
  h2 "Run all UnitTests"
  local dockerComposeBuildParameter=${1}
  docker-compose \
    -f "${PROJECT_DIR}/Deployment/docker-compose.yml" \
    --env-file "${PROJECT_DIR}/.env" \
    up \
    ${dockerComposeBuildParameter} \
    --exit-code-from test \
    test
}

# Run end-to-end tests
function e2eTests(){
  h2 "Run all e2e tests"
  local dockerComposeBuildParameter=${1}
  local ARGUMENTS="${2:-""}"
  local TAG="${3:-${TAG}}"
  buildReleaseIfNotPresent "${TAG}"

  trap "kindDeleteCluster" EXIT
  kindStartCluster "${TAG}"

  echo
  echo "Running tests:"

  status=0
  ARGUMENTS="${ARGUMENTS}" docker-compose \
    -f "${PROJECT_DIR}/Deployment/docker-compose.yml" \
    --env-file "${PROJECT_DIR}/.env" \
    up \
    ${dockerComposeBuildParameter} \
    --exit-code-from e2e \
    e2e || status=$?

  kindDeleteCluster
  trap - EXIT

  if [[ "${status}" -gt 0 ]]; then
    exit "${status}"
  fi
}
