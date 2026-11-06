"""Evidence validation and offline artifact regression checks (synthetic unit fixture)."""

import base64
import copy
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("slideshows", Path(__file__).parents[1] / "scripts/demo_slideshows.py")
slideshows = importlib.util.module_from_spec(spec)
spec.loader.exec_module(slideshows)

PNG = base64.b64decode("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+j4O8AAAAASUVORK5CYII=")


class SlideshowTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.demo = self.root / "unit-fixture"
        self.demo.mkdir()
        (self.demo / "unit.png").write_bytes(PNG)
        self.path = self.demo / "manifest.json"
        self.manifest = dict(version=1, demo_id="unit-fixture", title="<script>alert(1)</script>",
                             scenario="unit fixture only", host="unit", backend="unit", fixture="unit",
                             reproduce="unit-test", revision="abcdef0", scale=1,
                             slides=[dict(phase=phase, capture_kind="offscreen-render", image="unit.png",
                                          dimensions=[1, 1], caption="a 'quote' & <markup>",
                                          action="unit action", expected="unit result")
                                     for phase in ("initial", "interaction", "result", "recovery")])

    def load(self, manifest=None):
        self.path.write_text(json.dumps(manifest or self.manifest))
        return slideshows.load_manifest(self.path)

    def test_portable_html_escapes_metadata_and_parses_domains(self):
        loaded = self.load()
        self.assertIs(loaded["slides"][0]["phase"], slideshows.Phase.INITIAL)
        self.assertIs(loaded["slides"][0]["capture_kind"], slideshows.CaptureKind.OFFSCREEN)
        self.assertEqual(slideshows.build(self.root), 1)
        output = (self.demo / "index.html").read_text()
        self.assertIn("data:image/png;base64,", output)
        self.assertIn("&lt;script&gt;", output)
        self.assertNotIn("<script>alert(1)</script>", output)
        self.assertIn("ArrowRight", output)
        self.assertIn("unit-fixture/index.html", (self.root / "index.html").read_text())

    def test_missing_recovery_cannot_be_called_complete(self):
        self.manifest["slides"].pop()
        with self.assertRaisesRegex(ValueError, "recovery"):
            self.load()

    def test_reject_outside_image_even_if_it_exists(self):
        (self.root / "outside.png").write_bytes(PNG)
        self.manifest["slides"][0]["image"] = "../outside.png"
        with self.assertRaisesRegex(ValueError, "inside"):
            self.load()

    def test_reject_dimensions_missing_image_and_unknown_capture_kind(self):
        for field, value in (("dimensions", [2, 1]), ("image", "missing.png"),
                             ("capture_kind", "mockup"), ("phase", "almost-done")):
            with self.subTest(field=field):
                manifest = copy.deepcopy(self.manifest)
                manifest["slides"][0][field] = value
                with self.assertRaises((ValueError, FileNotFoundError)):
                    self.load(manifest)


if __name__ == "__main__":
    unittest.main()
