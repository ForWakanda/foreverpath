#!/usr/bin/env bash
# Copy the recorded dataset (SavedVariables) out of the WoW folder into data/ and print a summary.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WTF="${WOW_WTF:-/mnt/c/Program Files (x86)/World of Warcraft/_classic_beta_/WTF/Account}"
LUA="${LUA:-$HOME/.local/bin/lua5.1}"
ts="$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$ROOT/data/chars"
found=0
while IFS= read -r f; do
  found=1
  acct="$(echo "$f" | sed -E 's|.*/Account/([^/]+)/.*|\1|' | tr '#' '_')"
  if [[ "$f" == *"/SavedVariables/ForeverPath.lua" && "$f" != *"/Account/$(basename "$(dirname "$(dirname "$f")")")/SavedVariables/"* ]]; then :; fi
  if [[ "$(basename "$(dirname "$(dirname "$f")")")" == "Account" || "$(dirname "$(dirname "$f")")" == *"/Account/"* && "$(basename "$(dirname "$f")")" == "SavedVariables" && "$(dirname "$(dirname "$f")")" == "$WTF/"* && "$(dirname "$(dirname "$(dirname "$f")")")" == "$WTF" ]]; then
    dest="$ROOT/data/ForeverPathDB-$acct-$ts.lua"
    cp "$f" "$dest"; cp "$f" "$ROOT/data/ForeverPathDB-latest.lua"
    echo "account DB: $f -> $(basename "$dest") ($(stat -c %s "$f") bytes)"
  else
    char="$(basename "$(dirname "$(dirname "$f")")")"
    realm="$(basename "$(dirname "$(dirname "$(dirname "$f")")")")"
    dest="$ROOT/data/chars/ForeverPathCharDB-${realm// /_}-${char}-$ts.lua"
    cp "$f" "$dest"
    echo "char DB: $realm/$char ($(stat -c %s "$f") bytes)"
  fi
done < <(find "$WTF" -type f -name 'ForeverPath.lua' 2>/dev/null)
[ $found -eq 1 ] || { echo "no ForeverPath.lua found under $WTF yet (log out or /reload once in game to flush SavedVariables)"; exit 0; }
if [ -f "$ROOT/data/ForeverPathDB-latest.lua" ]; then
  "$LUA" - "$ROOT/data/ForeverPathDB-latest.lua" <<'LUA'
local f = assert(loadfile(arg[1])); f()
local db = ForeverPathDB or {}
local function n(t) local c = 0 for _ in pairs(t or {}) do c = c + 1 end return c end
local d = db.data or {}
print(string.format("dataset: quests %d, npcs %d, creatures %d, objects %d, items %d, vendors %d, trainers %d, taxi nodes %d, progress %d, deaths %d, recipes %d",
  n(d.quests), n(d.npcs), n(d.creatures), n(d.objects), n(d.items), n(d.vendors), n(d.trainers), n(d.taxi and d.taxi.nodes), #(d.progress or {}), #(d.deaths or {}), n(d.recipes)))
local errs = db.errors or {}
print("errors stored: " .. #errs)
for i = math.max(1, #errs - 9), #errs do print("  " .. tostring(errs[i].where) .. ": " .. tostring(errs[i].err)) end
for build, r in pairs(db.apicheck or {}) do
  print(string.format("apicheck %s: ok %s, fail %s", build, tostring(r.ok), tostring(r.fail or (r.missing and #r.missing))))
  if r.rows then for k, v in pairs(r.rows) do if type(v) == "table" then
      if k:match("^probe:") or not v.ok then print("   " .. k .. " [" .. tostring(v.status) .. "] = " .. tostring(v.note)) end
    elseif v == false or (type(v) == "string" and k:match("^probe:")) then print("   " .. k .. " = " .. tostring(v)) end end end
end
LUA
fi
