#!/bin/bash
# Migrate Jekyll posts to Hugo format
# Usage: ./migrate-posts.sh <source_dir> <dest_dir>
#
# Converts:
#   _posts/YYYY-MM-DD-slug.md -> content/posts/slug.md (with date in front matter)
#   {% highlight lang %} -> ```lang

set -e

SRC="${1:?Usage: $0 <source_dir> <dest_dir>}"
DEST="${2:?Usage: $0 <source_dir> <dest_dir>}"

mkdir -p "$DEST"

for f in "$SRC"/*.md; do
    [[ -f "$f" ]] || continue

    basename=$(basename "$f")

    # Extract date from filename (YYYY-MM-DD-slug.md)
    date=$(echo "$basename" | grep -oE '^[0-9]{4}-[0-9]{2}-[0-9]{2}')

    # Strip date prefix from filename to get slug
    slug=$(echo "$basename" | sed 's/^[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}-//')

    # Read existing front matter and content, converting highlight tags
    {
        # First line of front matter
        echo "---"
        # Add date to front matter
        echo "date: $date"
        # Copy existing front matter (skip opening ---), removing 'layout: post'
        # Also decode HTML entities in titles (Jekyll stored them escaped, Hugo escapes on output)
        sed -n '/^---$/,/^---$/p' "$f" | tail -n +2 | head -n -1 | grep -v '^layout:' | \
            sed 's/&amp;/\&/g; s/&lt;/</g; s/&gt;/>/g'
        echo "---"
        # Copy content after front matter, converting Jekyll highlight to Hugo fenced blocks
        sed -n '/^---$/,/^---$/!p' "$f" | tail -n +2 | \
            sed 's/{%\s*highlight\s*\(\w*\)\s*%}/```\1/g' | \
            sed 's/{%\s*endhighlight\s*%}/```/g'
    } > "$DEST/$slug"

    echo "Converted $basename -> $slug"
done

echo "Done. Review $DEST/"
