# ForeverPath

Quest GPS, route planner and data recorder for **World of Warcraft: Forever** (beta build 1.60.1.70205, interface 16001; launch 2026-11-04).

It shows you where to go. You play. Nothing in here moves your character, targets, casts, loots or turns anything in — that is the line Blizzard draws and the line this addon stays behind.

## What it does (v0.4.0)

- **Next steps panel** (`/fp`): the live quest log turned into an ordered list — nearest objective areas and turn-ins first, shared party quests marked with ★, hearth hint when several turn-ins are near your inn. Click a row to send the arrow there.
- **Arrow** (TomTom-style): rotates with your facing, shows distance and a rough ETA, goes green when you're lined up. Right-click cycles waypoints, shift-right-click clears. `/fp arrow flip` if it ever points the wrong way.
- **Map pins**: your waypoints on the world map (click = activate, right-click = remove) and a pin on the minimap edge.
- **Auto-next**: automatically rechecks the route every three seconds, including with the panel hidden. Arriving waits while you work nearby; completing the step or moving more than about 100 yards away resumes navigation. Nearby alternatives need a meaningful improvement before the arrow switches. Clicking a quest row keeps that selection until completion/arrival; manual waypoints remain yours. `/fp next` skips the arrived step, `/fp auto off` disables automatic selection, and `/fp auto on` resumes after clearing the route. Quest navigation pauses in battlegrounds.
- **Recorder**: while you play it writes a Forever dataset into SavedVariables — quest givers/enders with positions, offer/turn-in XP per level, objective progress with candidate mob/loot associations, approximate observer sightings, source-attributed observed loot including quest items, vendors, trainers (with skill requirements), flight nodes and edge costs, inn binds, deaths, zone level ranges, XP samples, profession recipes with reagents and difficulty per skill level.
- **Professions**: open your profession window and the next-steps panel shows three skill-up suggestions, bag-material craft counts and missing materials. `/fp prof` gives the longer list. Handles Forever base professions, delayed recipe loading, bag changes and skill-cap reminders. These are material/skill suggestions, not market-price or guaranteed skill-point estimates. Reopen the profession after changing skill to refresh old suggestions.
- **Mage supplies** (`/fp prep`): an out-of-combat checklist in the PvP HUD. Shows carried drinks/bandages, missing mana gems you can conjure, and relevant Slow Fall/teleport/portal/Arcane Brilliance reagents. Appears briefly on login/zone entry, at a vendor, and out of combat in a battleground. Updates on bag/spell changes; unknown item data stays unavailable.
- **Party seed**: `/fp partyexport` → paste string for a friend, `/fp partyimport <string>` here; when both run the addon, quest state syncs over addon messages automatically.

## PvP module

Built around what Forever's secret-value rules leave readable (Blizzard's own predicate docs, see `docs/FOREVERPATH_SPEC.md` §8): your own casts, enemy *player* identity, battleground objective data, and what a party member chooses to broadcast. Nothing here reads enemy casts or auras, because on Forever it cannot.

- **Timers** (`PvP/CastTimers.lua`): every control/interrupt/root you cast starts a bar with the target's name, a duration parsed from the spell's tooltip, and a diminishing-returns estimate per target (full → ½ → ¼ → immune, 15 s reset). Every timer is explicitly labeled `est.`: resists, successful interrupts and early breaks are unconfirmed. Cast-target identity is captured when the spell is sent; switching targets afterwards cannot change the DR attribution. Frost Nova is an area-cast estimate, without an invented single target or DR chain. Tooltip durations and the existing DR model are not verified PvP-duration measurements.
- **Enemies seen** (`PvP/Roster.lua`): class, race, level, last seen, what you used on them; in a battleground the scoreboard adds the enemy team composition.
- **Battleground** (`PvP/Battleground.lua`): base states with capture timers, flag carriers described relative to the nearest objective, `/fp pvp track` follows a single visible flag. With two flags, select `/fp pvp track 1` or `2`; `/fp pvp track off` stops. Faction is unverified: numbers identify API positions, not ally/enemy identity, and should be checked against the map. Map position may be unavailable in instances. Records raw objective/flag data so a real match can establish the exact icon meanings.
- **Coordination** (`PvP/Coordination.lua`): your CC timers are sent to party members running ForeverPath and shown on their HUD with a "window" flag before expiry. Blizzard locks addon messages inside battlegrounds and arenas; this works in world PvP and duels. Incoming timers must come from a current party member and have a valid, bounded duration.
- `/fp pvp` toggles the HUD; `/fp pvp status`, `track`, `spells`, `lock`, `reset`, `scale n`, `on|off`.

## Install (WoW Forever beta)

