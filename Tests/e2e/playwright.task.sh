#!/usr/bin/env bash

set -e
set -o pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
KUBECONFIG=${KUBECONFIG:-~/.kube/config}

COMMAND=
BROWSER=
LIMIT_PROJECT=
PLAYWRIGHT_ARGS=""
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
  --grep)
    # Playwright test filter argument
    PLAYWRIGHT_ARGS="${PLAYWRIGHT_ARGS} --grep \"${2}\""
    shift 2
    ;;
  --* | -*=) # pass through other flags to Playwright
    PLAYWRIGHT_ARGS="${PLAYWRIGHT_ARGS} $1"
    shift
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
	eval "yarn start ${LIMIT_PROJECT} ${PLAYWRIGHT_ARGS} ${PARAMS}"
popd
