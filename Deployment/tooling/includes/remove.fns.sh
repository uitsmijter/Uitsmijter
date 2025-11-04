#
# Clean functions
#
# This file contains functions for cleaning up Docker resources and build artifacts.
# These functions help maintain a clean development environment by removing
# containers, images, volumes, and build directories related to Uitsmijter.
#

# Remove all Docker containers related to Uitsmijter
# Parameters: None
# Returns: None
# Side effects: Force-removes all containers with 'uitsmijter' in the image name
# Use case: Clean up before rebuilding or when containers are in a bad state
function removeContainer() {
  h2 "Clean up docker container"
  for container in $(docker ps -a --format="{{.ID}}\t{{.Image}}" | grep 'uitsmijter' | cut -f -1); do
    docker rm -f "${container}"
  done;
}

# Remove all Docker images related to Uitsmijter
# Parameters: None
# Returns: None
# Side effects: Force-removes all images with 'uitsmijter' in the repository name
# Use case: Free up disk space or force complete rebuild from scratch
function removeImages() {
  h2 "Clean up docker images"
  for image in $(docker images --format="{{.Repository}}:{{.Tag}}" | grep 'uitsmijter'); do
    docker rmi -f "${image}"
  done;
}

# Remove all Docker volumes related to Uitsmijter
# Parameters: None
# Returns: None
# Side effects: Removes all volumes with 'uitsmijter' in the name
# Use case: Clean up persistent data, reset databases/caches for testing
function removeVolumes() {
  h2 "Clean up docker volumes"
  for vol in $(docker volume ls --format '{{.Name}}' | grep 'uitsmijter'); do
    docker volume rm "${vol}"
  done;
}

# Remove the .build directory containing build artifacts
# Parameters: None (uses PROJECT_DIR variable)
# Returns: None
# Side effects: Recursively removes ${PROJECT_DIR}.build directory
# Use case: Clean build artifacts, free disk space, or reset build state
function removeBuild() {
  h2 "Clean up build directory"
  rm -rf "${PROJECT_DIR}.build"
}
