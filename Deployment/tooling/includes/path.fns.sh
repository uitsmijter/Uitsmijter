#
# Functions to handle paths
#
# This file contains path manipulation and directory management functions
# used throughout the tooling scripts.
#

include "path.var.sh"

# Ensure the build directory exists, create it if it doesn't
# Parameters: None (uses BUILD_DIR from path.var.sh)
# Returns: None
# Side effects: Creates BUILD_DIR directory if it doesn't exist
# Used for: Preparing workspace for build artifacts and temporary files
function pathPrepareBuildDir() {
  [[ -d "${BUILD_DIR}" ]] || mkdir "${BUILD_DIR}"
}
