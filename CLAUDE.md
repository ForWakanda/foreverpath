# Hearth & Hustle — rules for AI coding sessions (Claude Code, Codex, cloud sessions)

This file is loaded automatically by Claude Code. It carries the durable engineering rules for this repo so a fresh session, local or cloud, can work safely without any other context.

## What this is
A World of Warcraft: Forever addon: quest GPS + route planner + profession help + PvP HUD, plus a recorder that builds a Forever dataset while people play. Lua 5.1 (WoW's dialect), interface 16001 (Forever release; the client was 1.60.1.70790 at the last data pull, Blizzard's `forever` source was at 70938 on 2026-11-13 — re-check `version.txt` after every patch). Design, verified API facts and phases: `docs/SPEC.md`.

## Hard rules
- Shared questing, dungeon, profession, trainer, reward and preparation tools must work regardless of the player's class. Gate specialized helpers by the current character; do not assume a Mage/Hunter pair, Enhancement spec or duo play. Custom joke/action sounds were retired at the user's request (2026-11-10); keep them out of the addon.
- **No automation, ever.** The addon shows information; the player acts. No inputs, targeting, casting, looting, turn-ins, or decisions driven by combat data. This is Blizzard's line and the project's.
- **One sanctioned background write: action bar layout** (`Modules/BarGuard.lua`, owner's decision 2026-11-13). It puts remembered buttons back on slots the server emptied. Keep it to that: empty slots only, never in combat, never while the cursor holds something, never replacing or removing a button, never using one. Do not widen it to other state.
- **Forever's secret values are real.** In combat, enemy casts/auras, and even your own cooldowns/auras, come back as secret values that throw on comparison. Every unit read goes through `FP.safe()`; never branch on a possibly-secret value; never register `COMBAT_LOG_EVENT_UNFILTERED`; never call `C_SuperTrack.SetSuperTrackedUserWaypoint`. The verified gate table is in the spec §2/§8.
- **Only `HearthAndHustle/API/Adapter.lua` calls gameplay WoW APIs.** Feature-detect everything (`has(C_QuestLog, "GetInfo")`), so a renamed function on the next build degrades one feature instead of breaking the addon. UI/framework calls (CreateFrame, fonts, timers) are fine anywhere.
- **Verify against Blizzard's own Forever UI source**, not Classic-era memory: `git clone --depth 1 --branch forever https://github.com/Gethe/wow-ui-source.git` and grep `Interface/AddOns/Blizzard_APIDocumentationGenerated/`.
- **`tools/check.sh` must be green before any commit that touches `HearthAndHustle/`.** It runs `luac -p` on every file, validates XML/TOC, the mock play-through (`tests/run.lua`) and the regression suite (`tests/regressions.py`). Run it unpiped and gate on its exit code; never judge a check through `| tail`.
- **In-game truth beats the mock.** Nothing here can run the game. `HearthAndHustleDB.errors` and `HearthAndHustleDB.apicheck` (SavedVariables) are the evidence after a session; read them before changing code. A null result from an unverified API is not evidence.
- Lua 5.1 only: no `goto`, no `//`, no `\z`. WoW's global `atan2`/`sin`/`cos` use degrees; use `math.*`. SavedVariables are created inside `ADDON_LOADED`, never at file scope.
- Keep it free, open, unobfuscated, ad-free (Blizzard UI Add-On Development Policy). MIT.
- **Renamed from "ForeverPath" in v0.17.0** because an unrelated addon now uses that name, the same SavedVariables names and `/fp`. Never register `/fp` or reuse the old global names. Old data is adopted only through the schema check in `Core/Config.lua` (`adoptLegacy`) or `tools/migrate-from-foreverpath.py`; a table that merely has the old variable name may belong to the other addon.

## Layout
`HearthAndHustle/` is the addon (what gets installed). `Core/` namespace, config, util · `API/Adapter.lua` the only gameplay API surface · `Nav/` position, waypoints, arrow, map pins · `Data/Recorder.lua` telemetry · `Route/Planner.lua` · `Prof/Tracker.lua` · `Party/Sync.lua` · `Modules/` cosmetic/diagnostic modules · `PvP/` HUD, own-cast timers, roster, battleground, coordination · `UI/` panel + `/hh` commands. `tests/` mock harness. `tools/check.sh` gate, `tools/deploy.sh` local install (Windows WoW path via WSL), `tools/pull-data.sh` dataset export.

## Toolchain
Lua 5.1: `apt-get install -y lua5.1` on Debian/Ubuntu (binaries `lua5.1`, `luac5.1`) or build from lua.org (`make generic`). Set `LUA`/`LUAC` for `tools/check.sh` if they are not at `~/.local/bin`. Python 3 for the regression suite and tooling. No other dependencies.

## Working agreement
- One feature or fix per commit; describe the in-game verification status honestly (mock-tested vs game-verified).
- Add or extend a `tests/run.lua` scenario or `tests/regressions.py` check with every behaviour change.
- New sound/texture files need a full game client restart, not `/reload`.
- Update `docs/SPEC.md` when an API fact is verified or falsified in game.
