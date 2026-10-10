#!/usr/bin/env bash
set -euo pipefail

# tools/subset-font.sh
# Subsets Vazirmatn variable font keeping wght axis range 300 to 700 and required Unicode ranges
# Ranges: U+0020-007E, U+00A0, U+0600-06FF, U+0750-077F, U+200C-200F, U+2026, U+2066-2069, U+06F0-06F9, U+066A-066C, U+FB50-FDFF, U+FE70-FEFF

SRC_FONT="${1:-app/assets/fonts/Vazirmatn/Vazirmatn-Variable.ttf}"
OUT_FONT="${2:-app/assets/fonts/Vazirmatn/Vazirmatn-Variable.ttf}"

if ! command -v pyftsubset &>/dev/null; then
    echo "pyftsubset not found. Please install fonttools: pip install fonttools"
    exit 1
fi

UNICODES="U+0020-007E,U+00A0,U+0600-06FF,U+0750-077F,U+200C-200F,U+2026,U+2066-2069,U+06F0-06F9,U+066A-066C,U+FB50-FDFF,U+FE70-FEFF"

pyftsubset "$SRC_FONT" \
    --unicodes="$UNICODES" \
    --layout-features="*" \
    --output-file="$OUT_FONT.tmp"

mv "$OUT_FONT.tmp" "$OUT_FONT"
echo "Subsetting complete: $OUT_FONT ($(du -h "$OUT_FONT" | cut -f1))"
