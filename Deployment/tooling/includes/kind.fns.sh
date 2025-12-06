#
# Kubernetes In Docker (kind) functions
#
# This file contains functions for creating and managing local Kubernetes clusters
# using kind (Kubernetes in Docker) for testing and development. It sets up a complete
# test environment with Traefik ingress, S3 storage, and test applications.
#

include "kind.var.sh"

# Delete the kind cluster and export logs
# Parameters: None (uses KIND_CLUSTER_NAME and KIND_KUBECONFIG from kind.var.sh)
# Returns: None
# Side effects:
#   - Exports cluster logs to ${PROJECT_DIR}/.build/kind/logs
#   - Deletes the kind cluster
#   - Removes kubeconfig file
# Use case: Cleanup after testing or when restarting cluster
function kindDeleteCluster() {
  echo "The cluster will be deleted."
  kind export logs --name ${KIND_CLUSTER_NAME} "${PROJECT_DIR}/.build/kind/logs" || true
  kind delete cluster --name ${KIND_CLUSTER_NAME}
  rm "${KIND_KUBECONFIG}" >/dev/null 2>&1 || true
}

# Start a new kind cluster with complete Uitsmijter test environment
# Parameters:
#   $1: IMAGE - Docker image to deploy (default: from IMAGE env var or "adt/uitsmijter:latest")
# Returns: None
# Side effects:
#   - Checks for required tools (kubectl, openssl, kind, helm, date, s3cmd)
#   - Creates kind cluster
#   - Sets up TLS certificates
#   - Installs Traefik ingress controller
#   - Installs S3-compatible storage
#   - Deploys Uitsmijter with Helm
#   - Applies tenant and client configurations
#   - Installs test applications from Deployment/e2e/applications/
# Environment setup: Full e2e test environment ready for integration testing
# Use case: Running end-to-end tests or manual testing in local Kubernetes
function kindStartCluster() {
  # Use IMAGE from env or second parameter
  local IMAGE=${IMAGE:-${1:-adt/uitsmijter:latest}}
  # Add latest tag if not defined
  [[ "${IMAGE}" == *:* ]] || IMAGE=${IMAGE}:latest
  echo "Using image ${IMAGE}"

  h3 'Checking requirements'
  checkKubectl
  checkOpenssl
  checkKind
  checkHelm
  checkDate
  checkS3cmd
  pathPrepareBuildDir

  h3 'Setup cluster'
  kindSetupCluster

  h3 'Setting up Traefik'
  kindSetupCert
  kindSetupTraefik

  h3 'Setting up S3'
  kindSetupS3

  h3 'Setup Uitsmijter'
  kind load docker-image --name ${KIND_CLUSTER_NAME} "${IMAGE}"
  helm upgrade --create-namespace --namespace uitsmijter \
    --install uitsmijter ${PROJECT_DIR}/Deployment/helm/uitsmijter \
    -f ${PROJECT_DIR}/Deployment/e2e/helm.yml \
    --set image.repository="${IMAGE%%:*}" \
    --set image.tag="${IMAGE##*:}"

  kindWaitForPods uitsmijter app=uitsmijter-sessions,statefulset.kubernetes.io/pod-name=uitsmijter-sessions-0 app=uitsmijter

  kubectl apply \
    -f "${PROJECT_DIR}/Deployment/e2e/uitsmijter-tenant.yaml" \
    -f "${PROJECT_DIR}/Deployment/e2e/uitsmijter-client.yaml" \
    -n uitsmijter

  # Install Applications
  while IFS= read -r -d '' app
  do
    NAME=$(basename ${app})
    # Skip the basedir, because we want subdirectories only
    if [ "${app}" == "${PROJECT_DIR}/Deployment/e2e/applications" ]; then
      continue
    fi
    echo ''
    # Skip empty directories
    if [ ! "$(ls -A ${app} | grep -E 'ya?ml')" ]; then
      echo "${NAME} has no files."
      continue
    fi

    underline "${SYMBOL_BELOW} Install application ${NAME}"
    if [ -f "${app}/kustomization.yml" ] || [ -f "${app}/kustomization.yaml" ]; then
      kubectl apply --server-side -k "${app}"
    else
      kubectl apply -f "${app}"
    fi

    # Application specific post routines
    if [ -f "${app}/postinstall.sh" ]; then
      echo "Executing post-install"
      "${app}/postinstall.sh"
    fi
  done < <(find "${PROJECT_DIR}/Deployment/e2e/applications" -type d -print0)

  sleep 3 # Give the cluster some time for route propagation
  echo 'OK'
}

