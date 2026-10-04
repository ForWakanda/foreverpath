# ForeverPath v0.3.0 usability review

Author: Codex. Date: 2026-10-04. Starting revision: `215b956` (v0.2.2).
User priorities: automatic nearest-quest guidance, useful profession help, Mage PvP and battlegrounds.

## Findings and repairs

| Finding | Evidence | Repair |
|---|---|---|
| Arrow can remain absent with no active waypoint, or after leaving an unfinished objective area. | New idle/movement and departure regressions failed before repair; saved autoNext was already true. | Independent three-second route refresh; departure/completion resumes navigation. |
| Same quest keeps old POI and objective count. | Moving the mock POI and incrementing progress left the active arrow unchanged. | Refresh active waypoint fields even when quest/step IDs match. |
| No recipes recorded despite profession skill tracking. | Fresh saved data contains zero recipe professions; adapter only accepts child profession info. | Base-profession fallback verified against Blizzard's Forever-specific UI; retries and context-safe scans. |
| Profession feature is hidden behind commands and omits caps/stale state. | Panel only showed skill ranks; mock cap and bag-change checks failed. | Visible craft/material guidance, skill-cap reminders, bag updates and stale-skill prompts. |
| Sheep DR uses the selected target at cast completion. | Cast at a player, switch to NPC before completion: player DR lost. | Snapshot matching cast-target identity at send time. Missing evidence stays unknown. |
| Frost Nova treated as if it hit the selected target. | Single-target DR state created by an AoE cast. | Area-cast estimate, no invented victim/DR chain. |
| PvP bars imply observed effects; arbitrary addon messages can inject timers. | No estimate label; outsider and infinite-duration test accepted. | Explicit estimated bars, qualified immunity text, current-party sender and payload validation. |
| Quest arrows compete with BG navigation; first flag called enemy without faction evidence. | BG suspension / two-flag regression failed. | Suspend quest arrow; explicit numbered flag selection and unknown-faction label. |
| Record-off does not cover newer PvP modules. | BG and roster data mutate while disabled. | Gate persistent writes while retaining session HUD information. |

Navigation preserves manual waypoints and explicit quest choices, avoids small-distance target flapping, and waits while the player is actually working in the arrived area. It does not imply that a quest has completed merely because the player reached its POI. Distances remain straight-line estimates; turn-in and shared-quest preferences remain in the score.

## Verification

- All 62 regression checks pass (46 existing, 16 added); 18 self-tests and mock play-through pass.
- The new tests reproduced 13 failures against the code before each repair group; additional preservation checks cover explicit selection, stop/off and target stability.
- Existing account and character SavedVariables initialize and refresh with zero mock errors. The test loads copies in memory, without writing the game files.
- Source verified against [Blizzard's Forever UI mirror](https://github.com/Gethe/wow-ui-source/tree/e3ecc27b64d30fdc735a3f6579b866858f9f9df1), build 1.60.1.70205. The profession fallback is supported by `Blizzard_ProfessionsTemplates/Camelot/Blizzard_Professions.lua` and the shared `Professions.GetProfessionInfo` implementation.
- **No v0.3.0 in-game verification yet.** A green mock does not emulate secrets, real frames, asynchronous client data or battleground restrictions.

## Client checkpoint

1. `/reload`; confirm `/fp status` reports 0.3.0. With auto on, move between quest areas without `/fp next`; completing a step or leaving its area should restore the arrow. A manually selected quest stays selected until arrival/completion.
2. Open Tailoring, leave it open briefly, then Enchanting. The panel should show suggestions/material needs. Run `/fp apicheck` while a profession is open; `probe:openProfession` should name the lookup and recipe-ID count. Buy/use materials and check the counts refresh.
3. In a battleground, quest arrows should disappear and `/fp pvp auto` should show relevant HUD sections. Cast sheep and switch targets during the cast. Compare the captured target with the actual cast. The bar is an estimate even when correctly attributed.
4. Check flags against Blizzard's map. If both appear, `/fp pvp track 1` or `2` explicitly chooses a position slot. Do not infer faction from the number. Record actual POIs/textures and whether map position works before promoting faction routing.
5. `/reload` or logout flushes saved evidence; pull data and inspect errors/open-profession probe/recipes/BG maps before further changes.

## Recommended next Mage work

1. A compact pre-match preparation checklist for water, bandages and spell reagents, based on bags and known spells. Keep it informational and avoid combat cooldown assumptions.
2. Clearer battleground objective/flag alerts, using the first recorded match to establish faction/state meanings. Prioritize this over adding more inferred combat timers.
3. Refine the HUD to show only relevant target/party estimates. Existing tooltip durations, DR factors/reset and guessed POI state keywords are not game-verified. Do not market them as enemy cooldown, interrupt confirmation or landed-CC tracking.

Remaining engineering debt: some older PvP/probe modules still call game APIs outside the adapter; locale-dependent spell-name/tooltip matching and English POI keyword inference remain. New reads in this repair use the adapter. No paid services or game actions were used.
