#!/usr/bin/env python3
"""One-time move of an existing ForeverPath installation to Hearth & Hustle (v0.17.0 rename).

For the account and every character, copies the SavedVariables file `ForeverPath.lua`
to `HearthAndHustle.lua` with the two top-level variable names rewritten, keeps the
original beside it as `ForeverPath.lua.pre-rename`, and removes the old addon folder.

Safe by construction:
- refuses while the game is running (the client rewrites SavedVariables on exit);
- an unrelated addon is also called "ForeverPath" and uses the same variable names, so a
  file or folder is touched only when it carries this project's own structure;
- never overwrites an existing `HearthAndHustle.lua`;
- `--dry-run` prints the plan and changes nothing.

Usage: tools/migrate-from-foreverpath.py [--client "/mnt/d/World of Warcraft/_forever_"] [--dry-run]
"""
import argparse
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

OLD, NEW = "ForeverPath", "HearthAndHustle"
ACCOUNT_KEYS = ("settings", "data", "meta")
CHARACTER_KEYS = ("waypoints", "completed", "nextId")


def top_level_keys(text, variable):
    """Keys directly inside `<variable> = {`. The client writes one entry per line with no
    indentation and CRLF endings, so depth comes from counting table opens and closes."""
    keys, depth, inside = set(), 0, False
    for line in text.splitlines():
        line = line.strip()
        if not inside:
            if line == variable + " = {":
                inside, depth = True, 1
            continue
        if line.startswith("}"):          # "}" or "}," (some clients add "-- [n]")
            depth -= 1
            if depth == 0:
                break
            continue
        if depth == 1:
            match = re.match(r'\["([^"]+)"\] = ', line)
            if match:
                keys.add(match.group(1))
        if line.endswith("{"):
            depth += 1
    return keys


def is_ours(text, character):
    if character:
        return set(CHARACTER_KEYS) <= top_level_keys(text, OLD + "CharDB")
    return set(ACCOUNT_KEYS) <= top_level_keys(text, OLD + "DB")


def old_addon_is_ours(folder):
    toc = folder / (OLD + ".toc")
    if not toc.is_file():
        return False
    text = toc.read_text(encoding="utf-8", errors="replace")
    return "API\\Adapter.lua" in text and "## X-License: MIT" in text


def game_running():
    tasklist = shutil.which("tasklist.exe")
    if not tasklist:
        return False
    out = subprocess.run([tasklist, "/FI", "IMAGENAME eq Wow.exe", "/NH"], capture_output=True, text=True).stdout
    return "wow.exe" in out.lower()


def saved_variable_files(wtf):
    account = sorted(wtf.glob("Account/*/SavedVariables/" + OLD + ".lua"))
    characters = sorted(wtf.glob("Account/*/*/*/SavedVariables/" + OLD + ".lua"))
    return [(p, False) for p in account] + [(p, True) for p in characters]


def migrate(client, dry_run=False, process_check=True, keep_old_addon=False, out=print):
    client = Path(client)
    wtf, addons = client / "WTF", client / "Interface" / "AddOns"
    if not wtf.is_dir():
        out(f"no WTF folder under {client}; nothing to migrate")
        return 1
    if process_check and game_running():
        out("World of Warcraft is running. Close the game first: it rewrites SavedVariables when it exits.")
        return 1
    # Plan everything first. One unrecognised file stops the whole run before any change.
    plan, skipped, unknown = [], 0, 0
    for source, character in saved_variable_files(wtf):
        target = source.with_name(NEW + ".lua")
        label = str(source.relative_to(wtf))
        raw = source.read_bytes()
        # Bytes in, bytes out: line endings and every other character stay exactly as written.
        new_raw, count = re.subn(rb"^" + OLD.encode() + rb"(CharDB|DB) = ", NEW.encode() + rb"\1 = ", raw, flags=re.M)
        if not is_ours(raw.decode("utf-8", errors="replace"), character) or count != 1:
            out(f"not recognised as this addon's data: {label}")
            unknown += 1
        elif target.exists():
            out(f"already migrated (has {target.name}): {label}")
            skipped += 1
        else:
            plan.append((source, target, label, raw, new_raw))
    old_addon = addons / OLD
    remove_old = old_addon.is_dir() and old_addon_is_ours(old_addon) and not keep_old_addon
    if old_addon.is_dir() and not old_addon_is_ours(old_addon):
        out(f"left alone (a different addon): {old_addon}")
    if unknown:
        out(f"stopped: {unknown} file(s) not recognised; nothing was changed. Move them aside or check which addon wrote them.")
        return 1
    for source, target, label, raw, new_raw in plan:
        out(f"{'would migrate' if dry_run else 'migrate'}: {label} -> {target.name} ({len(raw)} bytes)")
        if dry_run:
            continue
        temp = target.with_name(target.name + ".tmp")
        temp.write_bytes(new_raw)
        if temp.read_bytes() != new_raw:
            temp.unlink()
            out(f"write verification failed for {label}; stopped")
            return 1
        os.replace(temp, target)
        os.replace(source, source.with_name(OLD + ".lua.pre-rename"))
    if remove_old:
        out(f"{'would remove' if dry_run else 'remove'} old addon folder: {old_addon}")
        if not dry_run:
            shutil.rmtree(old_addon)
    elif old_addon.is_dir() and old_addon_is_ours(old_addon):
        out(f"kept on request: {old_addon} (delete it before starting the game, or both copies load)")
    out(f"{'planned' if dry_run else 'done'}: {len(plan)} file(s) migrated, {skipped} already migrated")
    return 0


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--client", default=os.environ.get("WOW_CLIENT", "/mnt/d/World of Warcraft/_forever_"))
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--keep-old-addon", action="store_true", help="do not delete Interface/AddOns/ForeverPath")
    parser.add_argument("--no-process-check", action="store_true", help="skip the running-game check (tests, other platforms)")
    args = parser.parse_args()
    sys.exit(migrate(args.client, args.dry_run, not args.no_process_check, args.keep_old_addon))
