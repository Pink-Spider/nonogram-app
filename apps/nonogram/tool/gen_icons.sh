#!/usr/bin/env bash
# Rasterize tool/app_icon.svg into the iOS AppIcon set.
# iOS icons must be opaque (no alpha), so every size is flattened.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
SVG=tool/app_icon.svg
OUT=ios/Runner/Assets.xcassets/AppIcon.appiconset

render() { # px, filename
  rsvg-convert -w "$1" -h "$1" "$SVG" -o "$OUT/$2.tmp.png"
  magick "$OUT/$2.tmp.png" -background white -flatten -alpha off -define png:color-type=2 "PNG24:$OUT/$2"
  rm -f "$OUT/$2.tmp.png"
}

render 40   Icon-App-20x20@2x.png
render 60   Icon-App-20x20@3x.png
render 20   Icon-App-20x20@1x.png
render 29   Icon-App-29x29@1x.png
render 58   Icon-App-29x29@2x.png
render 87   Icon-App-29x29@3x.png
render 40   Icon-App-40x40@1x.png
render 80   Icon-App-40x40@2x.png
render 120  Icon-App-40x40@3x.png
render 120  Icon-App-60x60@2x.png
render 180  Icon-App-60x60@3x.png
render 76   Icon-App-76x76@1x.png
render 152  Icon-App-76x76@2x.png
render 167  Icon-App-83.5x83.5@2x.png
render 1024 Icon-App-1024x1024@1x.png

echo "app icons regenerated from $SVG"

# Launch screen mark (centred on the storyboard's white background).
LAUNCH=ios/Runner/Assets.xcassets/LaunchImage.imageset
render_launch() { # px, filename
  rsvg-convert -w "$1" -h "$1" tool/launch_mark.svg -o "$LAUNCH/$2"
}
render_launch 200 LaunchImage.png
render_launch 400 LaunchImage@2x.png
render_launch 600 LaunchImage@3x.png
echo "launch images regenerated from tool/launch_mark.svg"

# ---------------------------------------------------------------------------
# Android launcher icons.
#
# This used to be missing: gen_icons.sh only did iOS, so the Flutter template's
# blue logo shipped as the launcher icon while the Play listing showed the
# sudoku grid. Play rejected the app for it — "the installed icon or name
# differs from the store listing" (2026-09-10). Do not drop this section.
RES=android/app/src/main/res

render_android() { # px, density
  local px="$1" dir="$RES/mipmap-$2"
  mkdir -p "$dir"
  rsvg-convert -w "$px" -h "$px" "$SVG" -o "$dir/ic_launcher.tmp.png"
  # Legacy icon: opaque, the launcher masks it itself.
  magick "$dir/ic_launcher.tmp.png" -background white -flatten -alpha off \
    -define png:color-type=2 "PNG24:$dir/ic_launcher.png"
  rm -f "$dir/ic_launcher.tmp.png"
}

render_android 48  mdpi
render_android 72  hdpi
render_android 96  xhdpi
render_android 144 xxhdpi
render_android 192 xxxhdpi

# Adaptive icon (Android 8+). The launcher crops the foreground to whatever
# shape the device uses, so the artwork sits in the middle 66% safe zone:
# render at 72/108 of the canvas and pad the rest transparent.
render_adaptive() { # px, density
  local px="$1" dir="$RES/mipmap-$2" inner
  inner=$(( px * 72 / 108 ))
  mkdir -p "$dir"
  rsvg-convert -w "$inner" -h "$inner" "$SVG" -o "$dir/fg.tmp.png"
  magick "$dir/fg.tmp.png" -background none -gravity center \
    -extent "${px}x${px}" "PNG32:$dir/ic_launcher_foreground.png"
  rm -f "$dir/fg.tmp.png"
}

render_adaptive 108 mdpi
render_adaptive 162 hdpi
render_adaptive 216 xhdpi
render_adaptive 324 xxhdpi
render_adaptive 432 xxxhdpi

mkdir -p "$RES/mipmap-anydpi-v26" "$RES/values"
cat > "$RES/mipmap-anydpi-v26/ic_launcher.xml" <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
XML

# Matches the board background in tool/app_icon.svg.
cat > "$RES/values/ic_launcher_background.xml" <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#FFFFFF</color>
</resources>
XML

echo "android launcher icons regenerated from $SVG"
