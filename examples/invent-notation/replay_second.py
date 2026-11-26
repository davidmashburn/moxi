"""Author a second score/schema configuration through the normal application UI.

This is a constrained-grammar check, not evidence of a second human author or
an independently extensible notation. Requires Python Playwright and an already
installed WebKit browser (or desktop Chrome with --browser chrome).
"""
import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import subprocess
import sys

from playwright.sync_api import expect, sync_playwright

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
SCORE_KEY = "moxi.v03.score.v1"

# Hand-calculated from the score below, without calling score.mjs.schedule.
# A sequence sums child spans; a group takes their maximum.
FORWARD = ["#4  Pulse   0 → 1", "#5  Pulse   1 → 3", "#6  Pulse   3 → 6",
           "#7  Pulse   0 → 4", "#8  Pulse   6 → 8"]
REVERSE = ["#8  Pulse   0 → 6", "#6  Pulse   6 → 15", "#5  Pulse   15 → 21",
           "#4  Pulse   21 → 24", "#7  Pulse   6 → 18"]


def replay(page, url, output):
    def saved():
        return json.loads(page.evaluate("key => localStorage.getItem(key)", SCORE_KEY))

    def capture(name):
        page.locator("#curve").evaluate("img => img.decode()")
        page.screenshot(path=output / f"{name}.png", full_page=True)
        (output / f"{name}.json").write_text(json.dumps(saved(), indent=2) + "\n")

    def select(slot):
        page.locator(f"#slot-{slot}").click()

    def add(kind, beats=None):
        page.locator(f"#add-{kind}").click()
        if beats is not None:
            select(saved()["next"] - 1)
            page.locator("#beats").fill(str(beats))
            page.locator("#beats").press("Tab")

    page.goto(url)
    expect(page.locator("#summary")).to_have_text("0 motions · 0 ticks")
    for kind, name in {"motion": "Pulse", "sequence": "Run", "group": "Cluster"}.items():
        page.locator(f"[name={kind}]").fill(name)
    page.locator("[name=capacity]").fill("2")
    page.locator("[name=beat]").fill("1")
    page.get_by_role("button", name="Apply revision").click()
    # root: [Cluster([Run([Pulse(1), Pulse(2), Pulse(3)]), Pulse(4)]), Pulse(2)]
    add("group")                         # 2, under root 1
    select(2)
    add("sequence")                      # 3, under group 2
    select(3)
    add("motion", 1)                     # 4
    select(3)
    add("motion", 2)                     # 5
    select(3)
    add("motion", 3)                     # 6
    select(2)
    add("motion", 4)                     # 7
    select(1)
    add("motion", 2)                     # 8
    select(3)
    expect(page.locator("#summary")).to_have_text("5 motions · 8 ticks")
    assert page.locator("#timeline > div").all_text_contents() == FORWARD
    before = saved()
    assert before["root"] == {
        "id": 1, "kind": "sequence", "children": [
            {"id": 2, "kind": "group", "children": [
                {"id": 3, "kind": "sequence", "children": [
                    {"id": 4, "kind": "motion", "beats": 1},
                    {"id": 5, "kind": "motion", "beats": 2},
                    {"id": 6, "kind": "motion", "beats": 3}]},
                {"id": 7, "kind": "motion", "beats": 4}]},
            {"id": 8, "kind": "motion", "beats": 2}]}
    capture("01-forward-nested")
    page.locator("[name=order]").select_option("reverse")
    page.locator("[name=beat]").fill("3")
    expect(page.locator("#candidate")).to_have_text("Proposed score · 24 ticks")
    expect(page.locator("#summary")).to_have_text("5 motions · 8 ticks")
    apply = page.get_by_role("button", name="Apply revision")
    apply.focus()
    apply.press("Enter")
    expect(apply).to_be_focused()
    expect(page.locator("#summary")).to_have_text("5 motions · 24 ticks")
    assert page.locator("#timeline > div").all_text_contents() == REVERSE
    revised = saved()
    assert revised["root"] == before["root"]
    assert revised["selected"] == before["selected"] == 3
    assert revised["next"] == before["next"] == 9
    assert revised["revision"] == before["revision"] + 1
    capture("02-reverse-scaled")
    page.locator("[name=capacity]").fill("1")
    expect(page.locator("#candidate")).to_contain_text("Group #2 has 2 slots")
    apply.click()
    expect(page.locator("#status")).to_contain_text("Edit rejected.")
    assert saved() == revised
    capture("03-rejected-capacity")
    page.get_by_role("button", name="Undo edit").click()
    assert saved() == before
    assert page.locator("#timeline > div").all_text_contents() == FORWARD
    capture("04-undo")
    page.reload()
    expect(page.locator("#summary")).to_have_text("5 motions · 8 ticks")
    assert saved() == before
    assert page.locator("#timeline > div").all_text_contents() == FORWARD
    expect(page.locator("#slot-3")).to_have_attribute("aria-pressed", "true")
    expect(page.get_by_role("button", name="Undo edit")).to_be_disabled()
    capture("05-reloaded")
    page.locator("[name=order]").select_option("reverse")
    page.locator("[name=beat]").fill("3")
    apply.click()
    assert saved() == revised
    page.locator("[name=capacity]").fill("1")
    apply.click()
    expect(page.locator("#status")).to_contain_text("Edit rejected.")
    page.reload()
    expect(page.locator("#summary")).to_have_text("5 motions · 24 ticks")
    assert saved() == revised
    assert page.locator("#timeline > div").all_text_contents() == REVERSE
    capture("06-rejected-reloaded")
    return {"source": before, "revised": revised, "expected_forward": FORWARD,
            "expected_reverse": REVERSE, "observed_reload": saved()}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--browser", choices=["webkit", "chrome"], default="webkit")
    parser.add_argument("--evidence", type=Path, required=True)
    args = parser.parse_args()
    args.evidence.mkdir(parents=True, exist_ok=True)
    server = subprocess.Popen([sys.executable, str(HERE / "app.py"), "--port", "0"],
                              stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
                              env={**os.environ, "PYTHONPATH": str(ROOT / "python")})
    try:
        url = server.stdout.readline().strip()
        if not url:
            raise RuntimeError(server.stderr.read())
        with sync_playwright() as pw:
            browser = (pw.webkit.launch() if args.browser == "webkit"
                       else pw.chromium.launch(channel="chrome"))
            page = browser.new_page(viewport={"width": 1280, "height": 900})
            errors = []
            page.on("pageerror", lambda error: errors.append(str(error)))
            result = replay(page, url, args.evidence)
            assert not errors, errors
            result.update(browser=args.browser, version=browser.version, url=url,
                          viewport={"width": 1280, "height": 900}, page_errors=errors,
                          captured_at=datetime.now(timezone.utc).isoformat(),
                          revision=subprocess.check_output(
                              ["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
                          changed_files=subprocess.check_output(
                              ["git", "status", "--short", "--", "examples/invent-notation"], cwd=ROOT, text=True).splitlines())
            (args.evidence / "result.json").write_text(json.dumps(result, indent=2) + "\n")
            print(f"PASS · {args.browser} {browser.version} · nested score, independent timing/IDs, compatible/rejected revision, undo, reload · no page exceptions")
            browser.close()
    finally:
        server.terminate()
        server.wait()
