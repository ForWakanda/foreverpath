## What changed

<!-- One feature or fix. Why it is needed. -->

## Verification

- [ ] `tools/check.sh` is green locally (exit code 0, not `| tail`)
- [ ] Added or extended a `tests/run.lua` scenario or `tests/regressions.py` check
- [ ] In game: <!-- verified on build XXXXX / mock-tested only -->

## Rules

- [ ] No automation: nothing accepts, turns in, loots, buys, targets, casts or moves for the player
- [ ] Gameplay API calls go through `HearthAndHustle/API/Adapter.lua`; unit reads through `FP.safe()`
- [ ] `docs/SPEC.md` updated if an API fact was verified or falsified
