#!/usr/bin/env python3
"""Install the pinned, unmodified Forever data addon beside ForeverPath.

No Questie interface, gameplay automation, or account data. Refuses to replace a
nonidentical existing installation. The upstream license stays with the addon.
"""
import argparse
import hashlib
import io
from pathlib import Path, PurePosixPath
import shutil
import tempfile
import urllib.request
import zipfile

VERSION = "1.0.13"
SHA256 = "f07c6cb18a723c8fba824038ffaaf5de23ab5c8ecd1d9235b122f06a59666f0c"
URL = f"https://github.com/Questie/QuestieDB/releases/download/v{VERSION}/QuestieDB-{VERSION}-Forever.zip"


def install(addons, archive=None):
    addons = Path(addons)
    if not addons.is_dir():
        raise ValueError(f"AddOns directory does not exist: {addons}")
    payload = Path(archive).read_bytes() if archive else urllib.request.urlopen(URL, timeout=60).read()
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
        def inventory(path):
            return {str(p.relative_to(path)): hashlib.sha256(p.read_bytes()).hexdigest()
                    for p in path.rglob("*") if p.is_file()}
        expected = inventory(src)
        if dest.exists():
            if inventory(dest) != expected:
                raise ValueError("Existing QuestieDB differs; preserved. Review/update it separately.")
        else:
            # Copy into a sibling temporary directory, then rename as one operation.
            stage = Path(tempfile.mkdtemp(prefix=".fp-questiedb-", dir=addons))
            try:
                shutil.copytree(src, stage, dirs_exist_ok=True)
                if inventory(stage) != expected:
                    raise ValueError("Staged QuestieDB verification failed")
                stage.rename(dest)
            finally:
                if stage.exists():
                    shutil.rmtree(stage)
        if inventory(dest) != expected:
            raise ValueError("Installed QuestieDB verification failed")
        print(f"QuestieDB {VERSION} Forever: {len(expected)} files verified; SHA-256 {SHA256}")
        print("Restart WoW to discover the new addon; enable QuestieDB in the AddOns list.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--addons", default="/mnt/d/World of Warcraft/_forever_/Interface/AddOns")
    parser.add_argument("--archive", help="Optional already-downloaded pinned ZIP")
    args = parser.parse_args()
    install(args.addons, args.archive)