#
# Local Kubernetes helper functions
# These are internal functions used by kindStartCluster and related operations.
#

# Wait for existing kind clusters to finish or remove old ones
# Parameters: None (uses KIND_CLUSTER_NAME from kind.var.sh)
# Returns: None
# Side effects:
#   - Waits up to 30 minutes for existing control-plane containers to finish
#   - Removes control-plane containers older than 30 minutes
#   - Sets trap to delete cluster on EXIT
# Behavior: Prevents conflicts when multiple CI jobs try to create clusters simultaneously
# Use case: CI/CD environments where clusters might overlap
function kindWaitForRunningClusters() {
  trap - EXIT
  ownDate=$(which gdate 2>/dev/null || which date 2>/dev/null || die "no date implementation found")
  echo "* date: ${ownDate}"
  runningControlPlane=$(docker ps --format '{{json .}}' --filter "name=uitsmijter.*control-plane")
  runningControlPlaneId=$(echo "${runningControlPlane}" | jq -r .ID)
  if [[ -n "${runningControlPlaneId}" ]]; then
  	echo -n "There is already a control-plane running... ID: ${runningControlPlaneId}"
  	countdown=30
  	while [ $countdown -gt 0 ]; do
  		containerStartTime=$(docker container inspect --format='{{.State.StartedAt}}' "${runningControlPlaneId}" | cut -d'.' -f 1)
  		runningSeconds=$(expr "$(${ownDate} +%s)" - "$(${ownDate} +%s -d "${containerStartTime}")")
  		if [[ $runningSeconds -gt $((30 * 60)) ]]; then
  			echo "but it is older than 30 minutes and will be removed!"
  			docker rm -f "${runningControlPlaneId}"
  			countdown=-1
  		fi
  		echo "But it is not old enough to delete."
  		echo -n "Waiting politely... $((countdown * 60)) seconds"
  		((countdown--))
  		sleep 60
  		stillExist=$(docker ps --filter="ID=${runningControlPlaneId}" -q | wc -l)
  		if [[ $stillExist -eq 0 ]]; then
  			echo "the control-plane is gone."
  			countdown=-1
  		fi
  		echo ""
  	done
  else
    echo "OK to create new cluster."
  fi
  trap "kindDeleteCluster" EXIT
}

# Ensure the kind cluster control-plane container is running
# Parameters: None (uses KIND_CLUSTER_NAME from kind.var.sh)
# Returns: None
# Side effects: Starts the control-plane container if it's stopped
# Use case: Check if cluster is running and start it if stopped (avoids recreating cluster)
function kindEnsureClusterRunning() {
  local container="${KIND_CLUSTER_NAME}-control-plane"
  docker ps -a | grep "${container}" | grep 'Up ' > /dev/null || docker start "${container}"
}

