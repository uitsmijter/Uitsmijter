#
# Clean functions
#

# removes the docker container
function removeContainer() {
  h2 "Clean up docker container"
  for container in $(docker ps -a --format="{{.ID}}\t{{.Image}}" | grep 'uitsmijter' | cut -f -1); do
    docker rm -f "${container}"
  done;
}

# removes the docker images
function removeImages() {
  h2 "Clean up docker images"
  for image in $(docker images --format="{{.Repository}}:{{.Tag}}" | grep 'uitsmijter'); do
    docker rmi -f "${image}"
  done;
}

# removes the docker volumes
function removeVolumes() {
  h2 "Clean up docker volumes"
  for vol in $(docker volume ls --format '{{.Name}}' | grep 'uitsmijter'); do
    docker volume rm "${vol}"
  done;
}

function removeBuild() {
  h2 "Clean up build directory"
  rm -rf "${PROJECT_DIR}.build"
}
