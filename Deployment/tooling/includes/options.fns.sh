#
# Options that can be set
#
# This file contains functions for handling command-line options and flags,
# particularly for enabling debug mode in the tooling scripts.
#

# Enable or disable debug mode (shell command tracing)
# Parameters:
#   $1: DEBUG - Optional debug flag (uses DEBUG environment variable if not provided)
# Returns: None
# Side effects:
#   - If DEBUG is set/non-empty: Enables bash tracing (set -x), prints "Debug mode is turned on."
#   - If DEBUG is not set/empty: Disables bash tracing (set +x)
# Use case: Troubleshooting scripts by showing each command as it executes
# Example: DEBUG=1 ./tooling.sh build  (or) ./tooling.sh --debug build
function shouldDebug() {
  local DEBUG=${DEBUG:-${1}}
  if [  -n "${DEBUG}" ]; then
    echo "Debug mode is turned on."
    set -x
  else
    set +x
  fi
}
shouldDebug "${DEBUG}"
