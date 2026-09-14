#!/usr/bin/env bash
# Build a signed App Store IPA and reveal it for Transporter.
#
#   scripts/build_ios.sh              # build number from pubspec
#   scripts/build_ios.sh 3            # override the build number
#
# Drag the revealed .ipa into Transporter and hit Deliver.
#
# App Store Connect rejects a build number it has already seen for this
# version, so bump it on every re-upload (either the argument here or the
# +N in apps/sudoku/pubspec.yaml).
#
# The app record must already exist in App Store Connect; neither
# Transporter nor the API can create one.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/apps/sudoku"
ENTRY=lib/main_prod.dart

cd "$APP"
BUILD_NAME="$(grep '^version:' pubspec.yaml | sed -E 's/^version: *([^+]+)\+.*/\1/')"
BUILD_NUMBER="${1:-$(grep '^version:' pubspec.yaml | sed -E 's/^.*\+//')}"

printf '\n\033[1;34m▶ Building %s (%s) from %s\033[0m\n' "$BUILD_NAME" "$BUILD_NUMBER" "$ENTRY"
# Real ad unit ids live outside the repo; without them the prod flavor
# falls back to Google's test units and earns nothing. ad_units.sh exits
# non-zero if they are missing, and set -e stops the build. docs/ad-units.md
AD_DEFINES="$(tool/ad_units.sh)"

# shellcheck disable=SC2086
flutter build ipa -t "$ENTRY" \
  --build-name="$BUILD_NAME" \
  --build-number="$BUILD_NUMBER" \
  $AD_DEFINES

IPA="$(ls "$APP"/build/ios/ipa/*.ipa | head -1)"
printf '\n\033[1;34m▶ %s\033[0m\n' "$IPA"
echo "Drag it into Transporter, then Deliver."
open -R "$IPA"
