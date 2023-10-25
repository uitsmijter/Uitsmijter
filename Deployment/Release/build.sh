#!/bin/bash

#
# Build a production release of uitsmijter
#

# Exit on error
set -e
# Handle errors in pipes as fails
set -o pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source ${SCRIPT_DIR}/../../.env
source ${SCRIPT_DIR}/../tooling/imports.sh

## Defaults
TAG="--tag ${IMAGENAME} --tag ${IMAGENAME}:${GIT_HASH}"
DOCKERFILE=${SCRIPT_DIR}/../${RELEASE_DOCKERFILE_OVERWRITE:-Uitsmijter.Dockerfile}
PROJECT_DIR="$( cd "${SCRIPT_DIR}/../.." >/dev/null 2>&1 && pwd )"
UITSMIJTER_BINARY=${PROJECT_DIR}/Deployment/Release/Linux/Uitsmijter

## Parsing parameters to overwrite some default values
PARAMS=""
while (( "$#" )); do
  case "$1" in
    -ssh|--ssh-key)
      SSH_KEY=$2
      shift 2
      ;;
    --skip-test)
      # For development only
      SKIPTESTS="true"
      shift 1
      ;;
    -t|--tag)
      TAG="--tag ${2}"
      shift 2
      ;;
    --) # end argument parsing
      shift
      break
      ;;
    -*|--*=) # unsupported flags
      echo "Error: Unsupported flag $1" >&2
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

if [ -n "${SSH_KEY}" ]; then
    eval $(ssh-agent)
    ssh-add ${SSH_KEY}
    SSH_ARGS="--build-arg SSH_KEY=${SSH_KEY} --ssh default=${SSH_AUTH_SOCK}"
fi
if [ -n "${SKIPTESTS}" ]; then
    EXTRA_ARGS="${EXTRA_ARGS} --build-arg SKIPTESTS=${SKIPTESTS} "
fi

if [[ -n "${RELEASE_DOCKERFILE_OVERWRITE}" ]]; then
  if [[ ! -f "${UITSMIJTER_BINARY}" ]]; then
    echo "Warning: Release with overwritten Dockerfile but ${UITSMIJTER_BINARY} not found." >&2
    UITSMIJTER_BINARY=${PROJECT_DIR}/.build/debug/Uitsmijter
    echo "Warning: Falling back to ${UITSMIJTER_BINARY}" >&2
  fi
  if [[ ! -f "${UITSMIJTER_BINARY}" ]]; then
    echo "Error: Release with overwritten Dockerfile but ${UITSMIJTER_BINARY} not found." >&2
    echo "Error: You can build it with ./tooling.sh build" >&2
    exit 2
  fi

  cp "${UITSMIJTER_BINARY}" "${PROJECT_DIR}/"
fi

docker build \
   ${TAG} \
   --file ${DOCKERFILE} \
   --build-arg BASEIMAGE=${BASEIMAGE} \
   --build-arg BUILDBOX=${BUILDBOX} \
   ${SSH_ARGS} \
   ${EXTRA_ARGS} \
   ${SCRIPT_DIR}/../..

if [[ -n "${RELEASE_DOCKERFILE_OVERWRITE}" ]]; then
  rm -f "${PROJECT_DIR}/Uitsmijter"
fi
