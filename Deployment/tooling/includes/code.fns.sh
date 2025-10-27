#
# Code functions
#
# This file contains functions for opening and managing code-server
# (web-based VS Code) for remote or containerized development.
#

# Open the project in a web-based code editor (code-server)
# Parameters: None (uses dockerComposeBuildParameter from environment)
# Returns: None
# Side effects:
#   - Starts code-server container in detached mode
#   - Opens browser to http://localhost:31546/?folder=/Project
#   - Waits for user to press enter, then stops the container
# Interactive: Prompts user to press enter to stop code-server
# Platform-specific: Uses 'open' on macOS, 'xdg-open' on Linux
# Use case: Remote development or containerized editing environment
function openCode() {
  h2 "Open project in code"
  docker compose \
    -f "${PROJECT_DIR}/Deployment/build-compose.yml" \
    --env-file "${PROJECT_DIR}/.env" \
    up \
    ${dockerComposeBuildParameter} \
    --detach --wait \
    code

  sleep 2
  if [ "$(uname -s)" == "Darwin" ]; then
    open http://localhost:31546/?folder=/Project
  else
    which xdg-open && true
    if [ "$?" == "0" ]; then
      xdg-open http://localhost:31546/?folder=/Project
    fi
  fi
  echo ""
  echo "Press enter to stop the code-server."
  read -r
  docker compose -f "${SCRIPT_DIR}/Deployment/build-compose.yml" down code


}
