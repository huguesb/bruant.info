#!/bin/bash
# Serve the site locally for preview
# Uses Jekyll's built-in server on port 4000

set -e

IMAGE_NAME="bruant-jekyll:ruby193"
CONTAINER_CMD="${CONTAINER_CMD:-podman}"

cd "$(dirname "$0")"

# Build the image if it doesn't exist
if ! $CONTAINER_CMD image inspect "$IMAGE_NAME" &>/dev/null; then
    echo "Image not found. Run ./build.sh first."
    exit 1
fi

echo "Starting Jekyll server on http://localhost:4000"
echo "Press Ctrl+C to stop"

$CONTAINER_CMD run --rm -it \
    -v "$(pwd):/site:Z" \
    -w /site \
    -p 4000:4000 \
    "$IMAGE_NAME" \
    bundle exec jekyll serve --host 0.0.0.0
