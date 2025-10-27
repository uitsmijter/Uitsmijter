#
# Check functions
#
# This file contains functions to verify that required executables and dependencies
# are available in the system PATH before running various tooling operations.
#

include "display.var.sh"

# Check if an executable is available in the system PATH
# Parameters:
#   $1: EXE - Name of the executable to check (required)
#   $2: MSG - Optional custom error message to display if executable is not found
# Returns: 0 if found, exits with error if not found
# Example: checkExecutableInPath "docker" "Please install Docker Desktop"
function checkExecutableInPath() {
  local EXE="${1}"
  local MSG="${2:-""}"
  echo -n "Looking for ${EXE}"
  # shellcheck disable=SC2015
  which "${EXE}" >/dev/null 2>&1 && echo " ${SYMBOL_SUCCESS}" && return || echo " ${SYMBOL_FAIL}" && true

  die "${EXE} not found ${MSG}"
}

# Check if kubectl is installed
# Parameters: None
# Returns: 0 if found, exits with error if not found
# Used for: Kubernetes cluster management and deployments
function checkKubectl() {
  checkExecutableInPath kubectl
}

# Check if helm is installed
# Parameters: None
# Returns: 0 if found, exits with error if not found
# Used for: Deploying Helm charts to Kubernetes
function checkHelm() {
  checkExecutableInPath helm 'Please install helm'
}

# Check if openssl is installed
# Parameters: None
# Returns: 0 if found, exits with error if not found
# Used for: Generating TLS certificates for local testing
function checkOpenssl() {
  checkExecutableInPath openssl
}

# Check if Go is installed (required for installing kind)
# Parameters: None
# Returns: 0 if found, exits with error if not found
# Used for: Installing kind via 'go install' if kind is not available
function checkGoForKind() {
  checkExecutableInPath go 'Please install kind or Golang to run e2e tests!'
}

# Check if kind is installed, offer to install it via Go if not found
# Parameters: None
# Returns: 0 if found or successfully installed
# Interactive: Prompts user for confirmation before installing kind
# Used for: Running local Kubernetes clusters for testing
function checkKind() {
  # shellcheck disable=SC2015
  which kind >/dev/null 2>&1 && return || true

  echo 'kind not found'
  checkGoForKind

  echo 'Should it be installed via go? (abort with Cmd+C, continue with [enter])'
  read -r # Wait for user confirmation or abort if not inside a tty

  echo 'Installing kind via go'
  go install sigs.k8s.io/kind@latest
}

# Check for GNU date command (required on macOS for date calculations)
# Parameters: None
# Returns: 0 if correct date command is available, exits with error if not found
# Platform-specific: On macOS, checks for 'gdate' from coreutils package
# Used for: Date/time calculations in cluster management
function checkDate() {
  if [[ $OSTYPE == 'darwin'* ]]; then
    checkExecutableInPath gdate 'please run "brew install coreutils"'
  fi
}

# Check if s3cmd is installed
# Parameters: None
# Returns: 0 if found, exits with error if not found
# Used for: Interacting with S3-compatible storage in e2e tests
function checkS3cmd() {
  checkExecutableInPath s3cmd 'Please install s3cmd'
}
