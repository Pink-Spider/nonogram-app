#!/usr/bin/env bash
# Copy tool/infoplist/<lang>.strings into ios/Runner/<lang>.lproj/ and
# register them with the Xcode project.
#
# The source of truth lives in tool/ rather than under ios/ so that
# regenerating the ios/ folder does not quietly lose the translations and
# leave every locale on the base English ATT prompt.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

LANGS=(en ko ja de)
for L in "${LANGS[@]}"; do
  mkdir -p "ios/Runner/$L.lproj"
  cp "tool/infoplist/$L.strings" "ios/Runner/$L.lproj/InfoPlist.strings"
done

# xcodeproj ships inside CocoaPods; there is no standalone install here.
GEM_DIR="$(ls -d /opt/homebrew/Cellar/cocoapods/*/libexec 2>/dev/null | tail -1 || true)"
if [[ -z "$GEM_DIR" ]]; then
  echo "!! xcodeproj (via CocoaPods) not found — InfoPlist.strings copied but NOT" >&2
  echo "!! registered in Xcode. Non-English ATT prompts will fall back to English." >&2
  exit 1
fi

GEM_HOME="$GEM_DIR" /usr/bin/ruby ../../scripts/lib/add_infoplist_strings.rb \
  ios/Runner.xcodeproj "${LANGS[@]}" 2>&1 | grep -v "^Ignoring " || true
