#!/usr/bin/env bash

set -e
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
source "${SCRIPT_DIR}/.env"
source "${SCRIPT_DIR}/Deployment/tooling/imports.sh"

h1 "Uitsmijter Tooling"
echoBanner "Branch: ${GIT_BRANCH} | Version: ${GIT_TAG}" "~"
echo ""

help() {
  echo "Choose one or more commands: "
  echo ""
  echo "        -rm   | --remove          | remove        Remove docker volumes, images and build directory"
  echo "        -b    | --build           | build         Build the project"
  echo "        -l    | --lint            | lint          Check code quality"
  echo "        -t    | --test            | test          Run all UnitTests"
  echo "                                                  Optional <filter> can be applied as: '--test <filter>'"
  echo "                                                  like: '--test ServerTests.AppTests/testHelloWorld'"
  echo "        -o    | --list-tests      | list-tests    Shows a list of tests"
  echo "        -e    | --e2e             | e2e           Run end-to-end tests"
  echo "                                                  Optional --filter can be applied as: 'e2e --filter <pattern>'"
  echo "                                                  like: 'e2e --filter \"should respond with error\"'"
  echo "        -r/-c | --run[-cluster]   | run[-cluster] Run Uitsmijter in docker or in a local kind-cluster"
  echo "        -d    | --run-docker      | run-docker    Run Uitsmijter in a production docker environment"
  echo "        -s    | --release         | release       Build a release version, can have an optional added image "
  echo "                                                  name (with optional tag)"
  echo "        -p    | --helm            | helm          Build the helm package"
  echo "              | --code            | code          Open a code editor"
  echo "        -h    | --help            | help          Show this help message"
  echo ""
  echo "Additional Parameters: "
  echo ""
  echo "        --rebuild                 Force rebuild images"
  echo "        --debug                   Enable debug output"
  echo "        --dirty                   Use incremental temporary runtime for the local cluster"
  echo "        --fast                    runs tests only on one virtual browser and resolution."
  echo ""
  echo "Example:"
  echo "        ./tooling build run"
  echo "        ./tooling -b -r"
  echo ""
  printSeparatorLine "-"
  echo "Documentation can be found at https://docs.uitsmijter.io"
  echo ""
}

## Image Tag Definition
TAG="${IMAGENAME}:${GIT_BRANCH}-${GIT_HASH}"

## Parsing parameters to overwrite some default values
dockerComposeBuildParameter=""
MODE=""
DEBUG=""
USE_DIRTY=""
USE_FAST=""
FILTER=
PARAMS=""
COUNT=$#
if [ ${COUNT} == 0 ]; then
  help
fi

while (("$#")); do
  case "$1" in
  -h | --help | help)
    help
    shift 1
    exit 0
    ;;
  -rm | --remove | remove)
    MODE+="|remove"
    shift 1
    ;;
  -b | --build | build)
    MODE+="|build"
    shift 1
    ;;
  -l | --lint | lint)
    MODE+="|lint"
    shift 1
    ;;
  -t | --test | test)
    MODE+="|test"
    shift 1
    if [[ -n ${1} ]] && [[ ${1} != "--"* ]]; then
      # Convert dashes to underscores for Swift test compatibility
      # Swift test converts target names with dashes to underscores in test identifiers
      FILTER=${1//-/_}
      shift 1
    fi
    ;;
  -o | --list-tests | list-tests)
    MODE+="|listtests"
    shift 1
    if [[ -n ${1} ]] && [[ ${1} != "--"* ]]; then
      # Convert dashes to underscores for Swift test compatibility
      # Swift test converts target names with dashes to underscores in test identifiers
      FILTER=${1//-/_}
      shift 1
    fi
    ;;    
  -e | --e2e | e2e)
    MODE+="|e2e"
    shift 1
    ;;
  --filter)
    if [[ -n ${2} ]] && [[ ${2} != "--"* ]]; then
      FILTER=${2}
      shift 2
    else
      echo "Error: --filter requires a value" >&2
      exit 1
    fi
    ;;
  -r | --run | run)
    MODE+="|build|run"
    shift 1
    ;;
  -c | --run-cluster | run-cluster)
    MODE+="|cluster"
    shift 1
    ;;
  -d | --run-docker | run-docker)
    MODE+="|docker"
    shift 1
    ;;    
  -i | --images | images)
    MODE+="|imagetool"
    shift 1
    ;;
  --release | release)
    MODE+="|release|helm"
    shift 1
    ;;
  -p | --helm | helm)
    MODE+="|helm"
    shift 1
    ;;
  --code | code)
    MODE+="|code"
    shift 1
    ;;
  # Extra Parameter
  --rebuild)
    dockerComposeBuildParameter="--build"
    shift 1
    ;;
  --debug)
    DEBUG=1
    shift 1
    ;;
  --dirty)
    USE_DIRTY=1
    shift 1
    ;;
  --fast)
    USE_FAST=1
    shift 1
    ;;
  --) # end argument parsing
    shift
    break
    ;;
  --* | -*=) # unsupported flags
    echo "Error: Unsupported flag $1" >&2
    echo "Possible options are: --remove --build --lint --test --e2e --run --run-cluster --release --helm and --help"
    echo "Possible flags: --rebuild --debug"
    exit 1
    ;;
  *) # preserve positional arguments
    PARAMS="$PARAMS $1"
    shift
    ;;
  esac
