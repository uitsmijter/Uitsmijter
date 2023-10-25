#
# Functions to handle paths
#

include "path.var.sh"

function pathPrepareBuildDir() {
  [[ -d "${BUILD_DIR}" ]] || mkdir "${BUILD_DIR}"
}
