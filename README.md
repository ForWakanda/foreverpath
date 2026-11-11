# Hearth & Hustle

Quest GPS, route planner and data recorder for **World of Warcraft: Forever** (release build 1.60.1.70862, interface 16001).

It shows you where to go. You play. Nothing in here moves your character, targets, casts, loots or turns anything in — that is the line Blizzard draws and the line this addon stays behind.

## Renamed from ForeverPath (v0.17.0)

Hearth & Hustle is the same addon under a new name. An unrelated addon called "ForeverPath" now exists and uses the same folder, saved-variable names and `/fp` command, so everything moved: the folder is `HearthAndHustle`, and the commands are `/hh` and `/hustle` (`/way` remains available when another addon or the client has not already claimed it; `/hh way` always works).

Updating from ForeverPath:

1. Close the game completely.
2. Delete `Interface\AddOns\ForeverPath` and install both `HearthAndHustle` and `HearthAndHustle_GearData` folders.
3. To keep your settings and recorded data, copy `ForeverPath.lua` to `HearthAndHustle.lua` in `WTF\Account\<account>\SavedVariables\` and in each `WTF\Account\<account>\<realm>\<character>\SavedVariables\`. No editing is needed: on first login the addon recognises its own old data and saves it under the new names. Skip this step to start fresh.

Developers on WSL: `tools/migrate-from-foreverpath.py` does steps 2 and 3 (`--dry-run` prints the plan and changes nothing), then run `tools/deploy.sh`.

Party features (quest sync, shared timers, rare alerts) only reach party members who are also on v0.17.0 or later.

## Quest map (v0.18.1)

Quests have stable colors shared by the world map, minimap, compact tracker and
Navigation list. World-map markers and quest lists also show quest numbers. Sword icons mean kill targets, bags mean
loot, gears mean objects and spyglasses mean events. Confirmed pickups use **!**
and known turn-ins use **?**. White markers identify locations shared by quests (a **+** on the world map);
hover for the full quest/objective list and live progress.

The world-map **Hearth & Hustle quests** legend lets you click a quest to focus it,
right-click to hide/show it, or **Show all** to restore the view. This only changes
markers; your route is preserved. Click a marker to guide to its first listed
objective, or right-click to focus that quest. The legend can collapse, and Display
settings control it, contacts, hints and marker density. The default groups nearby
sources into at most 150 world markers; Dense allows 350. The minimap groups nearby
sources into at most 24 small, spaced icons without number badges. These are known locations, not live spawn scans.

New Forever quests can use the provider's existing source data even when their
quest ID is missing: an exact, unique objective item/creature/object name supplies
fallback locations, labeled in the tooltip. Duplicate names and unsupported
objectives remain unavailable. Name indexes build in small batches outside combat
only when needed. This fixes **Skin Careful, Skin Sharp** via Intact Raptor Hide's
known Bloodfen Razormaw/Lashtail sources. It does not infer remote quest availability.
Reload after updating; no new media or companion addon is introduced.

## NPC pickup reporting (v0.17.2)

Map quest listings can omit available NPC quests. The pickup diagnostic now
reports map-listed and recently NPC-confirmed offers separately; zero reported
pickups is not proof that the zone has no available quests. Talking to a quest
giver adds its offered quests to guidance, even with recording off. These
session-only observations use your interaction position, expire after five
minutes, and clear on acceptance, turn-in, or map change. A repeat visit refreshes
the giver's list. Standing nearby alone does not confirm an NPC's offers.

## Review fixes (v0.17.1)

Fully restart WoW after installing this update: the bundled `HearthAndHustle_GearData`
folder is new. It loads only when you open **Best in slot**.

Quest guidance now reads Forever's count-first objectives, retains cross-continent
sources, and avoids routing delivery quests back to their acceptance location.
A saved manual destination is labeled in Navigation; **Resume guidance** returns to
quests while keeping your saved places. **Pause selection** lasts for this login.
Party reports reject malformed numbers. Combat-restricted map/HUD updates wait
until combat ends, and blocked addon actions are retained in Diagnostics.

New profiles start with observation recording and diagnostic probes off. Existing
choices are preserved; enable either in Diagnostics when collecting evidence.
Optional records are bounded, trainer notes retain separate ranks, and repeated
profession events reuse recipe data. Supplies can be shown without changing your
PvP display preference. Gear includes previously missing cloaks, thrown weapons,
attack power, mana regeneration and healing; off-hand weapons require the client's
dual-wield ability. Multi-wing dungeon sources offer an explicit wing selector.

## Gear browser and overview (v0.16.0)

Open Hearth & Hustle from the addon compartment or the compact panel's **Open tools**.
The new **Overview** cards lead directly to quest navigation/event markers, reward
comparisons, quest chains, dungeon preparation and supplies for every class.
All tools remain in the sidebar; no slash commands are required.

**Best in slot** is a gear explorer with 8,370 Forever item references. Choose a
slot, a role preset for your class, a maximum required level and a source category;
search by item name, ID or source. Select a row for its source and equipped stat
comparison; hover for the client tooltip. Save targets to your per-character
wishlist. **Edit stat weights** shows every scoring weight and accepts your own
priorities. Dungeon items link to the checklist; QuestieDB supplies reward quest
links with chain/pickup guidance where known. Multiple quest sources can be cycled.

These are **estimated stat rankings within the filtered catalog**, not simulation
results or a claim of definitive BiS. The reference snapshot runs through November 7, 2026 (some records are older);
the detail pane separately shows current-client stats when loaded. Procs, sets,
hit/crit caps, weapon speed and unmodeled stats are excluded. Class/type filters
are reference rules, not checks of learned weapon skills or every equip restriction.
An item source does not prove current availability. Missing level requirements are
filtered using item level as a clearly labeled estimate when available; the optional unknown filter includes only items with neither level. It never bypasses a known level limit.
Hand comparisons show individual scores without a misleading swap delta. All gear
reads pause in combat. No equipment or reward actions are automated.

Verification is offline/mock and installed-file verification; actual in-game layout,
item tooltips and current equipment API behavior still need a client check.

## What it does (v0.16.0)

- **Hearth & Hustle control window:** click Hearth & Hustle in the addon compartment or **Open tools** on the compact panel. Navigation, Quest rewards, Quest chains, Waypoints, Professions, Party, Supplies & town, PvP, Rare watch, Display, and Diagnostics have buttons, selectors and forms. Action results appear in the window. `/hh` opens it too; slash commands remain optional shortcuts.
- **Compact next-steps panel** (`/hh panel`): the live quest log turned into an ordered list — nearest objective areas and turn-ins first, shared party quests marked with ★, hearth hint when several turn-ins are near your inn. Click a row to send the arrow there.
- **Arrow** (TomTom-style): rotates with your facing, shows distance and a rough ETA, goes green when you're lined up. Right-click cycles waypoints, shift-right-click clears. `/hh arrow flip` if it ever points the wrong way.
- **Map pins**: your waypoints on the world map and a pin on the minimap edge. World-map pins sit below WoW's quest markers. Automatic route pins pass mouse input through so quest-area hover and map clicks work normally; manual pins keep click-to-activate and right-click-to-remove controls.
- **Display settings**: click **Settings** beside **Dungeons** in the next-steps panel. Toggle world-map/minimap pins and arrow visibility, lock the arrow's position, reverse its rotation if needed, adjust its size (40–300%), or reset its position and size. Changes apply immediately and save for all characters; hiding a display keeps the route active. `/hh settings` is an optional shortcut.
- **Auto-next**: automatically rechecks the route every three seconds, including with the panel hidden. Arriving waits while you work nearby; completing the step or moving more than about 100 yards away resumes navigation. Nearby alternatives need a meaningful improvement before the arrow switches. Clicking a quest row keeps that selection until completion/arrival; manual waypoints remain yours. `/hh next` skips the arrived step, `/hh auto off` disables automatic selection, and `/hh auto on` resumes after clearing the route. Quest navigation pauses in battlegrounds.
- **Recorder**: while you play it writes a Forever dataset into SavedVariables — quest givers/enders with positions, offer/turn-in XP per level, objective progress with candidate mob/loot associations, approximate observer sightings, source-attributed observed loot including quest items, vendors, trainers (with skill requirements), flight nodes and edge costs, inn binds, deaths, zone level ranges, XP samples, profession recipes with reagents and difficulty per skill level.
- **Professions**: open your profession window and the next-steps panel shows three skill-up suggestions, bag-material craft counts and missing materials. `/hh prof` gives the longer list. Handles Forever base professions, delayed recipe loading, bag changes and skill-cap reminders. These are material/skill suggestions, not market-price or guaranteed skill-point estimates. Reopen the profession after changing skill to refresh old suggestions.
- **Class supplies:** every class gets food, carried bandages and bag-space checks in **Town tools**, with drinks for mana classes. Add personal stocking targets from carried items or item links/IDs. Mage gems/reagents remain learned-spell gated; shaman reminders make no spec or party assumptions. Optional overlay display uses the existing HUD, and all supply reads pause in combat. `/hh prep` remains a shortcut.
- **Dungeon quest checklist:** click **Dungeons** on the next-steps panel, then choose a dungeon or wing. Shows missing pickups, quests in your log, ready turn-ins, completed quests, listed level requirements and prerequisites. Click a quest for its giver/location and chain details. Updates automatically as you quest; filters to your faction/class by default, with a Show all button. `/hh dungeon [name]` is an optional shortcut.
- **Dungeon rare watch** (`/hh rare`): inside Scarlet Monastery a small HUD answers "is Azshir up?". A rare is recognised the moment anyone in the party targets, mouses over, gets a nameplate for, or has a pet on it (names are secret inside Forever dungeons, so the watch reads the unit's *classification*, which is not). A **Scan** button runs a plain `/targetexact` macro once per click to check what the client has loaded without walking the lair. Sightings and kills are shared with party members running the addon; a raid-warning style alert plus sound fires once per run. Runs are keyed by the instance id carried in loot GUIDs, so the HUD counts runs vs sightings and shows the measured spawn rate. `/hh rare list|add|rm|instance` retarget it at any dungeon rare.
- **Vendor helper** (`/hh vendor`): at a merchant a small strip under the vendor window shows **Sell N grays · value** and **Repair cost** buttons. One click sells one batch of gray items (best value first) or repairs with your own gold; nothing sells or repairs without the click, nothing in combat, and if Forever ever turns on Blizzard's own Sell All Junk button the strip defers to it. Away from a vendor, item tooltips show the vendor value (and the full-stack value); quest reward buttons show each reward's vendor value, the best-value choice in gold. It never picks a reward.
- **Status line** (`/hh bar`): level and xp, xp per hour and time to level (rolling hour, seeded from the recorder so a reload keeps it), gold, free general bag slots, worst durability, hearth, ammo for ammo users, fps and world latency. Drag to move, `/hh bar lock`.
- **Reminders** (`/hh remind`, out of combat only, repeated in chat at most every 10 minutes): low or broken durability, low ammo, bags nearly full, a self-buff you know but do not have (Shaman Lightning Shield, Mage Arcane Intellect and Frost/Ice Armor, Hunter Aspect), a Shaman weapon with no imbue. Buff reads go through Blizzard's secret predicate; in combat the reminder row hides instead of guessing.
- **Trainer notes** (`/hh trainer`): at a class or profession trainer, what you can learn now, the total cost against your gold and the next level that unlocks something. On a level-up, which recorded trainer teaches something at the new level and what it costs. `/hh trainer 28` asks about a level.
- **Party seed**: `/hh partyexport` → paste string for a friend, `/hh partyimport <string>` here; when both run the addon, quest state syncs over addon messages automatically.

## All-class preparation and sound cleanup (v0.15.0)

The shared navigation, dungeon, reward comparison, profession, vendor, trainer and party tools work for every class. The former Mage preparation module is now **Class supplies**, available to all nine Forever classes and with a generic fallback for unknown classes.

Open **Hearth & Hustle → Town tools** to see carried stock without enabling the PvP HUD. Default per-character targets are 20 food, 40 drinks for mana classes, and 10 bandages. Warriors and rogues do not receive drink reminders; druids retain their mana supplies across forms. Mage gems and reagent suggestions remain mage-only. The existing automatic buff reminder list is still limited to supported mage/shaman/hunter buffs; the common repair, bag-space and applicable ammo reminders work across classes. This update adds no combat rotations or spec advice.

Under **Personal supplies**, choose an item from your bags, or enter its item link/ID, and save a target. Track up to 20 items per character with targets of 1–200; use 0 or **Stop tracking selected item** to remove one. This supports whatever supplies you choose, including class reagents, poisons and pet food. Existing targets survive upgrades and stay separate between characters. Inventory and item-cache failures show unavailable counts, never a guessed shortage. Food/drink category counts use localized item effects and level requirements; combined effects with different names can be tracked as individual items instead.

The custom hunter action sounds, all ten bundled sound files, the playback module, and its settings/UI are removed. Old `/hh audio` commands only report that the feature was removed. Normal configurable rare-alert sounds remain. `/reload` loads the update; current tests cover all nine classes, but in-game layout and item classification still need verification.

## Dungeon routing (v0.14.0)

Open **Dungeons**, choose a dungeon or wing, then **Guide entrance**. Where several approaches are authored, the nearest measurable entrance is selected initially; **Other entrance** cycles the choices. Coordinates remain visible when distance cannot be measured. The optional QuestieDB Forever provider supplies entrances for **30 of the 35 checklist entries**; the other five explicitly show unavailable coordinates. Shared Scarlet Monastery and Blackrock Mountain approaches are labeled as such.

Select a quest to **Guide pickup**, **Guide objective**, or **Guide turn-in**, according to its live state. **View quest chain** opens prerequisite details. Blocked/unknown/completed entries do not offer a pickup route. A known pickup is not a guarantee that the giver will offer the quest. The nearest known quest ender supplements live and recorded turn-in directions when available on your continent.

Dungeon quest sources that only identify an instance now produce labeled outdoor entrance markers, including supported event objectives. Native quest directions still win. Entrance arrows clear on instance entry, and arriving at an entrance never marks a quest complete. This provides entrance and quest preparation guidance; **interior paths, boss order, terrain-aware travel, keys and unlock requirements are not planned**. Follow the quest instructions and use the checklist during the run.

No new dependency or media; `/reload` loads this update. Packaged-provider and mock checks are separate from in-game validation; entrance placement and window rendering still need client confirmation.

## Event objectives and quest hints (v0.13.0)

Supported exploration, conversation and escort-completion areas now appear automatically alongside ordinary quest sources on the world map and nearby minimap. Click a marker to guide there; matched markers clear as the live objective finishes. An escort marker describes its completion area, not the route to walk or the location of a moving NPC. The arrow uses the known area only when existing native/recorded guidance has no location.

Shared quest-credit objectives can show all their known target species, including tasks such as Kodo Roundup. Follow the quest's instructions for the required action; these targets are not necessarily things to kill.

Provider notes such as **Use the cannon**, **Use a Fresh Carcass at the Flame of Uzel**, and **Lure the Kodos to Smeed Scrabblescrew** appear as clearly labeled **quest hints**. They have no individual progress tracking, remain until the quest is complete, and only become a destination when clicked. Hide them in **Display → Show quest hints** while keeping tracked objective pins visible. Navigation reports tracked event/credit objectives and hints separately.

Uses the existing QuestieDB Forever provider. Ambiguous matches, missing locations, unsupported spell objectives, and dungeon placeholders without authored entrances stay unmapped. No new dependency or media; `/reload` loads this update. Source, mock and packaged-provider checks pass; in-game rendering and locations still need verification.

## Quest reward comparisons (v0.12.0)

Open **Hearth & Hustle → Quest rewards**, or click **Compare rewards** beneath a quest offer/turn-in. The page follows either the quest selected in Blizzard's quest log or the open quest dialog; the two buttons choose the source. It never selects or claims a reward.

- Choice items and guaranteed items are listed separately, with stack vendor value, quest money and XP. Highest vendor value includes ties and appears only when all choice prices are known.
- Select a reward to see numeric stats alongside equipped gear, with gains and losses. Rings/trinkets show each slot; two-handed weapons compare against both equipped hands together. Hover a reward for its full tooltip.
- Equipment changes and arriving item data refresh the open page. Missing data stays unavailable, and comparisons pause in combat. Weapon effects, enchants, set bonuses and procs are not fully represented by numeric stats; there is no automatic upgrade score.

This version is source-checked and mock-tested; client layout, tooltips and reward reads await in-game verification. Dungeon routing remains the next roadmap item.

## Quest chains and prerequisites (v0.11.0)

Open **Hearth & Hustle → Quest chains**, or select a quest in Navigation and click **View quest chain**. The browser starts with your quest log; typing a name or quest ID searches QuestieDB's reference catalog too. Same-name quest stages retain their IDs. **Current quest** opens the quest selected in Blizzard's log.

Inspect a quest to see its completed/in-log/ready status, minimum level, **ANY ONE** versus **ALL** prerequisite groups, active-parent requirements, optional lead-ins, alternative branches, cutoff conditions, known pickup sources, and follow-ups. Click a linked row and **Inspect linked quest** to move through the chain; **Previous quest** retraces your steps and **Back to search** preserves your query. Long chains are shortened in the list; inspect a linked quest to continue. **Guide to pickup** explicitly sets a waypoint to a known pickup location; accepting/completing that quest clears the pickup waypoint.

Ordinary quest progress updates the view automatically. Browsing never changes your route or accepts quests. The first database search builds incrementally when you open the page, keeping spawn decoding out of the search path. QuestieDB Forever is the same optional data dependency used by source maps. Missing records, unknown completion reads, and contradictory prerequisites remain visible gaps. Character class/race/profession/reputation/event restrictions are flagged where listed; this is a chain browser, not a full eligibility engine. Only a live map offer is labeled as offered; satisfying reference prerequisites does not guarantee availability.

## Quest source maps (v0.10.0)

Hearth & Hustle can now show **known creature and object locations for unfinished quest objectives** on the world map and nearby sources on the minimap, including item drops, container sources, and vendors. Hover a small orange marker for the quest, progress, and source; click it to guide there. Completed objectives disappear automatically. Display settings let you hide either layer or show only the client-selected quest. Navigation shows coverage and database status.

This feature reads the standalone [QuestieDB Forever addon](https://github.com/Questie/QuestieDB/releases/tag/v1.0.13), version 1.0.13 tested. **Questie's interface is not required.** Install its `QuestieDB` folder beside `HearthAndHustle`, restart WoW, and enable both. On this development machine, `python3 tools/install-questiedb.py` installs the checksum-pinned, unmodified data addon and preserves any different existing installation. Hearth & Hustle's other tools continue working without it; source locations will report that the database is missing.

These are possible spawn/source locations, not live tracking of stealthed enemies or guaranteed drops. Objective text is matched to the live quest log rather than assuming database row order. Unmatched text, unsupported event/kill-credit/spell objectives, and dungeon floors without usable entrance data stay unmapped. Outdoor markers are grouped for readability (350 world-map / 40 nearby minimap frames); the nearest-source fallback uses the full matched point list. Live Blizzard directions and recorded areas remain preferred for automatic guidance. QuestieDB's Forever data includes converted coordinates and corrections, but does not cover every new quest.

## Using the control window (v0.9.0)

Open Hearth & Hustle from the addon compartment, or click **Open tools** on the compact quest panel. Choose a section on the left. The compact overlay continues to guide you while the main window is closed.

- **Navigation:** search/select a quest destination, resume or pause automatic selection, defer a crowded quest, or find pickups. Pause keeps the current destination; Clear route removes waypoints and pauses guidance.
- **Waypoints:** select destinations by name, activate/remove them, save your current position, or enter percentage coordinates with an optional map ID.
- **Professions:** open your profession once, select a learned recipe by name, enter a batch size, and view needed materials. This does not craft items.
- **Party:** compare quest progress, explicitly send your snapshot, or copy/paste a snapshot without typing a command.
- **Supplies & town:** set stocking targets, manage vendor values and reminders, and look up recorded trainer notes. Selling/repairing stays on the merchant window with its existing click buttons.
- **PvP / Rare watch:** HUD controls, flag-slot tracking, reports, watched-instance/rare editing and run history. Scan remains a separate click on the existing secure rare HUD; opening tools never targets anything.
- **Display:** map pins, arrow, compact panel, and status line controls. The main window saves its dragged position and scales down to fit smaller screens.
- **Diagnostics:** status, API checks, self-test, recording and errors. Data resets have a separate confirmation that is canceled when you leave the section or close the window.

Long sections and results scroll separately. Lists are paginated, typed drafts survive refreshes, and browsing does not change your preferences or route. The Dungeon quests button opens the existing checklist; **All tools** returns to the control window. The smaller display-settings dialog remains available from the compact panel.

Validated with source checks and the mock harness; actual client layout, scrolling and mouse behavior still require in-game verification. Run `/reload` to load the update.

## Vendor, status line, reminders, trainer notes (v0.8.0)

A survey of the most-installed World of Warcraft: Forever addons on CurseForge (ForeverPlus, ForeverForge, ForeverUI, Leatrix Plus, Questie, Vendor Price, What's Training?) found the features people install first: sell grays, repair, vendor value on tooltips and quest rewards, an info bar with xp/h, buff and consumable reminders, trainer awareness. v0.8.0 adds the information side of all of that and keeps every action behind a player click. There is no auto-accept, auto-turn-in, auto-loot or auto-buy here and there will not be: the addon shows, you play.

Mock-tested only on release; in-game verification pending: the merchant strip's anchor under Forever's Mainline-derived `MerchantFrame`, whether `C_UnitAuras.GetPlayerAuraBySpellID` returns your own buffs out of combat on Forever (the predicate `C_Secrets.ShouldAurasBeSecret` gates the read), the Classic-era spell ids used for the buff/imbue tables, `GetInventoryItemDurability` and `GetRepairAllCost` shapes, and the tooltip hook (`TooltipDataProcessor.AddTooltipPostCall`, present in Forever's UI source). `/hh vendor` and `/hh bar` print which hooks the client accepted.

## Dungeon quest preparation (v0.7.0)

Open the normal Hearth & Hustle panel from the addon compartment, then click **Dungeons**. Select a dungeon on the left; use the page buttons for more dungeons or quests. Click a quest on the right and scroll its details for pickup locations, prerequisite chains, item starts and follow-ups. The last dungeon and faction/class filter are saved per character. Browsing leaves your active navigation alone.

The bundled reference contains **455 quest records**, including prerequisite/return steps, with populated lists for **30 dungeon/wing entries**. Five additional dungeon entries explicitly show **coverage missing**. It is adapted from the MIT-licensed [DungeonQuestTracker catalog](https://github.com/jturnham/DungeonQuestTracker/tree/b4ae5a478d0f96c842c13d5ad96bb4adb11f15df/DungeonQuestTrackerForever/Data); attribution ships inside the addon. Classic-derived entries and conflicting reports remain marked. This is not a guarantee of every current Forever quest, nor proof that all listed quests can be accepted together. “Missing: check pickup” means absent from your log/completion flags, not confirmed eligible. Only a live current-map offer says “Available on this map.” Unknown API results stay unknown; accepting a quest overrides older reference restrictions. Prerequisites distinguish mandatory steps, optional breadcrumbs, alternative branches and steps that must remain in your log. Profession, reputation and unrecorded restrictions must still be checked at the giver.

The checklist is mock-tested; actual in-game layout and quest eligibility need client confirmation. Its completion reads use character flags, not account-wide progress. No automatic quest acceptance, sharing, targeting, travel or turn-ins.

## Launch questing tools

- **Nearby clusters:** routes modestly favor objectives within about 200 yards of other distinct quests. This uses straight-line distance, so caves, cliffs and travel connections still need player judgment. Quests more than three levels above you receive a bounded priority penalty; their level and suggested group size appear in the UI. Turn-ins are not penalized for level.
- **Crowded objective:** `/hh skip` defers the current quest for 10 minutes; `/hh skip 5` changes that. All its objectives are deferred together. `/hh skip clear` restores them, and clicking a deferred row resumes it immediately. Deferrals last only this login session. Manual waypoints are preserved.
- **Duo quest check:** `/hh duo` compares your log with your partner's latest addon snapshot: quests only one of you has, who still needs to finish, and turn-ins ready for both. ★ marks shared quests. Partner snapshots can be stale; the report shows their age. Both players need the addon for automatic sync.
- **Current directions first:** live client waypoints/POIs now override recorded beta turn-in positions. Recorded locations remain a fallback. The planner includes available pickups reported by the current client map. It does not contain a complete prewritten 1–60 route or terrain pathfinder.
- **Profession shopping:** open your learned crafting profession, then `/hh prof` for recipe IDs. `/hh prof plan <recipeID> <crafts>` displays a bag-aware materials checklist in the main panel; `/hh prof plan clear` clears it. The target is a fixed number of future crafts for this session: update it after crafting. It does not buy/craft anything or infer skill points. Unavailable counts stay unknown. Skinning is shown in the profession summary; it has no crafting recipe list. Switching to Engineering uses that character's learned recipes once opened.

Quest guidance (v0.6.2) starts automatically at login. The arrow follows the quest selected in the game's tracker when coordinates exist, otherwise it picks a nearby objective, turn-in or client-reported available pickup. It stays visible on arrival, advances when the objective is finished or quest is accepted/turned in, and runs independently of the panel. Missing coordinates produce a visible explanation instead of a blank area. Every few seconds it reconciles display state; deliberate hide/stop settings remain respected. Commands are optional overrides. Pickup eligibility comes from live client offers, not historical NPC sightings.

Release evidence: 70790 SavedVariables contain readable quest POIs, player position/facing and zero stored addon errors, but the user reports a blank arrow area on v0.6.0. v0.6.2 is mock-tested; its visual behavior and pickup coverage still need client confirmation. Reload the UI once after updating, then play normally. Diagnostics refresh automatically on addon-version changes, and the latest navigation/display snapshot updates every 30 seconds; ordinary logout or UI reload saves them to disk. `tools/pull-data.sh` reads the release client's WTF folder; it does not import beta data.

## PvP module

Built around what Forever's secret-value rules leave readable (Blizzard's own predicate docs, see `docs/SPEC.md` §8): your own casts, enemy *player* identity, battleground objective data, and what a party member chooses to broadcast. Nothing here reads enemy casts or auras, because on Forever it cannot.

- **Timers** (`PvP/CastTimers.lua`): every control/interrupt/root you cast starts a bar with the target's name, a duration parsed from the spell's tooltip, and a diminishing-returns estimate per target (full → ½ → ¼ → immune, 15 s reset). Every timer is explicitly labeled `est.`: resists, successful interrupts and early breaks are unconfirmed. Cast-target identity is captured when the spell is sent; switching targets afterwards cannot change the DR attribution. Frost Nova is an area-cast estimate, without an invented single target or DR chain. Tooltip durations and the existing DR model are not verified PvP-duration measurements.
- **Enemies seen** (`PvP/Roster.lua`): class, race, level, last seen, what you used on them; in a battleground the scoreboard adds the enemy team composition.
- **Battleground** (`PvP/Battleground.lua`): base states with capture timers, flag carriers described relative to the nearest objective, `/hh pvp track` follows a single visible flag. With two flags, select `/hh pvp track 1` or `2`; `/hh pvp track off` stops. Faction is unverified: numbers identify API positions, not ally/enemy identity, and should be checked against the map. Map position may be unavailable in instances. Records raw objective/flag data so a real match can establish the exact icon meanings.
- **Coordination** (`PvP/Coordination.lua`): your CC timers are sent to party members running Hearth & Hustle and shown on their HUD with a "window" flag before expiry. Blizzard locks addon messages inside battlegrounds and arenas; this works in world PvP and duels. Incoming timers must come from a current party member and have a valid, bounded duration.
- `/hh pvp` toggles the HUD; `/hh pvp status`, `track`, `spells`, `lock`, `reset`, `scale n`, `on|off`.

## Dungeon rare watch (v0.5.0)

Built for farming Azshir the Sleepless in the Scarlet Monastery Graveyard with a friend. What the Forever client allows (probe evidence from build 70291, see `docs/SPEC.md` §12): inside a dungeon the **Map** restriction is active even out of combat, so NPC names and GUIDs are secret and cannot be compared. `UnitClassification` (`rare` / `rareelite`), level, reaction and creature type are not gated and read normally, and loot-source GUIDs are never secret. The watch is built on exactly those reads.

- **Detection**: target, mouseover, focus, nameplates (turn enemy nameplates on), your pet's target and every party member's and party pet's target. Any hostile `rare`/`rareelite` inside the watched instance is a sighting. Outside dungeons names are readable and the watch list names are matched too.
- **Scan button**: a `SecureActionButtonTemplate` whose macro is `/targetexact Azshir the Sleepless` (one line per watched rare). It is the same thing as a player macro: one click, one targeting attempt, nothing automatic. It only finds a unit the client has already loaded, so press it while walking toward the lair; `/hh rare scan` prints the macro if you prefer your own keybind. How far it reaches inside the Graveyard is unverified: the HUD counts hits and misses per run so you learn it.
- **Identity**: which of the three rares it was becomes certain when it is looted (loot-source GUID carries the creature id). Until then the HUD shows "RARE UP (lvl 33 Undead)" and, where the client permits, the name as a display-only value.
- **Runs**: entering the instance opens a run; the first loot window keys it by the instance's zoneUID; a different zoneUID means the group reset while you were out; "has been reset" closes it; re-entering the same instance folds into the same run; runs idle for 2 h are over. `Not up` marks a run checked-and-empty; `/hh rare runs` lists the last ten. The stats line is sightings over checked runs against the ~5 % folk estimate.
- **Party share**: `RW;up`, `RW;no`, `RW;kill` addon messages, accepted only from current party members. Addon chat works in dungeons outside boss encounters.
- `/hh rare` status · `scan` · `notup` · `newrun` · `runs` · `list` · `add [id] <name>` · `rm <name>` · `instance <name>` · `show|hide|auto` · `on|off` · `share on|off` · `sound on|off` · `lock|unlock|reset|scale n` · `clear confirm`.

In-game verification pending (mock-tested only): that `UnitClassification` really stays readable in the Graveyard where names are secret (`/hh apicheck` → `probe:targetClassification` with a mob targeted), the reach of `/targetexact` inside the instance, whether `FontString:SetText` accepts a secret name, whether Forever flags vanilla rares with minimap vignettes (`probe:vignettes`, recorded under `HearthAndHustleDB.rare.vignettes`), and the vanilla creature ids 6490/6489/6488 (confirmed by the first loot window). Report with `tools/pull-data.sh`.

## Install (WoW Forever release)

1. Download **[HearthAndHustle.zip](https://github.com/ForWakanda/foreverpath/releases/latest/download/HearthAndHustle.zip)** (latest release).
2. Open your WoW folder, usually `D:\World of Warcraft\_forever_\Interface\AddOns\`. If `AddOns` does not exist yet, create it.
3. Extract the zip there. You should end up with `...\AddOns\HearthAndHustle\HearthAndHustle.toc` (a `HearthAndHustle` folder directly inside `AddOns`, not a folder inside a folder).
4. Start the game. If it was already running, close it completely and start it again (the client only picks up new addon files at startup). On the character screen, click **AddOns** and make sure Hearth & Hustle is ticked.
5. In game, open Hearth & Hustle from the addon compartment, or type `/hh` for the control window. `/hh panel` toggles the compact quest overlay; `/hh help` lists optional shortcuts.

**Updating:** delete the old `HearthAndHustle` folder, extract the new zip, restart the client. Your settings and recorded data live in `WTF\` and survive updates.

**Developers on WSL:** `tools/deploy.sh` runs the checks and copies the addon into the release folder directly. Set `WOW_CLIENT` for a different client root or `WOW_ADDONS` for an explicit AddOns directory. The default is `/mnt/d/World of Warcraft/_forever_`.

## Commands

`/hh help` prints them. `/way 45.4 70.4` points to those coordinates in your current zone; add an optional title, e.g. `/way 45.4 70.4 Quest cave`. `/way` is a shortcut for `/hh way`, including `here`, `list`, `next`, `clear`, and `rm <id>`. Waypoint coordinates always use percentages (0–100); three numeric arguments mean map ID, x%, y% (e.g. `/way 1413 45.4 70.4`). If another addon owns `/way`, use `/hh way` explicitly. Short version: `/hh` panel · `/hh vendor` · `/hh bar` · `/hh remind` · `/hh trainer` · `/hh next` · `/hh goto <quest>` · `/way x y [title]` · `/hh way here` · `/hh arrow lock|flip|scale n|reset` · `/hh prof` · `/hh rare` · `/hh status` · `/hh apicheck` · `/hh selftest` · `/hh record on|off`.

## Getting the data out

```
tools/pull-data.sh       # copies WTF/.../SavedVariables/HearthAndHustle.lua into data/ and prints counts + stored errors
```
Log out or `/reload` first so the client flushes SavedVariables.

## Development

- `HearthAndHustle/` is the addon; `API/Adapter.lua` owns game-data reads and API probes; Core/UI own frame creation, event registration, timers, and rendering. APIs are feature-detected so a renamed function on the next build degrades one feature instead of breaking the addon.
- `tools/check.sh` validates Lua/XML/TOC, runs the mock play-through and the pure self-tests, then `tests/regressions.py`. The same check runs in GitHub Actions on every push and pull request. Needs Lua 5.1 (`apt-get install lua5.1`, or set `LUA`/`LUAC`) and Python 3.
- APIs were verified against Blizzard's Forever UI source (`Gethe/wow-ui-source`, branch `forever`, same build) — see `docs/SPEC.md`. Forever runs the modern (12.x) addon API with Midnight's secret-value restrictions; Classic-era assumptions are usually wrong here.
- Lua 5.1 only: no `goto`, no `//`, no `\z`. WoW's global `atan2`/`sin`/`cos` use degrees; use `math.*`.
- Working with an AI coding assistant? `CLAUDE.md` holds the rules it should follow (no automation, secret-value guards, adapter-only API access, the check gate).

### Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Branch, make one change per commit, run `tools/check.sh`, open a pull request; `main` is protected and merges only with the CI check green. Say in the PR whether the change was verified in game or only against the mock; nothing here can run the client. Releases are tagged `vX.Y.Z`; the tag builds `HearthAndHustle.zip` automatically.

## Recorder evidence

Loot totals mean **items observed on a loot source**, not items picked up or unbiased drop rates. Reopening and partial looting use a per-source maximum, persisted across reloads; the deduplication cache retains up to 2,048 source GUIDs for 24 hours. A missing/malformed source stays an unknown observation with an optional target candidate, never a confirmed drop from the selected target.

Kill/loot timing alone is not enough to identify a quest objective. Such associations stay in the bounded progress tape as candidates; the planner can use observed progress areas but does not promote those candidates to confirmed mob locations. Sightings record the observer's position and are explicitly approximate.

`/hh record off` stops dataset collection, including pending callbacks and profession recording. Navigation, current profession recommendations, party seed/settings, bind navigation state, and error/API diagnostics continue. Turning recording back on starts a fresh objective baseline.

The v2 SavedVariables migration preserves older biased loot totals and objective identity guesses under `legacy*V1` fields, separate from corrected observations. The original review and failing results remain archived under `docs/reviews/2026-09-30/`; current verification is `tools/check.sh`.

