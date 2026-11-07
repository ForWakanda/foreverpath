# Contributing to ForeverPath

Two of us work on this at the same time, so the workflow is: branch, check, pull request, merge. `main` is protected: nothing lands on it until the `check` workflow is green, and it cannot be force-pushed or deleted.

The engineering rules live in [CLAUDE.md](CLAUDE.md) and apply to humans too. The short version: **no automation, ever**; every gameplay API call goes through `ForeverPath/API/Adapter.lua`; unit reads go through `FP.safe()`; `tools/check.sh` must pass before you commit anything under `ForeverPath/`.

## One-time setup

1. Clone with your GitHub account (collaborators push branches here; everyone else forks):
   ```sh
   git clone https://github.com/ForWakanda/foreverpath.git
   cd foreverpath
   ```
2. Lua 5.1 and Python 3. On Windows use WSL (Ubuntu): `sudo apt-get install -y lua5.1 python3`. Then tell the checks where Lua is:
   ```sh
   export LUA=lua5.1 LUAC=luac5.1
   ```
   (Put that in your `~/.bashrc`. The defaults assume `~/.local/bin/lua5.1`.)
3. Run the gate once to confirm the toolchain works:
   ```sh
   tools/check.sh
   ```
   It prints `syntax: all files OK`, the mock play-through, then the regression count. Watch its exit code, not a `| tail` of it.

## Daily loop

```sh
git switch main && git pull --ff-only
git switch -c <your-handle>/<short-topic>      # e.g. hunter/trainer-costs
# edit, then:
tools/check.sh
git commit -m "[<your-handle>] One change, described honestly"
git push -u origin HEAD
gh pr create --fill          # or open the PR on github.com
```

- **One feature or fix per commit.** Add or extend a `tests/run.lua` scenario or a `tests/regressions.py` check with every behaviour change.
- **Say in the PR what was verified in game and what only passed the mock.** Nothing in this repo can run the client. "Mock-tested only" is a fine answer; claiming more is not.
- When CI is green you can merge your own PR. Squash or merge commit, either is fine; the branch deletes itself on merge.
- Rebase on `main` when it has moved: `git fetch origin && git rebase origin/main`, re-run `tools/check.sh`, force-push **your own branch only** (`git push --force-with-lease`).
- Commit subjects carry a tag for who wrote them: `[claude]`, `[codex]`, or your handle.

## Installing your branch to play-test

`tools/deploy.sh` runs the checks and copies `ForeverPath/` into the game's AddOns folder. It takes no arguments; set `WOW_CLIENT` (client root) or `WOW_ADDONS` (the AddOns directory) if the game is not at `/mnt/d/World of Warcraft/_forever_`:

```sh
WOW_CLIENT="/mnt/c/Program Files (x86)/World of Warcraft/_forever_" tools/deploy.sh
```

`/reload` picks up Lua changes. New sound or texture files need a full client restart.

After a session, `tools/pull-data.sh` copies the SavedVariables into `data/` (git-ignored) and prints stored errors and the `apicheck` probe results. Read those before changing code: in-game truth beats the mock and beats memory of Classic.

## Verifying an API exists on Forever

Do not assume from Classic or retail. Grep Blizzard's own Forever UI source:

```sh
git clone --depth 1 --branch forever https://github.com/Gethe/wow-ui-source.git /tmp/wow-ui-source
grep -rn "GetQuestsOnMap" /tmp/wow-ui-source/Interface/AddOns/Blizzard_APIDocumentationGenerated/
```

Record a verified or falsified fact in `docs/FOREVERPATH_SPEC.md`.

## Releases

Tags `vX.Y.Z` on `main` build `ForeverPath.zip` and publish a GitHub release automatically. Bump `## Version` in `ForeverPath/ForeverPath.toc` and the version line in `README.md` in the same PR as the last change for that release, then:

```sh
git switch main && git pull --ff-only
git tag v0.9.0 && git push origin v0.9.0
```

## What will not be merged

Anything that accepts, turns in, loots, buys, targets, casts or moves for the player, or that decides from combat data. Anything that reads enemy casts or auras (secret on Forever by design). Anything obfuscated, ad-supported or paywalled. These are Blizzard's lines as much as ours, so please do not open the PR.
