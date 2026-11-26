"""Offline browser replay and V04 evidence generator. Run from the repository root."""
import json
import math
import platform
import subprocess
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path

from playwright.sync_api import sync_playwright
from build import ANGLES, ARMS, ANCHORS, HERE, build, force

ROOT = HERE.parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
from demo_slideshows import load_manifest, render

DEMO = "v04-spring-linkage"
OUT = ROOT / "artifacts/demo-slideshows" / DEMO
COMMAND = "PYTHONPATH=python python3 examples/spring-linkage/check.py"


def check_mechanics():
    # Independent virtual-work check: d(stored energy)/d(angle) / tip radius.
    def energy(a, h, theta):
        length = math.sqrt((a / 2)**2 + h*h + a*h*math.sin(theta))
        return 0.06 * max(0, length - 35)**2

    for arm in ARMS:
        for anchor in ANCHORS:
            for degrees in ANGLES:
                theta = math.radians(degrees)
                numerical = (energy(arm, anchor, theta + 1e-5) -
                             energy(arm, anchor, theta - 1e-5)) / (2e-5 * arm)
                assert math.isclose(force(arm, anchor, degrees), numerical, rel_tol=1e-8)


def replay(browser, app):
    page = browser.new_page(viewport={"width": 1120, "height": 1040}, device_scale_factor=1)
    page.context.set_offline(True)
    errors = []
    page.on("pageerror", lambda error: errors.append(str(error)))
    page.goto(app.as_uri())
    at = page.locator
    slides = []

    def capture(name, phase, action, expected):
        image = name + ".png"
        page.screenshot(path=OUT / image)
        slides.append(dict(image=image, phase=phase, capture_kind="browser", dimensions=[1120, 1040],
                           caption=name.split("-", 1)[1].replace("-", " ").capitalize(),
                           action=action, expected=expected))

    def state():
        return tuple(at(selector).get_attribute(attr) for selector, attr in
                     [("#armLine", "x2"), ("#pin", "cy"), ("#actual", "points"), ("#goal", "points")])

    start = state()
    assert "0.752 N" in at("#reading").inner_text()
    capture("01-linkage", "initial", "Open the synthetic folding lamp.",
            "The 100 mm arm and 40 mm anchor give 0.98 N at 45 degrees.")
    at("#pose").focus()
    at("#pose").press("ArrowRight")
    assert at("#degrees").inner_text() == "50°" and state()[0] != start[0]
    at("#pose").press("ArrowLeft")
    assert state() == start
    at("#anchor").press("ArrowUp")
    at("#hand button").click()
    hand = state()
    assert at("#anchor").input_value() == "50"
    assert hand[1] != start[1] and hand[2] != start[2]
    assert "0.424 N" in at("#reading").inner_text()
    capture("02-hand-tuning", "interaction", "Nudge anchor depth up and apply dimensions.",
            "Depth reads 50 mm. The spring attachment and solid response update together.")
    at("#sweep").click()
    best = state()
    assert "0.000 N RMS" in at("#choices label").first.inner_text()
    assert best[2] == best[3] and best != hand
    at("#choices input").nth(1).click()
    alternative = state()
    assert alternative != best and alternative != hand
    capture("03-preview-alternative", "interaction", "Sweep the grid and select the second match.",
            "The preview changes while the comparison retains the hand-tuned dimensions and error.")
    at("#choices input").nth(1).press("Escape")
    assert state() == hand and at("#actions").is_hidden()
    at("#sweep").click()
    at("#choices input").nth(1).click()
    at("#apply").click()
    assert state() == alternative and at("#actions").is_hidden()
    assert (at("#arm").input_value(), at("#anchor").input_value()) == ("130", "60")
    assert "0.034 N" in at("#reading").inner_text()
    capture("04-apply-alternative", "result", "Repeat the sweep and use the second preview.",
            "The committed fields now match the selected alternative.")
    at("#target").select_option(label="High load")
    at("#sweep").click()
    assert "Infeasible" in at("#message").inner_text() and state()[:3] == alternative[:3]
    assert at("#choices input").count() == 0 and state()[3] != alternative[3]
    capture("05-infeasible", "result", "Select High load and run the same sweep.",
            "The flat 4.8 N target exceeds all admissible matches. Geometry and response are preserved.")
    at("#undo").click()
    assert state() == alternative and at("#target").input_value() == "1"
    capture("06-undo", "recovery", "Undo the high-load target edit.",
            "The firm target, chosen geometry and previous response return exactly.")
    at("#undo").click()
    assert state() == hand
    at("#arm").fill("85")
    at("#hand button").click()
    assert not at("#arm").evaluate("e => e.validity.valid") and state() == hand
    at("#arm").press("Escape")
    assert at("#arm").input_value() == "100"
    at("#sweep").click()
    at("#anchor").fill("60")
    assert at("#actions").is_hidden() and state() == hand
    page.set_viewport_size({"width": 390, "height": 844})
    assert page.evaluate("document.documentElement.scrollWidth <= innerWidth")
    at("#hand button").click()
    assert state() != hand
    at("#undo").click()
    assert state() == hand
    assert not errors, errors
    return slides


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    check_mechanics()
    with tempfile.TemporaryDirectory() as temp, sync_playwright() as pw:
        app = Path(temp) / "lamp.html"
        build(app)
        browser = pw.chromium.launch(channel="chrome", args=["--disable-background-networking"])
        slides = replay(browser, app)
        revision = subprocess.check_output(
            ["git", "log", "-1", "--format=%H", "--", str(HERE / "build.py"),
             str(HERE / "workbench.html")], cwd=ROOT, text=True).strip()
        manifest = dict(version=1, demo_id=DEMO, title="Folding lamp", scenario="V04 / I03 / I21",
                        host=f"{platform.system()} {platform.release()} · headless Chrome {browser.version}",
                        backend="Moxi Python reference SVG / browser", fixture="42 dimension pairs, 13 poses",
                        scale=1, revision=revision, reproduce=COMMAND, slides=slides,
                        captured_at=datetime.now(timezone.utc).isoformat())
        path = OUT / "manifest.json"
        path.write_text(json.dumps(manifest, indent=2) + "\n")
        gallery = OUT / "index.html"
        gallery.write_text(render(load_manifest(path)))
        viewer = browser.new_page()
        viewer.context.set_offline(True)
        viewer.goto(gallery.as_uri())
        assert viewer.locator("figure:visible").count() == 1
        viewer.keyboard.press("ArrowRight")
        assert slides[1]["caption"] in viewer.locator("figure:visible").inner_text()
        browser.close()
    print("PASS: 546 virtual-work checks, offline browser replay, six PNGs, offline slideshow navigation")


if __name__ == "__main__":
    main()
