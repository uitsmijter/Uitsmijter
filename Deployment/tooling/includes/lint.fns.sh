#
# Code style functions
#
# This file contains functions for running code quality and style checks
# using SwiftLint to enforce Swift coding standards.
#

# Source SwiftLint version variable
include "lint.var.sh"

# Run SwiftLint code style analysis on the project
# Parameters: None (uses SWIFTLINT_VERSION from lint.var.sh, PROJECT_DIR from environment)
# Returns: Exit code from SwiftLint (0 if no issues, non-zero if violations found)
# Side effects: Runs SwiftLint in Docker container, outputs violations to stdout
# Configuration: Uses .swiftlint.yml in PROJECT_DIR
# Use case: Enforce Swift coding standards and catch style violations
function lintCode() {
  h2 "Check code style"
  docker run --rm -v "${PROJECT_DIR}:${PROJECT_DIR}" -w "${PROJECT_DIR}" ghcr.io/realm/swiftlint:${SWIFTLINT_VERSION}
}
