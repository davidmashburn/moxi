import asyncio
import json
import unittest

from recorder import CaptureMode, capture, inspect_episode


class RecorderTest(unittest.TestCase):
    def test_round_trip(self):
        episode = asyncio.run(capture(CaptureMode.COMPLETE))
        self.assertEqual(episode, asyncio.run(capture(CaptureMode.COMPLETE)))
        self.assertEqual([s[0] for s in episode["samples"]], list(range(12, 24)))
        self.assertEqual(episode["dropped"], 12)
        self.assertEqual(episode["result"]["peak"], 84)
        view = inspect_episode(json.loads(json.dumps(episode)))
        self.assertEqual(view["missing"], [])
        self.assertIn("<svg", view["svg"])
        episode["samples"][0][1] = 0
        self.assertNotEqual(view["svg"], inspect_episode(episode)["svg"])

    def test_incomplete(self):
        episode = asyncio.run(capture(CaptureMode.OMIT_RESULT))
        del episode["samples"][1]
        self.assertIsNone(episode["result"])
        self.assertEqual(inspect_episode(episode)["missing"], [13])
        episode["samples"].clear()
        self.assertEqual(inspect_episode(episode)["svg"], "")

    def test_reject_bad_ticks_and_unrelated_result(self):
        episode = asyncio.run(capture(CaptureMode.COMPLETE))
        episode["result"]["request"] = "other"
        with self.assertRaises(ValueError):
            inspect_episode(episode)
        del episode["result"]
        episode["samples"].reverse()
        with self.assertRaises(ValueError):
            inspect_episode(episode)