done
# set positional arguments in their proper place
eval set -- "$PARAMS"

# semantic checks
if [[ "${MODE}" == *"run"* ]] && [[ "${MODE}" == *"cluster"* ]]; then
  echo "Uitsmijter can run as docker standalone application or in a local Kubernetes cluster. Not both." "!"
  echo ""
  exit 1
fi
if [[ "${MODE}" == *"release"* ]] && [[ -n "${USE_DIRTY}" ]]; then
  echo "${SYMBOL_FAIL} It is not allowed to build a dirty release." "!"
  echo ""
  exit 1
fi
if [[ "${MODE}" != *"e2e"* ]] && [[ -n "${USE_FAST}" ]]; then
  echo "${SYMBOL_FAIL} Fast makes sense for e2e tests only" "!"
  echo ""
  exit 1
fi

# Settings
shouldDebug "${DEBUG}"

# Execute pipeline
if [[ "${MODE}" == *"|remove"* ]]; then
  removeContainer
  removeImages
  removeVolumes
  removeBuild
fi

if [[ "${MODE}" == *"|imagetool"* ]]; then
  buildImages
fi

if [[ "${MODE}" == *"|build"* ]]; then
  buildIncrementalBinary "${dockerComposeBuildParameter}"
fi

if [[ "${MODE}" == *"|lint"* ]]; then
  lintCode
fi

if [[ "${MODE}" == *"|test"* ]]; then
  if [[ -n ${FILTER} ]]; then
    FILTER=" --filter ${FILTER}"
  fi
  unitTests "${dockerComposeBuildParameter}" "${FILTER}"
fi

if [[ "${MODE}" == *"|listtests"* ]]; then
  if [[ -n ${FILTER} ]]; then
    FILTER=" --filter ${FILTER}"
  fi
  unitTestsList "${dockerComposeBuildParameter}" "${FILTER}"
fi

if [[ "${MODE}" == *"|run"* ]]; then
  runInDocker
fi

if [[ "${MODE}" == *'|release'* ]]; then
  buildRelease "${TAG}"
fi

if [[ "${MODE}" == *"|code"* ]]; then
  openCode
fi

if [[ "${MODE}" == *"|helm"* ]]; then
  buildHelm
fi

if [[ "${MODE}" == *'|cluster'* ]]; then
  runInKubernetesInDocker "${TAG}"
fi

if [[ "${MODE}" == *'docker'* ]]; then
  runInDockerProduction "${IMAGENAME}" "${GIT_BRANCH}-${GIT_HASH}"
fi

if [[ "${MODE}" == *"e2e"* ]]; then
  EXTRAS=""
  if [  -n "${USE_FAST}" ]; then
    EXTRAS="--browser chromium"
  fi
  if [[ -n "${FILTER}" ]]; then
    # Pass filter as a single argument by escaping it properly
    EXTRAS="${EXTRAS} --grep '${FILTER}'"
  fi
  e2eTests "${dockerComposeBuildParameter}" "${EXTRAS}" "${TAG}"
fi

echo ""
echoBanner "done." "*"
echo ""
