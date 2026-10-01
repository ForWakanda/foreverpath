# FOREVERPATH_SPEC — design, boundaries, phases

Written 2026-09-30 for the WoW Forever beta (client 1.60.1.70124). Everything in "Verified" was checked against Blizzard's Forever UI source, branch `forever` of `Gethe/wow-ui-source`, commit `966519c` ("1.60.1 (70124)").

## 2026-09-30 v0.1.1 corrections

The original design below is retained as the v0.1 baseline. Implemented corrections supersede its affected behavior/schema:

- Arrival state persists independently of the arrow. Objectives wait for completion; turn-ins wait for the quest action; explicit next skips the waiting step. Manual destinations are preserved.
- Recorder schema v2: observed loot uses every per-slot GUID/quantity pair and per-source item maxima, with a persisted 24-hour/2,048-source dedup cache. Unknown sources go to `data.lootObservations` (last 200 opens) with uncertain target candidates. Totals describe observed offers, not collection/drop probabilities.
- Progress entries retain `killCandidates`, `lootCandidates`, `lootItems`, `attribution="unconfirmed"`, and `observer=true`. Time proximity no longer writes confirmed `obj.mobs`/`obj.src`. Position records retain observer/provenance fields. Old biased totals/mappings are preserved under `legacy*V1` fields.
- Automatic/manual API reports persist `{ok,status,note}` rows, build/version/time, and ten-report history; one throwing probe does not prevent the others. No probe proves arrow texture orientation or in-game XML behavior.
- `/fp record off` gates dataset persistence, not live navigation/profession calculations, party/settings/bind state, or diagnostics. Queued dataset work rechecks the switch; toggling starts a new progress baseline.
- In-game self-tests are pure. Party send results are compared with the success enum; live imports refresh plans and expire when the sender leaves, while pasted seeds persist. Snapshots over 255 bytes use bounded reassembly. Completion/removal changes sync too.
- Profession counts use bags; craftable recipes sort before unavailable recipes before truncation. Learned state comes from the current character's live API, and queued scans stop when the profession window closes/changes.
- `/fp way` always takes percentages 0–100, including values <=1; three numeric arguments mean mapID/x%/y%. Invalid/nonfinite values are rejected.
- Game-data reads are centralized in Adapter; UI/framework operations (frames, timers, events, rendering, secret-value guard) remain in their owning modules. The strict mock rejects unknown frame methods.
- `tools/check.sh` fails on accumulated validation errors and runs the added regressions. Deployment has no skip-check path. These checks do not emulate WoW's secret-value engine or prove in-game operation.

## 1. The line we stay behind

Blizzard's rules (UI Add-On Development Policy + the Midnight "addon disarmament" that Forever inherits):

- Addons must be free, unobfuscated, publicly viewable, no ads, no donation prompts, must not hurt realm/client performance.
- Presenting information is fine; making gameplay decisions from live combat data or generating inputs is not. One physical input → one action.
- Forever ships Midnight's secret-value system: in combat (and in instanced/PvP contexts) unit health, auras, cooldowns, enemy names/GUIDs and combat-log data come back as **secret values** that error on comparison/arithmetic. `COMBAT_LOG_EVENT_UNFILTERED` cannot even be registered.

ForeverPath therefore: reads quest log, map, POI, loot, vendor, trainer, taxi, profession and non-combat unit data; guards every unit read with `issecretvalue`; never registers the combat log; never calls protected functions (`C_SuperTrack.SetSuperTrackedUserWaypoint` is protected for addons on Forever — we draw our own arrow); never sends inputs. Recording is observation of what the client already shows you.

## 2. Verified client facts (build 70124; re-checked unchanged on 70170, see §9)