## License

MIT; see [LICENSE](LICENSE). Free, unobfuscated, no ads or donation prompts.

## v0.3.0 verification

Checked against the Forever 70205 UI source; 18 self-tests, mock play-through and 62 regression checks pass. A copy of existing account/character SavedVariables also initializes cleanly in the mock. **The new behavior still needs in-game verification.** After installing, `/reload`, walk between quest areas, then open each profession. `/hh apicheck` with a profession open records which profession lookup worked. See [the review](docs/reviews/2026-10-04/REVIEW.md) for findings and the first battleground check.

## Original Mage preparation (v0.4.0; expanded in v0.15.0)

After `/reload`, use `/hh prep` for a report or `/hh prep show` to keep the checklist visible outside combat. `/hh prep auto` restores contextual display; `hide` hides its HUD section, and `off` disables its scans. It respects `/hh pvp hide|off`; use `/hh pvp on` and `/hh pvp auto` to re-enable the containing HUD. That release activated only for mages; v0.15.0 expands the checklist to every class, including a separate Town tools view.

Default per-character stocking targets: **40 drinks, 10 carried bandages, 5 of each relevant reagent**, and one of each known mana gem. Change them with `/hh prep water 60`, `/hh prep bandages 20`, or `/hh prep reagents 10`; targets accept 0–200 and zero hides that category. These are convenience targets, not required quantities. Gems/reagents appear only when the relevant supported spell is learned.

Counts include equipped bags only, including the reagent bag when the client exposes it. Drinks match the client's localized Drink item effect and must meet the character's level; food, potions and higher-level drinks are excluded. Combined food/drink items with a different effect name are not included. Bandages are **carried stock**, not a claim about First Aid requirements or debuffs. No cooldown/aura checks, purchase, cast or item use occurs. Missing data is retried briefly and on item-cache events; `/hh apicheck` includes `probe:magePrep` for diagnosis.

Validation: 72 regressions, 18 self-tests and the mock play-through. Actual bag classification, learned-spell lookups, layout and visibility still need the client. No battleground maps were present in the latest saved data, so faction-specific flag/base alerts remain pending real match evidence.
