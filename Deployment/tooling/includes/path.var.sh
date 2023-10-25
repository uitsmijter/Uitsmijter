#
# Paths used in this project
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
PROJECT_DIR="$(realpath "${SCRIPT_DIR}/../../..")"
BUILD_DIR=${PROJECT_DIR}/.build
