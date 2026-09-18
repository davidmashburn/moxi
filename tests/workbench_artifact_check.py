"""Failure-path checks against disposable copies of the built app."""
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
from workbench_artifact_check import validate


class ArtifactChecks(unittest.TestCase):
    def test_built_bundle(self):
        manifest = validate(ROOT / "dist/Moxi Data Workbench.app")
        self.assertEqual(len(manifest["executable_sha256"]), 64)

    def test_broken_resource_seal_is_rejected(self):
        with tempfile.TemporaryDirectory(prefix="moxi-broken-bundle-") as temp:
            app = Path(temp) / "Moxi Data Workbench.app"
            shutil.copytree(ROOT / "dist/Moxi Data Workbench.app", app)
            (app / "Contents/Resources/build.json").write_text("{}\n")
            with self.assertRaises(subprocess.CalledProcessError):
                validate(app)

    def test_missing_guard_input_is_rejected(self):
        with tempfile.TemporaryDirectory(prefix="moxi-missing-prose-") as temp:
            result = subprocess.run(["bash", str(ROOT / "scripts/prose_artifact_check.sh"),
                                     str(Path(temp) / "missing.md")], capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("missing or unreadable", result.stderr)

    def test_editor_artifact_is_rejected(self):
        with tempfile.TemporaryDirectory(prefix="moxi-invalid-prose-") as temp:
            prose = Path(temp) / "note.md"
            prose.write_text("Use code with caution\n")
            result = subprocess.run(["bash", str(ROOT / "scripts/prose_artifact_check.sh"), str(prose)],
                                    capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("editor artifacts", result.stderr)


if __name__ == "__main__":
    unittest.main()
