#!/usr/bin/env bash
# Install/refresh the release addon (WSL path to the Windows install).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/HearthAndHustle"
CLIENT="${WOW_CLIENT:-/mnt/d/World of Warcraft/_forever_}"
ADDONS="${WOW_ADDONS:-$CLIENT/Interface/AddOns}"
DEST="$ADDONS/HearthAndHustle"
[ "$#" -eq 0 ] || { echo "deploy takes no arguments; checks cannot be bypassed"; exit 1; }
[ -d "$ADDONS" ] || [ -f "$CLIENT/Wow.exe" ] || { echo "Release client not found: $CLIENT (set WOW_CLIENT or WOW_ADDONS)"; exit 1; }
"$ROOT/tools/check.sh" || { echo "check failed; not deploying"; exit 1; }
# Renamed from ForeverPath in v0.17.0: two copies must never load together.
LEGACY="$ADDONS/ForeverPath"
if [ -f "$LEGACY/ForeverPath.toc" ] && grep -qF 'API\Adapter.lua' "$LEGACY/ForeverPath.toc" && grep -qF '## X-License: MIT' "$LEGACY/ForeverPath.toc"; then
  echo "The old ForeverPath folder is still installed: $LEGACY"
  echo "Close the game, run tools/migrate-from-foreverpath.py (carries saved data over, removes that folder), then deploy again."
  exit 1
fi
mkdir -p "$DEST"
if command -v rsync >/dev/null; then
  rsync -rlt --delete --exclude '.git' "$SRC/" "$DEST/"
else
  rm -rf "$DEST" && cp -r "$SRC" "$DEST"
fi
echo "deployed $(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo uncommitted) -> $DEST"
find "$DEST" -type f | sed "s|$DEST/||" | sort | tr '\n' ' '; echo
echo "First installation/media changes: fully restart the client. Then /hh status and /hh apicheck."
