#!/usr/bin/env bash
# One-time (idempotent) project bootstrap. Run from anywhere:
#   ./scripts/bootstrap.sh
#
# 1. checks the Flutter toolchain
# 2. resolves the pub workspace
# 3. generates android/ + ios/ for apps/nonogram if missing (flutter create)
# 4. patches the real AdMob app ids, iOS 15 deployment target, ATT text and
#    SKAdNetwork into the platform projects
# 5. generates localizations, runs analyze + all tests
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/apps/nonogram"
ORG="io.pinkspider"

# AdMob *app* ids — the real ones (created 2026-09-15).
#
# Console: https://apps.admob.com (account: developer.ygpark@gmail.com).
# The 6 ad *unit* ids live outside the repo in
# ~/.pink-spider/secrets/nonogram/ad-units.env — see docs/ad-units.md.
ADMOB_APP_ID_ANDROID="ca-app-pub-6329038356545416~7260119820"
ADMOB_APP_ID_IOS="ca-app-pub-6329038356545416~4365354012"

say() { printf '\n\033[1;34m▶ %s\033[0m\n' "$*"; }
die() { printf '\033[1;31m✖ %s\033[0m\n' "$*" >&2; exit 1; }

# ---------------------------------------------------------------- 1. toolchain
say "Checking Flutter"
command -v flutter >/dev/null || die "flutter not on PATH. Install: https://docs.flutter.dev/get-started/install/macos"
FLUTTER_VERSION="$(flutter --version --machine 2>/dev/null | python3 -c 'import json,sys; print(json.load(sys.stdin)["frameworkVersion"])')"
python3 - "$FLUTTER_VERSION" <<'PY' || die "Flutter >= 3.29 required (found $FLUTTER_VERSION). Run: flutter upgrade"
import sys
v = tuple(int(x) for x in sys.argv[1].split('.')[:2])
sys.exit(0 if v >= (3, 29) else 1)
PY
echo "Flutter $FLUTTER_VERSION"

# ------------------------------------------------------------- 2. workspace
say "Resolving pub workspace"
cd "$ROOT"
flutter pub get

# ------------------------------------------------------ 3. platform folders
cd "$APP"
if [[ ! -d android || ! -d ios ]]; then
  say "Generating android/ and ios/ (flutter create)"
  # Keep our files: flutter create must not touch these.
  tmp="$(mktemp -d)"
  cp pubspec.yaml "$tmp/pubspec.yaml"
  cp -R lib "$tmp/lib"
  [[ -d test ]] && cp -R test "$tmp/test"
  flutter create --no-pub --platforms=android,ios --org "$ORG" --project-name nonogram . >/dev/null
  cp "$tmp/pubspec.yaml" pubspec.yaml
  rm -rf lib && cp -R "$tmp/lib" lib
  if [[ -d "$tmp/test" ]]; then rm -rf test && cp -R "$tmp/test" test; fi
  rm -f test/widget_test.dart 2>/dev/null || true
  # The template's analysis_options would shadow the workspace one.
  rm -f analysis_options.yaml
  rm -rf "$tmp"
  # Re-resolve now that platform plugins can be registered.
  (cd "$ROOT" && flutter pub get)
else
  echo "android/ and ios/ already exist — skipping flutter create"
fi

# ----------------------------------------------------- 4. platform patches
say "Patching Android (AdMob app id)"
"$ROOT/scripts/lib/set_admob_app_id.py" \
  android/app/src/main/AndroidManifest.xml "$ADMOB_APP_ID_ANDROID"

say "Patching iOS (deployment target, AdMob app id, ATT text, SKAdNetwork)"
# App Store Connect rejects uploads below iOS 15 (warning 90068; hard cutoff
# Spring 2027), and the Flutter template still emits 13.0. Unlike minSdk,
# this one does need patching -- flutter build does not regenerate pbxproj.
sed -i '' -E 's/IPHONEOS_DEPLOYMENT_TARGET = 1[34]\.0;/IPHONEOS_DEPLOYMENT_TARGET = 15.0;/g' \
  ios/Runner.xcodeproj/project.pbxproj
sed -i '' -E "s/^#? ?platform :ios, '[0-9.]+'/platform :ios, '15.0'/" ios/Podfile

PLIST="ios/Runner/Info.plist"
PB=/usr/libexec/PlistBuddy
# PlistBuddy, not plutil: plutil -insert with -json silently rewrites the
# whole file when the key path does not exist yet.
"$PB" -c "Delete :GADApplicationIdentifier" "$PLIST" 2>/dev/null || true
"$PB" -c "Add :GADApplicationIdentifier string $ADMOB_APP_ID_IOS" "$PLIST"
"$PB" -c "Delete :NSUserTrackingUsageDescription" "$PLIST" 2>/dev/null || true
"$PB" -c "Add :NSUserTrackingUsageDescription string 'Allowing this keeps Nonogram Daily free — it lets us show ads that fit you instead of random ones.'" "$PLIST"
"$PB" -c "Delete :CFBundleDisplayName" "$PLIST" 2>/dev/null || true
"$PB" -c "Add :CFBundleDisplayName string 'Nonogram Daily'" "$PLIST"
# Declares we use no non-exempt encryption, so App Store Connect stops
# asking the export-compliance question on every single upload.
"$PB" -c "Delete :ITSAppUsesNonExemptEncryption" "$PLIST" 2>/dev/null || true
"$PB" -c "Add :ITSAppUsesNonExemptEncryption bool false" "$PLIST"
if ! "$PB" -c "Print :SKAdNetworkItems" "$PLIST" >/dev/null 2>&1; then
  # Google's own network id. Add the full list from
  # https://developers.google.com/admob/ios/ios14#skadnetwork before release.
  "$PB" -c "Add :SKAdNetworkItems array" "$PLIST"
  "$PB" -c "Add :SKAdNetworkItems:0 dict" "$PLIST"
  "$PB" -c "Add :SKAdNetworkItems:0:SKAdNetworkIdentifier string cstr6suwn9.skadnetwork" "$PLIST"
fi
# --------------------------------------------------------- 5. generate + verify
say "Generating app icons and launch images"
./tool/gen_icons.sh

say "Localizing Info.plist strings (ATT prompt)"
./tool/gen_infoplist_strings.sh

say "Generating localizations"
flutter gen-l10n

say "flutter analyze"
cd "$ROOT"
flutter analyze

say "Running tests"
(cd packages/puzzle_engine && dart test)
(cd packages/rules_nonogram && dart test)
(cd packages/core_ads && flutter test)
(cd apps/nonogram && flutter test)

say "Done. Next:"
cat <<EOF
  cd apps/nonogram
  flutter run -t lib/main_dev.dart          # dev flavor (test ads)
  flutter run -t lib/main_prod.dart         # prod entrypoint

  Release builds need the secrets in ~/.pink-spider/secrets/nonogram/:
   - ad-units.env (docs/ad-units.md). The release scripts refuse to build
     without it -- prod would otherwise fall back to Google's test units.
   - upload-keystore.jks + key.properties (docs/android-signing.md)
   - play-store-key.json for 'fastlane internal|production'
     (docs/play-api-automation.md)

  The consent form only appears while the GDPR + IDFA messages are
  published in AdMob -> Privacy & messaging (docs/admob-setup.md).

  Still not done:
   - Firebase (google-services.json / GoogleService-Info.plist) and
     a Firebase-backed AnalyticsService / RemoteConfigService

  Always check a release build on a device before submitting — debug
  builds skip R8, which is how a startup crash reached Play review once.
EOF
