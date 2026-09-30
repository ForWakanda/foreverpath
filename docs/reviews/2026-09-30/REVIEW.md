# ForeverPath preflight code review

Codex, 2026-09-30. Reviewed addon revision `a58c91e`, all 15 Lua files, XML/TOC, tools, mock tests, spec, and selected Blizzard API/UI contracts from build 70124 (`966519cf0ad2c10301ea011a88c14b25697c9687`).

**Recommendation: repair the navigation and recorder defects before the first normal data-collection session.** The current suite passes, but the additional checks reproduce failures without launching WoW. These are review findings; no addon fixes or deployment were performed.

## Evidence and limits

- `tools/check.sh`: exit 0; 18 self-tests pass; mock play-through reports zero stored errors.
- Installed `ForeverPath/` under the Windows `_classic_beta_` client matches the reviewed repository byte for byte.
- Expected account SavedVariables file does not exist yet. No in-game execution or runtime secret-value behavior was verified.
- `python3 docs/reviews/2026-09-30/reproduce.py`: exit **1**, with **14 failing behavioral checks**. These are grouped into findings below, not 14 independent root causes. Exact output is in [results.txt](results.txt).
- The reproduction suite is separate from the normal gate and intentionally red against this revision. It uses a fresh mock process per scenario and an ephemeral copy for the malformed-XML test. It does not write to the installed addon or live dataset.

## Findings to fix before collecting data

### P1 Loot totals increase when reopening the same corpse

Location: `ForeverPath/Data/Recorder.lua:538-554`.

The GUID check deduplicates `holder.looted`, but every `LOOT_OPENED` still adds all visible quantities to `holder.loot`. Reopening a corpse holding two cloth records **four cloth from one corpse**. The existing test opens the corpse twice but checks only the corpse count, overlooking the inflated item count. Quest item source counters are incremented again too.

Track per-source item observations across reopenings, including partial looting, rather than adding the complete loot window each time. Decide explicitly whether the dataset measures loot offered or loot actually collected.

### P1 Multiple loot sources are collapsed into the first creature

Locations: `ForeverPath/Data/Recorder.lua:526-566`, `ForeverPath/API/Adapter.lua:467-474`.

The recorder selects the first source GUID found anywhere in the window and credits every slot to it. The adapter also discards source-specific quantities and reads only three GUID/quantity pairs. With two slots whose sources are different creatures, the second creature's item is recorded as a drop of the first creature. Area-loot source availability in Forever remains an in-game question; the failure is reproduced whenever the API supplies this supported shape.

Preserve all per-slot source/quantity pairs, allocate each item to its own source, and keep unknown or fallback attribution explicitly uncertain. A selected dead target is not proof that it owns the entire loot window.

### P1 Batched quest updates create false objective to mob relationships

Location: `ForeverPath/Data/Recorder.lua:193-216`.

After the 0.3-second rescan throttle, every monster-objective delta is assigned to `lastKills[#lastKills]` if it is less than four seconds old. Two quick kills of different species advancing different quests produce two relationships to the second species. These guesses are immediately folded into `q.obj[i].mobs`, which the planner consumes as location evidence. Item-objective attribution has the analogous problem: it uses the last loot source without checking that the required item was present.

Retain candidate observations and ambiguity instead of promoting temporal proximity directly into confirmed relationships. Test multiple kills and objective deltas in the same throttle window, party credit, and unrelated loot near an update.

### P1 Auto next loses its state after objective arrival

Locations: `ForeverPath/Nav/Waypoints.lua:125-131`, `ForeverPath/Route/Planner.lua:205-239`.

Arrival removes the waypoint. The objective branch records suppression and says the arrow will resume when the objective progresses, but `CheckActive` immediately returns when there is no active waypoint. Walking into the objective area and then completing the objective leaves the arrow absent. The visible panel rebuilding does not activate a new waypoint.

