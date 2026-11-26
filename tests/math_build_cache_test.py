"""Exercise rebuild decisions without requiring the native compiler toolchain."""

import importlib.util
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch


SPEC = importlib.util.spec_from_file_location(
    "math_build_cache", Path(__file__).resolve().parents[1] / "scripts/math/build_cached.py"
)
cache = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(cache)


class MathBuildCacheTests(unittest.TestCase):
    def setUp(self):
        self.original_cwd = Path.cwd()
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.repo = self.root / "repo"
        self.work = self.root / "outputs"
        self.hb = self.root / "harfbuzz"
        for name in (
            "pixi.toml", "pixi.lock", "src/example.mojo", "native/macos_window.m",
            "scripts/math/build_cached.py", "scripts/math/build.sh",
        ):
            path = self.repo / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("fixture")
        for name in ("include/harfbuzz/hb.h", "lib/libharfbuzz.dylib"):
            path = self.hb / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("fixture")
        self.patches = [
            patch.object(cache, "__file__", str(self.repo / "scripts/math/build_cached.py")),
            patch.dict(os.environ, {"MOXI_D02_BUILD_DIR": str(self.work),
                                    "MOXI_HARFBUZZ_PREFIX": str(self.hb)}),
            patch.object(cache.subprocess, "check_output", return_value="tool version"),
            patch.object(cache.subprocess, "run", side_effect=self.build),
        ]
        for item in self.patches:
            item.start()
        self.builds = 0

    def tearDown(self):
        os.chdir(self.original_cwd)
        for item in reversed(self.patches):
            item.stop()
        self.temp.cleanup()

    def build(self, *args, **kwargs):
        self.builds += 1
        for name in ("window.o", "font.o", "workbench", "consumer"):
            path = self.work / name
            path.write_text("compiled fixture")
            path.chmod(0o755)

    def test_unchanged_build_is_reused(self):
        cache.main()
        cache.main()
        self.assertEqual(self.builds, 1)

    def test_forced_build_refreshes_cache(self):
        cache.main()
        cache.main(force=True)
        cache.main()
        self.assertEqual(self.builds, 2)

    def test_source_and_harfbuzz_changes_rebuild(self):
        cache.main()
        for path in (self.repo / "src/example.mojo", self.hb / "include/harfbuzz/hb.h",
                     self.hb / "lib/libharfbuzz.dylib", self.repo / "pixi.lock"):
            path.write_text("changed")
            cache.main()
        self.assertEqual(self.builds, 5)

    def test_missing_corrupt_or_nonexecutable_output_rebuilds(self):
        cache.main()
        (self.work / "consumer").unlink()
        cache.main()
        (self.work / "font.o").write_text("corrupt")
        cache.main()
        (self.work / "workbench").chmod(0o644)
        cache.main()
        self.assertEqual(self.builds, 4)

    def test_toolchain_and_sdk_environment_changes_rebuild(self):
        cache.main()
        with patch.object(cache.subprocess, "check_output", return_value="new version"):
            cache.main()
            with patch.dict(os.environ, {"SDKROOT": "/fixture-sdk"}):
                cache.main()
        self.assertEqual(self.builds, 3)

    def test_failed_build_cannot_leave_a_cache_hit(self):
        cache.main()
        (self.repo / "src/example.mojo").write_text("changed")
        with patch.object(cache.subprocess, "run", side_effect=subprocess.CalledProcessError(1, "build")):
            with self.assertRaises(subprocess.CalledProcessError):
                cache.main()
        self.assertFalse((self.work / ".build-cache.json").exists())
        cache.main()
        self.assertEqual(self.builds, 2)


if __name__ == "__main__":
    unittest.main()
