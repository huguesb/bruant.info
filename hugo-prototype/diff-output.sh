#!/bin/bash
# Compare Jekyll and Hugo output
# Usage: ./diff-output.sh [file-pattern]
#
# Examples:
#   ./diff-output.sh                    # Compare all HTML files
#   ./diff-output.sh articles           # Compare only articles
#   ./diff-output.sh index.html         # Compare specific file

JEKYLL_DIR="/home/hugues/repos/personal/bruant.info/_site"
HUGO_DIR="/home/hugues/repos/personal/bruant.info/hugo-prototype/public"

PATTERN="${1:-}"

# Normalize HTML for comparison:
# - Remove Hugo generator meta tag
# - Remove livereload script (from hugo server)
# - Normalize whitespace
normalize() {
    sed 's/<meta name="generator"[^>]*>//g' | \
    sed 's/<script src="\/livereload.js[^>]*><\/script>//g' | \
    sed 's/[[:space:]]*$//' | \
    grep -v '^[[:space:]]*$'
}

# Find matching files
if [[ -n "$PATTERN" ]]; then
    JEKYLL_FILES=$(find "$JEKYLL_DIR" -type f -name "*.html" -path "*$PATTERN*" | sort)
else
    JEKYLL_FILES=$(find "$JEKYLL_DIR" -type f -name "*.html" | sort)
fi

for jf in $JEKYLL_FILES; do
    # Convert Jekyll path to Hugo path
    # /foo/bar.html -> /foo/bar/index.html
    rel=${jf#$JEKYLL_DIR}
    if [[ "$rel" == */index.html ]]; then
        hf="$HUGO_DIR$rel"
    else
        # foo.html -> foo/index.html
        hf="$HUGO_DIR${rel%.html}/index.html"
    fi

    if [[ -f "$hf" ]]; then
        # Compare normalized versions
        if ! diff -q <(normalize < "$jf") <(normalize < "$hf") > /dev/null 2>&1; then
            echo "=== $rel ==="
            diff --color=always -y -W "${COLUMNS:-180}" <(normalize < "$jf") <(normalize < "$hf") | head -80
            echo
        fi
    else
        echo "Missing in Hugo: $rel"
    fi
done
