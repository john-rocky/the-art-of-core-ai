#!/usr/bin/env bash
# Rebuild docs/index.html from chapters/.
#
# ⚠️ READ THIS BEFORE RUNNING IT ON THE PUBLISHED PAGE.
#
# The published docs/index.html was built with an older pandoc, and this script does not
# reproduce it byte for byte. Rebuilding with a current pandoc (verified against 3.9.0.2)
# changes every heading anchor:
#
#     published : #chapter-1--it-wasnt-compute-that-caught-up      (em dash -> two hyphens)
#     rebuilt   : #chapter-1-it-wasnt-compute-that-caught-up       (em dash -> one hyphen)
#
# and turns straight apostrophes into typographic ones. The anchors are the problem: the
# table of contents and any link anyone has made into a chapter would break. So do not run
# this to make a small edit — the diff will be the whole document.
#
# It exists because the recipe was not in the repository at all. The page is generated, and
# until now the command that generated it lived only in one shell's history, which meant the
# published book could not be rebuilt by anyone, including its author on a new machine.
#
# If you do rebuild deliberately (a new chapter, a real revision), expect the anchor change,
# and say so wherever the old anchors were linked.
#
#     ./build.sh          # rebuild docs/index.html
#
set -euo pipefail
cd "$(dirname "$0")"

TITLE="The Art of Core AI"
OUT="docs/index.html"

# Chapter order is filename order: 01..14 then lab-0..lab-6, which is what the glob gives.
pandoc chapters/*.md \
    --standalone \
    --toc \
    --metadata title="$TITLE" \
    --output "$OUT"

# The site styling is appended after </html> rather than passed to pandoc — that is how the
# published page is built, and docs/book.css was recovered from it.
cat docs/book.css >> "$OUT"

echo "wrote $OUT ($(wc -l < "$OUT") lines)"
