import importlib.util
import os
import plistlib
import sqlite3
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("transfer", Path(__file__).with_name("transfer_simulator_library.py"))
transfer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(transfer)


class SimulatorTransferTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.source = self.root / "source"
        self.source.mkdir()
        self.target = self.root / "target"
        self.backup = self.root / "backup"
        self.db = sqlite3.connect(self.source / "default.store")
        self.addCleanup(self.db.close)
        self.db.execute("PRAGMA journal_mode=WAL")
        self.db.execute("CREATE TABLE ZDISH (Z_PK INTEGER PRIMARY KEY, Z_OPT INTEGER, ZID BLOB, ZSCORE REAL)")
        self.db.execute("INSERT INTO ZDISH VALUES(1, 1, ?, 8.75)", (b"unchanged identity",))
        self.db.commit()

    def test_wal_media_and_isolated_account_roots_survive(self):
        media = self.source / "StayGrubbyMedia" / "existing.jpg"
        media.parent.mkdir()
        media.write_bytes(b"local photo bytes")
        account = self.source / "StayGrubbyAccounts" / "existing-account" / "cooking.store"
        account.parent.mkdir(parents=True)
        with sqlite3.connect(account) as db:
            db.execute("CREATE TABLE ZCOOK (ID TEXT)")
            db.execute("INSERT INTO ZCOOK VALUES ('account cook')")
        before = transfer.manifest(self.source)
        transfer.transfer(self.source, self.target, self.backup)
        self.assertEqual(before, transfer.manifest(self.source))
        self.assertEqual(before, transfer.manifest(self.target))
        self.assertEqual(before, transfer.manifest(self.backup / "source-support"))
        self.assertEqual(media.read_bytes(), (self.target / media.relative_to(self.source)).read_bytes())

    def test_repeated_transfer_is_read_only(self):
        transfer.transfer(self.source, self.target, self.backup)
        self.assertEqual(transfer.transfer(self.source, self.target, self.backup)["status"], "already identical")

    def test_relative_backup_path(self):
        backup = Path(os.path.relpath(self.backup))
        transfer.transfer(self.source, self.target, backup)
        self.assertEqual(transfer.manifest(self.source), transfer.manifest(self.target))

    def test_refuses_newer_destination_without_backup_or_mutation(self):
        self.target.mkdir()
        sentinel = self.target / "new-user-work"
        sentinel.write_text("keep")
        with self.assertRaisesRegex(ValueError, "nonempty"):
            transfer.transfer(self.source, self.target, self.backup)
        self.assertEqual(sentinel.read_text(), "keep")
        self.assertFalse(self.backup.exists())

    def test_refuses_symlinks(self):
        (self.source / "outside").symlink_to(self.root / "private")
        with self.assertRaisesRegex(ValueError, "symlinks"):
            transfer.transfer(self.source, self.target, self.backup)
        self.assertFalse(self.target.exists())

    def test_refuses_paths_outside_selected_simulator(self):
        with patch.object(transfer.subprocess, "check_output", return_value=str(self.source)):
            with self.assertRaisesRegex(ValueError, "outside"):
                transfer.checked_container("D839186C-3810-4C98-99FA-3C88230212DC", transfer.OLD_BUNDLE)

    def test_refuses_wrong_container_identity(self):
        simulator = "D839186C-3810-4C98-99FA-3C88230212DC"
        container = self.root / "Library/Developer/CoreSimulator/Devices" / simulator / "data/Containers/Data/Application/container"
        container.mkdir(parents=True)
        with (container / ".com.apple.mobile_container_manager.metadata.plist").open("wb") as f:
            plistlib.dump({"MCMMetadataIdentifier": "another.app"}, f)
        with patch.object(transfer.Path, "home", return_value=self.root), patch.object(transfer.subprocess, "check_output", return_value=str(container)):
            with self.assertRaisesRegex(ValueError, "identity mismatch"):
                transfer.checked_container(simulator, transfer.NEW_BUNDLE)


if __name__ == "__main__":
    unittest.main()
