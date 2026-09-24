#!/usr/bin/env bash
# Regenerates the bundled NagaMono subsets from the full JetBrains Mono files.
# The retro renderers only draw ASCII; Latin-1 and a few symbols are kept as
# headroom. Ligature and contextual-alternate features are dropped: no string
# drawn in NagaMono uses them, and they account for most of the glyphs. Requires fonttools (pip install fonttools).
set -euo pipefail
cd "$(dirname "$0")/.."
UNICODES="U+0020-007E,U+00A0-00FF,U+2022,U+2190-2193,U+2500-257F,U+2580-259F,U+2665,U+221E"
for weight in Regular Bold; do
  pyftsubset "tool/fonts/JetBrainsMono-$weight.ttf" \
    --unicodes="$UNICODES" \
    --layout-features="kern,mark,mkmk" --no-hinting --desubroutinize \
    --output-file="assets/fonts/JetBrainsMono-$weight.ttf"
done
ls -l assets/fonts/*.ttf