Track the arrived objective separately from the displayed waypoint and handle later progress/completion even while no waypoint is active.

### P2 Turn in arrival repeatedly selects the same destination

Location: `ForeverPath/Route/Planner.lua:205-212`.

A turn-in arrival removes its waypoint and schedules `Auto` after one second. While the quest is still in the log, the same nearby turn-in wins again, immediately arrives, and repeats. Five simulated cycles created five replacement waypoints while standing still. This also repeats arrival/next chat messages while the player is reading a dialog or waiting for a friend.

Retain an arrived/waiting-for-turn-in state until the quest changes or the player explicitly selects another step.

### P2 Automatic planning overrides manual waypoints

Location: `ForeverPath/Route/Planner.lua:190`.

The manual-waypoint guard requires `active.source` to exist. `/fp way` creates a waypoint with no source, so it bypasses that guard. A login, accept, or turn-in replan can redirect the arrow away from the user's chosen waypoint. Preserve an active waypoint whose source is absent or is not `plan`.

### P1 The deployment check can succeed after detecting bad XML

Location: `tools/check.sh:21-22`.

`[ $fail -eq 0 ] && echo ...` does not abort under `set -e` when the test is false: it is the non-final command in an AND-list. The script then runs the Lua mock and returns that command's exit status. An actually malformed `MapPins.xml` in a temporary copy prints `BAD XML`, then `ALL CHECKS PASSED`, and exits **0**. Forcing `LUAC=/bin/false` similarly prints 15 syntax failures yet exits 0. The real Lua loader would catch many Lua syntax failures independently, but does not load XML.

Explicitly exit nonzero when `fail != 0`; exercise the gate with malformed XML and missing TOC entries. The documented no-pipe discipline does not fix this separate shell-control-flow defect. Also remove or tightly define the `deploy.sh --no-check` bypass if the project rule is that all deployment must be gated.

## Additional reproducible defects

### P2 Manual API checks omit the successful probe evidence

Location: `ForeverPath/UI/Commands.lua:128`.

The automatic once-per-build check stores rows; the manual command stores only an OK count and failure strings. An early login probe can be inconclusive, and a later outdoor `/fp apicheck` can succeed while its position, facing, POI, and waypoint values are lost on logout. Store every manual row with an explicit status, note, and context. Preserve contextual absence separately from an API exception or missing API.

### P2 Recording off disables navigation updates but does not stop all recording

Locations: `ForeverPath/Data/Recorder.lua:299-310`, `ForeverPath/Prof/Tracker.lua:21-105`.

Planner events originate inside recording-gated handlers. After draining previous callbacks, `/fp record off` followed by quest completion leaves the objective waypoint active. Conversely, profession snapshot/recipe handlers, login snapshots, and some already-scheduled callbacks still write data with recording disabled.

Separate live quest-state notifications from optional dataset persistence, and define which settings/diagnostics are exempt from the recording switch.

### P2 Party synchronization reports failed sends as successful and leaves the plan stale

Locations: `ForeverPath/API/Adapter.lua:650`, `ForeverPath/Party/Sync.lua:33-56`.

