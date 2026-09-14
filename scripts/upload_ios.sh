#!/usr/bin/env bash
# Build and upload an iOS build to TestFlight.
#
#   scripts/upload_ios.sh [build-number]
#
# Requires an App Store Connect API key:
#   App Store Connect -> Users and Access -> Integrations -> App Store Connect API
#   Create a key with the "App Manager" role, download the .p8 ONCE, and put it at
#     ~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8
#   Then export the two ids (add them to your shell profile):
#     export ASC_KEY_ID=XXXXXXXXXX
#     export ASC_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
#
# The app record must already exist in App Store Connect: the API has no
# endpoint to create one, so the first time you must add it in the web UI
# with bundle id io.pinkspider.nonogram.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/apps/nonogram"
ENTRY=lib/main_prod.dart

: "${ASC_KEY_ID:?set ASC_KEY_ID (App Store Connect API key id)}"
: "${ASC_ISSUER_ID:?set ASC_ISSUER_ID (App Store Connect issuer id)}"

KEY_FILE="$HOME/.appstoreconnect/private_keys/AuthKey_${ASC_KEY_ID}.p8"
[[ -f "$KEY_FILE" ]] || { echo "✖ missing $KEY_FILE" >&2; exit 1; }

say() { printf '\n\033[1;34m▶ %s\033[0m\n' "$*"; }

cd "$APP"

# Version comes from pubspec (0.1.0+1); build number can be overridden so a
# re-upload of the same version does not collide.
BUILD_NAME="$(grep '^version:' pubspec.yaml | sed -E 's/^version: *([^+]+)\+.*/\1/')"
BUILD_NUMBER="${1:-$(grep '^version:' pubspec.yaml | sed -E 's/^.*\+//')}"

say "Building $BUILD_NAME ($BUILD_NUMBER) from $ENTRY"
flutter build ipa -t "$ENTRY" \
  --build-name="$BUILD_NAME" \
  --build-number="$BUILD_NUMBER"

IPA="$(ls "$APP"/build/ios/ipa/*.ipa | head -1)"

say "Validating $(basename "$IPA")"
xcrun altool --validate-app --type ios --file "$IPA" \
  --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"

say "Uploading to App Store Connect"
xcrun altool --upload-app --type ios --file "$IPA" \
  --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"

say "Done. Processing takes ~5-15 min before the build appears in TestFlight."
