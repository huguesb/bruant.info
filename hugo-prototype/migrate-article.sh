#!/bin/bash
# Migrate a Jekyll article to Hugo format
# Usage: ./migrate-article.sh <source_dir> <dest_dir>
#
# Converts:
#   _articles/foo/00-intro.md -> content/articles/foo/00-intro.md (with weight from filename)
#   _articles/foo/_article.yml -> content/articles/foo/_index.md
#   {% highlight lang %} -> ```lang
#   {% endhighlight %} -> ```

set -e

SRC="${1:?Usage: $0 <source_dir> <dest_dir>}"
DEST="${2:?Usage: $0 <source_dir> <dest_dir>}"

mkdir -p "$DEST"

# Convert _article.yml to _index.md
if [[ -f "$SRC/_article.yml" ]]; then
    echo "---" > "$DEST/_index.md"
    # Filter out 'special:' line as Hugo handles this differently
    grep -v '^special:' "$SRC/_article.yml" >> "$DEST/_index.md"
    echo "---" >> "$DEST/_index.md"
    echo "Converted _article.yml -> _index.md"
fi

# Create full.md for single-page view
TITLE=$(grep '^title:' "$SRC/_article.yml" | sed 's/^title: *//')
cat > "$DEST/full.md" << EOF
---
title: $TITLE
layout: full
---
EOF
echo "Created full.md"

# Convert section files
for f in "$SRC"/[0-9]*.md; do
    [[ -f "$f" ]] || continue

    basename=$(basename "$f")
    # Extract numeric prefix (e.g., "00-intro.md" -> "00", "99-conclusion.md" -> "99")
    prefix=$(echo "$basename" | sed 's/-.*//')
    # Convert to integer and add 1 (00 -> 1, 01 -> 2, 99 -> 100)
    weight=$((10#$prefix + 1))

    # Read existing front matter and content, converting highlight tags
    {
        echo "---"
        # Add weight to front matter
        echo "weight: $weight"
        # Copy existing front matter (skip opening ---)
        sed -n '/^---$/,/^---$/p' "$f" | tail -n +2 | head -n -1
        echo "---"
        # Copy content after front matter, converting Jekyll highlight to Hugo fenced blocks
        sed -n '/^---$/,/^---$/!p' "$f" | tail -n +2 | \
            sed 's/{%\s*highlight\s*\(\w*\)\s*%}/```\1/g' | \
            sed 's/{%\s*endhighlight\s*%}/```/g'
    } > "$DEST/$basename"

    echo "Converted $basename (weight: $weight)"
done

echo "Done. Review $DEST/"
