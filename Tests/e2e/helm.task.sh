#!/usr/bin/env bash

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

ICON_FAIL="❌"
ICON_PASS="✓"
ICON_ALLOK=""

globalfail=0

# Test if all generated yaml's are valid
headline() {
  local NAME=${1}
  local length=$((${#NAME}+2))
  echo "🧪 ${NAME}"
  for ((i=1; i <= length; i++)); do
  	printf '⏤'
  done;
  echo ""
}

result() {
  local name=${1}
  local err=${2}
  if [ "${err}" -gt 0 ]; then
    globalfail=1
    echo "Test ${name} result: ${ICON_FAIL} Failed"
  else
    echo "Test ${name} result: ${ICON_PASS} Pass"
  fi;
}

test_helm() {
  local NAME=${1}

  mkdir -p "./results/"
  mkdir -p "/output/${NAME}"

  helm template uitsmijter /helm/uitsmijter -f "${NAME}.yaml" --output-dir "/output/${NAME}" >> /dev/null

  err=0
  yamllint "/output/${NAME}/uitsmijter/templates" > ./results/${NAME} || err=1
  result "yaml" "${err}"
}

test_case() {
  local NAME=${1}
  if [ -f "${NAME}-test.sh" ]; then
    err=0
    eval "./${NAME}-test.sh /output/${NAME}" || err=1
    result "case" "${err}"
  fi
}

pushd "${SCRIPT_DIR}/helm"
  IFS=$'\n'
  TESTS=($(find . -name "*.yaml"))
  unset IFS

  for TEST in "${TESTS[@]}"; do
    TESTBASENAME=$(basename "${TEST}" .yaml)
    headline "${TESTBASENAME}"
    test_helm "${TESTBASENAME}"
    test_case "${TESTBASENAME}"
    echo ""
  done;
  if [ "${globalfail}" -gt 0 ]; then
    echo ""
    echo "${ICON_FAIL} Some errors occurred. Please see list above for more details."
    exit 1;
  else
    echo "${ICON_ALLOK} All tests pass."; echo ""
  fi;
popd
