# Hearth & Hustle

Quest GPS, route planner and data recorder for **World of Warcraft: Forever** (release build 1.60.1.70862, interface 16001).

It shows you where to go. You play. Nothing in here moves your character, targets, casts, loots or turns anything in — that is the line Blizzard draws and the line this addon stays behind.

## Dungeon quests: what to pick up now, and where (v0.32.0)

`/hh` → **Dungeon preparation**, or `/hh dungeon scholomance`.

- **One dungeon is chosen on the page.** Click a dungeon under *Which dungeon next* and the itinerary below is that dungeon's, and both checklist buttons open that dungeon. Click one in the itinerary's list and the mark in the ranking moves with it. The two lists can no longer name different dungeons.
- **A quest you already have is never a pickup.** The quest database lists some quests under two numbers (an older and a newer version, or one version per dungeon) and marks them exclusive to each other. The bundled dungeon list knows one number; the game may give you the other. The list now recognises the quest in your log or finished under either: `In your log`, with its turn-in, and the details say which number you hold. Where each dungeon has its own version (the Lord Valthalak's Amulet pieces), holding one closes the others and says which: `Because you have the Dire Maul: North version of this quest`.
- **The list leads with what to do now.** Gold lines are things a giver will hand over today, nearest first, each with the giver, the zone, the coordinates and how far it is (`Eva Sarkhoff — Western Plaguelands 70.2, 73.7 · 3.11k yd`, or `other continent`):
  - `Pick up now`: the dungeon's quests open to you. One that leads to others says so (`leads to Krastinov's Bag of Horrors +2`).
  - `Start a chain`: the first quest of a chain a dungeon quest sits behind, listed once however many quests wait behind it, with how long the chain is (`7 quests to Dawn's Gambit +1`). If that step is in your log it reads `Finish first`.
  - Green lines are in your log, with where to turn them in.
  - Grey lines come later: `Later: 2 quests first`, with the next step and where it starts.
- The line above the list counts the same: `Now: 2 to pick up · 3 chains to start · 2 in your log.  Later: 9 behind a quest chain.` The window shows seven lines a page, so "now" usually fits on the first.

What it is not: a live offer list. Givers, places and chains are the quest database's (Classic data with Forever corrections); a chain's first quest can have a requirement the database does not record. Distances are straight lines from where you stand.

## Gear the item reference does not have, and which quest reward to take (v0.31.0)

`/hh` → **Best in slot** used to list only what its bundled item reference had. That reference is a snapshot of the items one website had a Forever tooltip for: about a fifth of all quest rewards are not in it, and neither are most of the dungeon drops the quest database lists. If your reward was one of those, the page did not show it, and nothing said why.

- **Your quest rewards are listed.** Every reward and reward choice of a quest in your log is on the page, in its slot, ranked with everything else. The row says `Your quest: <name>`.
- **So is what the quest database knows.** Weapons and armor the installed QuestieDB names a source for (a quest, a creature, a chest, a vendor) are added, with that source. A boss inside a dungeon makes it that dungeon's drop.
- **The numbers are your client's.** The addon ships no stats for these items. It asks your game client what each one is, a few at a time, out of combat, the first time you open the page. An item your client does not know is not listed. The line above the list says how many rows were read this way and whether it is still reading.
- **Search looks in every slot.** Type a name and the list shows the matches in the slot you are on; the line above it says where the rest are (`same search in other slots: Hands 1`). A search also reaches items the database knows by name only, with no source.
- **At level 60 nothing is hidden for "no required level".** Quest rewards rarely list one, and the page used their item level as a stand-in: at 60 that hid 247 items above item level 60, 172 of them quest rewards. Nothing can ask for more than the level cap, so at 60 they are all listed.
- **Rewards page: which one to take.** Select the quest in your quest log, open `/hh` → Rewards (or press **Compare rewards** on the quest dialog). For each of your class's roles, your own first: every equippable reward with its score, its place among everything you could wear in that slot (`#4 of 212 head for level 60`), and what it adds over the best piece you carry, worn or in your bags. With two or more choices it names the bigger gain for that role. You still pick the reward yourself.

What it is not: a simulation. Scores are the page's stat weights; procs, set bonuses, hit, crit and "Equip:" lines are not in them. Where an added item comes from is the quest database's word, which is Classic data with Forever corrections. The dungeon pages still rank drops from the bundled reference only.

## Gear finder (v0.26.0)

`/hh` → **Best in slot**. The page now says what it is showing, and you can ask it for exactly the thing you are after: "the best two-hander for my second spec".

- **Ranked for** walks your class's roles (a Shaman: Strength melee, Spell damage, Healing) and only changes what this page shows. Your own role, the one the Healing page and the dungeon drop lists follow, stays put until you press **Make … my role**. A healer can look up melee weapons without switching the healer check off.
- **Hands** (main hand): any, two-hand only, one-hand only. **Type**: the weapon or armour types on offer for the slot (Axe, Mace, Staff …). **Sort** (weapons): best score, weapon DPS, or biggest hits (average damage per swing, what a slow weapon is picked for).
- **Source** offers only kinds the reference really has, and the creature-drop kind is called what it is: **World / raid drop** (every drop with no dungeon listed, raid bosses included). A row names the creature when the reference does (`Drop: C'Thun`).
- Every row carries the facts: `2. Taran Icebreaker · 2H Mace · 49.7 dps · speed 3.80 · L47 · Drop`, tinted by item quality. The line above the list states the whole filter (`302 items · Main hand · two-hand only · up to level 60 · any source · ranked for Strength melee · best score first`).
- Items that belong to the other faction (a reputation they ask for, or an honor-rank name such as *Grand Marshal's*) are left out and counted in that line; one tick shows them again.
- The selected item, directly under the list: damage range and speed, quality and binding, what it asks for, where it comes from, what is not in the score (hit, crit, procs), and for a two-hander the change against **both** hands you wear.

Rankings are still estimates from editable stat weights over a dated reference, not a simulation; weapon speed, hit, crit and procs are shown, not scored.

## Healer tools (v0.25.0)

For Shaman, Priest, Druid and Paladin. `/hh` → **Healing**, or `/hh heal`.

- **Heal ranks.** Every healing rank you know with its mana, cast time and the amount from its own tooltip, and what that is per mana and per second. With bonus healing from gear it adds an estimate by the Classic rule (cast time ÷ 3.5), marked "est."; that rule is not confirmed on Forever. `*` marks the most healing per mana. Select a rank for a one-line mouseover macro to copy; the addon never creates or runs a macro.
- **Between-pull check.** Out of combat, in a five-player party, with your gear role set to Healing: who is dead, offline, out of heal range or still fighting, plus your drinks, your Ankh (Shaman), your weapon imbue, and whether you are in the spec you marked as your healing spec. It shows on the HUD and on the Healing page; inside a dungeon it also says when everyone is ready.
- **What it cannot do.** Forever hides health, mana, debuffs, threat and cooldowns from addons. Nothing here warns about them and nothing runs in combat. The game's own raid-style party frames and click casting cover that part.

## Where a quest target walks (v0.30.0)

Some quest targets never stand still: a named creature on patrol, or one that wanders a hillside. The world map now shows where they move, in the quest's own colour.

- **A line** is the route the creature walks, as QuestieDB stores it (Old Murk-Eye along the Westfall coast, Mor'Ladim around Raven Hill, the Defias Messenger on his road). It can be anywhere along the line. The arrow leads to the nearest stretch of the route, not to a spawn point on the far side of it.
- **An outline** is drawn when the quest needs one thing from one creature and the database has many places for it close together, with no route (Zarrat Wormwing for *Spear of the Skylord* on Mount Hyjal). It marks the area those places cover. It is not a path: the database does not say in which order the creature visits them.
- The marker nearest to you carries the name: `Old Murk-Eye: walks the line` or `Zarrat Wormwing: roams this area`. The tooltip and the arrow say the same.
- Ordinary targets are unchanged: "kill 10" of something common gets its markers and no outline.

**Display → Draw the route a quest target walks, or the area it roams** switches it off. This is reference data, not a live scan: nothing here sees the creature, and a stealthed one stays stealthed.

Routes and many newer quests need a current **QuestieDB**: this release is tested with 1.1.4 (and 1.1.3), and 1.0.13 does not know *Spear of the Skylord* at all. `python3 tools/install-questiedb.py --update --backup <folder>` replaces an older copy with the game closed and keeps the old folder.

## Dungeon quests: where each one starts (v0.29.0)

The dungeon checklist (`/hh dungeon [name]`) and the itinerary now answer "what do I pick up before I go" without a web search. Each quest says where it starts, from the installed QuestieDB (Forever):

- **Pick up** — the giver and the place: `Yeh'kinya — Tanaris 67.0, 22.4`. These lead the list.
- **Chain: N quests first** — the quest is behind earlier quests. The line names the next one you have not done and where it starts; the details list the whole chain in order. **Guide next step** leads to that quest, not to a giver who would refuse.
- **Drops inside** / **Pick up inside** — it starts from an item a creature in the dungeon drops (named, with its level), or from a giver inside. Nothing to fetch beforehand.
- **Starts from an item** — an item that drops outside the dungeon, with what drops it and where.
- **Needs level N**, **No longer offered** (a later step is already done), and quests for another class or faction (hidden until **Show all**).

Click a quest for how to get it, what it asks, where to turn it in, the chain before it and what it leads to. Without QuestieDB the bundled list is used and says so. This is where a quest starts in the reference, not proof that it is offered to you now.

## Which dungeon next (v0.28.0)

`/hh` → **Dungeons** (top of the page), or `/hh dungeon next`. The dungeons around your
level, ranked by what their drops would add to your gear: for your own role and, if
you have one, a second spec (**Second spec** button; until you choose, it is the role
you last looked up on the gear page).

- Each role is compared with **the best you carry for it**, worn or in your bags, so a
  second spec is measured against its own gear. The bank is not seen.
- One drop per slot counts (two for rings and trinkets); a two-hander is weighed
  against a main hand and off hand together. The row shows the gain as a share of
  that role's whole set; the details name the drops, their bosses and what each adds.
- **Show its itinerary below** opens the run for the selected dungeon.
- Limits it tells you about: the item reference names a dungeon, not a wing, so
  Scarlet Monastery, Stratholme, Blackrock Spire and Dire Maul are one row each; the
  dungeons new on Forever have no drops in the reference and are listed as not
  ranked. Estimates from your stat weights; a listed drop is not proof it exists on
  Forever.

## Dungeon itinerary (v0.25.0)

`/hh` → **Dungeons**, or `/hh dungeon plan [name]`. Choose a dungeon and get the run as a list:

- **Turn in first**, then **Before you enter**: every quest you can pick up, grouped by zone, nearest zone first, with the zeppelin or ship where one is needed, ending at the entrance.
- **Inside**: quests already in your log, givers that stand inside, quests that start from a drop (with what drops it).
- **Behind a quest chain** (v0.29.0): quests that need earlier quests, each with the first one still to do; the button guides to that step.
- **Not available yet**: quests behind a level, so you do not ride out for them.
- **Drops for your role**: items from this dungeon that score higher than what you wear, for the role chosen on Best in slot. **Save drop to wishlist** keeps one on the list.

Select a step and click **Guide to selected step**; nothing changes until you do. The quest list is a community reference, distances are straight lines, and interior paths are not mapped. The full checklist with every quest is one button away.

## Guidance explanations (v0.23.0)

The compact quest panel shows why guidance chose its destination: your selected
quest, an explicitly chosen step, an automatic quest choice, a manual destination,
or waiting in the objective area. Click that explanation for details in
**Navigation**. **Resume guide** returns to automatic selection while keeping saved
manual destinations available under Waypoints. Automatic choices use straight-line
distance and quest priorities; they do not account for terrain or optimize XP/hour.

## Enemy browser (v0.23.0)

Open **Tools → PvP** (or **Overview → Enemy watch**) to search nearby and recent
players by full name. Select a row, then **Add selected to KOS**, **Ignore selected**,
or **Remove selected KOS**. The detail area shows local sightings, party reports,
ages and saved records separately. Possible attackers never appear as confirmed
losses. Ignored players can be restored through **Ignored enemies** on the same page.
Browsing does not select a game target, send a party message or change your route.

## Trip plan and sea crossings (v0.24.0)

- **Across the sea.** When your next step is on the other continent the arrow leads to the zeppelin or ship that crosses and names it ("Zeppelin to Undercity"), instead of stopping at "other continent". Your destination stays what it was.
- **Flight points.** Under the arrow, the nearest flight point you know to a far destination ("flight point: Hammerfall, Arathi"). It learns the points from the flight maps you open. If it cannot work out where they are it only names a point in the destination's own zone.
- **Trip plan** (`/hh` → Trip plan, or `/hh trip`): your whole quest log as stops, one per zone, nearest first, with ready turn-ins pulled forward, the crossing, then the other continent. Pick a stop and click **Guide to selected stop**; nothing changes until you do.
- Straight-line estimates only: no terrain, flight or ride times. Horde and neutral crossings come from the quest database's zeppelin and ship masters; the Alliance ships are the Classic routes with approximate docks and are labelled that way.

## Enemy watch (v0.21.0)

For world PvP: Hearth & Hustle now tells you when players of the other faction are near you in the open world, the way the Spy addon does.

- **Nameplates first (v0.24.0).** With enemy nameplates off outside combat it only sees players you target or mouse over. The PvP page says so at the top, with a **Turn on enemy nameplates** button; the setting changes only when you click it.
- **What it sees.** Forever closes the combat log to addons, so it only knows what your client already shows: a player whose nameplate is on screen, or one you target, focus or mouse over. It cannot see a stealthed player or anyone out of nameplate range. Turn on enemy nameplates and "always show nameplates" (Options → Nameplates, or `/hh enemies nameplates`); without them it only sees players you mouse over or target. The addon tells you once if they are off and never switches them on by itself.
- **Alerts.** A chat line, an on-screen notice and a sound for a new enemy, a louder one for a Kill On Sight player, and one when a visible enemy uses Stealth, Vanish, Prowl or Shadowmeld (only when the client lets the cast be read). A player who cannot attack you and whom you cannot attack (unflagged on a PvE realm) is listed without an alert. Sanctuaries are quiet. A raid on a town gives five lines and one summary, not a flood.
- **Nearby list** on the PvP HUD: name, level, class, guild, how long ago, Kill On Sight players first. Players are kept by their full name (first name and surname).
- **Kill On Sight and ignore lists**, shared by all your characters: `/hh kos Name Surname: reason`, `/hh ignore Name Surname`, or either command alone with the player targeted. Both lists are also under PvP in the control window.
- **Record.** Every enemy you met, with wins (your killing blow or your pet's) and confirmed losses from the game's death recap. A player who only had you targeted is shown as a possible attacker and does not add a loss. Older saved totals are retained. `/hh enemies stats` prints the record.
- **Party.** Sightings go to party members who also run v0.21.0 or later, and theirs show up for you as "seen by". Turn it off with `/hh enemies share off`.
- Off in dungeons, raids and battlegrounds. `/hh enemies off` switches it off everywhere; every part has its own tick under PvP.
- Not included: clicking a row to target the player, fight markers on the world map, a watch list for your own faction or for guilds, announcing to guild or raid chat.
- This is an independent implementation. Spy (Forever) is all rights reserved; none of its code, sounds or art is used. Its port showed which game functions still work for this on Forever.
- Mock-tested and checked against Blizzard's Forever UI source (70938). First client session pending.

## Quest item sparkles (v0.20.0; nearby-object sparkles removed in v0.27.1)

Quest items lying in the world are easy to walk past. The game has its own sparkle for them, and a graphics preset switches it off. Hearth & Hustle keeps it switched on: at login, and again about a second after a settings change resets it. Nothing to set up.

- It changes one graphics setting of the game (`outlineModeShowLootEffectWhenDisabled`) and nothing else. Your Outline Mode stays as you set it. Never in combat.
- The game draws the sparkle and decides what gets one. Some objects never get one (Un'Goro dirt piles, herbs, ore), and an addon cannot add it. If your Outline Mode is on and an item shows an outline and no sparkle, set **Options → Graphics → Outline Mode** to Disabled. The addon tells you once when that applies.
- Turn it off under **Display → Quest items** or with `/hh sparkle off`. A setting the addon switched on goes back to off; one that was already on before stays yours. The game keeps drawing the sparkle until you fully exit and restart it. The setting is saved by the game itself, so untick it before removing the addon, or type `/console outlineModeShowLootEffectWhenDisabled 0`.
- If something else keeps switching the setting off, the addon stops after four tries in a minute and says so once.
- The setting was found by the Forever Loot Sparkles addon (GPL-3.0); this is an independent implementation with none of its code. Its author reports that quest givers sparkle too, because the game uses one setting for both.
- The sparkle has been seen in game, also with Outline Mode on.

**Nearby-object sparkles (v0.27.0) are gone.** That mode drew stars on the one object the game's Interact Key selects. It needed the Interact Key mode switched on, reached about 15 yards, and that mode also changes who an untargeted heal or buff lands on. If you switched it on, v0.27.1 puts the game settings it changed back to what they were at your next login (outside combat), leaves alone any you changed since, and tells you once. If the game refuses, it prints the `/console` lines to type.

## Action bar guard (v0.19.0)

On the current Forever build a character with dual specialization can log in, swap spec or level up and find action bars emptied by the server. Hearth & Hustle now remembers what is on your bars while you play and puts missing buttons back on their slots a few seconds later, with one chat line saying how many. Nothing to set up and no command to type.

- It only fills empty slots. It never replaces or removes a button, never acts in combat or while you are dragging something, and never uses an ability.
- Your own changes are remembered as you make them, separately for each spec.
- The memory is kept on this computer: after the update, set your bars up once and they are covered from then on. A button you removed on another computer comes back once.
- Turn it off under **Display → Action bars** or with `/hh bars off`. `/hh bars` shows what is remembered.
- Mock-tested and checked against Blizzard's Forever UI source (70938); first client session pending.

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

**Windfury burst (shamans).** With the page ranked for Strength melee, the Main hand
slot has a fourth sort, and one button, **Windfury two-handers: biggest burst first**,
sets the whole list up. It estimates what one Windfury Weapon proc lands at once (the
swing plus two extra attacks): slow, hard-hitting weapons lead. The details show the
arithmetic and say which numbers came from your client (attack power, the bonus in
your spell's tooltip) and which are Classic rules or assumptions. It ranks the size of
the hit; damage over time follows weapon DPS whatever the speed.

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
- **Recorder** (`/hh record on|off`, off for new profiles): keeps what the addon reads back, in SavedVariables: quest givers and turn-ins with positions, objective areas, trainers (with skill requirements), flight nodes and edge costs, and the last hours of XP samples. `/hh record dataset on` adds the research dataset nothing in the addon reads: approximate observer sightings, objective progress with candidate mob/loot associations, source-attributed observed loot including quest items, vendors, inn binds, deaths, zone level ranges, profession recipes with reagents and difficulty per skill level. It grows the save file by megabytes, which the game parses at every login. v0.28.0 removes those rows once from an existing profile and says so in chat.
- **Professions**: open your profession window and the next-steps panel shows three skill-up suggestions, bag-material craft counts and missing materials. `/hh prof` gives the longer list. Handles Forever base professions, delayed recipe loading, bag changes and skill-cap reminders. These are material/skill suggestions, not market-price or guaranteed skill-point estimates. Reopen the profession after changing skill to refresh old suggestions.
- **Class supplies:** every class gets food, carried bandages and bag-space checks in **Town tools**, with drinks for mana classes. Add personal stocking targets from carried items or item links/IDs. Mage gems/reagents remain learned-spell gated; shaman reminders make no spec or party assumptions. Optional overlay display uses the existing HUD, and all supply reads pause in combat. `/hh prep` remains a shortcut.
- **Dungeon quest checklist:** click **Dungeons** on the next-steps panel, then choose a dungeon or wing. Lists what to pick up first (giver and place), quests behind a chain (with the next step), quests that start inside the dungeon (with what drops them), then your log, level requirements and completed quests. Click a quest for how to get it, what it asks, the turn-in and its chain. Updates automatically as you quest; filters to your faction/class by default, with a Show all button. `/hh dungeon [name]` is an optional shortcut.
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

This feature reads the standalone [QuestieDB Forever addon](https://github.com/Questie/QuestieDB/releases/tag/v1.1.4), versions 1.0.13, 1.1.3 and 1.1.4 tested (1.1.4 knows about 850 more quests than 1.0.13). **Questie's interface is not required.** Install its `QuestieDB` folder beside `HearthAndHustle`, restart WoW, and enable both. On this development machine, `python3 tools/install-questiedb.py` installs the checksum-pinned, unmodified data addon and preserves any different existing installation. Hearth & Hustle's other tools continue working without it; source locations will report that the database is missing.

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

The bundled reference contains **455 quest records**, including prerequisite/return steps, with populated lists for **30 dungeon/wing entries**. Five additional dungeon entries explicitly show **coverage missing**. It is adapted from the MIT-licensed [DungeonQuestTracker catalog](https://github.com/jturnham/DungeonQuestTracker/tree/b4ae5a478d0f96c842c13d5ad96bb4adb11f15df/DungeonQuestTrackerForever/Data); attribution ships inside the addon. Classic-derived entries and conflicting reports remain marked. This is not a guarantee of every current Forever quest, nor proof that all listed quests can be accepted together. Since v0.29.0 the checklist asks the installed quest database where each quest starts and what must be done first; the bundled list is the fallback, and its unfilled entries are shown as "not recorded".

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
