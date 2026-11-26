"""Real Chrome regressions. MATRIX_EVIDENCE retains captures and a manifest."""
import hashlib
import json
import os
import platform
import subprocess
import threading
import unittest
from datetime import datetime, timezone
from pathlib import Path
from tempfile import TemporaryDirectory

import moxi
from playwright.sync_api import expect, sync_playwright

from matrix import Matrix
from serve import ROOT, ThreadingHTTPServer
from test_matrix import QuietHandler


class BrowserTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temporary = TemporaryDirectory()
        cls.retain = bool(os.environ.get("MATRIX_EVIDENCE"))
        cls.out = Path(os.environ.get("MATRIX_EVIDENCE", cls.temporary.name)).resolve()
        cls.out.mkdir(parents=True, exist_ok=True)
        repo = ROOT.parent.parent
        assert Path(moxi.__file__).resolve() == repo / "python/moxi/__init__.py"
        cls.server = ThreadingHTTPServer(("127.0.0.1", 0), QuietHandler)
        cls.worker = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.worker.start()
        cls.url = f"http://127.0.0.1:{cls.server.server_port}/"
        cls.pw = sync_playwright().start()
        cls.browser = cls.pw.chromium.launch(channel="chrome")

        def git(*args):
            return subprocess.check_output(["git", *args], cwd=repo, text=True).strip()

        cls.evidence = dict(captured=datetime.now(timezone.utc).isoformat(),
                            revision=git("rev-parse", "HEAD"), base=git("merge-base", "HEAD", "origin/main"),
                            sourceState="Source hashes below include the tested uncommitted changes, if any.",
                            url=cls.url, chrome=cls.browser.version, python=platform.python_version(),
                            platform=platform.platform(), renderer="python/moxi/figure.py · python-reference",
                            rendererSha256=hashlib.sha256((repo / "python/moxi/figure.py").read_bytes()).hexdigest(),
                            fixture="Synthetic 2I matrix; no accounts, external services or persisted data.",
                            voiceOver="Paused; no assistive-technology checks performed.",
                            sources={p.name: hashlib.sha256(p.read_bytes()).hexdigest()
                                     for p in sorted(ROOT.iterdir()) if p.suffix in {".py", ".js", ".css", ".html"}},
                            scenarios=[], slides=[])

    @classmethod
    def tearDownClass(cls):
        cls.evidence["slides"].sort(key=lambda slide: slide["image"])
        (cls.out / "manifest.json").write_text(json.dumps(cls.evidence, indent=2) + "\n")
        cls.browser.close()
        cls.pw.stop()
        cls.server.shutdown()
        cls.server.server_close()
        cls.worker.join()
        cls.temporary.cleanup()

    def setUp(self):
        self.context = self.browser.new_context(viewport={"width": 1366, "height": 1100})
        self.page = self.context.new_page()
        self.page.set_default_timeout(5000)
        self.errors, self.failed_requests = [], []
        self.page.on("pageerror", lambda error: self.errors.append(str(error)))
        self.page.on("requestfailed", lambda request: self.failed_requests.append(dict(url=request.url, error=request.failure)))
        self.page.goto(self.url)
        self.ready("4")

    def tearDown(self):
        result = self._outcome.result
        failed = any(test.id().startswith(self.id()) for test, _ in result.failures + result.errors)
        self.evidence["scenarios"].append(dict(test=self.id(), steps=self._testMethodDoc,
                                               expected="All named assertions pass; no uncaught page errors.",
                                               observed="Assertion failure; see test log." if failed else "All assertions passed.",
                                               outcome="fail" if failed or self.errors else "pass",
                                               viewport=self.page.viewport_size, pageErrors=self.errors,
                                               failedRequests=self.failed_requests))
        self.context.close()
        self.assertEqual(self.errors, [])

    def ready(self, determinant):
        expect(self.page.locator("#metrics")).to_be_visible()
        expect(self.page.locator("#determinant")).to_have_text(determinant)
        expect(self.page.locator("#plot [data-moxi=plot]")).to_be_visible()

    def entries(self, values):
        for field, value in zip(("a", "b", "c", "d"), values):
            self.page.locator(f"#{field}").fill(str(value))
        self.page.get_by_role("button", name="Apply entries", exact=True).click()

    def values(self, values):
        for field, value in zip(("a", "b", "c", "d"), values):
            expect(self.page.locator(f"#{field}")).to_have_value(str(value))

    def selected(self, basis):
        expect(self.page.locator(f"[data-column={basis}]")).to_have_attribute("data-selected", "true")
        expect(self.page.locator(f"#basis-{basis}")).to_have_attribute("aria-pressed", "true")
        expect(self.page.locator(f"#plot polyline[data-basis={basis}]")).to_have_attribute("data-selected", "true")

    def capture(self, name, title, steps, expected):
        if not self.retain:
            return
        file = self.out / (name + ".png")
        self.page.screenshot(path=file, full_page=True)
        self.evidence["slides"].append(dict(image=file.name, title=title, steps=steps, expected=expected,
                                            observed=expected, outcome="pass", viewport=self.page.viewport_size,
                                            sha256=hashlib.sha256(file.read_bytes()).hexdigest()))

    def test_coordinated_matrix_journey(self):
        """Numeric edit → plot selection → keyboard move → mixed undo/redo → singular → recover."""
        self.selected("u")
        self.capture("01-start", "One matrix, two views", "Open the normal loopback UI at its initial 2I matrix.",
                     "Both basis vectors and the transformed square appear. det A = 4; column u is selected.")
        self.entries(("1.25", "0.5", "0.25", "2"))
        self.ready("2.375")
        self.values(("1.25", "0.5", "0.25", "2"))
        self.selected("v")
        self.capture("02-numeric", "Exact numeric entries", "Enter 1.25, 0.5, 0.25, 2 in row-major order; Apply entries.",
                     "The new frame uses those entries. The last edited column v is selected in both views; det A = 2.375.")
        self.page.locator("#plot circle[data-basis=u]").click()
        expect(self.page.locator("#basis-u")).to_be_focused()
        self.selected("u")
        self.page.keyboard.press("ArrowRight")
        self.page.keyboard.press("Shift+ArrowUp")
        self.ready("2.57")
        self.values(("1.35", "0.5", "0.26", "2"))
        expect(self.page.locator("#basis-u")).to_be_focused()
        self.selected("u")
        self.capture("03-keyboard", "Move the basis", "Click u’s plotted endpoint, press Right, then Shift+Up.",
                     "u moves by (0.1, 0.01), entries become 1.35 and 0.26, det A = 2.57, and keyboard focus stays on u.")
        for _ in range(3):
            self.page.get_by_role("button", name="Undo", exact=True).click()
        self.ready("4")
        self.values((2, 0, 0, 2))
        expect(self.page.locator("#undo")).to_be_disabled()
        self.capture("04-shared-undo", "One shared undo history", "Undo the two keyboard moves and the numeric edit, in that order.",
                     "The initial matrix, geometry and determinant return together. Three redo steps are available.")
        for _ in range(3):
            self.page.get_by_role("button", name="Redo", exact=True).click()
        self.ready("2.57")
        self.selected("u")
        self.entries((2, 1, 2, 1))
        self.ready("0")
        expect(self.page.locator("#rank")).to_contain_text("Singular")
        self.capture("05-singular", "A singular frame stays editable", "Apply columns u=(2,2) and v=(1,1).",
                     "The square collapses onto a line; det A = 0. The UI explains that no inverse exists and offers recovery.")
        self.page.locator("#basis-v").focus()
        self.page.keyboard.press("ArrowUp")
        self.ready("0.2")
        self.values((2, 1, 2, "1.1"))
        self.capture("06-recover", "Recover with a key", "Focus v and press Up once.",
                     "The basis becomes independent again: v=(1,1.1), det A = 0.2. The singular edit was never snapped or discarded.")
        self.page.locator("#undo").click()
        self.ready("0")
        self.page.locator("#redo").click()
        self.ready("0.2")

    def test_zero_and_near_singular(self):
        """Zero both columns, recover via Identity/Undo, then verify a near-singular exact entry."""
        self.entries((0, 0, 0, 0))
        self.ready("0")
        for basis in ("u", "v"):
            self.page.locator(f"#basis-{basis}").focus()
            expect(self.page.locator(f"#basis-{basis}")).to_be_focused()
        self.capture("07-zero", "Zero vectors remain reachable", "Apply the zero matrix; focus each separate basis button.",
                     "Both controls remain reachable even though their plotted endpoints coincide. det A = 0; recovery remains available.")
        self.page.locator("#identity").click()
        self.ready("1")
        self.page.locator("#undo").click()
        self.ready("0")
        self.page.locator("#redo").click()
        self.ready("1")
        self.entries((1, 1, 1, "1.001"))
        self.ready("0.001")
        self.values((1, 1, 1, "1.001"))
        expect(self.page.locator("#rank")).to_contain_text("Near singular")
        self.capture("08-near-singular", "Near singular, without a jump", "Apply u=(1,1), v=(1,1.001).",
                     "det A = 0.001 and a near-singular explanation appears. All three decimals remain unchanged.")

    def test_invalid_drafts_and_atomic_apply(self):
        """Reject empty/nonfinite/out-of-range/overprecision entries atomically; preserve drafts and discard with Escape."""
        for invalid in ("", "NaN", "Infinity", "3.001", "1.0001", "1e0", "abc"):
            self.page.locator("#a").fill(invalid)
            self.page.locator("#b").fill("1")
            self.page.locator("#apply").click()
            expect(self.page.locator("#error")).to_contain_text("No entries were applied")
            self.ready("4")
            expect(self.page.locator("#coords-v")).to_have_text("(0, 2)")
            expect(self.page.locator("#undo")).to_be_disabled()
        self.page.locator("#basis-v").focus()
        self.page.keyboard.press("ArrowUp")
        expect(self.page.locator("#error")).to_contain_text("Apply or discard")
        expect(self.page.locator("#a")).to_have_value("abc")
        self.page.locator("#a").focus()
        self.page.keyboard.press("Escape")
        self.values((2, 0, 0, 2))
        expect(self.page.locator("#error")).to_be_empty()
        expect(self.page.locator("#a")).to_be_focused()
        self.page.locator("#a").fill(".125")
        self.page.keyboard.press("Enter")
        self.ready("0.25")
        expect(self.page.locator("#a")).to_have_value("0.125")

    def test_bounds_exact_steps_and_redo_branch(self):
        """One hundred fine moves stay exact; reject range overflow; new edits replace redo; reload resets session."""
        self.page.locator("#basis-u").focus()
        for _ in range(100):
            self.page.keyboard.press("Shift+ArrowRight")
        self.ready("6")
        self.values((3, 0, 0, 2))
        self.page.keyboard.press("ArrowRight")
        expect(self.page.locator("#error")).to_contain_text("matrix is unchanged")
        self.values((3, 0, 0, 2))
        self.page.locator("#undo").click()
        self.ready("5.98")
        self.page.locator("#basis-u").focus()
        self.page.keyboard.press("Shift+ArrowDown")
        self.ready("5.98")
        self.values(("2.99", 0, "-0.01", 2))
        expect(self.page.locator("#redo")).to_be_disabled()
        self.page.reload()
        self.ready("4")
        self.values((2, 0, 0, 2))
        expect(self.page.locator("#undo")).to_be_disabled()

    def test_orientation_and_selection_only(self):
        """Select fields/vectors without creating history; reflect the basis and verify signed determinant."""
        self.page.locator("#b").focus()
        self.selected("v")
        self.page.locator("#basis-u").focus()
        self.selected("u")
        expect(self.page.locator("#undo")).to_be_disabled()
        self.entries((0, 1, 1, 0))
        self.ready("−1")
        expect(self.page.locator("#area")).to_have_text("1")
        expect(self.page.locator("#rank")).to_contain_text("negative determinant reverses orientation")

    def test_keyboard_entry_and_focus_order(self):
        """Tab through all matrix fields, type a numeric edit and apply with Enter; selection and focus persist."""
        self.page.keyboard.press("Tab")
        for field in ("a", "c", "b", "d"):
            expect(self.page.locator(f"#{field}")).to_be_focused()
            if field != "d":
                self.page.keyboard.press("Tab")
        self.page.keyboard.press("Meta+A" if platform.system() == "Darwin" else "Control+A")
        self.page.keyboard.type("2.5")
        self.page.keyboard.press("Enter")
        self.ready("5")
        self.values((2, 0, 0, "2.5"))
        self.selected("v")
        expect(self.page.locator("#d")).to_be_focused()

    def test_superseded_render_cannot_reappear(self):
        """Hold an earlier render, move again and release it after the new result; latest geometry wins."""
        held = []

        def route_render(route):
            if json.loads(route.request.post_data)["matrix"] == [2100, 0, 0, 2000]:
                held.append(route)
            else:
                route.continue_()

        self.page.route("**/render", route_render)
        self.page.locator("#basis-u").focus()
        with self.page.expect_request("**/render"):
            self.page.keyboard.press("ArrowRight")
        # A second normal key event starts a newer render and aborts the old one.
        self.page.keyboard.press("ArrowRight")
        self.ready("4.4")
        self.assertEqual(len(held), 1)
        held[0].fulfill(content_type="application/json", body=json.dumps(Matrix((2100, 0, 0, 2000)).render()))
        self.ready("4.4")
        self.values(("2.2", 0, 0, 2))
        self.selected("u")

    def test_network_failure_and_retry(self):
        """Fail a render, hide stale geometry/metrics, retain numeric history, then retry and undo."""
        self.page.route("**/render", lambda route: route.abort("failed"))
        self.page.locator("#basis-u").focus()
        self.page.keyboard.press("ArrowUp")
        expect(self.page.locator("#retry")).to_be_visible()
        expect(self.page.locator("#plot")).to_be_hidden()
        expect(self.page.locator("#metrics")).to_be_hidden()
        self.values((2, 0, "0.1", 2))
        expect(self.page.locator("#undo")).to_be_enabled()
        self.capture("09-network", "A failed drawing preserves the matrix", "Block the local render request, then move u upward.",
                     "The committed entry is 0.1 and Undo remains available. Stale geometry and metrics are hidden; Retry drawing is offered.")
        self.page.unroute("**/render")
        self.page.locator("#retry").click()
        self.ready("4")
        self.page.locator("#undo").click()
        self.ready("4")
        self.values((2, 0, 0, 2))

    def test_mismatched_response_rejected(self):
        """A response for another matrix cannot replace current geometry; retry renders the requested revision."""
        wrong = json.dumps(Matrix((0, 0, 0, 0)).render())
        self.page.route("**/render", lambda route: route.fulfill(content_type="application/json", body=wrong))
        self.page.locator("#basis-u").focus()
        self.page.keyboard.press("ArrowRight")
        expect(self.page.locator("#retry")).to_be_visible()
        expect(self.page.locator("#plot")).to_be_hidden()
        self.values(("2.1", 0, 0, 2))
        self.page.unroute("**/render")
        self.page.locator("#retry").click()
        self.ready("4.2")

    def test_narrow_keyboard_flow(self):
        """390×844: no horizontal overflow; numeric and keyboard editing plus singular recovery and undo work."""
        self.page.set_viewport_size({"width": 390, "height": 844})
        self.entries((2, 1, 2, 1))
        self.ready("0")
        self.selected("v")
        self.assertLessEqual(self.page.evaluate("document.documentElement.scrollWidth"), 390)
        self.capture("10-narrow-singular", "Narrow layout, same matrix", "At 390×844, apply the same collinear columns.",
                     "The two cards stack without horizontal scrolling. Numeric entries, basis controls and singular recovery remain available.")
        self.page.locator("#basis-v").focus()
        self.page.keyboard.press("ArrowDown")
        self.ready("−0.2")
        expect(self.page.locator("#basis-v")).to_be_focused()
        self.values((2, 1, 2, "0.9"))
        self.capture("11-narrow-recovery", "Narrow keyboard recovery", "Focus v and press Down on the narrow layout.",
                     "v becomes (1,0.9); det A = −0.2. Focus and shared column selection survive the render.")
        self.page.locator("#undo").click()
        self.ready("0")
        self.assertLessEqual(self.page.evaluate("document.documentElement.scrollWidth"), 390)


if __name__ == "__main__":
    unittest.main()
