#!/usr/bin/env bash
# Print the --dart-define flags for the real AdMob unit ids.
#
#   flutter build appbundle --release -t lib/main_prod.dart $(tool/ad_units.sh)
#
# The ids are not in the repo: a leaked unit id lets someone else serve it
# from their app, and the invalid traffic suspends OUR AdMob account. They
# live alongside the signing keys — see docs/ad-units.md.
#
# Lookup order matches the signing secrets:
#   1. $NONOGRAM_SECRETS/ad-units.env
#   2. ~/.pink-spider/secrets/nonogram/ad-units.env
#
# Exits non-zero if the file is missing, so a release build fails loudly
# instead of silently shipping Google's test units and earning nothing.
set -euo pipefail

ENV_FILE=""
for candidate in \
  "${NONOGRAM_SECRETS:-}/ad-units.env" \
  "$HOME/.pink-spider/secrets/nonogram/ad-units.env"; do
  [[ -f "$candidate" ]] && { ENV_FILE="$candidate"; break; }
done

if [[ -z "$ENV_FILE" ]]; then
  cat >&2 <<'MSG'
✖ ad-units.env not found.

  Without it the prod flavor falls back to Google's test units: the app
  works, shows ads, and earns nothing. Do not ship that.

  Expected at ~/.pink-spider/secrets/nonogram/ad-units.env — see
  docs/ad-units.md for the format and where to re-read the ids in AdMob.
MSG
  exit 1
fi

# shellcheck disable=SC1090
set -a; source "$ENV_FILE"; set +a

REQUIRED=(
  AD_UNIT_ANDROID_BANNER AD_UNIT_ANDROID_INTERSTITIAL AD_UNIT_ANDROID_REWARDED
  AD_UNIT_IOS_BANNER AD_UNIT_IOS_INTERSTITIAL AD_UNIT_IOS_REWARDED
)

out=()
for key in "${REQUIRED[@]}"; do
  value="${!key:-}"
  if [[ -z "$value" ]]; then
    echo "✖ $key is missing from $ENV_FILE" >&2
    exit 1
  fi
  out+=("--dart-define=$key=$value")
done

printf '%s\n' "${out[*]}"
