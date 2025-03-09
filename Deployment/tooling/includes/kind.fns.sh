#
# Kubernetes In Docker functions
#

include "kind.var.sh"

# Removed the kind cluster from docker
function kindDeleteCluster() {
  echo "The cluster will be deleted."
  kind export logs --name ${KIND_CLUSTER_NAME} "${PROJECT_DIR}/.build/kind/logs" || true
  kind delete cluster --name ${KIND_CLUSTER_NAME}
  rm "${KIND_KUBECONFIG}" >/dev/null 2>&1 || true
}

# Start a new kind cluster in docker
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

  kindWaitForPods uitsmijter app=uitsmijter-sessions,role=master app=uitsmijter

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
#

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
  			echo "but it is older than 30min and will be removed!"
  			docker rm -f "${runningControlPlaneId}"
  			countdown=-1
  		fi
  		echo "But it is not that old that we could delete it."
  		echo -n "We wait politely... $((countdown * 60)) seconds"
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

function kindEnsureClusterRunning() {
  local container="${KIND_CLUSTER_NAME}-control-plane"
  docker ps -a | grep "${container}" | grep 'Up ' > /dev/null || docker start "${container}"
}

function kindSetupCert() {
  local certificate="${PROJECT_DIR}/Deployment/e2e/traefik/certificates/tls"
  if  [[ -f "${certificate}.crt" ]]; then
    return
  fi
  mkdir -p "$(dirname "${certificate}")"

  echo "Creating default certificate"
  openssl req -x509 -newkey ec \
    -pkeyopt ec_paramgen_curve:secp384r1 -days 3650 \
    -nodes -keyout "${certificate}".key -out "${certificate}".crt \
    -subj '/CN=uitsmijter.localhost' \
    -addext 'subjectAltName=DNS:*.localhost,DNS:example.com,DNS:*.example.com,DNS:*.egg.example.com,DNS:ham.test,DNS:*.ham.test,DNS:*.s3.ham.test,DNS:bnbc.example,DNS:*.bnbc.example'
}

function kindSetupTraefik() {
  kubectl apply -k "${PROJECT_DIR}/Deployment/e2e/traefik/"
  kindWaitForPods traefik app=traefik
  kubectl wait --for=condition=ready pod --timeout=${K8S_TIMEOUT} --selector=app=traefik -n traefik
  kubectl apply \
    -f "${PROJECT_DIR}/Deployment/e2e/traefik/redirect-https.yml" \
    -f "${PROJECT_DIR}/Deployment/e2e/traefik/default-certificate.yml"
}

function kindSetupS3() {
  kubectl apply -k "${PROJECT_DIR}/Deployment/e2e/s3/"
  kubectl wait --for=condition=ready pod --timeout=${K8S_TIMEOUT} --selector=app=s3server -n uitsmijter-s3

}

function kindWaitForPods() {
  local ns=$1
  shift 1

  echo "Waiting for pods with lables ${*} in namespace ${ns}"
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
