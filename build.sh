#!/bin/bash
# Build script for bruant.info using Docker/Podman with Ruby 1.9.3 / Jekyll 1.2.1
#
# PREREQUISITES (rootless podman):
#   sudo usermod --add-subuids 100000-165535 --add-subgids 100000-165535 $USER
#   podman system migrate
#
# Then run: ./build.sh

set -e

IMAGE_NAME="bruant-jekyll:ruby193"
CONTAINER_CMD="${CONTAINER_CMD:-podman}"

# Check if container runtime is available
if ! command -v "$CONTAINER_CMD" &>/dev/null; then
    echo "Error: $CONTAINER_CMD not found"
    exit 1
fi

cd "$(dirname "$0")"

# Build the image if it doesn't exist
if ! $CONTAINER_CMD image inspect "$IMAGE_NAME" &>/dev/null; then
    echo "Building Docker image with Ruby 1.9.3..."
    $CONTAINER_CMD build -t "$IMAGE_NAME" -f Dockerfile.legacy .
fi

# Run Jekyll build
echo "Building site..."
$CONTAINER_CMD run --rm \
    -v "$(pwd):/site:Z" \
    -w /site \
    "$IMAGE_NAME" \
    bundle exec jekyll build

echo "Build complete. Output in _site/"
