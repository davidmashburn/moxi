import json
from pathlib import Path
import unittest
from xml.etree import ElementTree

from app import FIXTURE, MISSING_FIXTURE, ReplayMode, build, replay


class DebuggerTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        build()

    def episode(self, path=FIXTURE):
        return json.loads(Path(path).read_text())

    def test_measured_dispatch_and_frame(self):
        view = replay(self.episode(), ReplayMode.LOCALIZED, 16)
        self.assertIs(ReplayMode(view["mode"]), ReplayMode.LOCALIZED)
        self.assertEqual(view["summary"]["builds"], [13, 2])
        self.assertEqual(view["summary"]["final"], ["32", "84"])
        self.assertEqual(view["summary"]["emitted"], 13)
        self.assertEqual(view["summary"]["dropped"], 0)
        first, last = view["records"][0], view["records"][-1]
        self.assertEqual((first["tick"], first["value"]), (12, 25))
        self.assertEqual([work["builds"] for work in first["work"]], [1, 0])
        self.assertEqual([work["visits"] for work in last["work"]], [0, 1])
        self.assertEqual(last["before"], ["32", "Unavailable"])
        self.assertEqual(last["after"], ["32", "84"])
        self.assertEqual(last["tick"], -1)  # Unknown source completion time.
        text = " ".join(ElementTree.fromstring(last["svg"]).itertext())
        self.assertIn("32", text)
        self.assertIn("84", text)
        for record in view["records"]:
            self.assertGreaterEqual(record["dispatch_ns"], 0)
            self.assertGreater(sum(w["paints"] for w in record["work"]), 0)

    def test_replays_compare_actual_work_and_same_frames(self):
        normal = replay(self.episode(), ReplayMode.LOCALIZED, 16)
        broad = replay(self.episode(), ReplayMode.BROAD, 16)
        repeat = replay(self.episode(), ReplayMode.LOCALIZED, 16)
        self.assertEqual(broad["summary"]["builds"], [14, 14])
        for view in (broad, repeat):
            self.assertEqual(normal["episode_id"], view["episode_id"])
            self.assertEqual(normal["summary"]["final"], view["summary"]["final"])
            self.assertEqual([r["svg"] for r in normal["records"]],
                             [r["svg"] for r in view["records"]])
        for record in broad["records"]:
            self.assertEqual([work["builds"] for work in record["work"]], [1, 1])

    def test_trace_eviction_is_independent_of_source_eviction(self):
        all_frames = replay(self.episode(), ReplayMode.LOCALIZED, 16)
        bounded = replay(self.episode(), ReplayMode.LOCALIZED, 5)
        self.assertEqual(bounded["source_dropped"], 12)
        self.assertEqual(bounded["summary"]["dropped"], 8)
        self.assertEqual([r["ordinal"] for r in bounded["records"]], list(range(9, 14)))
        self.assertEqual([r["svg"] for r in bounded["records"]],
                         [r["svg"] for r in all_frames["records"][-5:]])
        self.assertEqual(bounded["summary"]["final"], all_frames["summary"]["final"])

    def test_incomplete_and_empty_episodes_do_not_invent_actions(self):
        episode = self.episode(MISSING_FIXTURE)
        view = replay(episode, ReplayMode.LOCALIZED, 16)
        self.assertEqual(view["missing_ticks"], [13])
        self.assertTrue(view["missing_result"])
        self.assertEqual(view["summary"]["emitted"], 11)
        self.assertEqual(view["summary"]["final"], ["32", "Unavailable"])
        self.assertTrue(all(r["action"] == "sample" for r in view["records"]))
        episode["samples"] = []
        empty = replay(episode, ReplayMode.LOCALIZED, 1)
        self.assertEqual(empty["records"], [])
        self.assertEqual(empty["summary"]["builds"], [1, 1])
        self.assertEqual(empty["summary"]["emitted"], 0)

    def test_input_affects_real_frame_and_boundary_rejects_bad_data(self):
        episode = self.episode()
        original = replay(episode, ReplayMode.LOCALIZED, 16)
        episode["samples"][0][1] = 99
        modified = replay(episode, ReplayMode.LOCALIZED, 16)
        self.assertNotEqual(original["records"][0]["svg"], modified["records"][0]["svg"])
        self.assertEqual(modified["records"][0]["after"][0], "99")
        for capacity in (0, 33, True, 1.5, "5"):
            with self.assertRaises(ValueError):
                replay(episode, ReplayMode.LOCALIZED, capacity)
        with self.assertRaises(ValueError):
            replay(episode, "localized", 16)
        with self.assertRaises(ValueError):
            ReplayMode("unsupported")
        episode["result"]["request"] = "unrelated"
        with self.assertRaises(ValueError):
            replay(episode, ReplayMode.LOCALIZED, 16)


if __name__ == "__main__":
    unittest.main()
