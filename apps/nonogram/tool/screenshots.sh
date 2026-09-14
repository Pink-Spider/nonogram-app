#!/usr/bin/env bash
# Capture store screenshots on a simulator, for every supported locale.
#
#   tool/screenshots.sh [simulator-name]
#
# Default device is the iPhone 17 Pro Max, whose 1320x2868 output is the
# 6.9" size App Store Connect requires. Play accepts the same files.
# Output lands in build/screenshots/<locale>-<n>-<state>.png.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

DEVICE="${1:-iPhone 17 Pro Max}"
UDID="$(xcrun simctl list devices available \
        | grep -F "$DEVICE (" | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')"
[[ -n "$UDID" ]] || { echo "✖ simulator not found: $DEVICE" >&2; exit 1; }

echo "▶ $DEVICE ($UDID)"
xcrun simctl boot "$UDID" 2>/dev/null || true

rm -rf build/screenshots
flutter drive \
  --driver=test_driver/screenshots_driver.dart \
  --target=integration_test/screenshots_test.dart \
  -d "$UDID"

echo
echo "▶ build/screenshots"
ls build/screenshots
