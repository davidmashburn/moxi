"""Chrome regressions for checkpoint, selection, report and bounded playback.

Run with PYTHONPATH=python:examples/oscillator. V07_EVIDENCE optionally retains
screenshots, the offline report and a source/environment manifest outside source.
"""
import hashlib
import json
import os
import platform
import threading
import unittest
from datetime import datetime, timezone
from pathlib import Path
from tempfile import TemporaryDirectory

from playwright.sync_api import expect, sync_playwright

from serve import Handler, ROOT, ThreadingHTTPServer


class QuietHandler(Handler):
    def log_message(self, *args):
        pass


class BrowserTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temporary = TemporaryDirectory()
        cls.out = Path(os.environ.get("V07_EVIDENCE", cls.temporary.name))
        cls.out.mkdir(parents=True, exist_ok=True)
        cls.server = ThreadingHTTPServer(("127.0.0.1", 0), QuietHandler)
        threading.Thread(target=cls.server.serve_forever, daemon=True).start()
        cls.url = f"http://127.0.0.1:{cls.server.server_port}/"
        cls.pw = sync_playwright().start()
        cls.browser = cls.pw.chromium.launch(channel="chrome")
        cls.evidence = dict(captured=datetime.now(timezone.utc).isoformat(),
                            url=cls.url, chrome=cls.browser.version,
                            python=platform.python_version(), platform=platform.platform(),
                            viewport=[1000, 850], checkout=str(ROOT.parent.parent),
                            sources={p.name: hashlib.sha256(p.read_bytes()).hexdigest()
                                     for p in ROOT.iterdir() if p.suffix in {".py", ".js", ".html", ".css"}},
                            scenarios=[])

    @classmethod
    def tearDownClass(cls):
        (cls.out / "manifest.json").write_text(json.dumps(cls.evidence, indent=2) + "\n")
        cls.browser.close()
        cls.pw.stop()
        cls.server.shutdown()
        cls.server.server_close()
        cls.temporary.cleanup()

    def setUp(self):
        self.context = self.browser.new_context(viewport={"width": 1000, "height": 850})
        self.page = self.context.new_page()
        self.page.set_default_timeout(5000)
        self.errors = []
        self.page.on("pageerror", lambda error: self.errors.append(str(error)))
        self.page.goto(self.url)

    def tearDown(self):
        result = self._outcome.result
        failed = any(test.id().startswith(self.id()) for test, _ in result.failures + result.errors)
        self.evidence["scenarios"].append(dict(test=self.id(), passed=not failed and not self.errors,
                                               pageErrors=self.errors))
        self.context.close()
        self.assertEqual(self.errors, [])

    def field(self, name):
        return self.page.locator("#" + name)

    def click(self, name):
        self.field(name).click()

    def press(self, name):
        target = self.field(name)
        for _ in range(80):
            if target.evaluate("e => e === document.activeElement"):
                self.page.keyboard.press("Enter")
                return
            self.page.keyboard.press("Tab")
        self.fail("Keyboard could not reach " + name)

    def begin(self):
        self.field("prediction").fill("Four times the mass should double the period.")
        self.click("lock")
        self.click("compare")
        expect(self.field("summary")).to_contain_text("3.142 s")

    def reveal(self, text):
        self.click("next")
        self.field("answer").fill(text)
        self.click("reveal")
        expect(self.field("feedback")).to_contain_text("1.571 s")

    def capture(self, name, target):
        self.field(target).scroll_into_view_if_needed()
        self.page.screenshot(path=self.out / name)

    def test_checkpoint_restores_progress_text_and_unrevealed_status(self):
        self.begin()
        self.field("note").fill("Original observation")
        self.click("branch")
        self.field("note").fill("Exploration observation")
        self.reveal("Exploration explanation")
        self.click("restore")
        expect(self.field("checkpoint")).to_have_text("Checkpoint restored.")
        expect(self.field("transfer")).to_be_hidden()
        expect(self.field("answer")).to_have_value("")
        self.assertFalse(self.field("answer").evaluate("e => e.readOnly"))
        expect(self.field("reveal")).to_be_enabled()
        expect(self.field("feedback")).to_be_empty()
        expect(self.field("note")).to_have_value("Original observation")
        expect(self.field("prediction")).to_have_value("Four times the mass should double the period.")
        self.click("next")
        self.click("reveal")
        expect(self.field("answerError")).to_contain_text("Write an explanation")
        expect(self.field("feedback")).to_be_empty()
        self.capture("checkpoint-unrevealed.png", "transfer")

    def test_checkpoint_retains_partial_and_revealed_answers(self):
        self.begin()
        self.click("next")
        self.field("answer").fill("Unfinished explanation")
        self.click("branch")
        self.field("answer").fill("Branch explanation")
        self.click("reveal")
        expect(self.field("feedback")).to_contain_text("1.571 s")
        self.click("restore")
        expect(self.field("checkpoint")).to_have_text("Checkpoint restored.")
        expect(self.field("transfer")).to_be_visible()
        expect(self.field("answer")).to_have_value("Unfinished explanation")
        expect(self.field("reveal")).to_be_enabled()
        expect(self.field("feedback")).to_be_empty()
        self.click("reveal")
        expect(self.field("feedback")).to_contain_text("1.571 s")
        feedback = self.field("feedback").inner_text()
        self.click("branch")
        self.click("restore")
        expect(self.field("checkpoint")).to_have_text("Checkpoint restored.")
        expect(self.field("feedback")).to_have_text(feedback)
        self.assertTrue(self.field("answer").evaluate("e => e.readOnly"))
        expect(self.field("reveal")).to_be_disabled()

    def test_formula_return_retains_active_selection_end(self):
        self.begin()
        self.field("note").fill("0123456789")
        def selection():
            return self.field("note").evaluate("e => [e.selectionStart,e.selectionEnd,e.selectionDirection]")
        def select(backward):
            self.field("note").focus()
            # Home scrolls on macOS; collapse and walk to the start with native
            # editing keys so both OS keyboard conventions produce [3, 6].
            for _ in range(11):
                self.page.keyboard.press("ArrowLeft")
            for _ in range(6 if backward else 3):
                self.page.keyboard.press("ArrowRight")
            for _ in range(3):
                self.page.keyboard.press("Shift+ArrowLeft" if backward else "Shift+ArrowRight")
            self.assertEqual(selection(), [3, 6, "backward" if backward else "forward"])
        for backward in (True, False):
            for key in ("Shift+ArrowLeft", "Shift+ArrowRight"):
                for escape in (False, True):
                    with self.subTest(backward=backward, key=key, escape=escape):
                        select(backward)
                        self.page.keyboard.press(key)
                        baseline = selection()
                        select(backward)
                        expected = selection()
                        self.click("inspect")
                        self.click("define")
                        self.page.evaluate("window.closedDetail=false; document.querySelector('#detail').addEventListener('close',()=>window.closedDetail=true,{once:true})")
                        if escape:
                            self.page.keyboard.press("Escape")
                        else:
                            self.click("back")
                        self.page.wait_for_function("window.closedDetail")
                        expect(self.field("note")).to_be_focused()
                        self.assertEqual(selection(), expected)
                        self.page.keyboard.press(key)
                        self.assertEqual(selection(), baseline)

    def test_restore_discards_inflight_compare_and_reveal(self):
        self.begin()
        self.click("branch")
        pending = []
        self.page.route("**/run?*", lambda route: pending.append((route, route.fetch())))
        self.field("m").fill("9")
        with self.page.expect_request("**/run?*"):
            self.click("compare")
        self.click("next")
        self.field("answer").fill("Late branch explanation")
        with self.page.expect_request("**/run?*"):
            self.click("reveal")
        self.click("restore")
        expect(self.field("checkpoint")).to_have_text("Checkpoint restored.")
        self.assertEqual(len(pending), 2)
        for route, response in pending:
            route.fulfill(response=response)
            response.dispose()
        self.page.wait_for_load_state("networkidle")
        expect(self.field("m")).to_have_value("4")
        expect(self.field("summary")).to_contain_text("3.142 s")
        expect(self.field("transfer")).to_be_hidden()
        expect(self.field("feedback")).to_be_empty()
        expect(self.field("answer")).to_have_value("")
        self.page.unroute("**/run?*")

    def test_restore_uses_saved_result_when_network_is_unavailable(self):
        self.begin()
        self.click("branch")
        self.field("m").fill("9")
        self.click("compare")
        expect(self.field("summary")).to_contain_text("4.712 s")
        self.click("insert")
        self.page.route("**/run?*", lambda route: route.abort("failed"))
        self.click("restore")
        expect(self.field("checkpoint")).to_have_text("Checkpoint restored.")
        expect(self.field("summary")).to_contain_text("3.142 s")
        expect(self.field("entry")).to_contain_text("Exploration: m = 9")
        expect(self.field("insert")).to_be_disabled()
        self.page.unroute("**/run?*")

    def test_failed_requests_remain_retryable(self):
        self.begin()
        self.click("branch")
        self.page.route("**/run?*", lambda route: route.abort("failed"))
        self.field("m").fill("9")
        self.click("compare")
        expect(self.field("error")).to_contain_text("Failed to fetch")
        expect(self.field("insert")).to_be_disabled()
        expect(self.field("summary")).to_contain_text("3.142 s")
        self.click("next")
        self.field("answer").fill("A synthetic explanation")
        self.click("reveal")
        expect(self.field("error")).to_contain_text("Failed to fetch")
        expect(self.field("reveal")).to_be_enabled()
        self.assertFalse(self.field("answer").evaluate("e => e.readOnly"))
        expect(self.field("feedback")).to_be_empty()
        self.page.unroute("**/run?*")
        self.click("reveal")
        expect(self.field("feedback")).to_contain_text("1.571 s")
        self.click("compare")
        expect(self.field("summary")).to_contain_text("4.712 s")
        expect(self.field("insert")).to_be_enabled()

    def test_report_distinguishes_control_checkpoint_and_exploration_offline(self):
        self.begin()
        self.click("branch")
        self.field("m").fill("9")
        self.click("compare")
        expect(self.field("summary")).to_contain_text("4.712 s")
        self.field("note").fill("<synthetic> & safe")
        self.click("insert")
        with self.page.expect_download() as download:
            self.click("download")
        report = self.out / "spring-report.html"
        download.value.save_as(report)
        self.click("restore")
        expect(self.field("checkpoint")).to_have_text("Checkpoint restored.")
        expect(self.field("entry")).to_contain_text("Exploration: m = 9")
        offline = self.context.new_page()
        requests = []
        offline.on("request", lambda req: requests.append(req.url))
        offline.goto(report.as_uri())
        text = offline.locator("body").inner_text()
        self.assertIn("Plotted reference: m = 1 kg, k = 16 N/m, A = 0.5 m; T = 1.571 s", text)
        self.assertIn("Checkpoint: m = 4 kg, k = 16 N/m, A = 0.5 m; T = 3.142 s (not plotted)", text)
        self.assertIn("Exploration: m = 9 kg, k = 16 N/m, A = 0.5 m; T = 4.712 s", text)
        self.assertIn("<synthetic> & safe", text)
        svg = offline.locator("svg")
        expect(svg).to_have_count(1)
        legend = svg.locator("[data-legend]")
        expect(legend).to_contain_text("Reference (1 kg)")
        expect(legend).to_contain_text("Trial (9 kg)")
        expect(legend).to_contain_text("Time probe")
        self.assertEqual(legend.locator("line").evaluate_all("es => es.map(e => e.getAttribute('stroke'))"),
                         svg.locator("polyline").evaluate_all("es => es.map(e => e.getAttribute('stroke'))"))
        self.assertFalse(any(url.startswith(("http:", "https:")) for url in requests), requests)
        offline.screenshot(path=self.out / "report-offline.png", full_page=True)
        offline.close()

    def test_recorded_five_steps_pause_explore_restore_and_resume(self):
        self.press("play")
        expect(self.field("playStatus")).to_contain_text("1 of 5")
        self.press("step")
        expect(self.field("playStatus")).to_contain_text("2 of 5")
        self.press("step")
        expect(self.field("playStatus")).to_contain_text("3 of 5")
        expect(self.field("step")).to_be_disabled()
        expect(self.field("restore")).to_be_enabled()
        expect(self.field("m")).to_have_value("4")
        expect(self.field("summary")).to_contain_text("3.142 s")
        self.capture("recorded-step-three.png", "playStatus")
        self.field("m").fill("9")
        self.click("compare")
        expect(self.field("summary")).to_contain_text("4.712 s")
        self.reveal("An exploration answer must not contaminate playback.")
        self.press("restore")
        expect(self.field("checkpoint")).to_have_text("Checkpoint restored.")
        expect(self.field("transfer")).to_be_hidden()
        expect(self.field("feedback")).to_be_empty()
        expect(self.field("m")).to_have_value("4")
        expect(self.field("step")).to_be_enabled()
        self.page.set_viewport_size({"width": 390, "height": 844})
        self.press("step")
        expect(self.field("playStatus")).to_contain_text("4 of 5")
        expect(self.field("point")).to_contain_text("At 0.5 s")
        expect(self.field("term")).to_contain_text("−Aω")
        self.press("step")
        expect(self.field("playStatus")).to_contain_text("5 of 5")
        expect(self.field("step")).to_be_disabled()
        expect(self.field("note")).to_have_value("Quadrupling mass doubles the period; the 1 kg reference is unchanged.")
        self.assertTrue(self.page.evaluate("document.documentElement.scrollWidth <= innerWidth"))
        self.capture("recorded-complete-narrow.png", "playStatus")
        self.page.reload()
        expect(self.field("lab")).to_be_hidden()
        expect(self.field("prediction")).to_have_value("")


if __name__ == "__main__":
    unittest.main()
