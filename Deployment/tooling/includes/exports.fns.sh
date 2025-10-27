#
# Export functions
#
# This file contains functions for exporting environment variables with default values.
# These exports ensure variables are set for use in Docker Compose and other scripts.
# All variables are exported with their current value or an empty string if unset.
#

# Export default values for commonly used environment variables
#
# This function ensures all required environment variables are defined before running
# Docker Compose, build scripts, or test runners. Variables are only set if not already
# defined, preserving any existing values from the environment or .env file.
#
# Parameters: None
# Returns: None
# Side effects: Exports environment variables if not already set
#
# Environment Variables Exported:
#   RUNTIME_IMAGE
#     Purpose: Specifies the Docker runtime image name and tag for deployments
#     Default: Empty string (uses docker-compose.yml defaults)
#     Example: "uitsmijter:main-abc123"
#     Used by: buildRuntime(), e2eTests(), runInKubernetesInDocker()
#
#   GITHUB_ACTION
#     Purpose: Flag indicating if running in GitHub Actions CI environment
#     Default: Empty string (false)
#     Values: "" (not in CI) or "true" (in GitHub Actions)
#     Used by: CI-specific conditional logic in test runners
#
#   ARGUMENTS
#     Purpose: Additional command-line arguments passed to test runners or other tools
#     Default: Empty string
#     Example: "--browser chromium" for e2e tests
#     Used by: e2eTests(), Playwright test runner
#
#   SUPPRESS_PACKAGE_WARNINGS
#     Purpose: Suppresses Swift package resolution warnings during build and test
#     Default: Empty string (show warnings)
#     Values: "" (show warnings) or any non-empty value (suppress warnings)
#     Used by: unitTests(), unitTestsList(), buildIncrementalBinary()
#     Behavior: When set, filters out "warning:" lines from Swift package output
#
#   FILTER_TEST
#     Purpose: Filters which Swift tests to run by name pattern
#     Default: Empty string (run all tests)
#     Format: "TargetName.TestSuite/testMethod" or "TargetName.TestSuite"
#     Example: "ServerTests.LoginControllerTests/testLoginSuccess"
#     Used by: unitTests(), unitTestsList()
#
# Use case: Called early in tooling.sh to ensure all scripts have required variables
function exportDefaults() {
    export RUNTIME_IMAGE=${RUNTIME_IMAGE:-}
    export GITHUB_ACTION=${GITHUB_ACTION:-}
    export ARGUMENTS=${ARGUMENTS:-}
    export SUPPRESS_PACKAGE_WARNINGS=${SUPPRESS_PACKAGE_WARNINGS:-}
    export FILTER_TEST=${FILTER_TEST:-}
}