| Fact | Value |
|---|---|
| TOC interface | `16001` (Forever beta); flavor suffix `_Camelot.toc`, `_Mainline.toc` also loads |
| API family | Mainline 12.1.5; game type "camelot" in Blizzard TOCs (`[AllowLoadGameType camelot]`) |
| `WOW_PROJECT_ID` | 1 (Mainline) — never branch on it |
| Removed globals | `GetSpellInfo`, `GetItemInfo`, `GetNumSkillLines`, `GetSpellBookItemName`, talent globals → `C_Spell`, `C_Item`, `C_SkillInfo` |
| Quest log | `C_QuestLog.GetNumQuestLogEntries/GetInfo/GetQuestObjectives/ReadyForTurnIn/IsComplete/GetQuestsOnMap/GetNextWaypoint/GetDistanceSqToQuest/GetAllCompletedQuestIDs`, `GetQuestLogRewardXP` (legacy, present) |
| Events | `QUEST_ACCEPTED(questID)`, `QUEST_TURNED_IN(questID, xp, money)`, `QUEST_DETAIL(startItemID)`, `UI_INFO_MESSAGE(type, msg)`, `UNIT_DIED(guid)`, `PARTY_KILL(attacker, target)`, `PLAYER_TARGET_DIED()`, `TAXIMAP_OPENED(system)`, `CONFIRM_BINDER(area)`, `HEARTHSTONE_BOUND` |
| Map | `C_Map.GetBestMapForUnit`, `GetPlayerMapPosition` (nil in instances), `GetWorldPosFromMapPos` (x=north, y=west), `GetMapWorldSize`, `CanSetUserWaypointOnMap`, `SetUserWaypoint`; `GetPlayerFacing()` documented, nilable |
| Minimap | Mainline minimap; `C_Minimap.GetViewRadius()` yards = half of `Minimap:GetWidth()` |
| World map pins | `MapCanvasDataProviderMixin` / `MapCanvasPinMixin`, XML virtual template **without** a `<Scripts>` block (the canvas wires mouse scripts; OnEnter/OnLeave must be nil) |
| Gossip | `C_GossipInfo.GetAvailableQuests/GetActiveQuests/GetOptions`; greeting panel legacy `GetNumAvailableQuests/GetAvailableQuestInfo/GetActiveQuestID` |
| Vendor | `GetMerchantNumItems`, `C_MerchantFrame.GetItemInfo(i)` (table), `GetMerchantItemLink` |
| Trainer | `GetNumTrainerServices`, `GetTrainerServiceInfo/SkillReq/Cost/SkillLine`, `IsTradeskillTrainer` |
| Taxi | `Blizzard_FlightMap` + `C_TaxiMap.GetAllTaxiNodes(GetTaxiMapID())`; legacy `NumTaxiNodes/TaxiNodeCost` still present |
| Loot | `GetNumLootItems/GetLootSlotInfo/GetLootSlotLink` (slot info includes `isQuestItem, questID`); `GetLootSourceInfo` undocumented → feature-detected, target-corpse fallback |
| Skills | `C_SkillInfo.GetNumSkillLines/GetSkillLineInfo` (table: name, rank, maxRank, skillID...), `GetProfessions/GetProfessionInfo` |
| Professions | Dragonflight-style `Blizzard_Professions` with Camelot overrides: `C_TradeSkillUI.GetChildProfessionInfo`, `GetFilteredRecipeIDs` (no `GetAllRecipeIDs` in docs), `GetRecipeInfo` (`relativeDifficulty` 0 orange…3 gray, `numSkillUps`), `GetRecipeSchematic` |
| Comms | `C_ChatInfo.RegisterAddonMessagePrefix/SendAddonMessage`, `InChatMessagingLockdown` |
| Secrets | `issecretvalue`, `C_RestrictedActions.IsAddOnRestrictionActive`; `UnitName` = SecretWhenUnitNameIdentityRestricted, `UnitGUID` = SecretWhenUnitIdentityRestricted |

**Verified in game 2026-09-30 (build 70124, The Barrens, out of combat):** `/fp apicheck` 87 of 90 rows green, zero Lua errors. `C_Map.GetPlayerMapPosition` works outdoors, `GetPlayerFacing` returns radians, the arrow renders with distance and direction, `C_QuestLog.GetQuestsOnMap` returned 17 POIs for the zone (Forever has quest POI data), `C_QuestLog.GetAllCompletedQuestIDs` returned 155 ids, professions readable via `GetProfessions/GetProfessionInfo`, `C_Map.CanSetUserWaypointOnMap` true, NPC identity readable out of combat (recorder captured a guard by creature id and position). Inconclusive: `C_QuestLog.GetNextWaypoint` returned nil for the one quest probed, `GetDistanceSqToQuest` nil, reward XP not loaded at probe time. Player's own `UnitHealth`/`UnitPower` are **secret even out of combat** (`SecretReturns`); the player's own auras were readable out of combat. **Blocked action:** registering `COMBAT_LOG_EVENT_UNFILTERED`, `COMBAT_LOG_EVENT`, `COMBAT_LOG_MESSAGE` or `ENCOUNTER_TIMELINE_EVENT_ADDED` from an addon succeeds in Lua (pcall sees no error) but the client raises the "blocked from an action only available to the Blizzard UI" popup — never register them, not even to test.

## 3. Architecture

