"""L29 (owner feedback 2026-11-05): the macOS build in the export and release tools.

Covers tools/export_all.py (the RLDB-process refusal parser and the macOS zip checks) and the macOS asset and
release notes of tools/publish_github.py. No Godot, no network, no gh: zips and pcks are built in memory.
"""
import contextlib
import io
import os
import struct
import sys
import tempfile
import unittest
import zipfile

TOOLS = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, TOOLS)
import export_all  # noqa: E402
import publish_github  # noqa: E402

UNIVERSAL = b"\xca\xfe\xba\xbe\x00\x00\x00\x02" + b"\0" * 16
THIN = b"\xcf\xfa\xed\xfe" + b"\0" * 20
GOOD_PCK_PATHS = ["res://.godot/imported/a.webp-1.s3tc.ctex", "res://.godot/imported/a.webp-1.etc2.ctex",
                  "res://src/ui/main.gd.remap", "res://data/cards.json"]


def make_pck(paths):
    """A minimal Godot 4 pck (format 3) with an empty body: header, then the directory."""
    header = b"GDPC" + struct.pack("<5I", 3, 4, 6, 1, 2) + struct.pack("<QQ", 0, 40 + 64) + b"\0" * 64
    body = struct.pack("<I", len(paths))
    for p in paths:
        raw = p.encode() + b"\0"
        raw += b"\0" * (-len(raw) % 4)
        body += struct.pack("<I", len(raw)) + raw + struct.pack("<QQ", 0, 0) + b"\0" * 16 + struct.pack("<I", 0)
    return header + body


def make_zip(path, drop=(), binary=UNIVERSAL, pck_paths=GOOD_PCK_PATHS):
    with zipfile.ZipFile(path, "w") as z:
        for name in export_all.MACOS_REQUIRED:
            if name in drop:
                continue
            if name.endswith("Contents/MacOS/RLDB"):
                z.writestr(name, binary)
            elif name.endswith(".pck"):
                z.writestr(name, make_pck(pck_paths))
            else:
                z.writestr(name, b"x")


class ExportAllTest(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.TemporaryDirectory()
        self.addCleanup(self.dir.cleanup)
        self.zip = os.path.join(self.dir.name, "RLDB-macos.zip")

    def test_running_rldb_finds_game_and_dev_build_ignores_others(self):
        out = '"RLDB.exe","123","Console","1","90,000 K"\n"rldb-dev.exe","9","Console","1","1 K"\n' \
              '"Godot_v4.6.1-stable_win64.exe","7","Console","1","1 K"\n"svchost.exe","4","Services","0","1 K"\n'
        self.assertEqual(export_all.running_rldb(out), ["RLDB.exe", "rldb-dev.exe"])

    def test_running_rldb_empty_when_nothing_matches(self):
        self.assertEqual(export_all.running_rldb('"svchost.exe","4","Services","0","1 K"\n'), [])

    def test_good_macos_zip_has_no_problems(self):
        make_zip(self.zip)
        self.assertEqual(export_all.check_macos_zip(self.zip), [])

    def test_missing_signature_is_reported(self):
        sig = "RLDB.app/Contents/_CodeSignature/CodeResources"
        make_zip(self.zip, drop=(sig,))
        self.assertIn("missing " + sig, export_all.check_macos_zip(self.zip))

    def test_single_architecture_binary_is_reported(self):
        make_zip(self.zip, binary=THIN)
        self.assertTrue(any("universal" in p for p in export_all.check_macos_zip(self.zip)))

    def test_excluded_paths_in_pck_are_reported(self):
        make_zip(self.zip, pck_paths=GOOD_PCK_PATHS + ["res://tests/unit/x_test.gd"])
        self.assertTrue(any("excluded paths" in p for p in export_all.check_macos_zip(self.zip)))

    def test_s3tc_only_pck_is_reported(self):
        make_zip(self.zip, pck_paths=[GOOD_PCK_PATHS[0], GOOD_PCK_PATHS[3]])
        self.assertTrue(any("texture format" in p for p in export_all.check_macos_zip(self.zip)))

    def test_garbage_file_is_reported_not_raised(self):
        with open(self.zip, "wb") as f:
            f.write(b"not a zip")
        self.assertTrue(export_all.check_macos_zip(self.zip))


class PublishMacosTest(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.TemporaryDirectory()
        self.addCleanup(self.dir.cleanup)
        os.makedirs(os.path.join(self.dir.name, "build", "macos"))
        self.zip = os.path.join(self.dir.name, publish_github.MACOS_ZIP)
        self._root = publish_github.ROOT
        publish_github.ROOT = self.dir.name
        self.addCleanup(setattr, publish_github, "ROOT", self._root)

    def run_asset(self):
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            result = publish_github.macos_asset()
        return result, buf.getvalue()

    def test_missing_zip_warns_and_returns_none(self):
        result, out = self.run_asset()
        self.assertIsNone(result)
        self.assertIn("WITHOUT the macOS build", out)

    def test_invalid_zip_warns_and_returns_none(self):
        with open(self.zip, "wb") as f:
            f.write(b"junk")
        result, out = self.run_asset()
        self.assertIsNone(result)
        self.assertIn("unusable", out)

    def test_zip_without_the_app_warns_and_returns_none(self):
        with zipfile.ZipFile(self.zip, "w") as z:
            z.writestr("readme.txt", "x")
        result, out = self.run_asset()
        self.assertIsNone(result)
        self.assertIn("missing RLDB.app/Contents/MacOS/RLDB", out)

    def test_good_zip_is_returned_with_its_time(self):
        make_zip(self.zip)
        result, _ = self.run_asset()
        self.assertEqual(result[0], self.zip)
        self.assertEqual(os.path.basename(result[0]), "RLDB-macos.zip")

    def test_release_notes_explain_macos_only_when_shipped(self):
        with_mac = publish_github.release_notes("1.2.3", "abc", "", "- fix", True)
        without = publish_github.release_notes("1.2.3", "abc", "", "- fix", False)
        self.assertIn("RLDB-macos.zip", with_mac)
        self.assertIn("right-click", with_mac)
        self.assertIn("xattr -cr", with_mac)
        self.assertNotIn("RLDB-macos.zip", without)
        self.assertIn("RLDB-friends.zip", without)
        self.assertIn("RLDB 1.2.3", with_mac)

    def test_release_notes_keep_extra_text_and_log(self):
        notes = publish_github.release_notes("1.2.3", "abc", "Owner text", "- a change", True)
        self.assertIn("Owner text", notes)
        self.assertIn("- a change", notes)
        self.assertIn("local commit abc", notes)


if __name__ == "__main__":
    unittest.main()
