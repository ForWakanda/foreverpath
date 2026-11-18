# HEARTHANDHUSTLE_SPEC — design, boundaries, phases

Written 2026-09-30 for the WoW Forever beta (client 1.60.1.70124). Everything in "Verified" was checked against Blizzard's Forever UI source, branch `forever` of `Gethe/wow-ui-source`, commit `966519c` ("1.60.1 (70124)").

## 2026-09-30 v0.1.1 corrections

The original design below is retained as the v0.1 baseline. Implemented corrections supersede its affected behavior/schema:

- Arrival state persists independently of the arrow. Objectives wait for completion; turn-ins wait for the quest action; explicit next skips the waiting step. Manual destinations are preserved.
- Recorder schema v2: observed loot uses every per-slot GUID/quantity pair and per-source item maxima, with a persisted 24-hour/2,048-source dedup cache. Unknown sources go to `data.lootObservations` (last 200 opens) with uncertain target candidates. Totals describe observed offers, not collection/drop probabilities.
- Progress entries retain `killCandidates`, `lootCandidates`, `lootItems`, `attribution="unconfirmed"`, and `observer=true`. Time proximity no longer writes confirmed `obj.mobs`/`obj.src`. Position records retain observer/provenance fields. Old biased totals/mappings are preserved under `legacy*V1` fields.
- Automatic/manual API reports persist `{ok,status,note}` rows, build/version/time, and ten-report history; one throwing probe does not prevent the others. No probe proves arrow texture orientation or in-game XML behavior.
- `/hh record off` gates dataset persistence, not live navigation/profession calculations, party/settings/bind state, or diagnostics. Queued dataset work rechecks the switch; toggling starts a new progress baseline.
- In-game self-tests are pure. Party send results are compared with the success enum; live imports refresh plans and expire when the sender leaves, while pasted seeds persist. Snapshots over 255 bytes use bounded reassembly. Completion/removal changes sync too.
- Profession counts use bags; craftable recipes sort before unavailable recipes before truncation. Learned state comes from the current character's live API, and queued scans stop when the profession window closes/changes.
- `/hh way` always takes percentages 0–100, including values <=1; three numeric arguments mean mapID/x%/y%. Invalid/nonfinite values are rejected.
- Game-data reads are centralized in Adapter; UI/framework operations (frames, timers, events, rendering, secret-value guard) remain in their owning modules. The strict mock rejects unknown frame methods.
- `tools/check.sh` fails on accumulated validation errors and runs the added regressions. Deployment has no skip-check path. These checks do not emulate WoW's secret-value engine or prove in-game operation.

## 1. The line we stay behind

Blizzard's rules (UI Add-On Development Policy + the Midnight "addon disarmament" that Forever inherits):

- Addons must be free, unobfuscated, publicly viewable, no ads, no donation prompts, must not hurt realm/client performance.
- Presenting information is fine; making gameplay decisions from live combat data or generating inputs is not. One physical input → one action.
- Forever ships Midnight's secret-value system: in combat (and in instanced/PvP contexts) unit health, auras, cooldowns, enemy names/GUIDs and combat-log data come back as **secret values** that error on comparison/arithmetic. `COMBAT_LOG_EVENT_UNFILTERED` cannot even be registered.

Hearth & Hustle therefore: reads quest log, map, POI, loot, vendor, trainer, taxi, profession and non-combat unit data; guards every unit read with `issecretvalue`; never registers the combat log; never calls protected functions (`C_SuperTrack.SetSuperTrackedUserWaypoint` is protected for addons on Forever — we draw our own arrow); never sends inputs. Recording is observation of what the client already shows you.

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

**Verified in game 2026-09-30 (build 70124, The Barrens, out of combat):** `/hh apicheck` 87 of 90 rows green, zero Lua errors. `C_Map.GetPlayerMapPosition` works outdoors, `GetPlayerFacing` returns radians, the arrow renders with distance and direction, `C_QuestLog.GetQuestsOnMap` returned 17 POIs for the zone (Forever has quest POI data), `C_QuestLog.GetAllCompletedQuestIDs` returned 155 ids, professions readable via `GetProfessions/GetProfessionInfo`, `C_Map.CanSetUserWaypointOnMap` true, NPC identity readable out of combat (recorder captured a guard by creature id and position). Inconclusive: `C_QuestLog.GetNextWaypoint` returned nil for the one quest probed, `GetDistanceSqToQuest` nil, reward XP not loaded at probe time. Player's own `UnitHealth`/`UnitPower` are **secret even out of combat** (`SecretReturns`); the player's own auras were readable out of combat. **Blocked action:** registering `COMBAT_LOG_EVENT_UNFILTERED`, `COMBAT_LOG_EVENT`, `COMBAT_LOG_MESSAGE` or `ENCOUNTER_TIMELINE_EVENT_ADDED` from an addon succeeds in Lua (pcall sees no error) but the client raises the "blocked from an action only available to the Blizzard UI" popup — never register them, not even to test.

## 3. Architecture

