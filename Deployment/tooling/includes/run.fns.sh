#
# Executable functions
#

# Run incremental build in docker environment
function runInDocker() {
  h2 "Run incremental build in a docker environment"
  RUNTIME_IMAGE="${IMAGENAME}-runtime:latest" docker compose \
    -f "${PROJECT_DIR}/Deployment/build-compose.yml" \
    --env-file "${SCRIPT_DIR}/.env" \
    up \
    --exit-code-from run \
    run
}

# Run official Uitsmijter in docker compose 
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

# Run a release or prerelease in kind
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
