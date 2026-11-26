"""Replay real GTK/X11 pixel evidence through the paint/stability checks.

Run with: python -m unittest discover -s examples/fdg/tests/dialog -p test_capture.py
Requires Pillow and Tesseract's English data; no desktop session is used.
"""
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from PIL import Image

import linux

EVIDENCE = Path(__file__).parent / "evidence"


class CaptureTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix="fdg-capture-test-")
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.record = json.loads((EVIDENCE / "result.json").read_text())

    def image(self, name):
        with Image.open(EVIDENCE / name) as image:
            return image.convert("RGB")

    def replay(self, frames, regions):
        def bounded_wait(test, description):
            for _ in frames:
                result = test()
                if result is not None:
                    return result
            raise TimeoutError(description)

        with patch.dict(os.environ, DISPLAY=":pixel-fixture"), \
                patch.object(linux.ImageGrab, "grab", side_effect=frames) as grab, \
                patch.object(linux, "wait", side_effect=bounded_wait):
            result = linux.capture(self.root, "capture", regions)
            return result, grab.call_count

    def test_stable_prior_graph_is_rejected(self):
        graph = self.image("negative/unpainted-chooser.png")
        regions = self.record["captures"]["current.svg-chooser"]["regions"]
        with self.assertRaises(TimeoutError):
            self.replay([graph, graph, graph], regions)
        self.assertFalse((self.root / "capture.png").exists())
        self.assertFalse(json.loads((self.root / "capture-timeout.json").read_text())["verified"])

    def test_stability_starts_after_expected_paint(self):
        graph = self.image("negative/unpainted-chooser.png")
        chooser = self.image("current.svg-chooser.png")
        regions = self.record["captures"]["current.svg-chooser"]["regions"]
        result, count = self.replay([graph, graph, chooser, chooser], regions)
        self.assertEqual(count, 4)
        self.assertEqual(result.tobytes(), chooser.tobytes())
        self.assertTrue(json.loads((self.root / "capture.json").read_text())["verified"])

    def test_unpainted_frame_resets_stability(self):
        chooser = self.image("current.svg-chooser.png")
        graph = self.image("negative/unpainted-chooser.png")
        regions = self.record["captures"]["current.svg-chooser"]["regions"]
        with self.assertRaises(TimeoutError):
            self.replay([chooser, graph, graph], regions)

    def test_wrong_cancellation_status_is_rejected(self):
        wrong = self.image("negative/wrong-cancellation.png")
        regions = self.record["captures"]["cancelled.svg-result"]["regions"]
        with self.assertRaises(TimeoutError):
            self.replay([wrong, wrong, wrong], regions)
        observed = json.loads((self.root / "capture-timeout.json").read_text())["observed"]
        self.assertIn("Export incorrect", observed["status"])


if __name__ == "__main__":
    unittest.main()
