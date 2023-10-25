#!/usr/bin/env bash
#
# Import all functions
#

imported_files=()
is_in_imported_files() {
    local needle="$1"
    shift 1

    local value
    for value in "${imported_files[@]}"; do
        [ "$value" = "$needle" ] && return 0
    done
    return 1
}

function include() {
  local SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
  local NAME=${1}
  if ! is_in_imported_files "${SCRIPT_DIR}/includes/${NAME}"; then
    imported_files+=("${SCRIPT_DIR}/includes/${NAME}")
    source "${SCRIPT_DIR}/includes/${NAME}"
  fi
}

# Imports `var` and `fns` files
function import(){
  local SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
  for sourceFile in ${SCRIPT_DIR}/includes/**.var.sh; do
    include "$(basename "${sourceFile}")"
  done
  for sourceFile in ${SCRIPT_DIR}/includes/**.fns.sh; do
    include "$(basename "${sourceFile}")"
  done
}

# Import all scripts
import;
