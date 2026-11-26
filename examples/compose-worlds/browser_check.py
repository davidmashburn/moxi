"""Exercise the built offline consumer. Pass --capture to refresh the gallery."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import platform
from pathlib import Path
import subprocess
import sys

from playwright.sync_api import sync_playwright

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
PAGE = ROOT / "dist/compose-worlds/index.html"
GALLERY = HERE / "evidence/compose-worlds"


def exercise(page, capture):
    def loc(name):
        return page.locator("#" + name)

    def pixels(name):
        data = loc(name).evaluate("canvas => canvas.toDataURL()")
        return hashlib.sha256(data.encode()).hexdigest()

    def replay(number):
        page.get_by_role("button", name=f"Replay trial {number}", exact=True).click()

    rule, season = loc("rule"), loc("season")
    origin = pixels("reference")
    assert rule.input_value() == "50" and pixels("branch") == origin
    capture("initial", "initial", "Identical beds at season zero", "Open the app.",
            "All branches inherit 50% and the initial maps match.")
    rule.press("End")
    assert season.is_disabled() and pixels("branch") == origin
    capture("edit", "interaction", "Local midpoint", "Press End on North’s midpoint.",
            "Only North uses a 100% local midpoint.")
    loc("compare").click()
    result, reference = pixels("branch"), pixels("reference")
    assert reference != result and reference != origin
    assert "21.11% grazers" in loc("branchStats").inner_text()
    capture("result", "result", "Season 12 comparison", "Run comparison.",
            "North has 21.11% grazers with the original 50% reference.")
    season.press("Home")
    assert pixels("branch") == pixels("reference") == origin
    season.press("ArrowRight")
    assert pixels("branch") != origin
    loc("reset").click()
    assert rule.input_value() == "50" and pixels("branch") == origin
    capture("reset", "recovery", "Reset the beds", "Reset beds.",
            "The original rule returns and trial 1 remains available.")
    loc("prediction").select_option("equal")
    loc("compare").click()
    assert "Prediction matched" in loc("status").inner_text()
    assert pixels("branch") == reference
    replay(1)
    assert rule.input_value() == "100" and loc("prediction").input_value() == "more"
    assert pixels("reference") == reference and pixels("branch") == result
    capture("replay", "result", "Replay the first trial", "Replay trial 1 after recording trial 2.",
            "The first trial restores its maps, rule and prediction.")
    replay(2)
    assert pixels("branch") == reference
    shared = loc("shared")
    shared.press("ArrowRight")
    for name in ("North", "East", "South"):
        loc("active").select_option(name)
        assert rule.input_value() == "60" and loc("inherit").is_disabled()
        loc("compare").click()
        assert pixels("reference") == pixels("branch") != reference
    loc("active").select_option("East")
    rule.press("End")
    loc("active").select_option("North")
    rule.press("Home")
    shared.press("ArrowRight")
    before = loc("settings").inner_text()
    assert before == "North 0% (local) · East 100% (local) · South 70% (shared)"
    loc("active").select_option("East")
    loc("compare").click()
    before_maps = pixels("reference"), pixels("branch")
    loc("promote").click()
    promoted = loc("settings").inner_text()
    assert promoted == "North 0% (local) · East 100% (shared) · South 100% (shared)"
    loc("compare").click()
    assert pixels("reference") == pixels("branch") == before_maps[1]
    capture("promotion", "result", "East promoted to shared", "Promote East and compare.",
            "South follows East to 100%. North retains its local 0%.")
    replay(1)
    assert pixels("reference") == reference and pixels("branch") == result
    replay(7)
    assert loc("settings").inner_text() == promoted
    loc("undo").click()
    assert loc("settings").inner_text() == before and loc("undo").is_disabled()
    loc("compare").click()
    assert (pixels("reference"), pixels("branch")) == before_maps
    assert loc("history").locator("li").count() == 8
    capture("undo", "recovery", "Restore branch ownership", "Replay the promoted trial and undo promotion.",
            "The shared 70% and both local overrides return with the prior trial’s maps.")

    formula = loc("formula")
    loc("curve").press("Enter")
    state = """e => [document.activeElement === e, e.value,
                     e.selectionStart, e.selectionEnd, e.selectionDirection]"""
    assert formula.evaluate(state)[:4] == [True, "knots(0, 100, 100)", 9, 12]
    page.keyboard.insert_text("30")
    draft = "knots(0, 30, 100)"
    for keys, bounds in [([], [11, 11, "forward"]),
                         (["Shift+ArrowLeft"] * 2, [9, 11, "backward"]),
                         (["ArrowLeft", "Shift+ArrowRight"], [9, 10, "forward"])]:
        for key in keys:
            formula.press(key)
        saved = formula.evaluate(state)
        assert saved[:4] == [True, draft, *bounds[:2]]
        if bounds[0] != bounds[1]:
            assert saved[4] == bounds[2]
        formula.press("Tab")
        page.keyboard.press("Tab")
        page.keyboard.press("Enter")
        assert loc("back").evaluate("e => document.activeElement === e")
        capture("definition", "interaction", "Inspect the feeding knots", "Edit the midpoint and open Knot definition.",
                "Keyboard focus moves into the definition dialog.")
        loc("back").press("Enter")
        page.wait_for_function("document.activeElement.id === 'formula'")
        assert formula.evaluate(state) == saved
        if saved[4] == "backward":
            capture("formula", "recovery", "Resume the draft", "Return from the definition.",
                    "The edited text and backward selection of 30 return to the focused editor.")
    loc("apply").click()
    loc("compare").click()
    assert rule.input_value() == "30" and pixels("branch") != before_maps[1]
    assert loc("history").locator("li").count() == 9
    loc("curve").click()
    formula.fill("knots(0, 33, 100)")
    loc("apply").click()
    assert formula.input_value() == "knots(0, 33, 100)" and rule.input_value() == "30"
    assert "steps of ten" in loc("formulaError").inner_text()
    assert loc("history").locator("li").count() == 9
    assert page.evaluate("document.documentElement.scrollWidth <= innerWidth")
    page.reload()
    assert pixels("branch") == origin and loc("history").locator("li").count() == 0


def replay_sweep(page):
    """Record every season of each allowed midpoint, then reopen rows out of order."""
    rule, season = page.locator("#rule"), page.locator("#season")

    def trajectory():
        status = page.locator("#status").inner_text()
        season.press("Home")
        frames = []
        for index in range(13):
            if index:
                season.press("ArrowRight")
            assert season.input_value() == str(index)
            canvases = page.locator("canvas").evaluate_all("nodes => nodes.map(c => c.toDataURL()).join('|')")
            frames.append(hashlib.sha256(canvases.encode()).digest())
        return status, frames

    recorded = []
    rule.press("Home")
    for index in range(11):
        if index:
            rule.press("ArrowRight")
        page.locator("#prediction").select_option(["more", "fewer", "equal"][index % 3])
        page.locator("#compare").click()
        recorded.append(trajectory())
    for index in [10, 0, 9, 1, 8, 2, 7, 3, 6, 4, 5]:
        page.get_by_role("button", name=f"Replay trial {index + 1}", exact=True).click()
        assert rule.input_value() == str(index * 10)
        assert trajectory() == recorded[index]
    assert page.locator("#history li").count() == 11


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--capture", action="store_true")
    args = parser.parse_args()
    subprocess.run([sys.executable, HERE / "build.py"], check=True)
    if args.capture:
        dirty = subprocess.check_output(
            ["git", "status", "--porcelain", "--", "examples/compose-worlds",
             ":(exclude)examples/compose-worlds/evidence"], cwd=ROOT, text=True)
        if dirty:
            parser.error("Commit the tested example source before stamping its gallery revision.")
    slides = []
    with sync_playwright() as driver:
        browser = driver.chromium.launch(channel="chrome")
        for width, height in [(1180, 1050), (390, 844)]:
            page = browser.new_page(viewport={"width": width, "height": height}, offline=True)
            errors = []
            page.on("pageerror", lambda error: errors.append(str(error)))
            page.on("request", lambda req: errors.append(req.url) if req.url.startswith(("http:", "https:")) else None)
            page.goto(PAGE.as_uri())

            def capture(name, phase, caption, action, expected):
                if not args.capture or (width == 390 and name not in ("formula", "promotion")):
                    return
                image = f"{name}{'-narrow' if width == 390 else ''}.png"
                if any(slide["image"] == image for slide in slides):
                    return
                data = page.screenshot(path=GALLERY / image, full_page=True)
                dimensions = [int.from_bytes(data[i:i+4], "big") for i in (16, 20)]
                slides.append(dict(image=image, phase=phase, caption=caption, action=action,
                                   expected=expected, dimensions=dimensions, capture_kind="browser",
                                   viewport=[width, height], result="pass"))

            exercise(page, capture)
            replay_sweep(page)
            assert not errors, errors
            page.close()
            print(f"PASS offline Chrome {browser.version} at {width} × {height}")
        version = browser.version
        browser.close()
    if args.capture:
        sys.path.insert(0, str(ROOT / "scripts"))
        from demo_slideshows import load_manifest, render
        path = GALLERY / "manifest.json"
        manifest = json.loads(path.read_text())
        manifest.update(scenario="V02 · Branch promotion, replay and semantic zoom",
                        revision=subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
                        captured_at=datetime.now(timezone.utc).isoformat(timespec="seconds"),
                        host=f"Chrome {version} / {platform.system()} {platform.release()}, offline file URL", scale=1,
                        reproduce="python3 examples/compose-worlds/browser_check.py --capture",
                        slides=slides)
        path.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n")
        (GALLERY / "index.html").write_text(render(load_manifest(path)))


if __name__ == "__main__":
    main()
