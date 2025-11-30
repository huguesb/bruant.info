#!/bin/bash
# Migrate Jekyll pages to Hugo format
# Usage: ./migrate-pages.sh <source_dir> <dest_dir>

set -e

SRC="${1:?Usage: $0 <source_dir> <dest_dir>}"
DEST="${2:?Usage: $0 <source_dir> <dest_dir>}"

mkdir -p "$DEST"

for f in "$SRC"/*.md; do
    [[ -f "$f" ]] || continue

    basename=$(basename "$f")

    # Read existing front matter and content
    {
        echo "---"
        # Copy existing front matter (skip opening ---), removing 'layout: page'
        sed -n '/^---$/,/^---$/p' "$f" | tail -n +2 | head -n -1 | grep -v '^layout:'
        echo "---"
        # Copy content after front matter
        sed -n '/^---$/,/^---$/!p' "$f" | tail -n +2
    } > "$DEST/$basename"

    echo "Converted $basename"
done

echo "Done. Review $DEST/"
