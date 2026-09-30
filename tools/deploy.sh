#!/usr/bin/env bash
# Install/refresh the addon in the Forever beta AddOns folder (WSL path to the Windows install).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/ForeverPath"
ADDONS="${WOW_ADDONS:-/mnt/c/Program Files (x86)/World of Warcraft/_classic_beta_/Interface/AddOns}"
DEST="$ADDONS/ForeverPath"
[ -d "$ADDONS" ] || { echo "AddOns folder not found: $ADDONS (set WOW_ADDONS)"; exit 1; }
[ "$#" -eq 0 ] || { echo "deploy takes no arguments; checks cannot be bypassed"; exit 1; }
"$ROOT/tools/check.sh" || { echo "check failed; not deploying"; exit 1; }
mkdir -p "$DEST"
if command -v rsync >/dev/null; then
  rsync -rlt --delete --exclude '.git' "$SRC/" "$DEST/"
else
  rm -rf "$DEST" && cp -r "$SRC" "$DEST"
fi
echo "deployed $(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo uncommitted) -> $DEST"
find "$DEST" -type f | sed "s|$DEST/||" | sort | tr '\n' ' '; echo
echo "in game: /reload (or relog) then /fp status"