# Generate certificate subjectAltName from TEST_HOSTS
# Parameters: None (uses TEST_HOSTS from test.var.sh)
# Returns: Comma-separated list of DNS entries for certificate SAN
# Example output: "DNS:*.localhost,DNS:example.com,DNS:*.example.com,DNS:*.ham.test,DNS:*.bnbc.example"
# Use case: Dynamically generate certificate domains from test host definitions
function generateCertDomains() {
  local domains="DNS:*.localhost"
  local seen_domains=()

  # Extract unique base domain patterns from TEST_HOSTS
  while IFS= read -r host; do
    # Skip empty lines
    [[ -z "$host" ]] && continue

    # Extract base domain and create wildcard pattern
    if [[ $host == *.*.* ]]; then
      # Multi-level subdomain: bucketname.s3.ham.test -> *.s3.ham.test and *.ham.test
      local base
      base=$(echo "$host" | sed 's/^[^.]*\.//')
      local parent
      parent=$(echo "$base" | sed 's/^[^.]*\.//')

      # Add both patterns if not already present
      if [[ ! " ${seen_domains[*]} " =~ " *.${base} " ]]; then
        domains="${domains},DNS:*.${base}"
        seen_domains+=("*.${base}")
      fi
      if [[ ! " ${seen_domains[*]} " =~ " *.${parent} " ]]; then
        domains="${domains},DNS:*.${parent}"
        seen_domains+=("*.${parent}")
      fi
    elif [[ $host == *.* ]]; then
      # Simple subdomain: login.example.com -> example.com and *.example.com
      local base
      base=$(echo "$host" | sed 's/^[^.]*\.//')

      # Add base domain
      if [[ ! " ${seen_domains[*]} " =~ " ${base} " ]]; then
        domains="${domains},DNS:${base}"
        seen_domains+=("${base}")
      fi
      # Add wildcard pattern
      if [[ ! " ${seen_domains[*]} " =~ " *.${base} " ]]; then
        domains="${domains},DNS:*.${base}"
        seen_domains+=("*.${base}")
      fi
    fi
  done <<< "$(echo "${TEST_HOSTS}" | tr ' ' '\n')"

  echo "${domains}"
}

# Generate self-signed TLS certificate for Traefik ingress
# Parameters: None
# Returns: None (early return if certificate already exists)
# Side effects: Creates certificate files in Deployment/e2e/traefik/certificates/
# Certificate details:
#   - Type: EC (secp384r1 curve)
#   - Validity: 10 years
#   - SANs: Dynamically generated from TEST_HOSTS variable
# Use case: Enable HTTPS in local test environment
function kindSetupCert() {
  local certificate="${PROJECT_DIR}/Deployment/e2e/traefik/certificates/tls"
  if  [[ -f "${certificate}.crt" ]]; then
    return
  fi
  mkdir -p "$(dirname "${certificate}")"

  local cert_domains
  cert_domains=$(generateCertDomains)

  echo "Creating default certificate"
  openssl req -x509 -newkey ec \
    -pkeyopt ec_paramgen_curve:secp384r1 -days 3650 \
    -nodes -keyout "${certificate}".key -out "${certificate}".crt \
    -subj '/CN=uitsmijter.localhost' \
    -addext "subjectAltName=${cert_domains}"
}

# Install and configure Traefik ingress controller in the cluster
# Parameters: None
# Returns: None
# Side effects:
#   - Applies Traefik kustomization from Deployment/e2e/traefik/
#   - Waits for Traefik pods to be ready
#   - Applies HTTPS redirect and default certificate configurations
# Use case: Set up ingress routing for test applications
function kindSetupTraefik() {
  #kubectl apply -k "${PROJECT_DIR}/Deployment/e2e/traefik/"
  helm repo add traefik https://traefik.github.io/charts
  helm repo update
  helm upgrade --install traefik --namespace traefik --create-namespace -f "${PROJECT_DIR}/Deployment/e2e/traefik/values.yaml" traefik/traefik
  
  kindWaitForPods traefik app.kubernetes.io/instance=traefik-traefik
  kubectl apply \
    -k "${PROJECT_DIR}/Deployment/e2e/traefik"

  kubectl apply \
    -f "${PROJECT_DIR}/Deployment/e2e/traefik/redirect-https.yml" \
    -f "${PROJECT_DIR}/Deployment/e2e/traefik/default-certificate.yml"
}

