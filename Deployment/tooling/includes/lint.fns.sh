#
# Code style functions
#

# Run code lint analysis
function lintCode() {
  h2 "Check code style"
  docker run -ti -v "${PROJECT_DIR}:${PROJECT_DIR}" -w "${PROJECT_DIR}" ghcr.io/realm/swiftlint:0.50.3
}
