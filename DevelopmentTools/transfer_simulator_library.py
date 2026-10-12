#!/usr/bin/env python3
"""Explicit, one-time simulator transfer. Never imported or invoked by the app."""
import argparse
import hashlib
import json
import plistlib
import shutil
import sqlite3
import subprocess
import uuid
from pathlib import Path

# Historical identity retained ONLY to locate the pre-rename simulator container.
OLD_BUNDLE = "com.guyrettig.Grub-Ranked"
NEW_BUNDLE = "com.guyrettig.StayGrubby"


def checked_container(simulator, bundle):
    simulator = str(uuid.UUID(simulator)).upper()
    root = (Path.home() / "Library/Developer/CoreSimulator/Devices" / simulator
            / "data/Containers/Data/Application").resolve()
    path = Path(subprocess.check_output(
        ["xcrun", "simctl", "get_app_container", simulator, bundle, "data"], text=True).strip()).resolve()
    if path.parent != root:
        raise ValueError("Refusing a path outside the selected Simulator's data containers")
    with (path / ".com.apple.mobile_container_manager.metadata.plist").open("rb") as f:
        if plistlib.load(f).get("MCMMetadataIdentifier") != bundle:
            raise ValueError("Container identity mismatch")
    return path


def snapshot_support(source, destination):
    """Keep relative media/account paths, but snapshot live SQLite with its WAL."""
    if destination.exists():
        raise ValueError("Never overwrite a backup")
    if any(p.is_symlink() for p in source.rglob("*")):
        raise ValueError("Refusing symlinks in Application Support")
    shutil.copytree(source, destination, ignore=shutil.ignore_patterns("*-wal", "*-shm"))
    for database in source.rglob("*.store"):
        target = destination / database.relative_to(source)
        target.unlink()
        with sqlite3.connect(database.as_uri() + "?mode=ro", uri=True) as src, sqlite3.connect(target) as dst:
            src.backup(dst)
            if dst.execute("PRAGMA integrity_check").fetchone()[0] != "ok":
                raise ValueError("SQLite integrity check failed")


def manifest(support):
    """Full entity fields/relationships; Core Data's optimistic-lock counter is housekeeping."""
    support = support.resolve()
    if any(p.is_symlink() for p in support.rglob("*")):
        raise ValueError("Refusing symlinks in Application Support")
    result = {}
    for p in sorted(support.rglob("*")):
        if not p.is_file() or p.name.endswith(("-wal", "-shm")):
            continue
        relative = str(p.relative_to(support))
        if p.suffix == ".store":
            tables = {}
            with sqlite3.connect(p.as_uri() + "?mode=ro", uri=True) as db:
                if db.execute("PRAGMA integrity_check").fetchone()[0] != "ok":
                    raise ValueError("SQLite integrity check failed")
                for (table,) in db.execute("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name"):
                    if table in ("Z_METADATA", "Z_PRIMARYKEY", "sqlite_sequence"):
                        continue
                    quote = lambda s: '"' + s.replace('"', '""') + '"'
                    columns = [row[1] for row in db.execute("PRAGMA table_info(" + quote(table) + ")")
                               if row[1] != "Z_OPT"]
                    fields = ",".join(map(quote, columns))
                    rows = db.execute("SELECT " + fields + " FROM " + quote(table) + " ORDER BY " + fields).fetchall()
                    tables[table] = {"columns": columns, "count": len(rows),
                                     "sha256": hashlib.sha256(repr(rows).encode()).hexdigest()}
            result[relative] = tables
        else:
            result[relative] = hashlib.sha256(p.read_bytes()).hexdigest()
    return result


def transfer(source, target, backup):
    if not (source / "default.store").is_file():
        raise ValueError("Missing existing guest database")
    before = manifest(source)
    # Repeated invocations may verify an identical transfer, never replace newer work.
    if target.exists() and any(target.iterdir()):
        if before == manifest(target):
            return {"status": "already identical", "manifest": before}
        raise ValueError("Target is nonempty and different; refusing to overwrite")
    backup.mkdir(parents=True, exist_ok=False)
    snapshot_support(source, backup / "source-support")
    if target.exists():
        snapshot_support(target, backup / "target-support")
    consistent = manifest(backup / "source-support")
    if before != consistent:
        raise ValueError("Source changed while backing up; nothing transferred")
    pending = target.with_name(target.name + ".transfer-" + str(uuid.uuid4()))
    try:
        shutil.copytree(backup / "source-support", pending)
        if manifest(pending) != before:
            raise ValueError("Transfer verification failed")
        if target.exists():
            target.rmdir()  # Only the verified empty destination.
        pending.rename(target)
    finally:
        if pending.exists():
            shutil.rmtree(pending)
    report = {"status": "transferred", "manifest": before}
    (backup / "transfer-report.json").write_text(json.dumps(report, indent=2))
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--simulator", required=True, help="Explicit Simulator UDID, never booted/device alias")
    parser.add_argument("--backup", type=Path, required=True, help="Fresh ignored .local-backups subdirectory")
    parser.add_argument("--apply", action="store_true", help="Without this flag only inspect")
    args = parser.parse_args()
    source = checked_container(args.simulator, OLD_BUNDLE) / "Library/Application Support"
    target = checked_container(args.simulator, NEW_BUNDLE) / "Library/Application Support"
    backup_root = Path(__file__).resolve().parent.parent / ".local-backups"
    if not args.backup.resolve().is_relative_to(backup_root.resolve()):
        raise ValueError("Backup must stay in the repository's ignored .local-backups")
    if not args.apply:
        print(json.dumps({"source": str(source), "target": str(target), "manifest": manifest(source)}, indent=2))
        return
    for bundle in (OLD_BUNDLE, NEW_BUNDLE):
        stopped = subprocess.run(["xcrun", "simctl", "terminate", args.simulator, bundle], capture_output=True, text=True)
        if stopped.returncode and "found nothing to terminate" not in stopped.stderr.lower():
            raise ValueError("Could not safely stop app: " + stopped.stderr)
    print(json.dumps(transfer(source, target, args.backup), indent=2))


if __name__ == "__main__":
    main()
