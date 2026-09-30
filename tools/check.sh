#!/usr/bin/env bash
# Syntax-check every Lua/XML file and run the mock play-through.
set -euo pipefail
cd "$(dirname "$0")/.."
LUAC="${LUAC:-$HOME/.local/bin/luac5.1}"
LUA="${LUA:-$HOME/.local/bin/lua5.1}"
fail=0
while IFS= read -r f; do
  if ! "$LUAC" -p "$f" >/dev/null 2>&1; then echo "SYNTAX ERROR: $f"; "$LUAC" -p "$f" || true; fail=1; fi
done < <(find ForeverPath -name '*.lua' | sort)
for x in $(find ForeverPath -name '*.xml'); do
  python3 -c "import xml.dom.minidom,sys; xml.dom.minidom.parse(sys.argv[1])" "$x" || { echo "BAD XML: $x"; fail=1; }
done
# every file listed in the TOC must exist
while IFS= read -r line; do
  line="${line%$'\r'}"
  case "$line" in \#*|"") continue;; esac
  p="ForeverPath/${line//\\//}"
  [ -f "$p" ] || { echo "MISSING FROM DISK (listed in TOC): $p"; fail=1; }
done < ForeverPath/ForeverPath.toc
[ "$fail" -eq 0 ] || { echo "validation failed; checks stopped"; exit 1; }
echo "syntax: all files OK"
"$LUA" tests/run.lua
LUA="$LUA" python3 tests/regressions.py