```
ForeverPath.toc            interface 16001, SavedVariables ForeverPathDB (account: dataset) / ForeverPathCharDB (waypoints, bind, levels, professions, party)
Core/Namespace.lua         addon table, event frame (handlers in pcall), error sink -> DB, message bus, module registry, timers/throttle
Core/Util.lua              GUID parsing, geometry (bearing/distance/minimap offset), formatting
Core/Config.lua            defaults, ADDON_LOADED init, module Init/Enable
API/Adapter.lua            THE ONLY WoW API surface; feature detection + secret guards + API.Check()
Nav/Position.lua           player pos/facing/world coords cache; 0.1 s ticker only while something needs it
Nav/Waypoints.lua          waypoint list, active selection (nearest-first), arrival
Nav/Arrow.lua              arrow frame (rotation = bearing - facing), distance/ETA
Nav/MapPins.lua + .xml     world map data provider + minimap pin
Data/Recorder.lua          telemetry (see schema)
Prof/Tracker.lua           profession ranks, recipe/reagent snapshots, best skill-up crafts
Route/Planner.lua          Phase 1 planner (see below)
Party/Sync.lua             export/import string + addon-message sync
UI/Panel.lua, UI/Commands.lua, Core/SelfTest.lua
```

Rule: only `API/Adapter.lua` calls WoW functions. If Blizzard renames something on 11/4, one file changes.

Performance: event-driven; the only polling is a 0.1 s position ticker while the arrow/panel/minimap pin is active, plus a 0.05 s-throttled arrow OnUpdate. Recorder writes are O(1) per event; positions are deduplicated at 25 yd and capped per entity.

## 4. Dataset schema (ForeverPathDB.data)

- `quests[id]` = `{ t=title, l=level, dl=difficulty, sg=group, h=log header, obj={ {text,type,req, mobs={creatureID=n}, src={objectID=n}, pos=[{m,x,y}]} }, otext=offer objective text, givers={npcID=true}, enders={npcID=true}, gpos={m,x,y}, epos={m,x,y}, xp={["playerLevel"]=xp}, money, rew=[itemID], choice=[itemID], startItem, items={itemID={sourceID=n}}, after={prevQuestID=true}, log=[{c,acc,done,lvl,dlvl,abandoned}] }`
- `npcs[id]` = `{ n=name, lvl, pos=[{m,x,y}]≤3, zone, flags={quest,vendor,trainer,taxi,inn}, gossip=[text] }`
- `creatures[id]` = `{ n, lmin, lmax, cls, type, react, pos=[{m,x,y}]≤40, kills, looted, loot={itemID=qty}, xp={["level"]=xp}, zone }`
- `objects[id]` (GameObjects: herbs, ore, chests, quest objects) = `{ pos≤60, count, loot }`
- `items[id]` = `{ n, q, quest }`; `vendors[npcID]` = `{ items={itemID={p,s,lim,ext}} }`; `trainers[npcID]` = `{ tradeskill, services={name={type,lvl,skill,rank,cost,line,item}} }`
- `taxi.nodes[nodeID]` = `{ n, m, x, y, npc, pos, known }`, `taxi.edges["from>to"]` = `{ cost }`
- `binds[npcID]`, `progress[]` (ring 4000: `{q,o,from,to,m,x,y,kill,src,t,c}`), `deaths[]`, `zones[name]={m,lmin,lmax}`, `xp[char][]`, `recipes[professionID]={ n, skill, max, r={ recipeID={ n, ups, diff={["skill"]=0..3}, reag={itemID=qty}, out, qmin, qmax } } }`, `chars[key]`
- Also `ForeverPathDB.apicheck[build]`, `ForeverPathDB.errors[]` (last 60 Lua errors with build), `meta.counters`.

## 5. Planner (Phase 1) and what replaces it

Steps come from the live log: complete quest → turn-in (position: recorded ender → recorded NPC → Blizzard POI → Blizzard next-waypoint → giver); unfinished objective → objective area (Blizzard next-waypoint → POI on the current map → recorded progress centroid → recorded mob positions). Score = yards, −250 for turn-ins, −150 for party-shared quests, unknown positions last; hearth hint when ≥2 turn-ins sit within 400 yd of the bind point and you're >1500 yd away.