1. Download **[ForeverPath.zip](https://github.com/ForWakanda/foreverpath/releases/latest/download/ForeverPath.zip)** (latest release).
2. Open your WoW folder, usually `C:\Program Files (x86)\World of Warcraft\_classic_beta_\Interface\AddOns\`. If `AddOns` does not exist yet, create it.
3. Extract the zip there. You should end up with `...\AddOns\ForeverPath\ForeverPath.toc` (a `ForeverPath` folder directly inside `AddOns`, not a folder inside a folder).
4. Start the game. If it was already running, close it completely and start it again (the client only picks up new addon files at startup). On the character screen, click **AddOns** and make sure ForeverPath is ticked.
5. In game, type `/fp` for the panel and `/fp help` for the commands.

**Updating:** delete the old `ForeverPath` folder, extract the new zip, restart the client. Your settings and recorded data live in `WTF\` and survive updates.

**Developers on WSL:** `tools/deploy.sh` runs the checks and copies the addon into the beta folder directly.

## Commands

`/fp help` prints them. Waypoint coordinates always use percentages (0–100); three numeric arguments mean map ID, x%, y%. Short version: `/fp` panel · `/fp next` · `/fp goto <quest>` · `/fp way x y [title]` · `/fp way here` · `/fp arrow lock|flip|scale n|reset` · `/fp prof` · `/fp status` · `/fp apicheck` · `/fp selftest` · `/fp record on|off`.

## Getting the data out

```
tools/pull-data.sh       # copies WTF/.../SavedVariables/ForeverPath.lua into data/ and prints counts + stored errors
```
Log out or `/reload` first so the client flushes SavedVariables.

## Development

- `ForeverPath/` is the addon; `API/Adapter.lua` owns game-data reads and API probes; Core/UI own frame creation, event registration, timers, and rendering. APIs are feature-detected so a renamed function on the next build degrades one feature instead of breaking the addon.
- `tools/check.sh` validates Lua/XML/TOC, runs the mock play-through and the pure self-tests, then `tests/regressions.py`. The same check runs in GitHub Actions on every push and pull request. Needs Lua 5.1 (`apt-get install lua5.1`, or set `LUA`/`LUAC`) and Python 3.
- APIs were verified against Blizzard's Forever UI source (`Gethe/wow-ui-source`, branch `forever`, same build) — see `docs/FOREVERPATH_SPEC.md`. Forever runs the modern (12.x) addon API with Midnight's secret-value restrictions; Classic-era assumptions are usually wrong here.
- Lua 5.1 only: no `goto`, no `//`, no `\z`. WoW's global `atan2`/`sin`/`cos` use degrees; use `math.*`.
- Working with an AI coding assistant? `CLAUDE.md` holds the rules it should follow (no automation, secret-value guards, adapter-only API access, the check gate).

### Contributing

Fork, branch, make one change per commit, run `tools/check.sh`, open a pull request. Say in the PR whether the change was verified in game or only against the mock; nothing here can run the client. Releases are tagged `vX.Y.Z`; the tag builds `ForeverPath.zip` automatically.

## Recorder evidence

Loot totals mean **items observed on a loot source**, not items picked up or unbiased drop rates. Reopening and partial looting use a per-source maximum, persisted across reloads; the deduplication cache retains up to 2,048 source GUIDs for 24 hours. A missing/malformed source stays an unknown observation with an optional target candidate, never a confirmed drop from the selected target.

Kill/loot timing alone is not enough to identify a quest objective. Such associations stay in the bounded progress tape as candidates; the planner can use observed progress areas but does not promote those candidates to confirmed mob locations. Sightings record the observer's position and are explicitly approximate.

`/fp record off` stops dataset collection, including pending callbacks and profession recording. Navigation, current profession recommendations, party seed/settings, bind navigation state, and error/API diagnostics continue. Turning recording back on starts a fresh objective baseline.

The v2 SavedVariables migration preserves older biased loot totals and objective identity guesses under `legacy*V1` fields, separate from corrected observations. The original review and failing results remain archived under `docs/reviews/2026-09-30/`; current verification is `tools/check.sh`.

## License

MIT; see [LICENSE](LICENSE). Free, unobfuscated, no ads or donation prompts.

## v0.3.0 verification

Checked against the Forever 70205 UI source; 18 self-tests, mock play-through and 62 regression checks pass. A copy of existing account/character SavedVariables also initializes cleanly in the mock. **The new behavior still needs in-game verification.** After installing, `/reload`, walk between quest areas, then open each profession. `/fp apicheck` with a profession open records which profession lookup worked. See [the review](docs/reviews/2026-10-04/REVIEW.md) for findings and the first battleground check.

## Mage preparation (v0.4.0)

After `/reload`, use `/fp prep` for a report or `/fp prep show` to keep the checklist visible outside combat. `/fp prep auto` restores contextual display; `hide` hides its HUD section, and `off` disables its scans. It respects `/fp pvp hide|off`; use `/fp pvp on` and `/fp pvp auto` to re-enable the containing HUD. Other classes do not activate this feature.

Default per-character stocking targets: **40 drinks, 10 carried bandages, 5 of each relevant reagent**, and one of each known mana gem. Change them with `/fp prep water 60`, `/fp prep bandages 20`, or `/fp prep reagents 10`; targets accept 0–200 and zero hides that category. These are convenience targets, not required quantities. Gems/reagents appear only when the relevant supported spell is learned.

Counts include equipped bags only, including the reagent bag when the client exposes it. Drinks match the client's localized Drink item effect and must meet the character's level; food, potions and higher-level drinks are excluded. Combined food/drink items with a different effect name are not included. Bandages are **carried stock**, not a claim about First Aid requirements or debuffs. No cooldown/aura checks, purchase, cast or item use occurs. Missing data is retried briefly and on item-cache events; `/fp apicheck` includes `probe:magePrep` for diagnosis.

Validation: 72 regressions, 18 self-tests and the mock play-through. Actual bag classification, learned-spell lookups, layout and visibility still need the client. No battleground maps were present in the latest saved data, so faction-specific flag/base alerts remain pending real match evidence.
