#
# Executable functions
#
# This file contains functions for running Uitsmijter in different environments:
# Docker (development), Docker Compose (production), and Kubernetes (kind cluster).
#

# Run Uitsmijter using incremental build in a Docker development environment
# Parameters: None (uses IMAGENAME, RUNTIME_IMAGE from environment)
# Returns: Exit code from the run container
# Side effects: Starts development environment with hot-reload capabilities
# Use case: Local development and testing with fast iteration
function runInDocker() {
  h2 "Run incremental build in a docker environment"
  RUNTIME_IMAGE="${IMAGENAME}-runtime:latest" docker compose \
    -f "${PROJECT_DIR}/Deployment/build-compose.yml" \
    --env-file "${SCRIPT_DIR}/.env" \
    up \
    --exit-code-from run \
    run
}

# Run Uitsmijter in a production-like Docker Compose environment
# Parameters:
#   $1: IMAGENAME - Docker image name (default: ${IMAGENAME} from environment)
#   $2: TAG - Docker image tag (default: ${TAG} from environment)
# Returns: None (runs until stopped with Ctrl+C)
# Side effects: Builds release if needed, starts full production stack
# Use case: Testing production configuration locally with Docker Compose
function runInDockerProduction() {
  h2 "Run Uitsmijter in production environment"
  local IMAGENAME="${1:-${IMAGENAME}}"
  local TAG="${2:-${TAG}}"
  buildReleaseIfNotPresent "${IMAGENAME}:${TAG}"
  IMAGENAME=${IMAGENAME} TAG=${TAG} \
    docker compose \
    -f "${PROJECT_DIR}/Deployment/Docker/docker-compose.yml" \
    --env-file "${PROJECT_DIR}/Deployment/Docker/.env" \
    up
}

# Run Uitsmijter in a local Kubernetes cluster using kind (Kubernetes in Docker)
# Parameters:
#   $1: TAG - Docker image tag to deploy (default: ${TAG} from environment)
# Returns: None
# Side effects:
#   - Builds release if needed
#   - Creates kind cluster with Traefik, S3, and test applications
#   - Displays /etc/hosts entries needed for local testing
#   - Waits for user to press enter, then deletes cluster
# Interactive: Prompts user to press enter to stop and delete the cluster
# Cleanup: Automatically deletes cluster on EXIT or user input
# Use case: Testing Kubernetes deployment and e2e scenarios locally
function runInKubernetesInDocker() {
  h2 "Run release in local KubernetesInDocker"
  local TAG="${1:-${TAG}}"
  buildReleaseIfNotPresent "${TAG}"
  trap "kindDeleteCluster" EXIT
  kindStartCluster "${TAG}"
  echo ''
  echo 'Cluster is running.'
  # Keep in sync with build-compose.yml
  echo 'Add the following to your local /etc/hosts file.'
  echo ''
  for host in ${TEST_HOSTS}; do
    echo "127.0.0.1 $host"
  done
  echo ''
  echo 'Press enter to stop the cluster'
  read -r || true
  trap - EXIT
  kindDeleteCluster
}
