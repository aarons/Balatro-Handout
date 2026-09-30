"""Exercise the real installer against isolated Mods directories."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


class InstallerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="neow test ")
        self.addCleanup(self.temp.cleanup)
        self.mods = Path(self.temp.name) / "Mods"
        self.mods.mkdir()
        self.dest = self.mods / "NeowBlessings"

    def run_installer(self, *args, script=None):
        return subprocess.run(
            ["bash", str(script or ROOT / "install.sh"), *args],
            env={**os.environ, "BALATRO_MODS_DIR": str(self.mods)},
            cwd=self.temp.name, capture_output=True, text=True,
        )

    def test_install_update_uninstall_preserves_neighbors(self):
        neighbor = self.mods / "another-mod.lua"
        neighbor.write_text("keep")
        settings = self.mods.parent / "config" / "NeowBlessings.jkr"
        settings.parent.mkdir()
        settings.write_text("player settings")
        self.assertEqual(self.run_installer().returncode, 0)
        self.assertEqual((self.dest / "neow_blessings.lua").read_bytes(),
                         (ROOT / "neow_blessings.lua").read_bytes())
        self.assertTrue((self.dest / "assets/1x/j_neow.png").is_file())
        self.assertTrue((self.dest / "localization/en-us.lua").is_file())
        for excluded in (".git", "tests", "install.sh", "screenshots"):
            self.assertFalse((self.dest / excluded).exists())
        (self.dest / "neow_blessings.lua").write_text("stale version")
        (self.dest / "assets/stale.png").write_text("obsolete asset")
        self.assertEqual(self.run_installer().returncode, 0)
        self.assertFalse((self.dest / "assets/stale.png").exists())
        self.assertEqual((self.dest / "neow_blessings.lua").read_bytes(),
                         (ROOT / "neow_blessings.lua").read_bytes())
        self.assertEqual(self.run_installer("--uninstall").returncode, 0)
        self.assertFalse(self.dest.exists())
        self.assertEqual(self.run_installer("--uninstall").returncode, 0)
        self.assertEqual(neighbor.read_text(), "keep")
        self.assertEqual(settings.read_text(), "player settings")

    def test_refuses_unrecognized_destination(self):
        self.dest.mkdir()
        sentinel = self.dest / "keep"
        sentinel.write_text("keep")
        for args in ((), ("--uninstall",)):
            self.assertNotEqual(self.run_installer(*args).returncode, 0)
            self.assertEqual(sentinel.read_text(), "keep")

    def test_refuses_symlink_and_source_checkout(self):
        self.dest.symlink_to(ROOT, target_is_directory=True)
        self.assertNotEqual(self.run_installer("--uninstall").returncode, 0)
        self.dest.unlink()
        self.dest.mkdir()
        script = self.dest / "install.sh"
        script.write_bytes((ROOT / "install.sh").read_bytes())
        for args in ((), ("--uninstall",)):
            self.assertNotEqual(self.run_installer(*args, script=script).returncode, 0)
            self.assertTrue(script.exists())

    def test_argument_validation_and_missing_directory(self):
        self.assertEqual(self.run_installer("--help").returncode, 0)
        self.assertEqual(self.run_installer("--typo").returncode, 2)
        self.assertEqual(self.run_installer("--uninstall", "extra").returncode, 2)
        self.mods.rmdir()
        self.assertNotEqual(self.run_installer().returncode, 0)


if __name__ == "__main__":
    unittest.main()