Phase 4 replaces the score with `xp / minutes` over a quest graph (prereqs from `after` hints + completed-ID snapshots, XP per level from `xp`, travel from taxi edges + measured speed, mob density from `creatures.pos`), and Phase 6 adds "prep mode" (complete-but-don't-turn-in before a cap raise).

## 6. Phases / acceptance

1. **Foundation** (this build): loads with zero errors on 70124; `/fp apicheck` all probes green outdoors; arrow points at `/fp way` targets; panel lists log; recorder fills quests/npcs/creatures/loot/vendors/trainers/taxi after a normal play session (check with `tools/pull-data.sh`).
2. **Quest GPS**: objective areas for every quest in the log come from POI/recorded data ≥90 % of the time after one pass through a zone; auto-next never loops on an arrived objective.
3. **Professions**: `/fp prof` recommends the cheapest orange/yellow craft including farm targets (creatures that drop the reagent, from `creatures.loot`) and vendor reagents (from `vendors`).
4. **Optimization**: quest graph + XP/time route; cluster quests by objective proximity; hearth/flight aware.
5. **Party**: joint route from two logs (shared quests first, individual detours by distance).
6. **Launch mode**: level-1 route from the beta dataset; prep mode.

## 7. Verification discipline

- `tools/check.sh` before every deploy (syntax + mock play-through, fails on any addon error).
- In game: `/fp status` (stored errors), `/fp apicheck` after every client build; `tools/pull-data.sh` after sessions — errors and API probes live in the SavedVariables file, so a session can be debugged from the file without the player present.
- A null result from an unverified probe is not evidence: if `GetQuestsOnMap` returns 0 POIs, confirm with a quest that Blizzard's own map shows a POI for before concluding Forever has no POI data.

## 8. PvP module (added 2026-09-30, v0.2.0)

Verdict from Blizzard's secret predicates (`SecretPredicatesDocumentation.lua`, build 70124): enemy cast events/info are secret for any unit that is "not the player or their pet"; auras and cooldowns (including your own) are secret whenever combat, encounter, challenge-mode or PvP-match restrictions are active; enemy **player** identity stays readable ("except in PvP when the queried unit is a player"); addon chat is locked in BGs/arenas and restricted maps; BG flag positions, area POIs and scoreboard name/class fields are never secret. Therefore:

| Idea | Verdict | Built as |
|---|---|---|
| Enemy cooldown / trinket / DR / interrupt trackers | impossible by design | — |
| Enemy cast alerts | Blizzard's important-cast highlight only | — |
| Own-cast timers (Counterspell lockout, Polymorph DR, Frost Nova…) | allowed | `PvP/CastTimers.lua` |
| Enemy roster / last seen | allowed for players | `PvP/Roster.lua` |
| Battleground objectives / flag carriers | allowed | `PvP/Battleground.lua` |
| Party CC coordination | allowed outside BGs/arenas | `PvP/Coordination.lua` |
| Frost Mage HUD | Blizzard Cooldown Manager ships on Forever | — |

Unverified until the first battleground: atlas/texture → base-state mapping (recorded raw in `data.bg`), flag texture → faction, whether `C_Map.GetPlayerMapPosition` works inside Forever BGs (expected nil), whether BG maps count as addon-restricted maps.

## 9. Build 70170 (2026-10-01 beta patch) — source-diff verification

Client updated 2026-10-01 to 1.60.1.70170 (`.build.info`); version string unchanged so the interface number stays **16001** and v0.2.1 loads as-is. Blizzard's UI source for 70170 (`Gethe/wow-ui-source` `forever` commit `9a789c0`) diffed against 70124 (`966519c`): 119 files, API documentation changes only additive.

| Change in 70170 | Effect on ForeverPath |
|---|---|
| Every function, namespace and event the addon references is still present (scripted check of 142 API names + registered events against `Blizzard_APIDocumentationGenerated`) | none |
| `C_TradeSkillUI.GetAllRecipeIDs/GetFilteredRecipeIDs` undocumented in both builds, still used by `Blizzard_Professions.lua`; in-game apicheck 9/30 = ok | none; feature-detected |
| New `C_Spell.GetItemCooldown(itemID)` → `SpellCooldownInfo` table, may return nothing | third fallback in `API.GetHearthCooldown` (table shape handled); apicheck row |
| New event `PLAYER_PVP_FLAG_CHANGED(isPvpFlagged)` | probe samples on it (`pvp-flag=true/false`) so the world-PvP restriction timeline is recorded |
| New `UnitUsesAmmo(unit)` | apicheck presence row only |
| `MAX_QUESTS`/`MAX_QUESTLOG_QUESTS` now read `Constants.QuestLogConsts.MAXIMUM_NUM_QUESTS_LOG_CAN_ACCEPT` (= 40 in source) | planner never hardcoded 25; `probe:questLogCap` records the live value |
| `PlayerLocation` name field now non-nilable, `MayReturnNothing` | unused |
| Quest frame fades detail text in when the CVar `instantQuestText` is "0" and disables Accept until shown; new Interface setting | recorder reads quest data from `QUEST_DETAIL`/API, not the frame — unaffected |
| Shard-transfer popup (`SHARD_TRANSFER_IMMINENT`) removed from the UI; patch notes "adjustments to world instances" | unused |
| Nameplate font/health-text layout, PvP indicator icons, stable/gamepad/cooldown-manager UI, Camelot `ProjectConstants` (`WOW_PROJECT_CAMELOT = 18`) | unused |

Patch-note items without an API footprint: level cap 30, Razorfen Downs/Uldaman/Excavation Site: Wetlands open, dungeon quests −50 % bonus XP (dataset `rewardXP` values will differ from 70124 captures for dungeon quests), Honor cap 25 000 and PvP gear costs +50 %, pet Aggressive Mode back. **Not yet run in game on 70170**: the next `/fp apicheck` (key `70170`) and `tools/pull-data.sh` are the verification; expect `probe:questLogCap` = 40.
