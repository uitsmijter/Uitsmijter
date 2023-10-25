#
# Kubernetes In Docker variables
#

# Ensure path variables are loaded
include "path.var.sh"

# Timeout for waiting for tasks to get ready
K8S_TIMEOUT=${K8S_TIMEOUT:-"5m"}

KIND_PORT_BOUND_LOWER=50000
KIND_PORT_BOUND_UPPER=56000
KIND_PORT=$((${KIND_PORT_BOUND_LOWER} + RANDOM % (${KIND_PORT_BOUND_UPPER} - ${KIND_PORT_BOUND_LOWER})))

KIND_CLUSTER_NAME=${KIND_CLUSTER_NAME:-uitsmijter}
KIND_KUBECONFIG=${BUILD_DIR}/kubeconfig
# `KUBECONFIG` exported for other commands
export KUBECONFIG=${KIND_KUBECONFIG}

KIND_CONFIG="
  kind: Cluster
  apiVersion: kind.x-k8s.io/v1alpha4
  ##  networking:
  ##    apiServerAddress: \"0.0.0.0\"
  ##    apiServerPort: ${KIND_PORT}
  nodes:
    - role: control-plane
      extraPortMappings:
        - containerPort: 30080
          hostPort: 80
          listenAddress: \"0.0.0.0\"
        - containerPort: 30443
          hostPort: 443
          listenAddress: \"0.0.0.0\"
        - containerPort: 30088
          hostPort: 8088
          listenAddress: \"0.0.0.0\"
 "
