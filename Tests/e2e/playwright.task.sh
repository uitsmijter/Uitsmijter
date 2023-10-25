#!/usr/bin/env bash

set -e
set -o pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
KUBECONFIG=${KUBECONFIG:-~/.kube/config}

COMMAND=
BROWSER=
LIMIT_PROJECT=
while (("$#")); do
  case "$1" in
  run)
    COMMAND=${1}
    shift 1
    ;;
  --browser)
    BROWSER=${2}
    shift 2
    ;;
  --) # end argument parsing
    shift
    break
    ;;
  --* | -*=) # unsupported flags
    echo "Error: Unsupported flag $1" >&2
    echo "Possible options are: --build --lint --test --e2e --run --run-cluster --release --helm and --help"
    echo "Possible flags: --rebuild --debug"
    exit 1
    ;;
  *) # preserve positional arguments
    PARAMS="$PARAMS $1"
    shift
    ;;
  esac
done

if [[ ! -f "${KUBECONFIG}" ]]; then
  echo "\$KUBECONFIG file not found" >&2
  exit 1
fi

if [[ -n "${BROWSER}" ]]; then
  LIMIT_PROJECT="--project ${BROWSER}"
  echo "Limit tests to: ${BROWSER}"
fi

echo "${COMMAND}..."
pushd "${SCRIPT_DIR}/playwright"
	yarn install
	yarn start ${LIMIT_PROJECT}
popd