`SendAddonMessage` returns an enum, not a success boolean. A mocked build-70124 `AddonMessageThrottle` result of 3 makes `/fp partysync` print that the state was sent because all Lua numbers are truthy. Compare the result with `Enum.SendAddonMessageResult.Success` and surface a useful failure reason. The enum contract is documented in [Blizzard's extracted build-70124 source](https://github.com/Gethe/wow-ui-source/blob/966519cf0ad2c10301ea011a88c14b25697c9687/Interface/AddOns/Blizzard_APIDocumentationGenerated/ChatConstantsDocumentation.lua#L144).

Separately, incoming state fires `PARTY_UPDATED`, but nothing subscribes to rebuild the plan. A received shared quest remains unstarred until another event happens to rebuild it. The sender also omits quest removal/completion updates; stored state is not cleared on leaving the party. Explicit paste seeds should be distinguished from current connected-party state.

### P2 Creature locations are observer locations without an uncertainty label

Location: `ForeverPath/Data/Recorder.lua:484-490`.

Targeting or mousing over a distant mob stores `Pos:Snapshot()`—the player's coordinates—in the creature's `pos` list. A hunter can therefore populate a route dataset with firing positions rather than mob positions. Kill events use the same observer position. This is reproducible without any missing API: the only position fetched is the player's.

Store these as observer sightings with provenance/range uncertainty. Use them as approximate search areas, not interchangeable precise entity coordinates. Nearby NPC interaction and remote targeting warrant different confidence.

### P2 The in game self test changes real user state

Location: `ForeverPath/Core/SelfTest.lua:75-90`.

The party test imports fake state and then sets `FP.cdb.party = {}`, erasing a real import. The waypoint test changes `activeId` and removes its test waypoints without restoring the user's previous selection. Both are reproducible while all 18 self-tests report success.

Run these cases against isolated state or restore all affected state even after assertions fail. Do not suggest `/fp selftest` as a harmless diagnostic until that is fixed.

## Other improvements and runtime checks

- **World-map right-click removal:** the addon inherits `MapCanvasPinMixin:ShouldMouseButtonBePassthrough`, which returns true for right clicks. Blizzard calls `CheckMouseButtonPassthrough("RightButton")` on acquisition. Override this if right-click is supposed to delete the pin. This is a source-level concern; the current mock does not implement mouse passthrough, and the client interaction was not exercised. See [Blizzard's pin mixin](https://github.com/Gethe/wow-ui-source/blob/966519cf0ad2c10301ea011a88c14b25697c9687/Interface/AddOns/Blizzard_MapCanvas/MapCanvas_DataProviderBase.lua#L284).
- **Profession wording and ranking:** `Craftable` includes bank items despite the UI saying bags; `BestCrafts(12)` truncates before filtering to craftable recipes, so twelve unavailable orange recipes can hide a craftable yellow recipe. Missing reagent data should remain unknown, and current-character learned state should not be treated as account-wide recipe knowledge.
- **Position recovery:** `Pos:WorldOf` caches a failed world conversion as `false` indefinitely for an unchanged waypoint. Retry transient failures after map transitions or a bounded interval.
- **Waypoint input:** enforce finite coordinates in `[0,1]` after an unambiguous percentage conversion; explicit map IDs below 101 currently cannot use the advertised syntax, and `1` ambiguously becomes 100% rather than 1%.
- **Architecture claim:** game reads are not confined to `API/Adapter.lua`; Recorder, Prof, Party, Position, UI, and Core contain direct calls. Distinguish permissible UI/framework calls from gameplay reads and enforce the latter boundary.
- **Tests:** unknown PascalCase mock methods silently become no-ops; XML is not instantiated; secret values are always ordinary values; timers do not reproduce actual frame scheduling. Keep pure unit tests, but add strict API contracts, event-order scenarios, and the regressions above. Do not pretend stock Lua emulates WoW secret values.
- **Distribution:** README and TOC say MIT, but no license file is present. Add the actual license/copyright before distributing. No legal or policy-compliance verdict is made in this code review.

The first in-game session is still needed to validate startup/XML, quest POI coverage, facing/texture rotation, loot-source availability, secret-value behavior, and SavedVariables flushing. This review does not establish that any of those already work.

## Suggested repair sequence

1. Fix the gate and make diagnostic/self-test commands preserve state and evidence.
2. Fix objective/turn-in arrival states and manual waypoint ownership; decouple planner updates from recording.
3. Fix loot attribution/deduplication and keep uncertain objective/entity observations explicitly uncertain.
4. Fix party status handling and plan refresh; check map-pin input behavior.
5. Run the normal suite plus promoted regression tests, deploy through the repaired gate, verify installed bytes, then perform the user's first in-game smoke test.
