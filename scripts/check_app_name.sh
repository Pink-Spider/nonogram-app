#!/usr/bin/env bash
# Check candidate App Store names against published US apps.
#
#   scripts/check_app_name.sh "Sudoku Daily: Logic Puzzle" "Sudoku Nine"
#   scripts/check_app_name.sh < names.txt        # one name per line
#
# CAVEAT: this only sees apps actually published on the US store. App Store
# Connect additionally rejects names that are merely *reserved* (a record
# created but never shipped) or too close to someone's trademark, so a
# "free?" here is a shortlist, not a guarantee. Always have a backup ready.
# App Store names are capped at 30 characters.
set -euo pipefail

check() {
  local name="$1" enc json seller
  enc=$(python3 -c "import urllib.parse,sys;print(urllib.parse.quote(sys.argv[1]))" "$name")
  json=$(curl -sS --max-time 20 \
    "https://itunes.apple.com/search?term=${enc}&entity=software&country=us&limit=50")
  seller=$(printf '%s' "$json" | python3 -c "
import json,sys
name = sys.argv[1].strip().lower()
for x in json.load(sys.stdin).get('results', []):
    if x.get('trackName','').strip().lower() == name:
        print(x.get('sellerName','?')); break
" "$name")

  local flag='free?'
  [[ -n "$seller" ]] && flag='TAKEN'
  local warn=''
  (( ${#name} > 30 )) && warn='  !! over 30 chars'
  printf '%-6s %2dc  %-32s %s%s\n' "$flag" "${#name}" "$name" "$seller" "$warn"
  sleep 0.4
}

if (( $# )); then
  for n in "$@"; do check "$n"; done
else
  while IFS= read -r n; do [[ -n "$n" ]] && check "$n"; done
fi
