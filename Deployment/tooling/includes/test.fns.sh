#
# Test functions
#
# This file contains functions for running unit tests and end-to-end (e2e) tests.
# Tests can be filtered and run in different configurations.
#

include "test.var.sh"

# Run Swift unit tests in Docker container
# Parameters:
#   $1: dockerComposeBuildParameter - Additional docker compose flags (optional)
#   $2: optionalFilter - Test filter pattern (e.g., "ServerTests.AppTests") (optional)
# Returns: Exit code from test container (0 if all tests pass)
# Environment variables:
#   - SUPPRESS_PACKAGE_WARNINGS: Set to suppress Swift package warnings
#   - FILTER_TEST: Test filter pattern passed to Swift test runner
# Use case: Running all or filtered unit tests during development or CI
# Example: unitTests "" "ServerTests.LoginControllerTests"
function unitTests() {
  h2 "Run all UnitTests"
  local dockerComposeBuildParameter=${1}
  local optionalFilter=${2}
  ARGUMENTS="${ARGUMENTS:-}" GITHUB_ACTION="${GITHUB_ACTION:-}" \
  SUPPRESS_PACKAGE_WARNINGS="${SUPPRESS_PACKAGE_WARNINGS:-}" RUNTIME_IMAGE="${RUNTIME_IMAGE}" \
  FILTER_TEST="${optionalFilter}" \
  docker compose \
    -f "${PROJECT_DIR}/Deployment/build-compose.yml" \
    --env-file "${PROJECT_DIR}/.env" \
    up \
    ${dockerComposeBuildParameter} \
    --abort-on-container-exit \
    --exit-code-from test \
    test
}

# List all available unit tests without running them
# Parameters:
#   $1: dockerComposeBuildParameter - Additional docker compose flags (optional)
#   $2: optionalFilter - Test filter pattern to narrow down the list (optional)
# Returns: Exit code from testlist container
# Environment variables:
#   - SUPPRESS_PACKAGE_WARNINGS: Set to suppress Swift package warnings
#   - FILTER_TEST: Test filter pattern to limit which tests are listed
# Output: Prints list of available test suites and test cases
# Use case: Discovering available tests or verifying test names for filtering
function unitTestsList() {
  h2 "List of available UnitTests"
  local dockerComposeBuildParameter=${1}
  local optionalFilter=${2}
  ARGUMENTS="${ARGUMENTS:-}" GITHUB_ACTION="${GITHUB_ACTION:-}" \
  SUPPRESS_PACKAGE_WARNINGS="${SUPPRESS_PACKAGE_WARNINGS:-}" \
  FILTER_TEST="${optionalFilter}" \
  docker compose \
    -f "${PROJECT_DIR}/Deployment/build-compose.yml" \
    --env-file "${PROJECT_DIR}/.env" \
    up \
    ${dockerComposeBuildParameter} \
    --abort-on-container-exit \
    --exit-code-from testlist \
    testlist
}

# Run end-to-end tests in a local Kubernetes cluster
# Parameters:
#   $1: dockerComposeBuildParameter - Additional docker compose flags (optional)
#   $2: ARGUMENTS - Additional arguments passed to Playwright/e2e runner (e.g., "--fast") (optional)
#   $3: TAG - Docker image tag to test (default: ${TAG} from environment)
#   $4: HOLD - If set, keep cluster running after tests (optional)
# Returns: Exit code from e2e tests (0 if all tests pass)
# Side effects:
#   - Builds release if needed
#   - Creates kind cluster with full test environment
#   - Runs Playwright e2e tests
#   - Deletes cluster after tests complete (unless HOLD is set)
# Environment variables:
#   - ARGUMENTS: Passed to e2e test runner
#   - GITHUB_ACTION: Set in CI to modify test behavior
# Cleanup: Automatically deletes kind cluster on completion or error (unless HOLD is set)
# Use case: Full integration testing of Uitsmijter in Kubernetes environment
function e2eTests(){
  h2 "Run all e2e tests"
  local dockerComposeBuildParameter=${1}
  local ARGUMENTS="${2:-""}"
  local TAG="${3:-${TAG}}"
  local HOLD="${4:-""}"
  buildReleaseIfNotPresent "${TAG}"

  if [[ -z "${HOLD}" ]]; then
    trap "kindDeleteCluster" EXIT
  fi
  kindStartCluster "${TAG}"

  echo
  echo "Running tests:"

  status=0
  SUPPRESS_PACKAGE_WARNINGS="${SUPPRESS_PACKAGE_WARNINGS:-}" \
  ARGUMENTS="${ARGUMENTS}" GITHUB_ACTION=${GITHUB_ACTION:-} docker compose \
    -f "${PROJECT_DIR}/Deployment/build-compose.yml" \
    --env-file "${PROJECT_DIR}/.env" \
    up \
    ${dockerComposeBuildParameter} \
    --abort-on-container-exit \
    --exit-code-from e2e \
    e2e || status=$?

  if [[ -n "${HOLD}" ]]; then
    echo ""
    h1 "Tests completed - Cluster is still running"
    echo ""
    echo "You can now interact with the cluster:"
    echo "  kubectl --kubeconfig .build/kubeconfig get pods -A"
    echo "  kubectl --kubeconfig .build/kubeconfig get clients -A"
    echo "  kubectl --kubeconfig .build/kubeconfig get tenants -A"
    echo ""
    echo "Access the services at:"
    echo "  https://login.example.com:$(cat .build/port)/login"
    echo ""
    echoBanner "Press ENTER to delete the cluster and exit" "!"
    read -r
    kindDeleteCluster
  else
    kindDeleteCluster
    trap - EXIT
  fi

  if [[ "${status}" -gt 0 ]]; then
    exit "${status}"
  fi
}