# Install S3-compatible storage server in the cluster
# Parameters: None
# Returns: None
# Side effects:
#   - Applies S3 kustomization from Deployment/e2e/s3/
#   - Waits for S3 server pod to be ready
# Use case: Test S3 template storage features
function kindSetupS3() {
  kubectl apply -k "${PROJECT_DIR}/Deployment/e2e/s3/"
  kubectl wait --for=condition=ready pod --timeout=${K8S_TIMEOUT} --selector=app=s3server -n uitsmijter-s3

}

# Wait for pods with specific labels to be created and become ready
# Parameters:
#   $1: ns - Kubernetes namespace to check
#   $@: labels - One or more label selectors (e.g., "app=traefik" "role=master")
# Returns: None
# Output: Progress indicators as pods are created and become ready
# Timeout: Uses K8S_TIMEOUT from kind.var.sh for readiness check
# Use case: Ensure dependencies are ready before proceeding with cluster setup
function kindWaitForPods() {
  local ns=$1
  shift 1

  echo "Waiting for pods with labels ${*} in namespace ${ns}"
  for labels in "$@"; do
    echo -n "${labels} "
    while ! kubectl -n "${ns}" get pods -l "${labels}" 2>&1 | grep STATUS > /dev/null; do
      echo -n .
      sleep 1
    done
    echo " created"
  done

  for labels in "$@"; do
    echo -n "${labels} "
    kubectl wait --for=condition=ready pod --timeout=${K8S_TIMEOUT} --selector="${labels}" -n "${ns}" > /dev/null
    echo " running"
  done
}

# Create or reuse existing kind cluster
# Parameters: None (uses KIND_CLUSTER_NAME, KIND_CONFIG from kind.var.sh)
# Returns: None
# Side effects:
#   - Waits for/removes conflicting clusters
#   - Creates new cluster if needed, or ensures existing one is running
#   - Configures cluster for GitLab CI if GITLAB_CI is set
# Special handling:
#   - Removes comment markers from KIND_CONFIG in GitLab CI
#   - Modifies kubeconfig for GitLab CI networking
#   - Adds /etc/hosts entry for control-plane in GitLab CI
# Use case: Set up the base Kubernetes cluster for testing
function kindSetupCluster() {
  kindWaitForRunningClusters
  echo "Setup cluster: ${KIND_CLUSTER_NAME}"
  if (kind get clusters | grep "${KIND_CLUSTER_NAME}") >/dev/null 2>&1; then
    if [[ -f "${KIND_KUBECONFIG}" ]]; then
      kindEnsureClusterRunning
      return
    else
      kindDeleteCluster
    fi
  fi

  echo "Finding port in range ${KIND_PORT_BOUND_LOWER}-${KIND_PORT_BOUND_UPPER}"
  echo "Found (possible) free port: ${KIND_PORT}"

  underline "Creating cluster ${KIND_CLUSTER_NAME}"
  if [[ -n "${GITLAB_CI}" ]]; then
    KIND_CONFIG=${KIND_CONFIG//##  /}
  fi
  if [[ -n "${DEBUG}" ]]; then
    echo "${KIND_CONFIG}"
  fi
  echo "${KIND_CONFIG}" | kind create cluster --name ${KIND_CLUSTER_NAME} --wait ${K8S_TIMEOUT} --config=-

  if [[ -n "${GITLAB_CI}" ]]; then
    sed -i "s/0\.0\.0\.0:${KIND_PORT}/${KIND_CLUSTER_NAME}-control-plane:6443/" "${KIND_KUBECONFIG}"
    controlPlaneIp=$(docker inspect "${KIND_CLUSTER_NAME}-control-plane" | jq -r '.[].NetworkSettings.Networks.kind.IPAddress')
    echo "${controlPlaneIp} ${KIND_CLUSTER_NAME}-control-plane docker" >> /etc/hosts
  fi
}
