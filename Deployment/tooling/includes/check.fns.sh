#
# Check functions
#

include "display.var.sh"

function checkExecutableInPath() {
  local EXE="${1}"
  local MSG="${2:-""}"
  echo -n "Looking for ${EXE}"
  # shellcheck disable=SC2015
  which "${EXE}" >/dev/null 2>&1 && echo " ${SYMBOL_SUCCESS}" && return || echo " ${SYMBOL_FAIL}" && true

  die "${EXE} not found ${MSG}"
}

function checkKubectl() {
  checkExecutableInPath kubectl
}

function checkHelm() {
  checkExecutableInPath helm 'Please install helm'
}

function checkOpenssl() {
  checkExecutableInPath openssl
}

function checkGoForKind() {
  checkExecutableInPath go 'Please install kind or Golang to run e2e tests!'
}

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

function checkDate() {
  if [[ $OSTYPE == 'darwin'* ]]; then
    checkExecutableInPath gdate 'please run "brew install coreutils"'
  fi
}

function checkS3cmd() {
  checkExecutableInPath s3cmd 'Please install s3cmd'
}
