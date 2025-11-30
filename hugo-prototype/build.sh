#!/bin/bash
# Build the Hugo site
set -e
cd "$(dirname "$0")"
hugo build "$@"
echo "Build complete. Output in public/"
