#
# Options that can be set
#

# Enable debug mode with DEBUG=1, or --debug flag
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
