#!/usr/bin/env bash
# Generate Google Play store graphics into build/store/.
#
# Play requires both of these before a listing can be submitted:
#   icon-512.png            512x512, the listing icon
#   feature-graphic.png     1024x500, shown at the top of the listing
#
# App Store Connect needs neither: it pulls the icon out of the uploaded
# build's asset catalog.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

OUT=build/store
mkdir -p "$OUT"

# Play shows the icon under its own rounded mask, so supply it full-bleed
# and square. Flattened because Play rejects transparency in the icon.
rsvg-convert -w 512 -h 512 tool/app_icon.svg -o "$OUT/icon-512.tmp.png"
magick "$OUT/icon-512.tmp.png" -background white -flatten -alpha off \
  -define png:color-type=2 "PNG24:$OUT/icon-512.png"
rm -f "$OUT/icon-512.tmp.png"

rsvg-convert -w 1024 -h 500 tool/feature_graphic.svg -o "$OUT/feature-graphic.tmp.png"
magick "$OUT/feature-graphic.tmp.png" -background white -flatten -alpha off \
  -define png:color-type=2 "PNG24:$OUT/feature-graphic.png"
rm -f "$OUT/feature-graphic.tmp.png"

echo "▶ $OUT"
magick identify -format "%f  %wx%h  ch=%[channels]\n" "$OUT"/*.png
