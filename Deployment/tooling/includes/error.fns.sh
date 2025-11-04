#
# Functions to handle errors
#
# This file contains error handling functions for graceful script termination
# with formatted error messages.
#

# Print an error message and exit the script with exit code 1
# Parameters:
#   $@ - All arguments are concatenated into the error message
# Returns: Never returns (exits with code 1)
# Output: Displays formatted error message in a box with failure symbol
# Example: die "Docker daemon is not running"
# Example: die "Failed to build image:" "${IMAGE_NAME}"
function die() {
  local msg="$@"
  echo "${msg}" >&2 1>/dev/null

  echo ""
  h2 "${SYMBOL_FAIL}  ERROR"
  echoBox "${msg}" "!"
  echo ""
  exit 1
}
