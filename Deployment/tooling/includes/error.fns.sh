#
# Functions to handle errors
#

# Print out an error message and exit with err:1
function die() {
  local msg="$@"
  echo "${msg}" >&2 1>/dev/null

  echo ""
  h2 "${SYMBOL_FAIL}  ERROR"
  echoBox "${msg}" "!"
  echo ""
  exit 1
}
