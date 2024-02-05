#
# Code functions
#

# Open a code edior
function openCode() {
  h2 "Open project in code"
  docker-compose \
    -f "${PROJECT_DIR}/Deployment/docker-compose.yml" \
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
  docker-compose -f "${SCRIPT_DIR}/Deployment/docker-compose.yml" down code


}
