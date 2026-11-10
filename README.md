# ForeverPath

Quest GPS, route planner and data recorder for **World of Warcraft: Forever** (release build 1.60.1.70862, interface 16001).

It shows you where to go. You play. Nothing in here moves your character, targets, casts, loots or turns anything in — that is the line Blizzard draws and the line this addon stays behind.

## What it does (v0.12.0)

- **ForeverPath control window:** click ForeverPath in the addon compartment or **Open tools** on the compact panel. Navigation, Quest rewards, Quest chains, Waypoints, Professions, Party, Supplies & town, PvP, Rare watch, Display, and Diagnostics have buttons, selectors and forms. Action results appear in the window. `/fp` opens it too; slash commands remain optional shortcuts.
- **Compact next-steps panel** (`/fp panel`): the live quest log turned into an ordered list — nearest objective areas and turn-ins first, shared party quests marked with ★, hearth hint when several turn-ins are near your inn. Click a row to send the arrow there.
- **Arrow** (TomTom-style): rotates with your facing, shows distance and a rough ETA, goes green when you're lined up. Right-click cycles waypoints, shift-right-click clears. `/fp arrow flip` if it ever points the wrong way.
- **Map pins**: your waypoints on the world map and a pin on the minimap edge. World-map pins sit below WoW's quest markers. Automatic route pins pass mouse input through so quest-area hover and map clicks work normally; manual pins keep click-to-activate and right-click-to-remove controls.
- **Display settings**: click **Settings** beside **Dungeons** in the next-steps panel. Toggle world-map/minimap pins and arrow visibility, lock the arrow's position, reverse its rotation if needed, adjust its size (40–300%), or reset its position and size. Changes apply immediately and save for all characters; hiding a display keeps the route active. `/fp settings` is an optional shortcut.
- **Auto-next**: automatically rechecks the route every three seconds, including with the panel hidden. Arriving waits while you work nearby; completing the step or moving more than about 100 yards away resumes navigation. Nearby alternatives need a meaningful improvement before the arrow switches. Clicking a quest row keeps that selection until completion/arrival; manual waypoints remain yours. `/fp next` skips the arrived step, `/fp auto off` disables automatic selection, and `/fp auto on` resumes after clearing the route. Quest navigation pauses in battlegrounds.
- **Recorder**: while you play it writes a Forever dataset into SavedVariables — quest givers/enders with positions, offer/turn-in XP per level, objective progress with candidate mob/loot associations, approximate observer sightings, source-attributed observed loot including quest items, vendors, trainers (with skill requirements), flight nodes and edge costs, inn binds, deaths, zone level ranges, XP samples, profession recipes with reagents and difficulty per skill level.
- **Professions**: open your profession window and the next-steps panel shows three skill-up suggestions, bag-material craft counts and missing materials. `/fp prof` gives the longer list. Handles Forever base professions, delayed recipe loading, bag changes and skill-cap reminders. These are material/skill suggestions, not market-price or guaranteed skill-point estimates. Reopen the profession after changing skill to refresh old suggestions.
- **Class supplies** (`/fp prep`): an out-of-combat checklist in the PvP HUD. Shows carried drinks/bandages and general bag space. Shaman characters get Enhancement preparation reminders; Hunters retain their audio feedback and get a town preparation reminder. Mage-only gems/reagents stay on Mages. Reminders do not inspect buffs, prescribe a rotation, or claim an imbue is active. Appears briefly on login/zone entry, at a vendor, and out of combat in a battleground. Updates on bag/spell changes; unknown item data stays unavailable.
- **Dungeon quest checklist:** click **Dungeons** on the next-steps panel, then choose a dungeon or wing. Shows missing pickups, quests in your log, ready turn-ins, completed quests, listed level requirements and prerequisites. Click a quest for its giver/location and chain details. Updates automatically as you quest; filters to your faction/class by default, with a Show all button. `/fp dungeon [name]` is an optional shortcut.
- **Dungeon rare watch** (`/fp rare`): inside Scarlet Monastery a small HUD answers "is Azshir up?". A rare is recognised the moment anyone in the party targets, mouses over, gets a nameplate for, or has a pet on it (names are secret inside Forever dungeons, so the watch reads the unit's *classification*, which is not). A **Scan** button runs a plain `/targetexact` macro once per click to check what the client has loaded without walking the lair. Sightings and kills are shared with party members running the addon; a raid-warning style alert plus sound fires once per run. Runs are keyed by the instance id carried in loot GUIDs, so the HUD counts runs vs sightings and shows the measured spawn rate. `/fp rare list|add|rm|instance` retarget it at any dungeon rare.
- **Vendor helper** (`/fp vendor`): at a merchant a small strip under the vendor window shows **Sell N grays · value** and **Repair cost** buttons. One click sells one batch of gray items (best value first) or repairs with your own gold; nothing sells or repairs without the click, nothing in combat, and if Forever ever turns on Blizzard's own Sell All Junk button the strip defers to it. Away from a vendor, item tooltips show the vendor value (and the full-stack value); quest reward buttons show each reward's vendor value, the best-value choice in gold. It never picks a reward.
- **Status line** (`/fp bar`): level and xp, xp per hour and time to level (rolling hour, seeded from the recorder so a reload keeps it), gold, free general bag slots, worst durability, hearth, ammo for ammo users, fps and world latency. Drag to move, `/fp bar lock`.
- **Reminders** (`/fp remind`, out of combat only, repeated in chat at most every 10 minutes): low or broken durability, low ammo, bags nearly full, a self-buff you know but do not have (Shaman Lightning Shield, Mage Arcane Intellect and Frost/Ice Armor, Hunter Aspect), a Shaman weapon with no imbue. Buff reads go through Blizzard's secret predicate; in combat the reminder row hides instead of guessing.
- **Trainer notes** (`/fp trainer`): at a class or profession trainer, what you can learn now, the total cost against your gold and the next level that unlocks something. On a level-up, which recorded trainer teaches something at the new level and what it costs. `/fp trainer 28` asks about a level.
- **Party seed**: `/fp partyexport` → paste string for a friend, `/fp partyimport <string>` here; when both run the addon, quest state syncs over addon messages automatically.

## Quest reward comparisons (v0.12.0)

Open **ForeverPath → Quest rewards**, or click **Compare rewards** beneath a quest offer/turn-in. The page follows either the quest selected in Blizzard's quest log or the open quest dialog; the two buttons choose the source. It never selects or claims a reward.

- Choice items and guaranteed items are listed separately, with stack vendor value, quest money and XP. Highest vendor value includes ties and appears only when all choice prices are known.
- Select a reward to see numeric stats alongside equipped gear, with gains and losses. Rings/trinkets show each slot; two-handed weapons compare against both equipped hands together. Hover a reward for its full tooltip.
- Equipment changes and arriving item data refresh the open page. Missing data stays unavailable, and comparisons pause in combat. Weapon effects, enchants, set bonuses and procs are not fully represented by numeric stats; there is no automatic upgrade score.

This version is source-checked and mock-tested; client layout, tooltips and reward reads await in-game verification. Event objectives and dungeon routing remain the next roadmap items.

## Quest chains and prerequisites (v0.11.0)

Open **ForeverPath → Quest chains**, or select a quest in Navigation and click **View quest chain**. The browser starts with your quest log; typing a name or quest ID searches QuestieDB's reference catalog too. Same-name quest stages retain their IDs. **Current quest** opens the quest selected in Blizzard's log.

Inspect a quest to see its completed/in-log/ready status, minimum level, **ANY ONE** versus **ALL** prerequisite groups, active-parent requirements, optional lead-ins, alternative branches, cutoff conditions, known pickup sources, and follow-ups. Click a linked row and **Inspect linked quest** to move through the chain; **Previous quest** retraces your steps and **Back to search** preserves your query. Long chains are shortened in the list; inspect a linked quest to continue. **Guide to pickup** explicitly sets a waypoint to a known pickup location; accepting/completing that quest clears the pickup waypoint.

Ordinary quest progress updates the view automatically. Browsing never changes your route or accepts quests. The first database search builds incrementally when you open the page, keeping spawn decoding out of the search path. QuestieDB Forever is the same optional data dependency used by source maps. Missing records, unknown completion reads, and contradictory prerequisites remain visible gaps. Character class/race/profession/reputation/event restrictions are flagged where listed; this is a chain browser, not a full eligibility engine. Only a live map offer is labeled as offered; satisfying reference prerequisites does not guarantee availability.

## Quest source maps (v0.10.0)

ForeverPath can now show **known creature and object locations for unfinished quest objectives** on the world map and nearby sources on the minimap, including item drops, container sources, and vendors. Hover a small orange marker for the quest, progress, and source; click it to guide there. Completed objectives disappear automatically. Display settings let you hide either layer or show only the client-selected quest. Navigation shows coverage and database status.

This feature reads the standalone [QuestieDB Forever addon](https://github.com/Questie/QuestieDB/releases/tag/v1.0.13), version 1.0.13 tested. **Questie's interface is not required.** Install its `QuestieDB` folder beside `ForeverPath`, restart WoW, and enable both. On this development machine, `python3 tools/install-questiedb.py` installs the checksum-pinned, unmodified data addon and preserves any different existing installation. ForeverPath's other tools continue working without it; source locations will report that the database is missing.

These are possible spawn/source locations, not live tracking of stealthed enemies or guaranteed drops. Objective text is matched to the live quest log rather than assuming database row order. Unmatched text, unsupported event/kill-credit/spell objectives, and dungeon floor/sentinel positions stay unmapped. Outdoor markers are grouped for readability (350 world-map / 40 nearby minimap frames); the nearest-source fallback uses the full matched point list. Live Blizzard directions and recorded areas remain preferred for automatic guidance. QuestieDB's Forever data includes converted coordinates and corrections, but does not cover every new quest.

## Using the control window (v0.9.0)

Open ForeverPath from the addon compartment, or click **Open tools** on the compact quest panel. Choose a section on the left. The compact overlay continues to guide you while the main window is closed.

- **Navigation:** search/select a quest destination, resume or pause automatic selection, defer a crowded quest, or find pickups. Pause keeps the current destination; Clear route removes waypoints and pauses guidance.
- **Waypoints:** select destinations by name, activate/remove them, save your current position, or enter percentage coordinates with an optional map ID.
- **Professions:** open your profession once, select a learned recipe by name, enter a batch size, and view needed materials. This does not craft items.
- **Party:** compare quest progress, explicitly send your snapshot, or copy/paste a snapshot without typing a command.
- **Supplies & town:** set stocking targets, manage vendor values and reminders, and look up recorded trainer notes. Selling/repairing stays on the merchant window with its existing click buttons.
- **PvP / Rare watch:** HUD controls, flag-slot tracking, reports, watched-instance/rare editing and run history. Scan remains a separate click on the existing secure rare HUD; opening tools never targets anything.
- **Display:** map pins, arrow, compact panel, status line, and Hunter audio controls. The main window saves its dragged position and scales down to fit smaller screens.
- **Diagnostics:** status, API checks, self-test, recording and errors. Data resets have a separate confirmation that is canceled when you leave the section or close the window.

Long sections and results scroll separately. Lists are paginated, typed drafts survive refreshes, and browsing does not change your preferences or route. The Dungeon quests button opens the existing checklist; **All tools** returns to the control window. The smaller display-settings dialog remains available from the compact panel.

Validated with source checks and the mock harness; actual client layout, scrolling and mouse behavior still require in-game verification. Run `/reload` to load the update.

## Vendor, status line, reminders, trainer notes (v0.8.0)

A survey of the most-installed World of Warcraft: Forever addons on CurseForge (ForeverPlus, ForeverForge, ForeverUI, Leatrix Plus, Questie, Vendor Price, What's Training?) found the features people install first: sell grays, repair, vendor value on tooltips and quest rewards, an info bar with xp/h, buff and consumable reminders, trainer awareness. v0.8.0 adds the information side of all of that and keeps every action behind a player click. There is no auto-accept, auto-turn-in, auto-loot or auto-buy here and there will not be: the addon shows, you play.

Mock-tested only on release; in-game verification pending: the merchant strip's anchor under Forever's Mainline-derived `MerchantFrame`, whether `C_UnitAuras.GetPlayerAuraBySpellID` returns your own buffs out of combat on Forever (the predicate `C_Secrets.ShouldAurasBeSecret` gates the read), the Classic-era spell ids used for the buff/imbue tables, `GetInventoryItemDurability` and `GetRepairAllCost` shapes, and the tooltip hook (`TooltipDataProcessor.AddTooltipPostCall`, present in Forever's UI source). `/fp vendor` and `/fp bar` print which hooks the client accepted.

## Dungeon quest preparation (v0.7.0)

Open the normal ForeverPath panel from the addon compartment, then click **Dungeons**. Select a dungeon on the left; use the page buttons for more dungeons or quests. Click a quest on the right and scroll its details for pickup locations, prerequisite chains, item starts and follow-ups. The last dungeon and faction/class filter are saved per character. Browsing leaves your active navigation alone.

The bundled reference contains **455 quest records**, including prerequisite/return steps, with populated lists for **30 dungeon/wing entries**. Five additional dungeon entries explicitly show **coverage missing**. It is adapted from the MIT-licensed [DungeonQuestTracker catalog](https://github.com/jturnham/DungeonQuestTracker/tree/b4ae5a478d0f96c842c13d5ad96bb4adb11f15df/DungeonQuestTrackerForever/Data); attribution ships inside the addon. Classic-derived entries and conflicting reports remain marked. This is not a guarantee of every current Forever quest, nor proof that all listed quests can be accepted together. “Missing: check pickup” means absent from your log/completion flags, not confirmed eligible. Only a live current-map offer says “Available on this map.” Unknown API results stay unknown; accepting a quest overrides older reference restrictions. Prerequisites distinguish mandatory steps, optional breadcrumbs, alternative branches and steps that must remain in your log. Profession, reputation and unrecorded restrictions must still be checked at the giver.

The checklist is mock-tested; actual in-game layout and quest eligibility need client confirmation. Its completion reads use character flags, not account-wide progress. No automatic quest acceptance, sharing, targeting, travel or turn-ins.

## Launch questing tools

- **Nearby clusters:** routes modestly favor objectives within about 200 yards of other distinct quests. This uses straight-line distance, so caves, cliffs and travel connections still need player judgment. Quests more than three levels above you receive a bounded priority penalty; their level and suggested group size appear in the UI. Turn-ins are not penalized for level.
- **Crowded objective:** `/fp skip` defers the current quest for 10 minutes; `/fp skip 5` changes that. All its objectives are deferred together. `/fp skip clear` restores them, and clicking a deferred row resumes it immediately. Deferrals last only this login session. Manual waypoints are preserved.
- **Duo quest check:** `/fp duo` compares your log with your partner's latest addon snapshot: quests only one of you has, who still needs to finish, and turn-ins ready for both. ★ marks shared quests. Partner snapshots can be stale; the report shows their age. Both players need the addon for automatic sync.
- **Current directions first:** live client waypoints/POIs now override recorded beta turn-in positions. Recorded locations remain a fallback. The planner includes available pickups reported by the current client map. It does not contain a complete prewritten 1–60 route or terrain pathfinder.
- **Profession shopping:** open your learned crafting profession, then `/fp prof` for recipe IDs. `/fp prof plan <recipeID> <crafts>` displays a bag-aware materials checklist in the main panel; `/fp prof plan clear` clears it. The target is a fixed number of future crafts for this session: update it after crafting. It does not buy/craft anything or infer skill points. Unavailable counts stay unknown. Skinning is shown in the profession summary; it has no crafting recipe list. Switching to Engineering uses that character's learned recipes once opened.

Quest guidance (v0.6.2) starts automatically at login. The arrow follows the quest selected in the game's tracker when coordinates exist, otherwise it picks a nearby objective, turn-in or client-reported available pickup. It stays visible on arrival, advances when the objective is finished or quest is accepted/turned in, and runs independently of the panel. Missing coordinates produce a visible explanation instead of a blank area. Every few seconds it reconciles display state; deliberate hide/stop settings remain respected. Commands are optional overrides. Pickup eligibility comes from live client offers, not historical NPC sightings.

Release evidence: 70790 SavedVariables contain readable quest POIs, player position/facing and zero stored addon errors, but the user reports a blank arrow area on v0.6.0. v0.6.2 is mock-tested; its visual behavior and pickup coverage still need client confirmation. Reload the UI once after updating, then play normally. Diagnostics refresh automatically on addon-version changes, and the latest navigation/display snapshot updates every 30 seconds; ordinary logout or UI reload saves them to disk. `tools/pull-data.sh` reads the release client's WTF folder; it does not import beta data.

## PvP module

Built around what Forever's secret-value rules leave readable (Blizzard's own predicate docs, see `docs/FOREVERPATH_SPEC.md` §8): your own casts, enemy *player* identity, battleground objective data, and what a party member chooses to broadcast. Nothing here reads enemy casts or auras, because on Forever it cannot.

- **Timers** (`PvP/CastTimers.lua`): every control/interrupt/root you cast starts a bar with the target's name, a duration parsed from the spell's tooltip, and a diminishing-returns estimate per target (full → ½ → ¼ → immune, 15 s reset). Every timer is explicitly labeled `est.`: resists, successful interrupts and early breaks are unconfirmed. Cast-target identity is captured when the spell is sent; switching targets afterwards cannot change the DR attribution. Frost Nova is an area-cast estimate, without an invented single target or DR chain. Tooltip durations and the existing DR model are not verified PvP-duration measurements.
- **Enemies seen** (`PvP/Roster.lua`): class, race, level, last seen, what you used on them; in a battleground the scoreboard adds the enemy team composition.
- **Battleground** (`PvP/Battleground.lua`): base states with capture timers, flag carriers described relative to the nearest objective, `/fp pvp track` follows a single visible flag. With two flags, select `/fp pvp track 1` or `2`; `/fp pvp track off` stops. Faction is unverified: numbers identify API positions, not ally/enemy identity, and should be checked against the map. Map position may be unavailable in instances. Records raw objective/flag data so a real match can establish the exact icon meanings.
- **Coordination** (`PvP/Coordination.lua`): your CC timers are sent to party members running ForeverPath and shown on their HUD with a "window" flag before expiry. Blizzard locks addon messages inside battlegrounds and arenas; this works in world PvP and duels. Incoming timers must come from a current party member and have a valid, bounded duration.
- `/fp pvp` toggles the HUD; `/fp pvp status`, `track`, `spells`, `lock`, `reset`, `scale n`, `on|off`.

## Dungeon rare watch (v0.5.0)

Built for farming Azshir the Sleepless in the Scarlet Monastery Graveyard with a friend. What the Forever client allows (probe evidence from build 70291, see `docs/FOREVERPATH_SPEC.md` §12): inside a dungeon the **Map** restriction is active even out of combat, so NPC names and GUIDs are secret and cannot be compared. `UnitClassification` (`rare` / `rareelite`), level, reaction and creature type are not gated and read normally, and loot-source GUIDs are never secret. The watch is built on exactly those reads.

- **Detection**: target, mouseover, focus, nameplates (turn enemy nameplates on), your pet's target and every party member's and party pet's target. Any hostile `rare`/`rareelite` inside the watched instance is a sighting. Outside dungeons names are readable and the watch list names are matched too.
- **Scan button**: a `SecureActionButtonTemplate` whose macro is `/targetexact Azshir the Sleepless` (one line per watched rare). It is the same thing as a player macro: one click, one targeting attempt, nothing automatic. It only finds a unit the client has already loaded, so press it while walking toward the lair; `/fp rare scan` prints the macro if you prefer your own keybind. How far it reaches inside the Graveyard is unverified: the HUD counts hits and misses per run so you learn it.
- **Identity**: which of the three rares it was becomes certain when it is looted (loot-source GUID carries the creature id). Until then the HUD shows "RARE UP (lvl 33 Undead)" and, where the client permits, the name as a display-only value.
- **Runs**: entering the instance opens a run; the first loot window keys it by the instance's zoneUID; a different zoneUID means the group reset while you were out; "has been reset" closes it; re-entering the same instance folds into the same run; runs idle for 2 h are over. `Not up` marks a run checked-and-empty; `/fp rare runs` lists the last ten. The stats line is sightings over checked runs against the ~5 % folk estimate.
- **Party share**: `RW;up`, `RW;no`, `RW;kill` addon messages, accepted only from current party members. Addon chat works in dungeons outside boss encounters.
- `/fp rare` status · `scan` · `notup` · `newrun` · `runs` · `list` · `add [id] <name>` · `rm <name>` · `instance <name>` · `show|hide|auto` · `on|off` · `share on|off` · `sound on|off` · `lock|unlock|reset|scale n` · `clear confirm`.

In-game verification pending (mock-tested only): that `UnitClassification` really stays readable in the Graveyard where names are secret (`/fp apicheck` → `probe:targetClassification` with a mob targeted), the reach of `/targetexact` inside the instance, whether `FontString:SetText` accepts a secret name, whether Forever flags vanilla rares with minimap vignettes (`probe:vignettes`, recorded under `ForeverPathDB.rare.vignettes`), and the vanilla creature ids 6490/6489/6488 (confirmed by the first loot window). Report with `tools/pull-data.sh`.

## Install (WoW Forever release)

1. Download **[ForeverPath.zip](https://github.com/ForWakanda/foreverpath/releases/latest/download/ForeverPath.zip)** (latest release).
2. Open your WoW folder, usually `D:\World of Warcraft\_forever_\Interface\AddOns\`. If `AddOns` does not exist yet, create it.
3. Extract the zip there. You should end up with `...\AddOns\ForeverPath\ForeverPath.toc` (a `ForeverPath` folder directly inside `AddOns`, not a folder inside a folder).
4. Start the game. If it was already running, close it completely and start it again (the client only picks up new addon files at startup). On the character screen, click **AddOns** and make sure ForeverPath is ticked.
5. In game, open ForeverPath from the addon compartment, or type `/fp` for the control window. `/fp panel` toggles the compact quest overlay; `/fp help` lists optional shortcuts.

**Updating:** delete the old `ForeverPath` folder, extract the new zip, restart the client. Your settings and recorded data live in `WTF\` and survive updates.

**Developers on WSL:** `tools/deploy.sh` runs the checks and copies the addon into the release folder directly. Set `WOW_CLIENT` for a different client root or `WOW_ADDONS` for an explicit AddOns directory. The default is `/mnt/d/World of Warcraft/_forever_`.

## Commands

`/fp help` prints them. `/way 45.4 70.4` points to those coordinates in your current zone; add an optional title, e.g. `/way 45.4 70.4 Quest cave`. `/way` is a shortcut for `/fp way`, including `here`, `list`, `next`, `clear`, and `rm <id>`. Waypoint coordinates always use percentages (0–100); three numeric arguments mean map ID, x%, y% (e.g. `/way 1413 45.4 70.4`). If another addon owns `/way`, use `/fp way` explicitly. Short version: `/fp` panel · `/fp vendor` · `/fp bar` · `/fp remind` · `/fp trainer` · `/fp next` · `/fp goto <quest>` · `/way x y [title]` · `/fp way here` · `/fp arrow lock|flip|scale n|reset` · `/fp prof` · `/fp rare` · `/fp status` · `/fp apicheck` · `/fp selftest` · `/fp record on|off`.

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

See [CONTRIBUTING.md](CONTRIBUTING.md). Branch, make one change per commit, run `tools/check.sh`, open a pull request; `main` is protected and merges only with the CI check green. Say in the PR whether the change was verified in game or only against the mock; nothing here can run the client. Releases are tagged `vX.Y.Z`; the tag builds `ForeverPath.zip` automatically.

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