```
HearthAndHustle.toc            interface 16001, SavedVariables HearthAndHustleDB (account: dataset) / HearthAndHustleCharDB (waypoints, bind, levels, professions, party)
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

## 4. Dataset schema (HearthAndHustleDB.data)

- `quests[id]` = `{ t=title, l=level, dl=difficulty, sg=group, h=log header, obj={ {text,type,req, mobs={creatureID=n}, src={objectID=n}, pos=[{m,x,y}]} }, otext=offer objective text, givers={npcID=true}, enders={npcID=true}, gpos={m,x,y}, epos={m,x,y}, xp={["playerLevel"]=xp}, money, rew=[itemID], choice=[itemID], startItem, items={itemID={sourceID=n}}, after={prevQuestID=true}, log=[{c,acc,done,lvl,dlvl,abandoned}] }`
- `npcs[id]` = `{ n=name, lvl, pos=[{m,x,y}]≤3, zone, flags={quest,vendor,trainer,taxi,inn}, gossip=[text] }`
- `creatures[id]` = `{ n, lmin, lmax, cls, type, react, pos=[{m,x,y}]≤40, kills, looted, loot={itemID=qty}, xp={["level"]=xp}, zone }`
- `objects[id]` (GameObjects: herbs, ore, chests, quest objects) = `{ pos≤60, count, loot }`
- `items[id]` = `{ n, q, quest }`; `vendors[npcID]` = `{ items={itemID={p,s,lim,ext}} }`; `trainers[npcID]` = `{ tradeskill, services={name={type,lvl,skill,rank,cost,line,item}} }`
- `taxi.nodes[nodeID]` = `{ n, m, x, y, npc, pos, known }`, `taxi.edges["from>to"]` = `{ cost }`
- `binds[npcID]`, `progress[]` (ring 4000: `{q,o,from,to,m,x,y,kill,src,t,c}`), `deaths[]`, `zones[name]={m,lmin,lmax}`, `xp[char][]`, `recipes[professionID]={ n, skill, max, r={ recipeID={ n, ups, diff={["skill"]=0..3}, reag={itemID=qty}, out, qmin, qmax } } }`, `chars[key]`
- Also `HearthAndHustleDB.apicheck[build]`, `HearthAndHustleDB.errors[]` (last 60 Lua errors with build), `meta.counters`.

## 5. Planner (Phase 1) and what replaces it

Steps come from the live log: complete quest → turn-in (position: recorded ender → recorded NPC → Blizzard POI → Blizzard next-waypoint → giver); unfinished objective → objective area (Blizzard next-waypoint → POI on the current map → recorded progress centroid → recorded mob positions). Score = yards, −250 for turn-ins, −150 for party-shared quests, unknown positions last; hearth hint when ≥2 turn-ins sit within 400 yd of the bind point and you're >1500 yd away.

Phase 4 replaces the score with `xp / minutes` over a quest graph (prereqs from `after` hints + completed-ID snapshots, XP per level from `xp`, travel from taxi edges + measured speed, mob density from `creatures.pos`), and Phase 6 adds "prep mode" (complete-but-don't-turn-in before a cap raise).

## 6. Phases / acceptance

1. **Foundation** (this build): loads with zero errors on 70124; `/hh apicheck` all probes green outdoors; arrow points at `/hh way` targets; panel lists log; recorder fills quests/npcs/creatures/loot/vendors/trainers/taxi after a normal play session (check with `tools/pull-data.sh`).
2. **Quest GPS**: objective areas for every quest in the log come from POI/recorded data ≥90 % of the time after one pass through a zone; auto-next never loops on an arrived objective.
3. **Professions**: `/hh prof` recommends the cheapest orange/yellow craft including farm targets (creatures that drop the reagent, from `creatures.loot`) and vendor reagents (from `vendors`).
4. **Optimization**: quest graph + XP/time route; cluster quests by objective proximity; hearth/flight aware.
5. **Party**: joint route from two logs (shared quests first, individual detours by distance).
6. **Launch mode**: level-1 route from the beta dataset; prep mode.

## 7. Verification discipline

- `tools/check.sh` before every deploy (syntax + mock play-through, fails on any addon error).
- In game: `/hh status` (stored errors), `/hh apicheck` after every client build; `tools/pull-data.sh` after sessions — errors and API probes live in the SavedVariables file, so a session can be debugged from the file without the player present.
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

| Change in 70170 | Effect on Hearth & Hustle |
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

Patch-note items without an API footprint: level cap 30, Razorfen Downs/Uldaman/Excavation Site: Wetlands open, dungeon quests −50 % bonus XP (dataset `rewardXP` values will differ from 70124 captures for dungeon quests), Honor cap 25 000 and PvP gear costs +50 %, pet Aggressive Mode back. **Not yet run in game on 70170**: the next `/hh apicheck` (key `70170`) and `tools/pull-data.sh` are the verification; expect `probe:questLogCap` = 40.


## 10. 2026-10-04 usability review (Codex, v0.3.0)

Source basis: Forever **1.60.1.70205**, Blizzard UI mirror `e3ecc27b64d30fdc735a3f6579b866858f9f9df1`.
Fresh pre-change SavedVariables: zero stored errors, 139 recorded quests, 447 progress observations, zero recipe professions, no recorded battleground maps. Build 70205 probes: 90 ok, three inconclusive (quest waypoint, quest distance, unloaded reward XP). These describe v0.2.2 play, not v0.3.0 runtime verification.

- Profession correction to section 2: `Blizzard_ProfessionsTemplates/Camelot/Blizzard_Professions.lua` uses `GetBaseProfessionInfo`; shared `Professions.GetProfessionInfo` also falls back when child `professionID == 0`. The adapter previously rejected that context. It now checks child then base, rejects linked/guild/NPC contexts and exposes `probe:openProfession`. This is a source-supported failure mechanism plus a failing mock reproduction; a new in-game recipe scan remains required.
- Trade skill scans retry transient empty data at most three times, stop after close/context changes, and refresh on name/source/list/skill events. The panel shows three learned skill-up suggestions and missing bag materials; rank-cap and stale-skill states have explicit guidance. Unsupported required reagent slots stay unknown. Live advice remains available with recording off.
- Route refresh runs every three seconds independently of panel visibility. It refreshes same-step coordinates/progress; resumes from idle or departure beyond max(100 yd, 3 × arrival radius); retains an automatic target unless a competitor improves the score by more than 75 yd. Existing turn-in/shared-quest score bonuses remain. Explicit row selections stay pinned until invalid/arrived; clear pauses until next/go/auto-on. Battlegrounds suspend quest waypoints.
- Mage timers use the cast-send target's readable identity, never the selected target at cast completion. Frost Nova does not claim a single victim or DR category. All bars say `est.`. The legacy DR factors/reset and tooltip-derived durations remain hypotheses, not verified landed-effect/PvP-duration readings.
- Party timer receives now require current PARTY membership and bounded valid payloads. BG flag tracking does not label an arbitrary first flag as the enemy carrier; users can choose a numbered map slot when multiple flags appear. Slot/faction stability is unverified. BG and PvP-roster collection now respect recording off.
- No game inputs, targeting, casting, turn-ins, combat-log registration or secret-value bypass introduced. New map/spell/identity reads pass through the adapter.

Validation: 62 regressions + 18 self-tests + mock play-through; existing SavedVariables mock-load smoke passes. Actual frame sizing, automatic navigation feel, profession scans and battleground behavior still require the client. See `docs/reviews/2026-10-04/REVIEW.md`.


## 11. 2026-10-04 Mage preparation (Codex, v0.4.0)

`PvP/MagePrep.lua` adds a read-only preparation section to the existing PvP HUD. Per-character `prep` defaults are mode auto, 40 drinks, 10 carried bandages, 5 reagents per relevant type. Display is temporary for 20 s on login/zone transitions, while at merchants, and out of combat in BGs; explicit show/hide/auto/off controls and `/hh prep` reporting are available. PvP HUD hide/off remains authoritative. No game action or combat cooldown/aura read is performed. Runtime snapshots do not write the recorded dataset.

New adapter contracts verified against Blizzard Forever source `e3ecc27b64d30fdc735a3f6579b866858f9f9df1` (70205): `C_Container.GetContainerNumSlots`, `GetContainerItemInfo` (`itemID`, `stackCount`); `C_Item.GetItemInfo` tuple (`itemMinLevel` fifth, `classID` twelfth, `subclassID` thirteenth); `C_Item.GetItemSpell`; `C_SpellBook.IsSpellKnown` default Player bank; `C_Item.RequestLoadItemDataByID`. Inventory scans iterate 0..NUM_TOTAL_EQUIPPED_BAG_SLOTS (NUM_BAG_SLOTS/4 fallback), never banks. Missing/error/secret reads stay unknown. Relevant events are documented `SPELLS_CHANGED`, `GET_ITEM_INFO_RECEIVED`, `MERCHANT_SHOW/CLOSED`, bags, levels, zones and combat transitions.

Drink classification compares a carried Fooddrink item's localized use-effect name with item 159's Drink effect; rejects minLevel above the player. Combined food/drink effects with a different name are intentionally outside coverage. Consumable/Bandage class 0/subclass 7 means carried supply, not learned First Aid/usability. Cache misses mark category totals unknown and trigger bounded retries; gear cache misses cannot silently become zero supplies. `probe:magePrep` persists summary counts and a learned-spell lookup result.

Supported static associations, gated by learned spells at runtime: Agate 759→5514, Jade 3552→5513, Citrine 10053→8007, Ruby 10054→8008; Slow Fall 130→17056; six original capital teleports→17031; six original portals→17032; Arcane Brilliance 23028→17020. No rank-training levels, heal/mana amounts or cooldown values are inferred. Association references: [Agate](https://www.wowhead.com/classic/spell=759/conjure-mana-agate), [Jade](https://www.wowhead.com/classic/spell=3552/conjure-mana-jade), [Citrine](https://www.wowhead.com/classic/it/spell=10053/conjure-mana-citrine), [Ruby](https://www.wowhead.com/classic/spell=10054/conjure-mana-ruby), [Slow Fall](https://www.wowhead.com/classic/spell=130/slow-fall). These reference mappings do not establish in-game Forever behavior; live learned-state/count probes remain required.

Validation: 72 regression checks, 18 self-tests, mock play-through. Added cases cover localized drink classification, food/potion/high-level/bank exclusion, reagent bag, item-cache recovery, unsupported APIs, false-versus-unknown learned state, stock changes/new spells, combat guards, display lifecycle, per-character settings, other classes, record-off and global HUD controls. Latest saved session still has zero errors and no BG map observations. Faction-specific BG alerts are deferred until observed state/faction meanings can be validated.


## 12. 2026-10-11 Dungeon rare watch (Claude, v0.5.0)

Purpose: tell two players farming the Scarlet Monastery Graveyard whether Azshir the Sleepless (or Ironspine / Fallen Champion) is up in their instance, share the answer, and measure the spawn rate.

**Verified from the 2026-10-09 SavedVariables (build 70291, probe samples inside a party dungeon):** with `c.active=Map`, `combat=0`, `pAuras=0`, the targeted NPC reads `t.name=secret t.guid=secret t.class=secret t.pIdentity=1` while `t.level=number t.reaction=2 t.isPlayer=npc`. So the Map restriction alone makes NPC identity secret inside dungeons, out of combat. Chat lockdown was 0 in those samples (1 only under `Encounter`). The City of Dalaran loot windows (2026-10-08) recorded boss creature ids from `GetLootSourceInfo` → loot-source GUIDs are not guarded in dungeons.

**Verified in Blizzard's Forever source (`Gethe/wow-ui-source` `forever`, 1.60.1.70338):** `UnitClassification`, `UnitIsDead`, `UnitExists`, `UnitLevel` carry no `SecretWhen…` attribute (only `SecretArguments = "AllowedWhenUntainted"`); `UnitGUID` is `SecretWhenUnitIdentityRestricted`, `UnitName` `SecretWhenUnitNameIdentityRestricted`. `/targetexact` is a secure slash command (`Blizzard_ChatFrameBase/Shared/SlashCommands.lua`, `TargetUnit(target, true)`), usable from a `SecureActionButtonTemplate` macro. `C_VignetteInfo.GetVignettes/GetVignetteInfo` + `VIGNETTE_MINIMAP_UPDATED` exist (whether vanilla rares carry vignettes is unknown). `PlaySound` exists; `SOUNDKIT.RAID_WARNING = 8959`. `CHAT_MSG_SYSTEM` text is `SecretInChatMessagingLockdown`. `GetInstanceInfo` returns `instanceID` (map id) eighth. `INSTANCE_RESET_SUCCESS` is a GlobalString not present in the mirror; the parser falls back to "%s has been reset.".

**Design:** `Modules/RareWatch.lua` + adapter `API.UnitRare / GetInstance / GetVignettes / PlayAlert / ShowUnitName` + `U.ParseGUIDFull` (zoneUID = fourth GUID field). Sighting = hostile unit with classification `rare`/`rareelite` (or a readable name / loot-source id on the watch list) inside the watched instance; sources: target, mouseover, focus, `NAME_PLATE_UNIT_ADDED`, `UNIT_TARGET` for party/pet tokens, the Scan button's post-click sweep. Alert once per run (re-alert after 10 min), party messages `RW;up|no|kill`. Runs keyed by loot-source zoneUID; provisional `visit-<t>` until loot; merge on re-entry; close on reset message, superseding zoneUID, 2 h idle, or `/hh rare newrun`. Scan button is a protected frame on UIParent: attributes and Show/Hide happen out of combat only, deferred to `PLAYER_REGEN_ENABLED`. Secret names are passed to `FontString:SetText` inside pcall for display and never compared, concatenated or stored (`sightings[].secret = 1`).

**Line check:** no automatic targeting; the Scan button is a player-clicked macro (one input → one action), identical to a `/targetexact` macro on the action bar. No combat-log registration, no protected calls from Lua.

**Unverified until the first Graveyard session:** `probe:targetClassification` (classification readable where the name is secret), `/targetexact` reach, `SetText` with a secret, vignettes on vanilla rares (`HearthAndHustleDB.rare.vignettes`), creature ids 6490/6489/6488 on Forever, hunter-pet GUID zoneUID semantics (`run.petZone` recorded for comparison with the loot key).

Validation: mock play-through scenario + 4 regressions (79 total) + 18 self-tests; `tools/check.sh` green.



## 13. Release launch update — 2026-11-04 (Codex, v0.6.0)

The installed release manifest reports `wowf 1.60.1.70790`. Blizzard UI source mirror `Gethe/wow-ui-source`, branch `forever`, HEAD `eac30af597e5aaa43a60f6675ef5fdcea100375f`, has the identical `version.txt`. Interface remains 16001. This is source/install evidence, not a loaded-client probe.

New adapter reads: `C_Container.GetContainerNumFreeSlots(bagIndex)` returns `numFreeSlots, bagFamily`; only family zero contributes general loot capacity. `C_Item.GetItemCount(itemID, false)` is guarded for crafting guidance: missing, throwing, secret, or negative counts become unavailable, never zero. Both new helpers refuse reads in combat. `C_QuestLog.GetInfo` documents `level` and `suggestedGroup`; routing uses guarded values and does not guess when absent. Class supplies use existing bag/learned-spell reads; shaman/hunter reminders are static, not aura/rotation decisions. The historical `probe:magePrep` key remains, with `probe:classPrep` added for class/general bag capacity.

Quest scoring adds at most 180 yards of cluster preference (60 per other distinct quest within 200 yards), and a 500-yard penalty for unfinished quests more than three levels above the player. These are bounded heuristics, not measured XP/hour improvement. Explicit pins/manual waypoints remain authoritative. Live turn-in navigation is preferred over beta recordings. `/hh skip` defers the entire active quest for 1–60 minutes, defaults to 10, expires/clears without abandoning any quest, and is session-only. `/hh duo` labels partner data as a last snapshot.

Profession batch targets are session-only fixed craft counts; they recalculate bag deficits but do not decrement based on ambiguous item-output events. Players adjust the target after crafting. Only current learned usable recipes with complete supported reagent schematics can seed a plan. No price/profit claims, purchases, or crafting actions.

Old beta SavedVariables are retained as historical evidence and not installed into the release client. The latest local October 11 archive contains six rare-watch secret-height errors predating the existing fixed-height repairs; it is not a fresh 70790 result. First release login must establish actual arrow, party, profession and supply behavior through `/hh apicheck`, `/reload`, and `tools/pull-data.sh`.


## 14. Release quest guidance repair — 2026-11-04 (Codex, v0.6.1)

Fresh build 70790 SavedVariables report three logged quests, three map POIs, readable position/facing, and zero stored errors. GetNextWaypoint for quest 4402 returned no waypoint, while the planner saved a valid POI-derived objective waypoint. Arrow setting was shown=true, default center offset; panel hidden. User reports the entire arrow area blank and wants Vile Familiars (792), while automatic routing had selected Galgar's Cactus Apple Surprise (4402). This does not establish a working arrow: the old render callback was outside the stored error handler.

Code changes: unfinished-objective arrival retains a visible area indicator; explicit client quest selection takes precedence over distance heuristics; /hh guide restores frame positions and display; /hh pickups selects among current-map available offers. C_QuestLine.GetAvailableQuestLines and RequestQuestLinesForMap signatures/offer coordinates checked against 70790 Blizzard UI source (QuestOfferDataProvider.lua uses coordinates in the queried map). GetNextWaypointForMap supplements GetNextWaypoint before POI fallback. No historical giver sightings are treated as eligibility; no full static quest database is bundled. New manual diagnostics capture exact log/POI/offer/active/waiting state and arrow visibility/texture; rendering failures now enter the stored error sink.

Runtime boundary: source and regression-tested changes only until the user's reload and subsequent saved-data read. Selected-quest tracking and available questline coverage remain client checks.


## 15. Automatic guidance follow-up — v0.6.2

User requires useful normal gameplay without slash-command setup or diagnosis. Guidance already replanned periodically; v0.6.2 reconciles and paints the display on the same independent timer even while waiting or with the panel closed. No coordinates produces visible explanatory text without a misleading directional arrow; location data arriving later recovers the arrow automatically. Explicit hide/stop preferences remain respected. API probes rerun automatically on addon-version change; latest navigation/display evidence is overwritten every 30 seconds (bounded one snapshot), independent of recording, and flushed by normal WoW SavedVariables behavior. A no-command regression exercises objective arrival, completion, turn-in, next available pickup, acceptance and automatic diagnostics. Client visual behavior remains pending; only one reload is required to load edited Lua files.


## Dungeon quest checklist — v0.7.0 (2026-11-05, Codex)

`Data/DungeonCatalog.lua` is a deterministic, offline-generated reference from DungeonQuestTracker revision `b4ae5a478d0f96c842c13d5ad96bb4adb11f15df` (MIT notice bundled). `tools/import-dungeon-catalog.lua <reviewed source checkout>` loads only its named data files in a restricted Lua environment, emits selected data fields, and imports no runtime behavior. Regeneration requires reviewing upstream changes and provenance; do not silently claim this community/Classic data is release-verified. 455 quest records, 35 dungeon/wing entries, 30 populated and 5 explicit coverage gaps.

`Modules/Dungeons.lua` evaluates character-specific state via `API.GetDungeonQuestState`: feature-detected, protected calls to `C_QuestLog.IsOnQuest`, `IsComplete`, and `IsQuestFlaggedCompleted`. Boolean signatures verified in the local Blizzard Forever 70790 source `QuestLogDocumentation.lua`; these new adapter paths are mock-tested, not client-proven. Nil/secret/error remains unknown. Actual active/completed state and live map offers take precedence over source restrictions. Missing quests never imply confirmed eligibility. Gates implement AND across prerequisites and OR within `anyOf`; `state=active` requires the predecessor in log; breadcrumbs are nonmandatory; detail recursion is cycle/depth bounded.

The panel's Dungeons button opens a paginated, draggable browser with faction/class filtering, scrollable pickup/chain details, per-character selection/filter, and event-coalesced refresh while open. Closed panel does not scan the catalogue. The feature does not change waypoints, send group chat or accept/share quests. Catalogue-only information cannot certify all-quest readiness. Fresh SavedVariables/client observations remain the next verification boundary.


## 16. Vendor helper, status line, reminders, trainer notes — v0.8.0 (2026-11-07, Claude)

Motivation: a CurseForge survey of the most-installed Forever addons (ForeverPlus ≈97k, ForeverForge ≈32k, ForeverUI ≈30k; Leatrix Plus, Questie, Vendor Price, What's Training? in every roundup). Their common features: auto quest accept/turn-in, sell grays, repair, vendor value on tooltips and quest rewards, buff/consumable warnings, an info bar (xp/h, gold, bags, durability, ammo, latency), trainer awareness. Adopted: everything informational, plus sell-grays and repair as **click buttons** (one click = one batch/one repair). Rejected on the project's line: auto accept/turn-in, auto loot, auto buy, auto gossip, auto release.

Source facts verified in Blizzard's Forever UI source at `1.60.1.70862` (`Gethe/wow-ui-source` `forever`, 2026-11-07; the installed client was 70790 at the last pull, 70840/70862 are later builds): `C_Item.GetItemInfo` 11th return `sellPrice`; `ContainerItemInfo` fields `quality`, `hasNoValue`, `isLocked`, `hyperlink`, `itemID`, `stackCount`; `C_Container.UseContainerItem(bag, slot)`; `GetRepairAllCost() -> cost, canRepair`, `CanMerchantRepair()`, `RepairAllItems()` (used by Blizzard's Mainline MerchantFrame, which camelot loads); `GetInventoryItemDurability(slot)` (used by Camelot PaperDollFrame); `UnitUsesAmmo`, `GetInventoryItemCount/ID("player", INVSLOT_AMMO=0)`; `GetMoney`; `GetFramerate`; `GetNetStats -> in, out, latencyHome, latencyWorld`; `C_UnitAuras.GetPlayerAuraBySpellID` with `C_Secrets.ShouldAurasBeSecret` as the gate; `C_PaperDollInfo.GetTemporaryEnchantmentInfo(slot) -> { remainingTimeMs, chargesRemaining, enchantID }` (the deprecated `GetWeaponEnchantInfo` shim wraps it); `TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, fn)` and `TooltipUtil.GetDisplayedItem(tooltip) -> name, link, id`; `QuestInfo_ShowRewards` + `QuestInfoFrame.rewardsFrame.RewardButtons[i]` with `.type` and `:GetID()`; `GetQuestItemLink(type, i)`. Forever's Mainline MerchantFrame carries `MerchantSellAllJunkButton` gated by `C_MerchantFrame.IsSellAllJunkEnabled()`: when it is shown the strip's sell button becomes a value readout and never sells.

Guards: every read in `API` returns nil on combat, missing API, secret or non-finite values; unpriced (uncached) grays count as "not priced yet", never as worthless or as junk to sell. `SellSlot`/`RepairAll` refuse unless `MerchantFrame` is shown and the player is out of combat. Aura reads return nil (not false) when the predicate says secret, when the API is missing, or when a value is secret; a reminder requires a KNOWN rank and an aura read of exactly `false`.

Unverified in game (mock-tested): strip anchoring under the live `MerchantFrame`; own-buff readability out of combat on Forever; the Classic spell ids in `InfoBar.lua` (`BUFFS`, `IMBUES`); the reward-button layout with the value text; the tooltip hook firing for bag items. Also fixed: live 70790 stored error `C_QuestLog.IsOnQuest(nil)` from the plan check — the adapter now guards the argument.

New settings: `vendor { enabled, tooltipPrice, rewardValues }`, `bar { shown, locked, scale, x, y, point, fps }`, `reminders { enabled, buffs, durability, ammo }`, `trainer { enabled }`. Trainer records gain `class` (the visiting class) so level-up notes read only this class's trainers. Regressions: 7 new cases (117 total) + a play-through smoke block.



## 17. World-map quest hover — v0.8.1 (2026-11-09, Codex)

User report: the Hearth & Hustle pin obscures WoW's quest marker and prevents the quest-area hover outline. Right-click removal lasts only a few seconds. Source confirms two interacting behaviors: our template enables clicks/motion and uses `PIN_FRAME_LEVEL_TOPMOST`; the route planner recreates a removed planned waypoint on its three-second tick.

Repair: all Hearth & Hustle world-map pins use `PIN_FRAME_LEVEL_DEFAULT`, below native quest/offer markers. Planner-created pins (`source.type == "plan"`, including panel-selected steps) are passive: `EnableMouse(false)` disables clicks and hover, and their callbacks cannot remove the route or replace a native tooltip. Manual pins retain activation/removal and tooltip controls. Mouse state is set on every `OnAcquired` so pooled frames can move between manual and planned use. `OnMouseLeave` hides only a tooltip owned by that pin. Arrow, minimap, and automatic route selection remain unchanged.

Verified against Blizzard's Forever UI source mirror `Gethe/wow-ui-source` revision `9dc84f0d3bbae1768ac3405b3716000bd93eda06`, `version.txt` 1.60.1.70862: `Blizzard_MapCanvas/Blizzard_MapCanvas.lua` wires click/motion scripts from the XML template before `OnLoad`, calls `OnAcquired` on each reuse, then refreshes right-button passthrough; `MapCanvas_DataProviderBase.lua` supplies `UseFrameLevelType`; `MapCanvas_PinFrameLevelsManager.lua` and `Blizzard_WorldMap/Blizzard_WorldMap.lua` place native quest/offer layers above DEFAULT. Leave the template mouse-enabled so manual pins retain their initial script bindings; disable input per acquisition.

Four regressions cover repeated planner ticks, passive callbacks/native tooltip ownership, manual activation/removal, and manual/plan/manual reuse. Pre-fix tests reproduced the hover capture and topmost-layer defects. These are source/mock checks, not an in-game hit-test or quest-area visual verification. One `/reload` loads the Lua update; open M and hover a native quest marker through several route ticks for the client check.


## 18. Display settings — v0.8.2 (2026-11-09, Codex)

The next-steps panel has a Settings button beside Dungeons on a dedicated toolbar. A lazily created, draggable dialog exposes the existing account-wide `worldMapPins`, `minimapPin`, and `arrow.shown/locked/flip/scale` preferences. No defaults are overwritten on open. Checkbox labels are clickable; Esc or Done closes the dialog. Changes apply immediately; normal SavedVariables persistence retains them across sessions/characters. An optional `/hh settings` opens the same dialog. Existing `/hh arrow` commands and `/hh guide` refresh its controls.

Arrow size changes in 10-percentage-point steps, clamped to the existing 40–300% command range. Reset arrow position & size calls the existing reset, restoring CENTER / 0 / 180 / 100% while preserving shown, locked and flip preferences and map visibility. The map and minimap refresh immediately, even without a position tick. Display changes never clear/pause/reselect the route. World-map quest-marker layering/passive input from v0.8.1 remains in effect. All UI is in the already-loaded `UI/Panel.lua`; no new TOC files or media.

UI primitives checked against the existing Forever 70862 source revision `9dc84f0d3bbae1768ac3405b3716000bd93eda06`: `Blizzard_SharedXML/Shared/Button/CheckButtonTemplates.xml` defines UICheckButtonTemplate; `SimpleCheckboxAPIDocumentation.lua` defines GetChecked/SetChecked boolean state. No new gameplay API reads bypass the adapter.

Four additional regressions cover normal addon-compartment/panel access without commands, preserving preferences on open, immediate visibility and recurring-tick behavior, manual route retention, lock/drag/flip/size/reset, existing command synchronization, and startup default filling retaining saved false values. Mock UI tests do not establish real client layout or input behavior. One `/reload` loads this update; normal in-game Settings use is the remaining client check.


## 19. Unified control window — v0.9.0 (2026-11-09, Codex)

The addon compartment, compact panel's Open tools button, and `/hh` now open `UI/Hub.lua`, a draggable sidebar window. `/hh panel` retains the compact next-steps overlay; all other slash handlers remain available. The old small Settings dialog stays available, while the Display page exposes the same preferences in the main window. The dungeon checklist remains a dedicated existing window with All tools navigation back.

| Section | Click-driven coverage |
| --- | --- |
| Navigation | Resume/pause selection, next suggestion, pickup search, restore guidance layout, quest search/list/select, clear route, timed defer/restore |
| Waypoints | Named paginated list, activate/remove/next, current-location save, validated percentage coordinates and optional map ID |
| Professions | Learned recipe-name picker, validated batch count, materials, clear batch, skill-up report |
| Party | Quest comparison, explicit snapshot send, editable copy/import field |
| Supplies & town | Class prep enable/mode/stock targets, vendor options/value report, reminder enable/buff/thresholds, trainer notes/level lookup |
| PvP | Enable/mode/lock/scale/reset, flag slot tracking/off, status/spell reports, confirmed session clear |
| Rare watch | Enable/mode/lock/scale/reset/share/sound, open existing secure Scan HUD, status/runs, confirmed absent/new-run recording, instance/name/ID watch list editing |
| Display | Map/minimap toggles; arrow visibility/lock/flip/scale/reset; compact panel/status-line visibility/lock/scale/reset; FPS; Hunter audio enable/sample/status |
| Diagnostics | Record/debug/probe toggles, status/API checks/self-test/probe samples/export location/error viewer, confirmed rare history/character/account resets |

Merchant sell/repair actions stay on the merchant window so item/value context is visible. The rare Scan action only shows the existing protected HUD, never invokes targeting; inside the watched instance it closes the main window so the Scan button is accessible. Dungeon browsing and route/display changes do not imply client or economic/mechanic proof.

`FP:CaptureOutput(fn)` scopes synchronous Print output for GUI actions, caps at 200 lines and restores the previous destination even on errors/nested capture. Existing guarded module commands supply behavior; output appears in a separate scrollable result pane and ordinary/asynchronous chat remains unchanged. Form validation reports in the results area, never dispatches invalid numbers, and never partially applies a paired reminder form. Destructive callbacks are not invoked until confirmation; cancel, section changes, closing, or another action clears the pending callback. Account reset wording explicitly includes settings, matching the existing command's whole-account-DB behavior.

Pages are built lazily once. Live lists/checkboxes update only for the visible window via coalesced events; refresh never rebuilds edit boxes or overwrites draft text. Recipe names replace the need to know recipe IDs; quest search uses literal text. Seven-row lists are paginated and selection is revalidated against current items before action. Removing a planned waypoint pauses selection so it is not recreated on the next tick. Main-window position is stored in `settings.hub`; UIParent dimensions set a fitting scale (up to 100%), recalculated on open/scale/display events. All actions are player initiated; no new gameplay API reads outside Adapter.

Validation: 12 new GUI/capture regressions plus the 125 existing regressions (137 total), 18 self-tests, mock play-through, Lua/XML/TOC checks. Tests cover every page opening without settings/route/data mutation or sends/sales, frame reuse, normal entry points and dungeon return, quest selection/defer, waypoint validation/pagination/removal, recipe planning and drafts, explicit party send/import, settings, rare secure deferral, cancel/confirm scopes, capture restoration/bounds, coalescing/closed-window inactivity, screen fit/position, and diagnostic actions. An initial decimal-coordinate assertion used exact floating equality and was corrected to a 1e-9 tolerance; no code defect was masked.

Client boundary: latest pre-change saved data still v0.8.0/build 70862; v0.8.1 map hover, v0.8.2 display dialog and v0.9.0 main-window visual behavior require actual client observation. Lua primitives/templates reuse the verified Forever source revision `9dc84f0d3bbae1768ac3405b3716000bd93eda06`. No generated images/media or paid dependencies.


## 19. Quest source locations — v0.10.0 (2026-11-10, Codex)

The missing concealed-spider markers exposed a general coverage gap: the planner and map renderer had no quest→item→source→spawn database. `Modules/QuestObjectives.lua` now consumes the separately installed QuestieDB Forever provider through `API/Adapter.lua`. Optional dependency ordering lets the remaining addon work without that provider; Navigation reports missing/wrong-flavor/incompatible data. No upstream database/code is copied into Hearth & Hustle. Upstream remains a separate unmodified addon with its own licensing.

Public contract-1 reads resolve ordinary NPC/object/item objectives, item NPC/object drops, vendors, and recursively nested containers (cycle guard and depth 3). Uses the provider's canonical AreaID→UiMapID table; validates native mapType=3 and 0–100 coordinates. Never applies Era conversion again, uses instance compatibility overrides, or turns -1 sentinels into pins. Forever flavor is mandatory. Blizzard Forever source `QuestObjectiveInfo` has text/type/finished/counts/objectiveType but **no entity ID**. Matching uses exact localized entity/custom text (and common English kill suffixes); rejects ambiguous names, type mismatches and unsupported kinds rather than assigning completion by row index. No quest-specific spider exception.

Live log/progress controls automatic markers; data is cached for up to 30s with immediate signature changes, active-log-only storage, coalesced scan events, and a 3s recovery ticker. New account settings: questWorldPins, questMinimapPins (on), questSelectedOnly (off). Existing world/minimap master toggles still apply. World pins merge nearby points and share quest tooltips, capped at 350 fairly across objectives. A separate native map template/pool keeps manual waypoints and passive planner pins intact, below native quest markers. Nearby-only minimap pool is capped at 40, respects facing/rotation and hides stale slots. No distant spawn clamping. Click creates an explicit manual destination, removed when its quest/objective finishes or is abandoned. Automatic nearest-source fallback runs only after existing live/recorded guidance.

Validation: see the dated shared handoff for exact checks and upstream packaged-provider integration results. Mocks/installed hashes do not establish client rendering or spawn accuracy. First client check requires a full restart for the newly installed QuestieDB folder, then ordinary quest play/map hover/minimap/completion, followed by a normal SavedVariables flush. `HearthAndHustleDB.questLocations` saves status and matched/missing objective counts automatically.

Remaining quest-helper work: event/kill-credit/spell/exploration targets, dungeon entrance/floor routing, chain/prerequisite browsing, availability filtering and reward comparison. Do not claim full Questie parity. Keep these inside the unified interface and preserve the information-only gameplay boundary.


## 20. Quest chain browser — v0.11.0 (2026-11-10, Codex)

`Modules/QuestChains.lua` and `UI/QuestChains.lua` add a Quest chains section to the existing Hub and a View quest chain button to Navigation. Search current quests or reference names/IDs, preserving separate IDs for same-name stages. Search/detail views reuse controls; linked prerequisites and follow-ups are inspectable, with bounded back history and preserved query/filter/pagination. Dynamic detail height keeps the linked-quest list below longer descriptions. No new media or gameplay automation.

Provider access stays in Adapter.lua: protected ID enumeration, validated chain records, and named NPC/object/item starters. The first visit builds names and reverse prerequisite edges in40-record batches separated by0.02s; no startup-wide scan or quest spawn decode. Index refresh generations discard old queued work. Reference rows and inspected starter lists are session caches; live character states are cached only per UI refresh. Only displayed result rows query live completion state. No quest-chain SavedVariables or private player data are published.

Semantics checked against QuestieDB1.0.13 public schema and Questie `42787ae88eb814bf60db619c8fe6f5627ac34922` Database/QuestieDB.lua (public source reviewed; no upstream implementation copied): preQuestSingle is ANY completed; preQuestGroup is ALL completed, with positive entries accepting a completed exclusive alternative and negative entries requiring the exact quest. Signed single prerequisites remain unknown. Both modes populated is a reference conflict, not a guessed precedence. parentQuest requires active; availableStartingWith allows active or completed. Breadcrumbs are optional leads, though an active breadcrumb can affect pickup. nextQuestInChain is also a suppression/cutoff field, not a mandatory prerequisite. exclusiveTo, disabledByQuest, and availableUntilCompleted are shown separately. Ancestor traversal is cycle-guarded and bounded to8levels/100rows; following a link lets the user continue. Reverse prerequisite edges plus childQuests expose follow-ups, marked as incomplete until indexing finishes.

Reuses the existing secret/error-aware GetDungeonQuestState adapter so false, nil, and completed are distinct; actual log rows and current-map offers outrank reference claims. Repeatables in log display active/ready even if completion history exists. Missing quest records, malformed fields, contradictory lists and unavailable state never turn into an availability claim. Other listed level/class/race/profession/reputation/spell/event constraints remain informational; full eligibility evaluation is outside this increment.

Guide to pickup is an explicit click, preferring a live map offer then nearest same-continent valid outdoor starter coordinates. No item-start coordinates are invented, and unknown/already-active/completed quest state rejects the action. It preserves navigation during browsing, creates a manual chain-pickup waypoint only on click, and removes that waypoint on accepted/completed log refresh. The player still travels, talks, accepts and turns in manually.

Verification: see the shared handoff for final regression count, CI and installed-file manifest. Actual packaged-provider integration checks Black Shield1251→1321→1322→1323→1276, distinct same-name stages, Do'gol's pickup, a5,233-row asynchronous index, and UI rendering under the mock. No client visual or eligibility proof is implied. Reload loads Lua changes; a full restart is still needed if the preceding QuestieDB folder installation has not yet been discovered by WoW.


## 22. Quest reward comparisons — v0.12.0 (2026-11-10, Codex)

Next roadmap increment after the chain browser. The Hub's **Quest rewards** page reads either the native quest-log selection or an open NPC quest dialog. A player-clicked **Compare rewards** button below QuestFrame opens the dialog view. No native quest selection, route, equipment, reward choice or acceptance/turn-in is changed. Session-only UI state; no new SavedVariables schema or provider dependency. Existing vendor reward labels are retained.

API source checked against Gethe/wow-ui-source `forever` commit `4cd0ab752a77164f654ccbca9d0c1fe8dafceebe`, version **1.60.1.70888** (source version, not verified installed client): Mainline/QuestInfo.lua, ItemDocumentation.lua and QuestLogDocumentation.lua. QuestInfo uses `C_QuestLog.GetSelectedQuest` (distinct from the supertracked quest), `GetNumQuestLogChoices/Rewards`, context-bound `GetQuestLogChoiceInfo/RewardInfo`, `GetQuestLogItemLink`, and dialog `GetQuestItemInfo/Link`. Reward quantity is the third return, usability the fifth; `C_Item.GetItemInfo` supplies equipLoc at return9, sellPrice at11, and `C_Item.GetItemStats` supplies numeric stat keys. All new gameplay reads remain in Adapter, feature-detected and protected; context failures never fall back to another quest's reward APIs.

Guaranteed versus choice rewards stay separate. Vendor totals multiply unit price by the known positive integer quantity; unknown quantity/cache/count prevents a full-choice ranking. Ties at a positive highest value are included; fixed rewards never compete. Counts are bounded to64per category. Quest identity is checked again after the read. Missing/secret/error data stays unknown; a partially unreadable stat table is rejected wholesale. Missing item metadata requests its item ID once per session, bounded128distinct requests, with normal item-data events/manual refresh providing recovery. Open comparison refreshes coalesce at0.2s; hidden pages do no comparison reads. Combat suppresses comparison reads and clears visible rows.

Numeric stat comparisons include stats absent from either known table as zero; absent tables stay unavailable. Rings/trinkets show each slot separately, and two-handed weapons subtract the sum of both hands. One-hand/shield/held-offhand comparisons explicitly remain per-slot and flag dual-wield/two-hand constraints. Empty equipped slots require a successful nonsecret nil inventory-ID read; unavailable equipment must not become empty. Non-equippable/unsupported types get no slot comparison. Item level, usability and vendor value are informational; no weighted upgrade score, DPS simulation, class loadout recommendation or full effect/enchant/proc coverage.

Validation:177regressions,18self-tests, mock play-through, syntax/XML/TOC pass. Tests cover stack/tie/fixed-choice ranking, delayed data, nil quantity, missing/count/secret/error guards, ring and two-hand deltas, log/dialog isolation, changed identity, combat, page selection/live refresh, hidden-page inactivity, and click-only dialog entry. Initial two assertion failures were Lua-pattern test errors (literal signed deltas); printed comparisons confirmed the correct values and the assertions now use literal matches. Actual client layout, tooltips and reward reads remain unverified. Source build70888 does not override latest saved client build70862.


## 23. Event objectives and quest-level hints — v0.13.0 (2026-11-10, Codex)

Extends the existing objective map/arrow pipeline with QuestieDB `triggerEnd`, shared quest-credit `objectives[5]`, and unbound `extraObjectives` notes. `triggerEnd={text,spawnList}` supplies a completion area, not an escort path. Credit rows are `{memberNpcIDs,rootNpcID,customText,icon}`: only members supply spawn lists; a credit root can be an invisible dummy. Hint rows use custom coordinates or referenced NPC/object/item sources, with provider references taking precedence. Only explicit binding index0 is a quest-level hint. Positive/unknown bindings are withheld instead of assuming the provider's objective order equals the client order. Quest-level hints never count as tracked progress or supply an automatic-route destination.

Schema verified from the installed unmodified QuestieDB1.0.13 Forever package and source tag commit `0f7d8adc92b28ac6594f4ad8745257f4d9784edf`, plus Questie `42787ae88eb814bf60db619c8fe6f5627ac34922` Database/QuestieDB.lua (reference semantics only; no upstream implementation copied). Blizzard Forever `QuestObjectiveInfo` still exposes text/type/progress but no entity ID (source70888/`4cd0ab7`). Existing provider canonical AreaID→UiMapID conversion is reused; only valid outdoor mapType3 coordinates render. Sentinel -1 coordinates, floors, absent event locations and locationless spell objectives remain unknown.

Match exact normalized live labels/type first. Event/credit text can differ from reference labels: fallback is permitted only when the entire live objective list and compatible reference list each contain exactly one candidate of that type. Finished live rows count toward ambiguity. Duplicate live event/credit labels fail closed; absent/unknown finished state does not produce a new event/credit marker. No positional matching, broad English substring rules, or quest-specific exceptions. Shared credit targets are labeled as possible targets; the quest decides whether to tame, use an item, talk, fight, etc.

Unfinished matched events/credits join the existing capped world/minimap pools, selected-quest filters, normal progress cleanup and native-first arrow fallback. Separate quest hints are click-to-guide only, visibly identified as not tied to individual progress and cleared when the quest completes or is abandoned. New account setting `questEventHints=true`, clickable in Display; master source/map toggles remain authoritative. `questLocations` bounded snapshot and Navigation summary add events/hints counts, keeping hints out of matched/missing progress metrics. Pin clicks revalidate identity and coordinates; source waypoints carry semantic objective/reference keys so row reordering cannot bind cleanup to another objective. Pure manual waypoints remain unchanged.

Reader bounds:64rows per reference category,256source IDs per list,4096points per group, existing item-container depth3/cycle guard. Provider failure remains isolated. No new game APIs, gameplay action, media or dependency.

Validation:191regressions,18self-tests, mock/syntax/XML/TOC pass. Fourteen new event cases exercise matching/ambiguity/completed-row controls, credit members versus roots, unknown states, invalid/sentinel/dungeon data, hint separation/source precedence/filtering, semantic reorder cleanup, stale clicks, native/manual navigation preservation, minimap and automatic refresh. Actual packaged-provider integration preserves previous ordinary/chain cases and maps Forgotten Pools870, Questioning Reethe1273, Stonetalon Standstill25, Free From the Hold898; verifies Kodo Roundup5561's three species plus separate lure hint, Frostmaw1136's Flame of Uzel hint, and unknown sentinel/spell cases92401/92474. These are offline integrations, not fresh gameplay evidence.

Initial fixture failures retained in the shared evidence: the lifecycle test needed both nested rescan/refresh timer drains; the provider test incorrectly required an empty active route even though removing the completed event correctly restored an older planner waypoint. Tests now check the event's removal without deleting unrelated routes. Actual client appearance, spawn accuracy and event behavior remain pending. Dungeon routing is the next planned feature.


## 24. Dungeon entrance and quest routing — v0.14.0 (2026-11-10, Codex)

- Source: QuestieDB contract1, Forever1.0.13 (`0f7d8adc92b28ac6594f4ad8745257f4d9784edf`), `docs/api.md` dungeon tuple contract and `docs/forever-map-override-audit.md`. `Support.Get("ZoneDB").private.dungeons` contains `{name, aliases, parentArea, {{outdoorArea,x,y},...}}`. Entrance coordinates already use Forever percentages; do not convert again or use parentArea instead of each tuple's area. Provider rows and old UiMap aliases do not prove live floor availability.
- Adapter resolves exact dungeon IDs/aliases before map lookup. Only exact `{-1,-1}` instance membership markers become authored entrances; legacy positive floor coordinates remain excluded. Require mapped native outdoor mapType3, finite bounded coordinates; missing/throwing/malformed provider returns no route. All provider/game reads remain in Adapter.
- Explicit 30-entry catalogue crosswalk, no name guessing for the five unlocated Forever sites. Stratholme main/service use the two converted2017 entrance triples, not the unverified10001 Cata-frame row. Scarlet Monastery shares an approach; both Blackrock Spire wings share Blackrock Mountain entrances. Alternative entrances remain player-selectable.
- Dungeon checklist adds entrance controls, selected-quest pickup/objective/turn-in guidance and chain link. Browsing preserves navigation. Fresh state checks block stale/restricted/completed/unknown pickups. Known `finishedBy` coordinates supplement native and recorded turn-ins before the historical giver fallback. Native guidance retains priority. Pickup/ender contacts inside an instance route to its outdoor entrance, labeled explicitly.
- Entrance identity propagates through planner and clicked quest locations. Entering any instance removes only entrance-tagged waypoints and entrance waiting state; new entrance routes are blocked while inside. Arrival does not complete quest progress. Interior paths/boss order/terrain travel/access requirements are outside this increment.
- Verification: mock regression gate plus actual installed QuestieDB under its emulator, including ordinary maps/chains/events, 30/35 entrance coverage, converted Stratholme, quests7461/5382 dungeon NPC/object aliases,92401 Ruins event,7461 instance pickup,6981 item-start unknown and1486 ender. No client runtime or visual proof claimed. Pre-change SavedVariables still report v0.9.0/build70862.


## 25. Class-neutral tools and retired Hunter sounds — v0.15.0 (2026-11-10, Codex)

User intent: the addon is a useful general addon for any class, no longer a beta Mage/Hunter pair experiment. Remove the custom Hunter action noises completely; preserve legitimate class-specific functionality.

- Removed `Modules/HunterAudioFeedback.lua`, its TOC entry, all10 `Sounds/Hunter/*.ogg` assets, default config, display controls and unused PlaySoundFile probe. Initialization deletes an old `settings.hunterAudio` field; legacy audio commands only print a retirement notice. No sound playback handler remains. Rare-alert sounds and their explicit preference remain. Historical Git commits/private lab are not rewritten.
- Renamed `PvP/MagePrep.lua` / MagePrep to `Modules/ClassPrep.lua` / ClassPrep. The saved per-character `prep` schema stays compatible, adding food20 and an empty personal supplies table. Checklist registration is unconditional; all9 classes receive food/bandage/bag checks, unknown classes receive the same generic tools. Drinks are enabled for the seven mana classes using class identity, not current druid form/resource. Existing learned Mage gem/reagent suggestions remain Mage-only. Shaman static hints no longer assume Enhancement or a two-person party.
- Food classification extends the guarded bag snapshot: localized Food effect from item4540, separate from Drink159, carried ItemClass0/subclass5, minLevel <= player level. Bandages remain carried stock, not usability. Missing/secret/throwing item metadata cannot become a zero total; existing bounded retries/item events retained. Combined effects with different names are outside automatic category coverage. New GetPrepItemName wraps existing guarded lookups outside combat; no new gameplay API surface required. Verified C_Item source contract against Blizzard Forever documentation; placement/count accuracy awaits client proof.
- Town tools now has a paginated supply report independent of HUD visibility, food/drink/bandage/Mage reagent targets, carried/tracked item picker, item-link/ID input, save/remove personal target controls. Up to20 personal items, targets1–200,0 removes; validated inputs, per-character persistence, unknown counts preserved, draft fields retained. Runtime names cached, no item use/purchase/target/cast. Personal counts use equipped bags only. All supply snapshots and reads pause in combat; editing a target does not read inventory.
- Audit: planner/source maps/chains/dungeons are class-neutral except intentional live faction/class eligibility filtering. Rewards compare raw stats/current equipment/usability without mage/hunter weighting. Professions, trainer records and party messages use the actual character/roster. PvP own-action estimates have an explicit cross-class spell table, not player-class gating. Legacy personal names in self-tests are fixtures, not runtime recipient defaults. InfoBar's optional specialized buff list remains mage/shaman/hunter-only; repair/bags/ammo apply where relevant. No blanket claim of every class-specific spell/rotation being covered.
- Verification includes all nine fresh mock logins with legacy sound-enabled settings and existing character targets, class-appropriate supplies, trainer filtering, dungeon class filter, native quest routing, combat pause/resume; custom targets/cache/bank boundaries, GUI without PvP, and proof that hunter actions/retired commands play no sounds or ship sound files. Actual client evidence remains savedv0.9.0/build70862 before change.


## Gear explorer and GUI discovery — v0.16.0 (2026-11-10, Codex)

Home now defaults to Overview: six cards for Navigation, Best in slot, Rewards,
Chains, Dungeons and Supplies. Sidebar adds a first-class dungeon page; spacing
keeps all 14 sections clear of the compact-panel and map-settings shortcuts.
The gear page has slot chips, role/source controls, name/ID/source search, level
filter, a paged list and independent scrolling comparison pane. A modal edits
weights atomically; cancel/navigation/close discards unsaved edits. Profile,
custom weights and wishlist persist per character; browsing/filtering does not
write route, quest tracking or character state.

8,370 normalized factual Forever records from the pinned cache revision in
HearthAndHustle_GearData/GearCatalog.lua (LoadOnDemand). tools/import-gear-catalog.py regenerates deterministically;
no Classic fallback or copied BiS rankings. Reference data stays immutable. Scores
use explicit authored starting weights for all nine class families and expose
all weights. They omit proc/set/cap/weapon-speed interactions and are labeled
estimates. Unknown required levels stay unknown; item level is a labeled conservative filter proxy. The optional unknown filter applies only when both levels are absent.
Class armor/weapon/relic filters are reference compatibility rules; training,
reputation/race/unique restrictions and current obtainability are not certified.

API: reverified Blizzard Forever source 70888 / 4cd0ab7. Existing guarded
GetRewardItem/GetRewardEquipment adapters supply live stat comparisons. Item
requests remain bounded (128 IDs per session) and events refresh only the visible
page. No full-catalog live API scan. New GetGearQuestSources adapter consumes
QuestieDB Item.Get(id, "questRewards"), then guarded Quest chain records; deduped,
bounded and read-only. Missing provider/data never blocks offline gear browsing.
Two-hand/per-hand scores do not emit swap deltas. Spell damage/healing supports
combined and separate API keys without double-counting the healer preset.

Installed/mock evidence is not client proof. Reload and check real tooltips,
scrolling, equipment refresh, quest sources, source navigation, persisted weights
and wishlist; pull SavedVariables after normal flush. No new media or dependency.

## Rename to Hearth & Hustle — v0.17.0 (2026-11-10, Claude)

- Reason: CurseForge project 1793337 "ForeverPath" (created 2026-11-09, unrelated code) uses the same addon folder, `ForeverPathDB` / `ForeverPathCharDB` and `/fp`. Either addon installed over the other would read the other's saved tables.
- Changed: folder and TOC `HearthAndHustle`, title "Hearth & Hustle", SavedVariables `HearthAndHustleDB` / `HearthAndHustleCharDB`, every named frame, mixin, XML template and the addon-compartment function, asset paths, slash commands `/hh` + `/hustle` (`/fp` and `/foreverpath` removed, `/way` kept), addon-message prefix `HHUSTLE` (was `FPATH`; not compatible with older versions), release zip `HearthAndHustle.zip`. The GitHub repository name is unchanged.
- Saved data: `Core/Config.lua` adopts legacy globals once, only when they carry this addon's schema (`settings.arrow`, `data.quests`, `meta`; character: `waypoints`, `completed`, `nextId`), by reference when the file was merely copied and as a deep copy while the old addon is still loaded. `tools/migrate-from-foreverpath.py` renames the files byte-for-byte apart from the variable name, keeps the originals as `ForeverPath.lua.pre-rename`, refuses while the game runs, and stops before any change if a file is not recognised.
- Client fact used: build 70888 writes SavedVariables with CRLF line endings and no indentation; closers are `},` or `}`.
- Verification: 234 regressions (5 new: adoption, live-old-addon copy, foreign tables ignored, existing new data kept, file-tool fixture). The tool and both adoption paths were also run against a copy of a real 4.3 MB account file and a character file: every setting, dataset count and waypoint preserved. Not yet run in the client.


## Review repair — v0.17.1 (2026-11-11 UTC, Codex)

- Build 70888 saved objective labels are count-first. A shared cleaner handles both
  formats and uncached blank names; immutable references are cached per live quest.
  Source waypoints survive temporarily uncached names. Provider status validates
  zone payload availability. Continent coordinates can project onto a child map;
  cross-continent destinations remain selectable without invented distance.
- Deliveries with no countable objectives and item-started quests cannot fall back
  to their acceptance position. Known enders supply delivery destinations. Hearth
  hints never enter automatic selection. Unchanged routes do not reacquire pins.
- Native MapCanvas calls CheckMouseButtonPassthrough after acquisition. Both addon
  pin mixins guard that method in combat and refresh on combat end. Rare HUD
  geometry/show/hide and secure macro updates are deferred together. Blocked and
  forbidden actions for this addon enter the bounded error sink.
- Rare message numeric fields require bounded positive integers; text loses pipes
  and control characters. All receive kinds require enabled/in-instance context.
  Party sender checks preserve full realm identity and use UnitFullName plus
  C_NameUtil's surname converter when available (70888 source; client unverified).
- CanDualWield is a documented global in PlayerScriptDocumentation; only true
  permits off-hand weapon ranking. GetNumQuestLogChoices receives questID,true,
  matching Blizzard Mainline/QuestInfo.lua:633; fixed reward count remains argless.
- Catalog importer strips comment markup, handles slot-only cloaks and thrown
  weapons, and excludes set bonuses from scalar effect parsing. The companion
  gear addon loads on demand outside combat. Checks, deployment and ZIP packaging
  include both folders. A full restart discovers the companion addon.
- Navigation Resume suspends manual destinations without deleting them; explicit
  selection reactivates one. Pause is session-local. Stable top-left compact-panel
  anchoring, UTF-8 truncation, focus clearing, live settings refresh with draft
  preservation, Escape-close windows and stable rare-list keys repair UI state.
- New profile recording/probes default off; existing choices survive. Optional
  entity records are capped (quests 8000, NPCs 6000, creatures 3000, objects 2000,
  items 10000, vendors/trainers 1000 each, characters 100, zones 1000, PvP players
  500); existing bounded event lists stay bounded. Trainer keys include rank.
  Complete recipe schematics cache during an open profession window; skill/data
  changes refresh them, and identical records do not increment write counters.
- Automated/provider/saved-data replays are not fresh client gameplay evidence.
  Verify map hover/clicks in combat, layout/focus, party surnames and item/gear UI
  after a full restart; then pull newly flushed SavedVariables.

### NPC offers and map coverage — v0.17.2 (2026-11-11, Codex)

The user reports standing beside Melisara offering The Crown of Will while the
map-only questOffers probe reports zero. This is a client observation of incomplete
map coverage, not proof of an empty zone. Current SavedVariables have not yet
flushed that interaction. `C_QuestLine.GetAvailableQuestLines(uiMapID)` and
`C_QuestLog.GetQuestsOnMap` remain map-list sources, not a nearby-NPC census.

`GOSSIP_SHOW` / `QUEST_GREETING` snapshot the actual dialog NPC's available quests;
`QUEST_DETAIL` supplements single-quest offers. Blizzard's Forever UI at
`4cd0ab752a77164f654ccbca9d0c1fe8dafceebe` confirms the greeting quest ID is the
fifth `GetAvailableQuestInfo` return and QUEST_DETAIL carries questStartItemID.
Item/area/adventure-map details and an unrelated selected target cannot supply NPC
locations. Observations work with recording off, use the interaction position,
expire after 300 seconds, cap at 100, and clear on quest acceptance/removal/turn-in
or map transition. Current offers can override an earlier completion flag for
repeatables. Map coordinates win when both sources report the same quest.

No remote availability inference from historical giver records or the provider
catalog; no automatic interactions. Mock verification is not client proof.

### Quest map and missing-ID sources — v0.18.0 (2026-11-11, Codex)

User client report: quest98192 Skin Careful, Skin Sharp has no markers and all
source markers look alike. Fresh saved v0.17.1 evidence includes objective
Intact Raptor Hide x8; one unchanged historical error. Installed QuestieDB1.0.13
has no quest98192 but contains Item279601 with npcDrops4356/4357, Bloodfen
Razormaw/Lashtail: 14+16 outdoor points in Area15 -> UiMap1445.

The existing Forever QuestObjectiveInfo API has text/type/counts but no entity ID.
Missing/unlocated quest references now fall back only to a unique exact localized
entity name of the live objective's type, using the provider's public IdsByName
and BuildNameIndexAsync(150) APIs. The index is caller-driven through small timer
batches outside combat. No fuzzy matches, duplicate-ID selection, unknown event
inference or Classic database substitution. Successful sources are cached only
for active objective keys and marked as name-based in tooltips. Explicit refresh
rechecks them. Existing native guidance retains priority.

Quest colors/numbers are per-character and stable while a quest remains active.
Type icons reuse client art; map and minimap share style, shared locations have a
white + badge. A paged/collapsible map legend controls focus and hidden quests
without changing navigation; Show all resets those filters and selected-only.
Contacts are confirmed map/NPC offers and known enders of completed active quests,
not inferred prerequisite-based availability. Default world clustering uses a
60x60 grid/cap150; Dense uses125x125/cap350. Round-robin allocation retains fairness
across quests; source arrays stay intact for nearest guidance. Minimap clustering
scales to icon size (18 pixels), capped40 with no distant-rim clamping.

Validation includes the real installed QuestieDB and 98192, all source locations,
world/minimap/legend/completion, duplicate names, async/combat index behavior,
stable/repaired color assignments, overlapping quests, focus/hide and manual
route preservation, pickup/turn-in lifecycle, density and legend pagination.
Client rendering/behavior still needs user verification. Questie icon convention
reference: https://github.com/Questie/Questie/wiki/Icons (no Questie UI/code/art copied).

### Map layer and minimap repair — v0.18.1 (2026-11-11, Codex)

- Verified against Forever UI build70888, revision `4cd0ab752a77164f654ccbca9d0c1fe8dafceebe`: `WorldMapMixin:OnLoad` registers MAP_EXPLORATION, FOG_OF_WAR and QUEST_BLOB above PIN_FRAME_LEVEL_DEFAULT. `MapExplorationPinMixin` draws explored terrain textures there, so DEFAULT can hide addon markers. Previous mock assertions requiring DEFAULT were wrong.
- Both addon pin types now use an explicit level inserted above MAP_HIGHLIGHT and below native POI/quest markers. Existing pin levels are reapplied after insertion. Native map refresh callbacks record errors; legend errors cannot prevent marker drawing.
- Minimap quest icons11px (was16), no numeric badges,14px minimum center spacing after merging adjacent cells, nearest24 maximum (was40). Shared markers retain all merged objective tooltip entries. World markers remain18px with numbers.
- Mock coverage now models layer ordering and map open/map-change/reopen, plus legend focus, completion cleanup, spacing and error recovery. These checks and source verification do not establish fresh in-game rendering; reload and user verification remain required.

### Restricted map button and icon layers — v0.18.2 (2026-11-11, Codex)

- User reports0.18.1 improved map rendering, then `ADDON_ACTION_BLOCKED: Button:SetPassThroughButtons()`. Reload/pull20261111T031507Z confirms the error on build70888; original activity/combat state and call stack are unknown.
- Forever's SimpleScriptRegionAPI marks SetPassThroughButtons protected/restricted. MapCanvasMixin:AcquirePin invokes CheckMouseButtonPassthrough on each acquire. Our combat-only guard still called the setter outside combat. Remove the unnecessary setter path entirely for our own mixins: interactive pins consume clicks by default; passive planner pins disable mouse input. Blizzard's shared mixin is untouched.
- Store up to10 blocked-action context samples (one per distinct action/session, trace4096 bytes max) for recurrence. Event stacks may not contain the originating callback. No assumption that this record identifies the exact originating Button.
- User screenshot shows solid cyan quest squares with badges. XML border and dynamically created action texture were both ARTWORK, making their order unspecified. Set border BACKGROUND and action ARTWORK sublevel1 on each reuse, explicitly show regions, and use a dark glyph fallback if the client's SetTexture reports a missing asset. Colors and quest IDs are preserved.
- Tests cover restricted setter rejection in/out of combat, click/hover/pool reuse, layer order and missing-texture fallback. Fresh client error/visual verification remains necessary.

### Native pin levels and review follow-ups — v0.18.3 (2026-11-11, Claude)

- **Correction to v0.18.1/v0.18.2.** The saved v0.18.2 session (build 70888) blocked `Button:SetPassThroughButtons()` again 24 s after the reload, with `combat=true`, `mapShown=true` and this stack: `QuestDataProvider:RefreshAllData` → `AddQuest` → `MapCanvasMixin:AcquirePin` → `CheckMouseButtonPassthrough` → `SetPassThroughButtons`, under `secureexecuterange`. The blocked object is Blizzard's quest pin (a Button); addon pins are Frames and were never the blocked object.
- Cause: v0.18.1 called `InsertFrameLevelAbove` on the world map's pin frame-level manager. `AddDefinition` then rewrites `startLevel` on every level above the insertion point (33 native levels in the 70888 list, `ACTIVE_QUEST` and `AREA_POI` included) from addon code. `AcquirePin` runs `OnAcquired` → `SetPosition` → `ApplyFrameLevel`, which reads that value, before the restricted passthrough call; in combat the call is blocked and attributed to the addon. Data providers are isolated by `secureexecuterange`; table values are not.
- Rule: never add, move or override a level in Blizzard's manager. Addon pins use an existing level through `UseFrameLevelType`: the first registered of `PIN_FRAME_LEVEL_DIG_SITE`, `DUNGEON_ENTRANCE`, `AREA_POI` above `MAP_HIGHLIGHT` (read-only check; an unregistered name reads as DEFAULT). In the 70888 list DIG_SITE is 2014: above MAP_EXPLORATION 2002, FOG_OF_WAR 2006, QUEST_BLOB 2007, MAP_HIGHLIGHT 2009; below DUNGEON_ENTRANCE 2015, FLIGHT_POINT 2017, AREA_POI 2023, QUEST_OFFER 2228, ACTIVE_QUEST 2833. Same drawing order as the v0.18.1 level.
- Minimap quest markers project a source onto the map the client reports when it is the parent or a child of the source's map (outdoor caves report the continent map). Cached per reported map; tooltips and guidance keep the source's own point.
- Party cast-timer messages (`PT;`) drop `|` and control bytes from spell, target and DR text before display.
- Rare-watch HUD text updates during combat; size, position, visibility and the secure Scan button still wait for combat to end (the Scan button is anchored to the HUD).
- Gear: with "No required level listed: allow 5 item levels above the limit" ticked, items without a required level are listed up to five item levels above the level field. A listed requirement is never widened.
- A skill-up with no profession window open no longer starts a recipe scan and its retries.
- Each change has a regression that fails on v0.18.2. Mock- and source-verified; marker visibility on the borrowed level and the absence of the blocked action need a client session.


### Action bar guard — v0.19.0 (2026-11-13, Claude)

- Owner's report on build 70938 (Shaman 47): the two bars above the main bar were empty at login, refilled, and empty again at the next login. Cause is outside the client files: slot contents are server-side, no installed addon writes them, the Blizzard UI diff 70888 → 70938 has no action-bar change, and the first wipe followed buying dual specialization. The Forever bug-report forum has the same report from 2026-11-10 on (login, spec change, level-up; no addons). No fix announced as of 2026-11-13.
- Owner's decision: Hearth & Hustle repairs it in the background, no command. This is the one background write the addon makes; the limits are in `CLAUDE.md` and enforced in `API.PlaceOnBar`: empty slot only, not in combat, cursor free, never replaces or removes a button, never uses one.
- `Modules/BarGuard.lua` keeps, per character and per spec group (`C_SpecializationInfo.GetActiveSpecGroup`), what is on slots 1–120 and 145–180 (`HearthAndHustleCharDB.barGuard.specs[group].slots[slot] = { k, id, sub, n }`). Pages 11–12 (possess/vehicle, totem slots) are not player-placed and are left alone.
- What counts as a wipe: a remembered button missing at the first look after login (5 s after `PLAYER_LOGIN`), after `ACTIVE_TALENT_GROUP_CHANGED` (3 s), within 6 s of `PLAYER_LEVEL_UP`, or three or more remembered buttons emptied within 0.3 s at any time. A burst is looked at a second time 2 s later before anything is placed, so a spec change that announces itself late is compared against the right spec. Anything else is a hand edit and becomes the new memory 1.5 s after the last change.
- Restore: `C_Spell.PickupSpell` / `C_Item.PickupItem` / `PickupMacro` (found by the name from `C_ActionBar.GetActionText`; the id `GetActionInfo` returns for a macro slot is not a macro index) / mounts through their spell, then `PlaceAction`, then `ClearCursor`. A button that cannot be picked up is retried on two later looks (10 s apart) and then forgotten, without chat. Unreadable (secret) slot data is never treated as empty: nothing is saved or placed.
- If the client reports `ADDON_ACTION_BLOCKED` during a restore, the guard pauses until the next login and says so once.
- Known limits: memory lives in this computer's SavedVariables, so buttons removed on another computer or with the addon disabled come back once at the next login; one or two buttons lost mid-session outside the windows above are taken as an edit; flyouts, pets and equipment sets are remembered but not restorable.
- Settings `barGuard { enabled, announce }` (both on), `/hh bars [on|off|notice on|off]`, two ticks under Display, `probe:actionBars` in `/hh apicheck`. `barGuard.log` keeps the last 20 restores (`lost`, `restored`, `failed`, `group`, `mode`).
- Source-checked against `forever` `bebcb6b` (70938). Ten regressions (290 total); mutation controls for the combat, burst, spec-group and secret-data guards each fail the matching case. **Not yet run in the client**: `PlaceAction` from addon code out of combat, the slot ranges, and the event order on a real spec change need a session; read `barGuard.log`, `errors` and `blockedActions` after it.

### Quest item sparkles — v0.20.0 (2026-11-14, Claude)

- Owner's request: build what the "Forever Loot Sparkles" addon does into Hearth & Hustle. That addon (CurseForge 1729017, GPL-3.0-or-later, v2.0.0) keeps one console variable on, `outlineModeShowLootEffectWhenDisabled` = 1, at login and after a graphics preset. Its source was read for the mechanism only; no code was taken (this addon is MIT).
- This is the second background write the addon makes (the first is the action bar guard). Limits are in `CLAUDE.md` and enforced in `API.SetLootSparkle`: that one variable, never in combat, only when the value differs. The adapter has no general console-variable setter. `graphicsOutlineMode` is read (`API.OutlineModeOn`) and never written.
- `Modules/QuestSparkle.lua`: looks at `PLAYER_LOGIN`, 5 s later, 1 s after any `CVAR_UPDATE` or `PLAYER_ENTERING_WORLD` (one coalesced timer; the look is a single read), and at `PLAYER_REGEN_ENABLED` when a look fell into combat. It writes only when the value is not "1".
- Switching off (`/hh sparkle off`, the tick under Display → Quest items) writes "0" only if this addon switched it on (`HearthAndHustleDB.questSparkle.ours`). A setting found already on is left alone. In combat the write waits for the fight to end; switching back on before then cancels it.
- Stops for the session, with one chat line: four writes inside 60 s (something else keeps switching it off; `/hh sparkle on` starts over), `ADDON_ACTION_BLOCKED` during the write, or a value that does not read back.
- A client where `C_CVar.GetCVar` returns nil or a secret for the variable is treated as "no such setting": no writes, `/hh sparkle` says so.
- Evidence for the next pull: `HearthAndHustleDB.questSparkle` = `{ ours, count, introduced, last = { t, build, version, reason, was, outline, failed } }`, `probe:lootSparkle` in `/hh apicheck`.
- Reported by the other addon's author, not verified here: the sparkle shows at once when switched on; switching off needs a full client restart, `/reload` is not enough; the game shows the sparkle or the outline on an item, never both; quest givers sparkle too; graphics presets reset the setting. Its v1.0 documentation said the sparkle only shows while Outline Mode is off, and its v1.3.1 commit that stopped forcing Outline Mode off says the combination was not tested. The owner's `Config.wtf` on 2026-11-14 has `graphicsOutlineMode "2"` and no entry for the sparkle variable. So the first question for the client is whether items sparkle with Outline Mode on.
- The variable is an engine setting: it does not appear in Blizzard's UI source (`forever` `bebcb6b`, 70938). `C_CVar.SetCVar` (`RequiresNonSecureCVar`, secret arguments not allowed) and `CVAR_UPDATE` are documented there.
- Settings `questSparkle { enabled }` (on), `/hh sparkle [on|off]`, one tick under Display. Twelve regressions (302 total); eight mutation controls (combat guard, tug-of-war cap, off switch, foreign setting, Outline Mode write, refusal, ownership memory, secret value) each fail a matching case. **Not yet run in the client.**

### Enemy watch — v0.21.0 (2026-11-14, Claude)

- Owner's request: build the features of "Spy (Forever)" into Hearth & Hustle for world PvP. That addon (CurseForge 1701654, Zerkaa's port of Spy 1.3.8, **All Rights Reserved**) was downloaded and its `Forever.lua` read for which client functions it relies on. No code, sound, texture or text was taken; the name "Spy" is not used.
- `PvP/EnemyWatch.lua` + adapter section "Enemy watch". Detection: `NAME_PLATE_UNIT_ADDED` / `_REMOVED` tokens, `PLAYER_TARGET_CHANGED`, `PLAYER_FOCUS_CHANGED`, `UPDATE_MOUSEOVER_UNIT`, and a 1 s ticker over the tokens still on screen plus target and focus. A unit counts when `UnitIsPlayer` and `UnitIsEnemy("player", unit)` are true and its name is readable.
- **Names.** On this client `UnitName(unit)` returns first name and surname; Blizzard's Camelot `NameUtil` joins them with `Constants.CharacterNameSeparatorConsts.CHARACTERNAME_SURNAME_SEPARATOR` (source `bebcb6b`). Enemy watch keys every player by that full name (`API.PlayerFullName`). The older `PvP/Roster.lua` keys by first name only; in the open world its HUD section yields to the enemy watch whenever that has rows.
- An encounter starts when a player is seen who was not seen in the last 120 s. Rows stay on the HUD for 60 s after the last look. Everyone met is kept in `HearthAndHustleDB.enemyWatch.players[name] = { class, race, level, guild, first, last, seen, zone, wins, losses }`, at most 2000.
- Alerts (chat, `RaidNotice_AddMessage`, `PlaySound`): new enemy (kit `PVP_ENTER_QUEUE` 8458), Kill On Sight (`RAID_WARNING` 8959), stealth (`RAID_BOSS_EMOTE_WARNING` 12197). No custom sound files. Not alerted: `UnitCanAttack("player", unit)` false (listed with "not flagged"), zone type "sanctuary" (`C_PvP.GetZonePVPInfo`). More than five new enemies in 10 s gives one summary line. On-screen notices for ordinary enemies are at least 4 s apart.
- **Stealth notice: the one place the addon reads another player's cast.** `UNIT_SPELLCAST_SUCCEEDED` on a nameplate, target, focus or mouseover token of an enemy player; the spell id is used only when it is not secret, and only compared with Stealth, Vanish, Prowl and Shadowmeld (by id, or by the spell's own name for a changed id). Nothing is timed or tracked. The limit is in `CLAUDE.md`; cooldown, diminishing-returns and interrupt trackers on enemies stay ruled out (§8).
- Wins: `PARTY_KILL(attackerGUID, targetGUID)` with the attacker being the player or the pet and the target a player GUID seen this session. Losses: `PLAYER_DEAD`, then 1.5 s later `C_DeathRecap.GetRecapEvents()[1]` (the killing blow, as `Blizzard_DeathRecap` reads it) matched by GUID or source name against players seen; a recap whose link id was already counted is stale and retried once after 3 s. As of v0.21.1, an unreadable recap can produce an explicitly unconfirmed targeting hint, never a loss. Confirmed loss attribution requires a player GUID or an unambiguous name from a locally seen player in this session; an explicit non-player or unknown GUID cannot fall back to a name. Pending death callbacks are canceled when disabled or leaving the current world. A killing blow from anything else is not a loss.
- Lists in `HearthAndHustleDB.enemyWatch.kos[name] = { t, reason }` and `.ignore[name] = t`, account-wide (names are unique for the region). As of v0.21.1, list keys match exact full names only. A typed first name resolves only to one known full name; ambiguous or unknown shorthand is rejected. Old shorthand entries can be removed but do not wildcard-match surnamed players. Ignoring a player immediately removes their HUD row. `/hh kos` and `/hh ignore`: bare name switches, `+name` only adds, `-name` only removes, no name = the targeted enemy.
- Party share: `EW;1;<name>;<CLASS>;<level>;<guild>` on the existing `HHUSTLE` prefix, PARTY channel, verified party sender, fields stripped of `|`, `;` and control bytes and length-capped. Only what this client saw itself is sent; a received sighting is shown as "seen by", never stored in `players` and never passed on.
- Nameplates: `nameplateShowEnemies` and `nameplateShowAll` are read; when one is off the addon says so once. `API.EnableEnemyNameplates` writes them only from `/hh enemies nameplates` or the button under PvP, never in combat. This is a player's click, not a background write.
- Off when `IsInInstance()` is true (dungeons, raids, battlegrounds, arenas).
- Evidence for the next pull: `enemyWatch.counts` (encounters by channel: `nameplate`, `target`, `focus`, `mouseover`, `cast`, `party`; `secret` = enemy players whose name was withheld; `castRead` / `castSecret`; `stealth`), `lastKill`, `lastDeath` (`how`), `sound` (whether the client played the last alert), `probe:enemyWatch`.
- Reported by the other addon, not verified here: nameplate range is about 40 yards; without "always show nameplates" the client only shows nameplates in combat; `/targetexact First-Last` finds nobody while `First Last` does; `GetRealmName()` is an internal server name that differs between characters.
- Not built: click-to-target rows (secure buttons anchored to the PvP HUD would stop the HUD from resizing in combat, which the cast timers need), fight markers on the world map, own-faction and guild watch lists, guild/raid chat announcements.
- Settings `enemyWatch { enabled, alerts, sound, stealth, share }` (all on). Fifteen regressions (317 total); 26 mutation controls, 25 caught, the 26th removed dead code. **Not yet run in the client**: whether enemy-player names, GUIDs and cast ids are readable in the open world in and out of combat, the three sound kits, `PARTY_KILL` and the death recap.

### Deep review repairs — v0.21.1 (2026-11-14, Codex)

- Quest arrival state releases after a confirmed continent change; missing position data retains the current wait.
- Action bar recovery retains a level-up or confirmed reset request through combat and delayed post-write reads. Empty slots only, never in combat or with an occupied cursor; deliberate edits outside recovery remain valid.
- Enemy loss records require readable recap evidence. Targeting-only hints are labeled unconfirmed; canceled callbacks cannot write after disabling or changing world. KOS/ignore shorthand resolves uniquely to full names, and ignored rows disappear immediately.
- Quest vendor ranking requires every choice's price and quantity, plus readable choice counts. Unknown values remain unknown. Disabled reward prices clear immediately and queued callbacks respect the current setting; finishing a quest clears labels.
- Disabled sparkle handling resumes an unfinished, addon-owned off request after reload and retries unavailable settings on later world/CVar events. Values already enabled by the player are preserved.
- XP/hour excludes expired gains and retains the cumulative sample before the rolling-hour boundary, so the first in-window gain is counted.
- Local gate: 341 regression scenarios (24 added), 18 self-tests. These are mock/source checks; behavior in the live client remains pending. No additional background writes or gameplay automation introduced.

### Quest location guidance — v0.22.0 (2026-11-14, Codex)

User reported Alpha Strike (2863) in Feralas lacked useful map/minimap locations. Fresh saved v0.21.1/build70938 shows 4/5 Woodpaw Alphas, enabled marker settings, 25 matched/2 missing objectives and no new stored errors. Actual installed QuestieDB supplies twelve NPC5258 coordinates; reproducing the full saved quest log generates ten merged Alpha Strike markers among 108 Feralas markers. A missing database record, disabled settings and marker-budget starvation were not reproduced. User confirms the legend and some icons are visible; exact cause of the original visual absence remains unconfirmed.

- New **Quest locations** page: searchable current log; target/contact source names, zones, coordinates and distances; progress; coverage and filter explanations; explicit Show quest on map, Show this location and Guide buttons. Hidden sources remain browsable. Map actions revalidate, reveal that quest and restore relevant marker toggles only on the player's click. Browsing never changes routes, settings or tracking.
- Entry points: sidebar, Navigation, map legend Locations button, right-click on a compact-panel quest row. Existing left-click guidance remains. Sidebar spacing accommodates fifteen sections.
- Focused/tracked/current guidance quest markers are larger (22 px) with one source-name label per objective. Native frame-level definitions and restricted mouse passthrough remain untouched.
- Minimap keeps nearby-only source markers and adds one distance-labelled rim arrow to the focused/tracked/current quest's nearest known area outside view, on the current map or its parent/child. Tooltip explicitly says outside view/known search area; click guides, right-click browses. It clears near the source, when filtered/disabled, or without a valid same-continent position. No live-spawn claim.
- Missing exact references can show a **client quest area**, using validated native next-waypoint/current-map POI data. Areas are visibly approximate, remain separate from matched-objective counts, obey the hints toggle, and clear on completion/abandonment. No inferred NPC identity, fabricated spawn coordinates or quest-specific override.
- Bounded latest `questLocations` coverage, world acquired-pin counts by quest and minimap cue/count snapshots distinguish source availability from rendered-map state on a later SavedVariables pull. Last world snapshot is timestamped and may describe an earlier opened map.
- Source verification: Forever UI `bebcb6bf309cf41b41bd74f8ca651e6a105b2676`, build70938; `WorldMap.lua` global `OpenWorldMap(mapID)` opens via the native UI action. All gameplay reads remain in Adapter. Existing route priority stays native-first.
- Local verification: 348 regressions and 18 self-tests; packaged provider now includes Alpha Strike's actual twelve coordinates, map/minimap and completion cleanup. Live presentation requires client confirmation. No automation, new background writes, new media or changed QuestieDB files.

### Nameplate notice, sea crossings and trip plan — v0.24.0 (2026-11-15, Claude)

First client read of v0.23.0 (build 70938, save flushed 2026-11-15T06:53Z): no new errors, no blocked action since v0.18.2, quest sources matched 21 / missing 0. Two findings drove this release.

**Enemy watch only saw players the user pointed at.** `enemyWatch.counts` = mouseover 21, target 7, nameplate 0 over 26 players; enemy nameplates were off outside combat and the one-time chat line (v0.21.0) had been missed.

- The PvP page opens with what the watch can see: a red line while enemy nameplates are off (or only shown in combat), the sightings so far by source, and **Turn on enemy nameplates** directly under it. The same line appears on Overview. The existing rule holds: the two nameplate console variables are written only on that click or `/hh enemies nameplates`, never in combat (`W:TurnOnNameplates`).
- The login chat line is said each login while it applies (was once ever). The PvP HUD adds one footer line under a non-empty enemy list; an empty HUD stays hidden. Both obey **Remind me while enemy nameplates are off** (`/hh enemies notice on|off`, default on).
- For the next data read: `enemyWatch.nameplateState` (setting at login) and `enemyWatch.nameplates` (result of the last click: `on`, `combat`, `refused`).
- Still unobserved in the client: a sighting through a nameplate. After the click, `counts.nameplate` should rise; `counts.secret` rising instead means nameplate names are hidden.

**A step on the other continent was a dead end** (`other continent: The Hinterlands`), with 14 quests spread over nine zones on both continents.

- `Route/Travel.lua` (new). Read-only help: it never creates, changes or reorders a waypoint except on the player's **Guide to selected stop** click, which uses the planner's own `Go`.
- **Sea crossings.** When the active destination is on another continent the arrow leads to the boarding end of the best crossing (least straight-line distance to board plus from the landing to the destination) and names it: `Zeppelin to Undercity  1.2k yd`, `Board here: …` within 45 yd. The destination waypoint is untouched. No crossing known → the old text.
  - Horde zeppelins (Orgrimmar ↔ Undercity, Orgrimmar ↔ Grom'gol) and the neutral ship (Ratchet ↔ Booty Bay) use the positions of four zeppelin masters and two shipmasters in the installed QuestieDB Forever reference (NPC 9564, 9566, 12136, 3149, 9558, 9559; read 2026-11-15). That shows the routes exist in Forever's data; none has been ridden with this addon watching.
  - Alliance ships (Menethil ↔ Theramore, Menethil ↔ Auberdine) are the Classic routes with approximate docks. No Forever evidence; every text that shows one says so.
  - Unknown faction → neutral crossings only. No timetable, ride time or terrain.
- **Flight points.** `HearthAndHustleCharDB.flights`: the names the flight map shows as current or reachable, learned on `TAXIMAP_OPENED` whether or not the recorder is on, plus where the player stood for the current one. Seeded once from the recorder's account-wide list only when that list has seen exactly this one character.
  - Positions: a flight map is the continent drawn to scale, so points with both a map coordinate and a stood-at position give a least-squares affine fit (map → world) that places the rest. Checked on the user's data inside one zone (The Barrens, three points): the two slopes agree to 0.2 % (x) and 1 % (y).
  - The fit is not trusted with fewer than four samples (three always fit exactly), on a mix of continents (the majority continent is kept), or above 250 yd RMS; with six or more samples one worst sample is left out once. A distrusted fit falls back to a known point named after the destination's zone. `HearthAndHustleDB.travel.fits[<flight map>]` keeps `n`, `rms`, `ok`, `dropped` for the next data read — **the fit has not run in the client yet.**
  - The arrow's third line names the nearest known point only when it is a real shortcut (destination ≥ 1,500 yd away and the point less than 60 % of that from it): `flight point: Hammerfall, Arathi`, or after a crossing `then The Hinterlands · fly to Hammerfall, Arathi`. The tooltip and Navigation page give the sentence, including the Hearthstone when the inn is on the destination's continent.
- **Trip plan** (sidebar, Overview button, `/hh trip`). The planner's existing steps grouped into one stop per zone: nearest first on the current continent (each ready turn-in is worth 250 yd, at most three, the planner's own figure), then the crossing that lands nearest a stop, then that continent. Shows quest, turn-in and pickup counts, straight-line distance from the previous stop, which stop the Hearthstone reaches, and how many quests have no known location or are deferred. Sidebar spacing now fits sixteen sections.
- Limits, stated in the UI: straight lines between zone centres, not travel time; "finish this continent, then cross" is a rule of thumb, not an optimum; quests without a known location are counted, not placed.
- Validation: nine new regression cases (seven travel, two nameplate), each failing on v0.23.0; 22 mutation controls on the new guards, all caught; real saved account and character files replayed under the mock (20 known flight points adopted, stored errors 4 → 4). The mock's world is not the client's: crossing choice, fit quality and the arrow's third line need a client session.


### Healer tools and dungeon itinerary — v0.25.0 (2026-11-15, Claude)

Owner's request after the v0.23.0 client read: a resto shaman at 50 who heals dungeons. Built without a client session in between, so each read below is a documented one (generated docs, `forever` `bebcb6b`, build 70938), checked value by value, and **none has been seen inside a dungeon yet**.

**What stays impossible.** Health, missing health, incoming heals, absorbs and `UnitInRange` are `SecretReturns`; power is secret when restricted; auras, cooldowns and threat are secret in combat. So there is no lowest-member, low-health, out-of-mana, dispel or threat warning, and nothing in `Modules/Healer.lua` runs in combat. The page says so and points at the client's own raid-style party frames and click casting, which draw those values natively.

**Heal rank table** (`/hh` → Healing, `/hh heal ranks [all]`). Shown only to classes with healing spells (the sidebar lists Healing for Shaman, Priest, Druid and Paladin; seventeen buttons use 26-px spacing).

- Per rank: mana (`C_Spell.GetSpellPowerCost`, mana entry), cast time (`C_Spell.GetSpellInfo().castTime`), the amount parsed from the spell's own tooltip text (`C_Spell.GetSpellDescription`: `A to B`, `N over S sec`, or both), healing per mana and per second of casting (an instant counts 1.5 s). None of these calls has a secret gate in the docs.
- Spell ids by rank are the Classic ones. A rank is used only when the client gives its id the same name as rank 1 of the family, so a wrong id drops a row instead of mislabelling one. The user's saved bars hold Healing Wave r8 (10395), Lesser Healing Wave r4 (10466) and Chain Heal r2 (10622), which agrees with the table for those three.
- "Known" = `C_SpellBook.IsSpellKnown(id)` is true, or the spell is on the action bars the bar guard remembers (the spellbook may answer only for the highest rank; unverified).
- **Bonus healing estimate.** `GetSpellBonusHealing` is `SecretWhenUnitStatsRestricted`; when readable, each row adds bonus × coefficient by the Classic rule: base cast time ÷ 3.5 (heal over time: duration ÷ 15), capped at 1, × (1 − (20 − learn level) × 0.0375) for a rank learned before 20. Base cast times and learn levels are a table in the module. Regrowth and Prayer of Healing get no estimate. The UI labels it "est." and says the rule is not confirmed on Forever. Whether Forever's tooltips already include bonus healing is unknown: `HearthAndHustleDB.healer.tooltip` keeps up to twelve `{id, heal, bonus, cost, cast}` samples of the main heal, so a gear change between two samples answers it.
- A one-line mouseover macro for the selected rank is offered as text to copy. The addon creates and runs no macro (`CreateMacro`/`EditMacro` are not in the generated docs).

**Between-pull check** (PvP HUD section "Healer check (between pulls)", the Healing page, `/hh heal`).

- Runs only when: healer tools on, a healing class, the gear role on Best in slot is Healing, out of combat, in a party and not a raid.
- Per party member: offline (`UnitIsConnected`), dead (`UnitIsDeadOrGhost`), out of heal range (`UnitIsVisible` false, or `C_Spell.IsSpellInRange` false for the highest known rank of the class's main heal), still in combat (`UnitAffectingCombat`). A value that comes back nil or secret says nothing: never "in range", never "out of range".
- Own essentials: drinks at or below four (the supply module's bag count), no Ankh while Reincarnation is known, weapon imbue missing or under five minutes (classes with an imbue), and "not your healing spec" once the player has marked a spec group with **This spec is my healing spec** (`HearthAndHustleCharDB.healer.specGroup`; no talent API is read).
- A member whose dead/alive state the client withholds is counted as unreadable, not alive: the party is then never called ready, and inside an instance the check says `Party state unreadable here for N of M`.
- No problem → nothing in the open world; inside an instance one green line (`Party ready: 4 of 4 alive, in heal range · 23 drinks · 2 Ankh`). A 3-second ticker brings the section up when the HUD is hidden and something changes.
- For the next data read: `HearthAndHustleDB.healer.seen` counts, per context (`inst=party dead=boolean online=boolean visible=boolean combat=boolean range=boolean`), which reads answered. `range=nil` inside a dungeon means the range check does not work there and the line should go. `/hh apicheck` gains a `probe:healer` row.
- Validation: five regression cases (`tests/healer.py`); mock-tested only.

**Dungeon itinerary** (`Modules/DungeonPlan.lua`; the Dungeons page of the control window, `/hh dungeon plan [name]`). The checklist window (v0.7.0/v0.14.0) answers "what is the state of each quest"; this answers "in what order do I go". It reads the same catalogue and states (`Dungeons:Rows`) and adds places from the quest database. Nothing changes until **Guide to selected step**, which uses the checklist's own `GuideQuest` / `GuideEntrance`.

- Sections, in order: **Turn in first** (ready dungeon quests: a turn-in can open the next step) · **Before you enter** · **Inside** (quests already in the log, givers that stand inside, item-started quests) · **Not available yet** (missing prerequisite, listed level, unreadable state: never offered as a pickup) · **Drops for your role**.
- **Before you enter.** Each available pickup is placed at a live offer on the current map, else the nearest known giver outside the dungeon (`QuestChains:Starters`), and the pickups are grouped one stop per zone: nearest zone first on the current continent, then the sea crossing from `Route/Travel.lua` and the other continent, ending at the nearest entrance (with a crossing back when needed). A giver the reference cannot place is listed apart with the catalogue's giver and zone. Without a position (inside an instance) the list is complete but carries no distance from where you stand. Straight lines, as on the trip plan.
- **Drops for your role.** Items of the gear reference whose dungeon source is this dungeon, usable by the class, wearable within two levels, scored with the Best in slot weights for the chosen role and compared with the weaker worn piece of that slot. Listed when the score is higher (best eight) or when the item is on the wishlist; **Save drop to wishlist** toggles it. Worn items that cannot be read yet give no comparison and therefore no claim. Not shown in combat.
- Fixed on the way: `UI/Gear.lua` compared the source name "The Temple of Atal'Hakkar" with `temple of atal'hakkar`, so the Temple's 18 drops never linked to The Sunken Temple. One matcher (`Gear:SourceIsDungeon`) now serves both pages.
- The page opens on the dungeon for your level with most quests in your log; else the one last opened in the checklist if it has a quest list; else the one whose level range you are nearest the middle of. A dungeon with no catalogued quests (five Forever dungeons) says so and claims nothing.
- Checked offline against the installed QuestieDB 1.0.13 Forever and the user's saved profile (level 50 Horde shaman, standing in Orgrimmar): The Sunken Temple 4 pickups in 3 zones + entrance, Zul'Farrak 5 in 3, Maraudon 6 in 2 + 1 inside, Blackrock Depths 8 in 4 + 3 inside; 4–80 ms each; stored errors 4 → 4. Quest states in that run were the mock's, not his.
- Validation: four regression cases (`tests/dungeon_plan.py`) on a two-continent test world. Mock-tested only; the order on real coordinates and the worn-gear comparison need a client session.

Controls for the release: all nine new cases fail on the v0.24.0 source; 39 mutations of the new guards and rules (combat, raid and role gates, the wrong-id check, the bonus rule, unknown range, blocked quests, givers inside, zone order, crossings, what can be guided, upgrade and class filters, combat guards, the default dungeon) are each caught by at least one of them.


### Gear finder — v0.26.0 (2026-11-15, Claude)

Owner's report: "trying to find best in slot 2 hander weapons for my windfury shaman and it's clear as mud … Staff of Jordan is #6 on the source: drop list". Reproduced exactly from his saved profile and the reference: gear role Healing (he is a resto shaman with a second spec), level 60, Main hand, Source: Drop puts Staff of Jordan at #6 of 267. The page ranked for his healing role and nothing on it said so; the main-hand list mixed one- and two-handers; a row showed a name and a score.

- **A browsed role, separate from the character's role.** `Gear:Browse()` (`HearthAndHustleCharDB.gear.browse`, one of the class's roles) is what the page ranks for; `Gear:Profile()` (`gear.profile`) stays the character's own role, which `Healer:IsHealer` and `DungeonPlan:Gear` follow. `Gear:Weights(role)` and `Gear:Rows{role=…}` take the role. Only **Make … my role** writes `gear.profile`. The weights editor edits the browsed role.
- **Filters** (`Gear:Rows`): `hands` ("two"/"one", main hand only; ignored elsewhere), `subtype` (the reference's type name; the third return lists the types the other filters leave, so the choice does not shrink once one is picked), `sort` ("dps", "hit" = `(dmgMin+dmgMax)/2`; ties and the default fall to score, then id), `otherFaction`. Hands, type and sort reset when the slot changes.
- **Sources.** `Gear:Sources()` offers only source types present in the loaded reference (Forever has no Raid or Reputation rows; the old fixed list offered both and matched nothing). The reference files every creature drop without a listed dungeon under `Drop`, raid bosses included (Dark Edge of Insanity: `Drops`, `Dropped by: C'Thun`), so the label is "World / raid drop" and a row says `Drop: <creature>` when one is listed.
- **Other faction.** `Gear:Side(item)`: a required reputation (Classic battleground factions, plus Darkspear Raiders = Horde and Theramore Expeditionary Force = Alliance, **unverified in the client**) or an honor-rank title opening the name of a Vendor/PvP item (the reference lists no requirement on the Horde rank items). An item that asks for one reputation per side is open to both. Other-side items are left out when `UnitFactionGroup` is readable, counted in the summary line, and shown again by a tick.
- **Reference fields added** by `tools/import-gear-catalog.py` from the same pinned revision (every earlier field byte-identical on all 8,370 records; the unmodified importer reproduced the shipped file first): `quality`, `bind`, `dmgMin`/`dmgMax`/`speed` (all 1,319 weapons; `(min+max)/2/speed` within 0.6 of the listed DPS), `crit`/`hit` (melee lines only), `droppedBy`/`dropChance` (911), `requires` (488: reputation, rank, skill).
- **Rows and details.** `Gear:RowText` fits 80 characters: rank, name, kind (`2H Mace`), DPS, speed, level (`ilvl N` when no requirement is listed), then the source in the room left, then as many of the role's stats as fit whole. Rows are tinted by quality (`Hub:List` option `color`). `Gear:Details` leads with what the item is and where it comes from; states reference-vs-client differences only when there are any; a two-hander is compared with main + off hand together and gives no number when either hand is unreadable.
- Not scored, on purpose: weapon speed, hit, crit, procs. They are shown. Whether a shaman needs a talent for two-hand axes and maces on Forever is not known here; the details say weapon training is the player's check.
- Page order: two filter rows, search + level on one line, slots, the summary line, six rows with paging (all within the first screen), the selected item, then wishlist / dungeon / quest-source / role buttons.
- Validation: nine regression cases (`tests/gear_finder.py`), each failing on v0.25.0; 31 mutation controls, all caught; provider integration unchanged; the page replayed on the owner's saved account and character files (errors 4 → 4). **Mock-tested only.** For the client: do the rows fit the buttons at his UI scale, is the quality tint readable, does the hover tooltip load uncached items.



### Supplemental nearby-object sparkles — v0.27.0 (2026-11-16, Codex)

- User reports Un'Goro dirt piles never outline or sparkle, including on hover, while other quest objects have sparkled. Fresh SavedVariables: native setting on, outline on, four historical errors. This contradicts universal coverage, not the existence of native sparkles. Exact engine classification of dirt piles remains unobserved.
- `Modules/NearbySparkle.lua` adds a separate, default-off overlay. It reads only the game's `softinteract` object, requires `UnitIsGameObject == true`, a readable GameObject GUID, and a visible non-forbidden nameplate from `C_NamePlate.GetNamePlateForUnit(..., false)`. It draws six animated gold stars on an addon-owned, mouse-transparent frame anchored to the plate. No Blizzard frame is hidden, restyled or reparented. Combat, missing/secret reads, target changes and removed plates hide the overlay. Recheck at 5 Hz while enabled. No object enumeration, quest flags, hardcoded object IDs, target/cast/interact/loot calls, or living-unit overlays.
- GUI: Display → Quest items → Enable nearby sparkles, with explicit disclosure that enabling Interact Key can alter untargeted spell recipients. Disable / restore is adjacent. Native checkbox is independent. No claim of safe self-cast, all-object coverage, or zone-wide simultaneous rendering. Approximate range 15 yards; one game-selected object at a time, potentially herbs/ore/chests/other objects too.
- Setup is **only** on the player's confirmed GUI action, never in combat. Fixed adapter allow-list: `SoftTargetInteractRange=15`, `SoftTargetInteractArc=2`, `SoftTargetInteractOnlyInRange=0`, `SoftTargetNameplateInteract=1`, `SoftTargetIconInteract=1`, `SoftTargetIconGameObject=1`, `SoftTargetInteract=3` (last). Preflight all reads before changing anything, record originals before each write, verify readback, roll back on failure. Disable uses compare-and-restore: newer differing values win; failed undo receipts remain. An explicit undo can finish after combat/reload. Never reapply activation at login, after graphics changes, or in response to targets. Never change friendly/enemy targeting or self-cast settings.
- API surface verified against Blizzard Forever UI source `bebcb6bf309cf41b41bd74f8ca651e6a105b2676`, build `1.60.1.70938`: UnitIsGameObject, UnitGUID, UnitName, PLAYER_SOFT_INTERACT_CHANGED, C_NamePlate.GetNamePlateForUnit, CVars. Engine setting availability is checked at runtime; names are not a guarantee that a particular client exposes a plate. Native and extra sparkle implementations are independent; no external addon code copied.
- Evidence: native `questSparkle.observed` refreshes even when already on (old `.last` remains a write receipt). `questSparkle.nearby` stores the undo list, latest state, lastAttached object/build/version and attachment count. An attachment receipt verifies only UI logic, not rendered appearance. After playing inspect these, errors and blocked actions, plus the user's observation. Actual dirt-pile detection, texture appearance, anchor placement, range and spell interactions remain client-unverified.
- Twelve added regression cases cover numeric CVar normalization, dirt/other objects without a database, no default activation, combat/secret/unit/forbidden/hidden filters, plate removal, ownership-aware undo, partial setup failure, failed undo/reload, combat-deferred undo, preset/login non-enforcement, allow-list and the GUI disclosure/action path. Prior native message tests now assert setting state instead of claiming all objects visibly sparkle.

- Numeric CVar readback/undo compares values numerically: the engine may return `15.000000` for a requested `15`. The added normalization case fails against initial merge `243d123` and passes with the comparison fix, before local installation.

### Nearby-object sparkles retired — v0.27.1 (2026-11-16, Claude)

- Owner's report the same day: the v0.27.0 mode "made things worse". Client state read with the game closed: the mode was still on (`settings.questSparkle.nearby = true`) and five game settings were at the setup values (`SoftTargetInteract` 3 from 1, `SoftTargetInteractRange` 15 from 10, `SoftTargetInteractArc` 2 from 0, `SoftTargetNameplateInteract` 1 from 0, `SoftTargetIconGameObject` 1 from 0), saved by the game in the account's `config-cache.wtf`. The overlay reached one object within about 15 yards, which is not what was asked for (sparkles to find objects from a distance). The Interact Key mode also changes who an untargeted heal or buff lands on; the owner plays a healer. The upstream Forever Loot Sparkles addon removed the same approach in its v2.0.0 for that reason (see the 2026-11-14 notes).
- Removed: the overlay frame, the setup and disable buttons, every read of the `softinteract` unit and its nameplate, the 5 Hz ticker, the `nearby` settings default.
- Kept as the undo (`Modules/NearbySparkle.lua`, same file name, no TOC change): at login + 5 s, on a settings change and after combat it reads the saved list `HearthAndHustleDB.questSparkle.nearby.restore` (name, earlier value, setup value) newest first, so the Interact Key mode goes back before its display settings. A setting still at the setup value gets its earlier value back. One that differs is left alone and, if it still differs 30 s after it was first seen, forgotten as the player's own (account settings can arrive after login, so a first look is not trusted). Rows naming anything but the seven settings, or with nothing to undo, are dropped unwritten. A refusal is retried on three looks, then the exact `/console` lines are printed once and the list is kept for the next login. One chat line when done. Receipt: `questSparkle.nearby.retired` (`restored`, `kept`, `failed`, `pending`, `told`). The v0.27.0 evidence (`last`, `lastAttached`, `attachments`) is left in place.
- Adapter: `API.RetiredNearbySetting(name)` reads one of the seven; `API.RestoreRetiredNearbySetting(name, value)` writes an earlier value, never in combat, and refuses the setup value of each setting, any other setting and non-numeric text. Numeric comparison, because the client prints `10` as `10.000000`.
- What the client's own sparkle covers (engine help text from the `forever` console variable list, `outlineModeShowLootEffectWhenDisabled`: "When Outline Mode is disabled, replace passive outlines with loot sparkles"): the sparkle stands in for the engine's passive outline, so it appears on the objects the engine would outline and on nothing else. Which objects those are is decided outside the UI: nothing in Blizzard's `forever` UI source (70938) selects them, and no addon API attaches an effect to a world object or lists world objects. The owner's graphics Outline Mode is on (`graphicsOutlineMode` 2) and the sparkle still shows, so "Outline Mode is disabled" there is the gameplay setting (`Outline`, default 0, not in his saved settings), not the graphics quality setting. **Not established:** why Un'Goro Dirt Piles (object 157936) get neither. Likely, from Classic behaviour only: the pile is a container anyone may loot (Un'Goro Soil also drops from creatures and is tradeable), so the game does not treat it as a quest objective of the player. No client evidence either way.
- Validation: 11 regression cases (`tests/nearby_sparkle.py`), ten of them failing on v0.27.0; 23 mutation controls, 22 caught, the one miss is a combat check that exists twice (removing both is caught); the build replayed on the owner's saved account and character files with the client's saved settings: five writes, all five back at the earlier values, errors 4 → 4. **Mock-tested only.** For the client: the chat line at the first login, and `questSparkle.nearby.retired` in the next save.

### Save diet: two recording levels, one-time prune — v0.28.0 (2026-11-17, Claude)

- Read first (owner's save, build 70938, 2026-11-16): `HearthAndHustle.lua` was 6.62 MB and had grown 171 KB that day. By rough serialized size: `data.creatures` 2.26 MB (1,334 of 2,265 creatures only looked at, never killed), `data.progress` 0.94 MB, `data.quests` 0.75, `data.npcs` 0.42, `data.recipes` 0.28 (95,393 writes counted), `apicheckHistory` + `apicheck` + `probe` 0.67. The client parses the whole file at every login and `/reload`.
- What a feature reads back (grep of every `FP.data.` / `FP.db.` reader outside the recorder): `data.quests` givers/enders/`gpos`/`epos`/`startItem`/`obj[i].pos` and `data.npcs[id].pos` (route fallback, `Route/Planner.lua`), `data.trainers` (`Modules/Trainer.lua`), `data.taxi.nodes` and `data.chars` (`Route/Travel.lua`), the last hour of `data.xp` (`Modules/InfoBar.lua`), `data.pvp.players` (`PvP/Roster.lua`), `data.bg`. Nothing reads creatures, objects, items (one name lookup with a live fallback), vendors, zones, binds, recipes, progress, deaths, loot observations, quest logs/loot tallies, NPC gossip lines or the API report history. `obj[i].mobs` has not been written since schema 2, so the route's creature-position branch was already dead.
- `settings.record` (unchanged default: off) now keeps only the first group. `settings.recordDataset` (new, default off, `/hh record dataset on|off`, tick on Diagnostics) adds the research dataset as before; switching it on switches recording on, and recording off silences it without forgetting the choice. XP samples: 180 per character without the dataset (2,000 with). API reports: one per build key, newest three kept, no history list.
- Schema 3 (`FP.SlimSave`, `Core/Config.lua`), once per account at `ADDON_LOADED`: empties the research tables; strips `log`, `items` and the `legacy*V1` fields from quests (opt-in quest text stays); keeps an NPC only if it carries an interaction flag or a quest names it as giver or turn-in; trims XP to the newest 180; drops `apicheckHistory`, all but the newest three API reports and the probe samples. When anything was removed it switches the beta probe off (it was a diagnostic of the same era; `/hh probe on` restores it), stores the receipt `HearthAndHustleDB.meta.diet` (`removed` counts, `from` schema, `probeWasOn`) and prints one chat line. A fresh install or a profile with nothing to remove is not touched and not told anything. Lifetime counters (`meta.counters`) stay. A v1 profile passes through schema 2 first; its set-aside biased totals are then dropped with the rest.
- Not reversible in the client: the removed rows exist only in copies made before the first v0.28.0 login (`tools/pull-data.sh` output under `data/`, and the deploy backup).
- Validation: five regression cases (`tests/save_diet.py`), each failing on v0.27.1, 29/29 mutation controls. The legacy-profile case loads a schema-2 fixture through the real `ADDON_LOADED`/`PLAYER_LOGIN` path, checks a second login removes nothing, and as a positive control resolves a kept quest's turn-in place through `Planner:ResolveTurnIn` ("recorded"). Three older cases changed with the format: the API report case now asserts there is no history, the v1 migration case asserts the biased fields are gone rather than set aside, and the suite's seeded profile turns the dataset on so every older recorder case still exercises it. The same login replayed on the owner's real account and character files: 5.99 MB → 1.15 MB by the same measure, 693 quests / 483 of 1,076 NPCs / 30 trainers / 36 flight nodes kept, errors 4 → 4. **Mock-tested only.** For the client: the chat line at the first login, `meta.diet` in the next save, and the file size.

### Windfury burst: a weapon sort for a shaman's melee spec — v0.28.0 (2026-11-17, Claude)

- Owner's case: resto shaman with a Windfury two-hander second spec; the gear page showed speed and damage but ranked by a stat score in which weapon DPS dominates and speed counts for nothing. Open since v0.26.0 as "score hit/crit/speed needs weights he agrees with"; he asked for a Windfury score without naming weights, so the estimate below is the default and every number in it is shown.
- `G:Windfury(item, ctx)` (`Modules/Gear.lua`) estimates what one Windfury Weapon proc lands at once: the swing that set it off plus the extra attacks, each extra one with the spell's bonus attack power. `burst = (1+extra) × average weapon damage + speed × ((1+extra) × attack power + extra × bonus) / 14`, times `1 + (crit% + hit%)/100` for the weapon's own crit and hit as an expected value. Attack power includes the weapon's own (attack power + 2 per Strength).
- It ranks the size of the hit, on purpose. Expected Windfury damage over time is `chance × extra × (weapon DPS + (attack power + bonus)/14)`: it follows DPS and does not depend on speed (the hidden cooldown aside). The page says so under the number.
- Where the numbers come from, each named on the page and saved in `HearthAndHustleDB.windfury` for the next pull:
  - attack power: `API.GetAttackPower()` = `UnitAttackPower("player")` base + buffs + debuffs, out of combat only. Forever docs (70938, `UnitDocumentation.lua`): `SecretWhenUnitStatsRestricted`, the same gate as `GetSpellBonusHealing`, which the client gave out of combat on 2026-11-16 (`probe:healer`, 56). The worn main hand's contribution is subtracted (and the off hand's for a two-hander), since a candidate brings its own. Unreadable → `level × 10`, labelled as assumed. **Client-unverified**: `windfury.apRead`.
  - bonus: `(%d+) extra attack power` parsed from `C_Spell.GetSpellDescription` of the highest Windfury Weapon rank the character knows (8232, 8235, 10486, 16362), else of the rank for its level (30/40/50/60). No parse → Classic values 104/119/249/333, labelled as such. **Client-unverified**: whether those ids exist on Forever and what the tooltip says (`windfury.bonusSource`).
  - two extra attacks, attack power / 14 per second of weapon speed, 2 attack power per Strength: Classic rules, unverified on Forever, stated in the code comment; none is read from the client.
- Offered only where it means something (`G:WindfuryFor`): class Shaman, the page ranked for Strength melee, Main hand. `G:Sorts(slot, role)` adds "Windfury burst" to the Sort cycle there; the shared `G.sorts` list is unchanged. A leftover choice on another slot or role falls back to the score. Rows show `WF <n>`; the details show the arithmetic.
- One button for a shaman, "Windfury two-handers: biggest burst first": Ranked for → Strength melee, Main hand, two-hand only, any source, Windfury sort. It writes `gear.browse`, never `gear.profile` (the Healing page and dungeon drops keep following the character's own role). Not built for other classes.
- Validation: four regression cases (`tests/windfury.py`), 34/34 mutation controls after one added assertion. On the shipped reference at level 52 the list leads with 3.8–4.0 speed weapons (Taran Icebreaker, Soulkeeper, Executioner's Cleaver, Thorium Greatmace) where the stat score led with 3.1–3.2 speed axes. **Mock-tested only.**

### Which dungeon next, for the character's role and a second spec — v0.28.0 (2026-11-17, Claude)

- Owner: level 52 resto shaman with a Windfury second spec, asking which dungeon to run. The itinerary (v0.25.0) lists drops for one dungeon and one role, against what is worn. This ranks the dungeons.
- `DP:Next()` (`Modules/DungeonPlan.lua`), read-only, out of combat. Per role, a dungeon's value is the score its best drop per slot group adds over the best the character carries for that role, as a share of that role's whole set; the roles' shares are added (their scores use different weights, so raw scores are not). Dungeons with nothing better are not listed. Ties: raw gain, then quests of that dungeon in the log, then name.
- "The best you carry" (`G:Owned(role)`): every worn piece plus every item in the bags that the character can wear (not above its level; class and armor type by `G:ClassMatches` when the client gives the item's class, taken as wearable when it does not), each scored for the role. Reason: a second spec's gear is in the bags, not worn, and the worn set is the wrong bar for it. The bank is not seen, and the page says so. A worn piece the client has not given yet makes its slot unknown: drops for it are left out, counted, and the page says how many in red; unreadable bags fall back to worn only, also said. New adapter read `API.GetBagGear()` (`C_Container.GetContainerNumSlots` / `GetContainerItemInfo` hyperlinks through the existing `API.GetRewardItem`, which now also returns `classID`/`subclassID`); never in combat; nil, not empty, when a call fails.
- `G:Gain(owned, role, items)`: each slot group counts once, rings and trinkets twice (the n best of owned and dropped against the n best owned; a new piece is measured against the piece it displaces). Hands are one group: a two-hander stands against a main hand and off hand together, a dropped main or off hand is weighed with the owned other hand, and the better of the two arrangements is taken.
- Second spec (`G:Second()`, `gear.second` per character): chosen with the page's "Second spec" button (none → the class's other roles → none). Until a choice is made it is the role last browsed on the gear page, when that is not the own role. It never writes `gear.profile`.
- Reference limits, shown rather than hidden. The item reference names a dungeon, not a wing: Scarlet Monastery (4), Stratholme (2), Blackrock Spire (2) and Dire Maul (3) are one row each, with the span of their level ranges and a note. It has no drops for The Drowned City, Krol'dok Stronghold, Alcaz Prison, Blackmaw Hold and Shaper's Terrace (new on Forever) and two items for Dire Maul: a dungeon without listed drops in the character's level range is named as "not ranked", never ranked as worthless. Dungeons whose range starts more than two levels above the character are counted, not listed; drops are counted when wearable now or within two levels (the itinerary's rule).
- Surface: top of the Dungeons page (summary, four-row list, details naming up to four upgrades per role with boss and gain, "Second spec" and "Show its itinerary below"), and `/hh dungeon next`. Receipt for the next pull: `HearthAndHustleDB.dungeonNext` (`bagsRead`, `unread`, `loading`, `rows`, `first`, roles).
- Not changed: the itinerary's own "Drops for your role" list still compares with worn gear only. With a second spec's gear on, it measures the own role against the wrong set; left for a follow-up because its rows and tests define "the weaker of two worn pieces".
- Validation: five regression cases (`tests/dungeon_next.py`) on a synthetic reference with hand-computed gains; 56 mutation controls, 54 caught after three added assertions, two equivalent (a second guard catches each: `delta > 0`, and the combat check in `G:Owned`). **Mock-tested only.** For the client: do bag hyperlinks and `GetItemStats` on them answer (`dungeonNext.bagsRead`, `loading`), and does the ranking look right against his real gear.

### Dungeon quests say where they start — v0.29.0 (2026-11-18, Claude)

- Owner's report: at level 54 the Sunken Temple checklist showed "Missing: check pickup" and "Contact awaiting verification - Location awaiting verification" for The Essence of Eranikus, which starts from an item the Shade of Eranikus drops inside. He had to search the web. Reproduced on his saved character before any change; the same replay showed The God Hakkar listed as a pickup although two quests of its chain were not done.
- Cause: the checklist read only the bundled catalogue (DungeonQuestTracker). For 27 of its 455 quests the pickup is an unfilled placeholder, and all 27 are item-started quests it types as "npc". The installed QuestieDB (Forever) has all 455: 38 start from an item (25 dropped only inside a dungeon, 7 with a drop outdoors, 6 with no source listed), 68 have a giver inside a dungeon, 257 have a prerequisite (15 the catalogue lacks, 16 only the catalogue has, 18 where the two differ).
- `API.GetQuestChainStarters`/`GetQuestEnders` contacts now carry `dungeon`/`dungeonArea` (a spawn area that is a provider dungeon, whether or not an entrance is authored), `outdoor`, and for creatures `level` and `rank`; a starting item carries `sources` (creature and object drops, vendors, containers, quest rewards: 12 kept for display, up to 64 per list checked, `outside`/`unchecked` so "only inside" is never claimed from a shortened list). `API.GetQuestAskText` returns the reference's objective text; `API.GetDungeonAreaID` the provider's own id for a dungeon area or alias.
- `D:Origin(id)` (`Modules/Dungeons.lua`): giver(s) or starting item with its sources, `inside` when every known way to start it is in a dungeon; catalogue fallback when the database has no starter, placeholders treated as not recorded.
- `D:Needs`/`D:Path`: what must be done first. The database's `preQuestSingle` (any one) and `preQuestGroup` (all; an exclusive alternative satisfies a positive entry) lead; catalogue prerequisites apply where the database lists none for the quest, and for "keep X in your log". `Path` walks back to the first quest not completed, choosing among alternatives the one this character can take (catalogue restriction, else the reference's race mask read as a faction and its class mask), preferring one already in the log; a loop or a step the client will not answer for is "unknown", a step with no usable branch is said.
- Statuses, in list order: offered on this map, pick up, chain (N quests first), inside (drops / pick up), ready, in your log, needs level N (the larger of catalogue and database), unknown, no longer offered (the next step of the chain is done or in the log, or the exclusive branch is finished), completed, restricted. The row's second line is the one thing to know (`D:Where`); details give how to get it, what it asks, the turn-in, the chain in order and what it leads to.
- Itinerary: item-started quests whose drops are all inside go under Inside with the creature named; an item that drops outdoors is a stop at the drop's place; quests behind a chain have their own section naming the first step, and its button guides to that step; closed quests are left out.
- Client fact (his save, build 70959): the completed-quest list includes copies he never took. 24 completed quests carry the Alliance race mask on a Horde character; none was ever recorded as accepted, and each has a same-name non-Alliance quest completed. Six completed "The Adventurer" variants are mutually exclusive. So the client flags the other faction's twin and the exclusive variants of a finished quest as completed; a completed flag is not proof the character did that id.
- Validation: five regression cases (`tests/dungeon_sources.py`) plus four updated ones, each failing on v0.28.0; 36 mutation controls, all caught after assertions were added for two. On his saved character against the packaged QuestieDB 1.0.13: 471 rows over 35 dungeons build with no stored error and no placeholder text; of his 231 completed quests that have a chain, 225 read as "chain done" and the other six are the exclusive variants above. **Mock-tested only.** Receipt for the next pull: `HearthAndHustleDB.dungeonSources` (`database`, `by`, `rows`, `key`).
- Limits: the database's quest data is largely Classic's with Forever corrections; where Forever changed a giver or a chain and the database has not caught up, the page is wrong in the same way. Zone names and coordinates are the database's known places, not live spawns. A quest's objectives are not checked against the dungeon (a listed follow-up may be done elsewhere).
