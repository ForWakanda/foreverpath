#!/usr/bin/env python3
"""Install or update the pinned Forever data addon beside HearthAndHustle.

No Questie interface, gameplay automation, or account data. The upstream license
stays with the addon. The archive is checksum-pinned; a newer QuestieDB release is
adopted by changing VERSION and SHA256 here after the provider integration test
(tests/questiedb-integration.lua) has passed against it.

  install-questiedb.py                    install, or confirm the pinned version is installed
  install-questiedb.py --update --backup DIR
                                          replace a different installed version: game closed,
                                          the old folder is copied to DIR first

An existing installation that differs is never replaced without --update and a backup.
"""
import argparse
import hashlib
import io
from pathlib import Path, PurePosixPath
import re
import shutil
import subprocess
import sys
import tempfile
import urllib.request
import zipfile

VERSION = "1.1.4"
SHA256 = "77560ed5a425de989b45bbaddb3fd0eb2173df25f43c4d5c3ef8b4622985486c"
URL = f"https://github.com/Questie/QuestieDB/releases/download/v{VERSION}/QuestieDB-{VERSION}-Forever.zip"
# Blizzard's own Forever TOCs select files with the game type "camelot" (build 71037),
# and QuestieDB up to 1.0.16 shipped a second, byte-identical QuestieDB_Camelot.toc for
# it. 1.1.x ships QuestieDB_Forever.toc alone. Whether the release client loads that
# name by itself is not established here, so the copy the working installation had is
# kept: same bytes, second name. It is the one file not taken from the archive.
TOC, ALIAS = "QuestieDB_Forever.toc", "QuestieDB_Camelot.toc"


def inventory(path):
    return {p.relative_to(path).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in path.rglob("*") if p.is_file()}


def installed_version(dest):
    for name in (TOC, ALIAS):
        toc = dest / name
        if toc.is_file():
            with toc.open("r", encoding="utf-8", errors="replace") as handle:
                for _, line in zip(range(200), handle):
                    found = re.match(r"## Version:\s*(\S+)", line)
                    if found:
                        return found.group(1)
    return "unknown"


def game_running():
    """True, False, or None when Windows cannot be asked."""
    tasklist = shutil.which("tasklist.exe")
    if not tasklist:
        return None
    result = subprocess.run([tasklist, "/FI", "IMAGENAME eq Wow.exe", "/NH"], capture_output=True, text=True)
    out = result.stdout.lower()
    if result.returncode != 0 or not out.strip():
        return None
    if "wow.exe" in out:
        return True
    return False if "no tasks are running" in out else None


def stage_beside(src, addons, expected):
    """Copy into a sibling directory of the destination, verified, ready to rename."""
    stage = Path(tempfile.mkdtemp(prefix=".fp-questiedb-", dir=addons))
    try:
        shutil.copytree(src, stage, dirs_exist_ok=True)
        if inventory(stage) != expected:
            raise ValueError("Staged QuestieDB verification failed")
    except BaseException:
        shutil.rmtree(stage, ignore_errors=True)
        raise
    return stage


def install(addons, archive=None, update=False, backup=None, process_check=True):
    addons = Path(addons)
    if not addons.is_dir():
        raise ValueError(f"AddOns directory does not exist: {addons}")
    payload = Path(archive).read_bytes() if archive else urllib.request.urlopen(URL, timeout=120).read()
    if hashlib.sha256(payload).hexdigest() != SHA256:
        raise ValueError("QuestieDB archive checksum mismatch; nothing installed")
    with tempfile.TemporaryDirectory(prefix="fp-questiedb-") as temp:
        root = Path(temp)
        with zipfile.ZipFile(io.BytesIO(payload)) as bundle:
            for entry in bundle.infolist():
                path = PurePosixPath(entry.filename)
                if path.is_absolute() or ".." in path.parts or path.parts[0] != "QuestieDB":
                    raise ValueError("Unsafe or unexpected archive path")
            bundle.extractall(root)
        src, dest = root / "QuestieDB", addons / "QuestieDB"
        if not (src / TOC).is_file():
            raise ValueError(f"The archive has no {TOC}; nothing installed")
        if not (src / ALIAS).exists():
            shutil.copyfile(src / TOC, src / ALIAS)
        expected = inventory(src)
        if dest.exists() and inventory(dest) == expected:
            print(f"QuestieDB {VERSION} Forever is already installed: {len(expected)} files verified")
            return "current"
        if dest.exists():
            found = installed_version(dest)
            if not update:
                raise ValueError(f"Existing QuestieDB ({found}) differs from the pinned {VERSION}; preserved. "
                                 "Close the game and run again with --update --backup DIR to replace it.")
            if not backup:
                raise ValueError("--update needs --backup DIR: the installed folder is copied there first")
            if process_check:
                running = game_running()
                if running is not False:
                    raise ValueError("The game is running; nothing changed. Close it first: the data lives in a file the client reads only at startup."
                                     if running else "Could not ask Windows whether the game is running; nothing changed.")
            kept = Path(backup) / "QuestieDB"
            if kept.exists():
                raise ValueError(f"Backup folder already holds a QuestieDB: {kept}")
            kept.parent.mkdir(parents=True, exist_ok=True)
            before = inventory(dest)
            shutil.copytree(dest, kept)
            if inventory(kept) != before:
                raise ValueError(f"Backup verification failed: {kept}; nothing changed")
            stage = stage_beside(src, addons, expected)
            old = Path(tempfile.mkdtemp(prefix=".fp-questiedb-old-", dir=addons))
            old.rmdir()
            dest.rename(old)
            try:
                stage.rename(dest)
            except BaseException:
                old.rename(dest)
                shutil.rmtree(stage, ignore_errors=True)
                raise
            shutil.rmtree(old)
            print(f"QuestieDB {found} -> {VERSION}; previous folder kept at {kept}")
        else:
            stage_beside(src, addons, expected).rename(dest)
        if inventory(dest) != expected:
            raise ValueError("Installed QuestieDB verification failed")
        print(f"QuestieDB {VERSION} Forever: {len(expected)} files verified; SHA-256 {SHA256}")
        print(f"{ALIAS} is a byte-identical copy of {TOC} (the second name the previous package shipped).")
        print("Restart WoW: the client reads this addon's data only when it starts. Keep QuestieDB enabled in the AddOns list.")
        return "installed"


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--addons", default="/mnt/d/World of Warcraft/_forever_/Interface/AddOns")
    parser.add_argument("--archive", help="Optional already-downloaded pinned ZIP")
    parser.add_argument("--update", action="store_true", help="replace a different installed version (game closed, needs --backup)")
    parser.add_argument("--backup", help="folder that receives the replaced installation")
    parser.add_argument("--no-process-check", action="store_true", help="skip the running-game check (tests, other platforms)")
    args = parser.parse_args()
    try:
        install(args.addons, args.archive, args.update, args.backup, not args.no_process_check)
    except ValueError as problem:
        print(f"NOT INSTALLED: {problem}")
        sys.exit(1)
