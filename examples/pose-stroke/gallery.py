"""Exercise the file-based demo and verify its self-contained slideshow offline."""
import hashlib
import json
import platform
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

from playwright.sync_api import sync_playwright

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
DEST = ROOT / "artifacts/demo-slideshows/v15-pose-stroke"
sys.path.insert(0, str(ROOT / "scripts"))
from demo_slideshows import load_manifest, render

# Frame, phase, status and independent expected widths in CSS pixels.
FRAMES = [
    (1, "initial", "Clutch released", 12, 12),
    (4, "interaction", "Engaged", 24, 18.25),
    (5, "result", "Confidence hold", 24, 18.25),
    (7, "recovery", "Anchored", 24, 18.25),
    (8, "interaction", "Engaged", 21.6, 15.09),
    (9, "result", "Clutch released", 21.6, 15.09),
    (10, "recovery", "Anchored", 21.6, 15.09),
]


def check(page, frame, status, direct, interp):
    assert page.locator("#status").inner_text() == f"Sample {frame} / 11 · {status}"
    expected = [direct, interp]
    assert page.locator("output").all_text_contents() == [f"{v:.2f} px" for v in expected]
    for path, width in zip(page.locator("svg path").all(), expected, strict=True):
        assert abs(float(path.get_attribute("stroke-width")) - width) < 1e-8


def run():
    if subprocess.check_output(["git", "status", "--porcelain", "--", "."], cwd=HERE):
        raise RuntimeError("Commit the example before recording revision-specific evidence.")
    DEST.mkdir(parents=True, exist_ok=True)
    with sync_playwright() as driver:
        browser = driver.chromium.launch(channel="chrome", args=["--disable-background-networking"])
        page = browser.new_page(viewport={"width": 960, "height": 820}, offline=True)
        errors = []
        page.on("pageerror", lambda error: errors.append(str(error)))
        page.on("request", lambda req: errors.append(req.url) if req.url.startswith(("http:", "https:")) else None)
        page.goto((HERE / "index.html").as_uri())
        current = 1
        slides = []
        for frame, phase, status, direct, interp in FRAMES:
            for _ in range(current, frame):
                page.locator("#next").click()
            check(page, frame, status, direct, interp)
            image = DEST / f"sample-{frame:02}.png"
            page.screenshot(path=image)
            slides.append(dict(image=image.name, phase=phase, capture_kind="browser",
                               caption=f"Sample {frame} · {status}", dimensions=[960, 820],
                               action="Open the demo." if frame == 1 else f"Advance to sample {frame}.",
                               expected=f"{status}. Direct {direct:.2f} px. Interpolated {interp:.2f} px.",
                               sha256=hashlib.sha256(image.read_bytes()).hexdigest()))
            current = frame
        page.locator("#next").click()
        assert page.locator("#next").is_disabled()
        page.locator("#reset").click()
        check(page, 1, "Clutch released", 12, 12)
        page.set_viewport_size({"width": 390, "height": 844})
        assert page.evaluate("document.documentElement.scrollWidth <= innerWidth")
        page.locator("#next").focus()
        page.keyboard.press("Enter")
        page.locator("#hold").click()
        page.locator("#next").click()
        check(page, 3, "Clutch released", 12, 12)
        page.locator("#hold").click()
        check(page, 3, "Anchored", 12, 12)
        page.locator("#next").click()
        check(page, 4, "Engaged", 18, 14.5)
        page.reload()
        check(page, 1, "Clutch released", 12, 12)

        revision = subprocess.check_output(["git", "log", "-1", "--format=%H", "--", "."],
                                           cwd=HERE, text=True).strip()
        manifest = dict(version=1, demo_id=DEST.name, title="Pose stroke study",
                        scenario="V15 synthetic replay. Released clutch and low confidence freeze both brushes.",
                        fixture="Eleven authored numeric samples in model.js",
                        revision=revision, host=f"{platform.system()} {platform.release()} {platform.machine()}",
                        backend="Headless Chrome " + browser.version, scale=1,
                        captured_at=datetime.now(timezone.utc).isoformat(),
                        reproduce="python examples/pose-stroke/gallery.py", slides=slides)
        file = DEST / "manifest.json"
        file.write_text(json.dumps(manifest, indent=2) + "\n")
        deck = DEST / "index.html"
        deck.write_text(render(load_manifest(file)))
        page.goto(deck.as_uri())
        assert page.locator("img").evaluate_all("(imgs) => imgs.every(i => i.complete && i.naturalWidth === 960)")
        page.keyboard.press("ArrowRight")
        assert page.locator("#counter").inner_text() == "2 / 7"
        page.locator("[data-jump='6']").click()
        assert page.locator("figure:visible").get_attribute("data-slide") == "6"
        page.locator("#next").click()
        page.locator("#prev").click()
        assert page.locator("#counter").inner_text() == "7 / 7"
        assert not errors, errors
        browser.close()
    print("Passed browser replay, clutch override, reset, narrow layout and offline slideshow.")


if __name__ == "__main__":
    run()
