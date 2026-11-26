"""Verify the actual Moxi consumer in Chrome; capture a local offline deck."""
import argparse
import hashlib
import importlib.metadata
import json
import platform
import subprocess
import sys
import threading
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import urlparse

from playwright.sync_api import expect, sync_playwright
from serve import BINARY, HERE, ROOT, RENDERER, make_server

DEST = ROOT / "artifacts/demo-slideshows/v15-pose-stroke"
sys.path.insert(0, str(ROOT / "scripts"))
from demo_slideshows import CaptureKind, Phase, load_manifest, render

# Independent expected table, not derived from the browser's mapping code.
FRAMES = [
    ("Clutch released", 12, 12), ("Anchored", 12, 12), ("Engaged", 18, 15.75),
    ("Engaged", 24, 18.25), ("Confidence hold", 24, 18.25),
    ("Confidence hold", 24, 18.25), ("Anchored", 24, 18.25),
    ("Engaged", 21.6, 15.09), ("Clutch released", 21.6, 15.09),
    ("Anchored", 21.6, 15.09), ("Engaged", 26.4, 15.97),
]
PHASES = {1: Phase.INITIAL, 4: Phase.INTERACTION, 5: Phase.RESULT, 7: Phase.RECOVERY,
          8: Phase.INTERACTION, 9: Phase.RESULT, 10: Phase.RECOVERY}


def wait(page):
    expect(page.locator("#brushes")).to_have_attribute("aria-busy", "false")


def action(page, selector, key=None):
    if key:
        page.locator(selector).focus()
        page.keyboard.press(key)
    else:
        page.locator(selector).click()
    wait(page)


def check(page, frame, status, direct, interp):
    wait(page)
    assert page.locator("#status").inner_text() == f"Sample {frame} / 11 · {status}"
    assert page.locator("#render-state").inner_text() == RENDERER
    assert page.locator("output").all_text_contents() == [f"{v:.2f} px" for v in (direct, interp)]
    paths = page.locator("svg path").all()
    assert len(paths) == 2
    for path, width in zip(paths, (direct, interp), strict=True):
        assert abs(float(path.get_attribute("stroke-width")) - width) < 1e-4
        assert path.evaluate("element => getComputedStyle(element).vectorEffect") == "non-scaling-stroke"


def run(output):
    output = output.resolve()
    dirty = subprocess.check_output(["git", "status", "--porcelain", "--", "examples/pose-stroke"], cwd=ROOT, text=True).splitlines()
    if output == DEST and dirty:
        raise RuntimeError("Commit the example before refreshing checked-in evidence. Use --output /tmp/... for a trial.")
    output.mkdir(parents=True, exist_ok=True)
    revision = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    record = dict(revision=revision, dirty_source=dirty, captured_at=datetime.now(timezone.utc).isoformat(),
                  host=f"{platform.system()} {platform.release()} {platform.machine()}",
                  python=platform.python_version(), playwright=importlib.metadata.version("playwright"),
                  fixture="Eleven authored synthetic numeric samples; no devices or accounts", role="local author",
                  source_sha256={str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest()
                                 for path in sorted(HERE.iterdir()) if path.suffix in (".py", ".js", ".mojo", ".html")},
                  binary_sha256=hashlib.sha256(BINARY.read_bytes()).hexdigest(), scenarios=[])
    slides = []
    def scenario(name, steps, expected, observed, artifacts=()):
        record["scenarios"].append(dict(name=name, steps=steps, expected=expected, observed=observed,
                                        outcome="pass", artifacts=list(artifacts)))

    with make_server(0) as server:
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            with sync_playwright() as driver:
                browser = driver.chromium.launch(channel="chrome", args=["--disable-background-networking"])
                record["browser"] = "Chrome " + browser.version
                record["viewports"] = [dict(width=960, height=1000), dict(width=390, height=844)]
                url = f"http://127.0.0.1:{server.server_port}"
                record["url"] = url
                context = browser.new_context(viewport=record["viewports"][0], service_workers="block")
                page = context.new_page()
                errors, external, scenes = [], [], []
                page.on("pageerror", lambda error: errors.append(str(error)))
                context.route("**/*", lambda route: route.continue_() if urlparse(route.request.url).scheme == "file" or urlparse(route.request.url).hostname in ("127.0.0.1", "localhost")
                              else (external.append(route.request.url), route.abort())[-1])
                def response_received(response):
                    if response.url == url + "/scene" and response.ok:
                        scenes.append(response.json())
                page.on("response", response_received)

                def capture(name, phase, caption, steps, expected):
                    image = output / name
                    page.screenshot(path=image, full_page=True)
                    png = image.read_bytes()
                    dimensions = [int.from_bytes(png[16:20], "big"), int.from_bytes(png[20:24], "big")]
                    slides.append(dict(image=name, phase=phase, capture_kind=CaptureKind.BROWSER, caption=caption,
                                       dimensions=dimensions, action=steps, expected=expected,
                                       sha256=hashlib.sha256(image.read_bytes()).hexdigest()))

                page.goto(url)
                for frame, (status, direct, interp) in enumerate(FRAMES, 1):
                    if frame > 1:
                        action(page, "#next")
                    check(page, frame, status, direct, interp)
                    if frame in PHASES:
                        capture(f"sample-{frame:02}.png", PHASES[frame], f"Moxi sample {frame} · {status}",
                                f"Open the loopback consumer; advance to sample {frame}.",
                                f"{status}. Direct {direct:.2f} px. Interpolated {interp:.2f} px.")
                assert page.locator("#next").is_disabled()
                scenario("real Moxi replay", "Open consumer; advance all 11 samples; compare returned SVG with mounted paths.",
                         "Fixed table widths, holds and no-jump anchors; final Next disabled; compiled Moxi SVG only.",
                         "All eleven states and widths match; both paths are Moxi response bytes.",
                         [f"sample-{frame:02}.png" for frame in PHASES])
                assert len(scenes) == 11
                assert all(s["renderer"] == RENDERER and s["binary_sha256"] == record["binary_sha256"] for s in scenes)
                for i, svg in enumerate(scenes[-1]["svgs"]):
                    assert page.locator(".scene").nth(i).evaluate("(element, svg) => { const expected = document.createElement('div'); expected.innerHTML = svg; return element.innerHTML === expected.innerHTML; }", svg)
                # Compare live endpoint with direct execution of the tested Mojo binary.
                assert scenes[3]["svgs"] == subprocess.check_output([str(BINARY), "24", "18.25"], text=True).splitlines()
                record["baseline_scene_responses"] = len(scenes)

                action(page, "#reset")
                page.set_viewport_size(record["viewports"][1])
                page.locator("#next").focus()
                page.keyboard.press("Tab")
                assert page.locator("#hold").evaluate("element => element === document.activeElement")
                page.keyboard.press("Shift+Tab")
                action(page, "#next", "Enter")
                assert page.locator("#next").evaluate("element => element === document.activeElement")
                action(page, "#hold", "Enter")
                action(page, "#next", "Enter")
                check(page, 3, "Clutch released", 12, 12)
                action(page, "#hold", "Enter")
                check(page, 3, "Anchored", 12, 12)
                action(page, "#next", "Enter")
                check(page, 4, "Engaged", 18, 14.5)
                assert page.evaluate("document.documentElement.scrollWidth <= innerWidth")
                capture("keyboard-narrow.png", Phase.RECOVERY, "Keyboard clutch, narrow Moxi consumer",
                        "At 390 px, use Tab/Enter to override clutch, re-anchor and advance.",
                        "No jump on reengagement, then widths 18.00 / 14.50 px; no horizontal overflow.")
                scenario("keyboard and narrow layout", "Tab/Shift+Tab and Enter: release, advance, reengage, advance at 390 px.",
                         "Every replay action reachable; no-jump reengagement; no horizontal overflow.",
                         "Held at 12/12; anchored at 12/12; resumed 18/14.5 px; no overflow.", ["keyboard-narrow.png"])

                page.set_viewport_size(record["viewports"][0])
                page.reload()
                check(page, 1, *FRAMES[0])
                action(page, "#reopen", "Enter")
                assert "No saved mapping" in page.locator("#notice").inner_text()
                for _ in range(3):
                    action(page, "#next")
                page.locator("#curled").fill("20")
                page.locator("#response").fill("2")
                action(page, "#apply", "Enter")
                check(page, 4, "Anchored", 24, 18.25)
                page.locator("#response").fill("3")
                page.keyboard.press("Escape")
                assert page.locator("#response").input_value() == "2"
                page.locator("#curled").fill("29")
                action(page, "#apply", "Enter")
                assert not page.locator("#curled").evaluate("element => element.validity.valid")
                check(page, 4, "Anchored", 24, 18.25)
                action(page, "#revert", "Enter")
                page.keyboard.press("Meta+s")
                assert "mapping saved" in page.locator("#notice").inner_text()
                saved = page.evaluate("localStorage.getItem('moxi.pose-stroke.mapping.v1')")
                assert json.loads(saved) == dict(version=1, calibration=dict(relaxed=4, curled=20, spread=16, spreadCurled=12, response=2))
                capture("mapping-applied.png", Phase.INTERACTION, "Editable mapping applied without a jump",
                        "At sample 4 change curled width to 20 and response exponent to 2. Enter applies; Cmd+S saves.",
                        "Widths remain 24.00 / 18.25 px. Mapping is anchored and saved locally.")
                page.reload()
                check(page, 1, *FRAMES[0])
                page.keyboard.press("Control+o")
                wait(page)
                assert page.locator("#curled").input_value() == "20"
                assert page.locator("#response").input_value() == "2"
                for _ in range(3):
                    action(page, "#next", "Enter")
                check(page, 4, "Engaged", 20, 17.6875)
                capture("mapping-reopened.png", Phase.RESULT, "Saved instrument reopened after reload",
                        "Reload, Ctrl+O to reopen, advance to sample 4.",
                        "Edited fields persist; new mapping produces 20.00 / 17.69 px through Moxi.")
                # A second page proves storage is not just a live object in the original page.
                reopened = context.new_page()
                reopened.goto(url)
                check(reopened, 1, *FRAMES[0])
                action(reopened, "#reopen", "Enter")
                assert reopened.locator("#response").input_value() == "2"
                reopened.close()
                page.evaluate("localStorage.setItem('moxi.pose-stroke.mapping.v1', '{\"version\":99}')")
                action(page, "#reopen", "Enter")
                assert "not reopened" in page.locator("#notice").inner_text()
                check(page, 4, "Engaged", 20, 17.6875)
                page.evaluate("text => localStorage.setItem('moxi.pose-stroke.mapping.v1', text)", saved)
                for _ in range(3):
                    action(page, "#next")
                check(page, 7, "Anchored", 20, 17.6875)
                action(page, "#next")
                check(page, 8, "Engaged", 17.28, 15.2275)
                scenario("author, validate, save and reopen", "Enter applies edited corners/curve; Escape reverts; reject 29 px; Cmd+S saves; reload and Ctrl+O reopen; reopen in a new page; reject bad saved version; loss/recovery replay.",
                         "No jump on apply; persisted calibration drives different rendered widths; rejected edits leave state intact.",
                         "Apply held 24/18.25. Reopened sample 4 rendered 20/17.6875. Loss held, reacquisition anchored; sample 8 resumed 17.28/15.2275.",
                         ["mapping-applied.png", "mapping-reopened.png"])

                # A failed render cannot advance domain state or silently use the former JS renderer.
                page.route("**/scene", lambda route: route.fulfill(status=503, content_type="application/json", body='{"error":"test renderer failure"}'))
                action(page, "#next")
                assert "503" in page.locator("#notice").inner_text()
                check(page, 8, "Engaged", 17.28, 15.2275)
                capture("render-failure.png", Phase.RECOVERY, "Failed Moxi render retains the last state",
                        "Reject the next /scene request with a synthetic 503.",
                        "Sample 8 and both previous Moxi strokes remain; error explains retry; no JS fallback.")
                page.unroute("**/scene")
                action(page, "#next")
                check(page, 9, "Clutch released", 17.28, 15.2275)
                page.route("**/scene", lambda route: route.fulfill(status=503, content_type="application/json", body='{}'))
                page.reload()
                wait(page)
                assert page.locator("svg path").count() == 0
                assert page.locator("#next").is_disabled()
                assert page.locator("#render-state").inner_text() == "Moxi unavailable"
                page.unroute("**/scene")
                action(page, "#reset")
                check(page, 1, *FRAMES[0])
                scenario("render rejection and recovery", "Synthetic 503 after a good scene; retry. Synthetic 503 at startup; Restart retries.",
                         "Keep prior frame and rendered state after failure; no brushes when Moxi never rendered; recover via retry.",
                         "Failed Next stayed at sample 8; retry reached 9. Failed startup showed zero paths and disabled Next; Restart restored Moxi.",
                         ["render-failure.png"])

                assert not errors, errors
                assert not external, external
                record["page_errors"] = errors
                record["external_requests"] = external
                manifest = dict(version=1, demo_id=output.name, title="Pose stroke study · Moxi consumer",
                                scenario="V15 synthetic Moxi scene consumer: replay, hold/recovery and saved editable calibration.",
                                fixture=record["fixture"], revision=revision, host=record["host"], backend=record["browser"] + " + " + RENDERER,
                                scale=1, captured_at=record["captured_at"], reproduce="python examples/pose-stroke/gallery.py", slides=slides)
                file = output / "manifest.json"
                file.write_text(json.dumps(manifest, indent=2) + "\n")
                deck = output / "index.html"
                deck.write_text(render(load_manifest(file)))
                context.set_offline(True)
                page.goto(deck.as_uri())
                assert page.locator("img").evaluate_all("imgs => imgs.every(i => i.complete && i.naturalWidth > 0)")
                page.keyboard.press("ArrowRight")
                assert page.locator("#counter").inner_text() == f"2 / {len(slides)}"
                page.locator(f"[data-jump='{len(slides)-1}']").click()
                assert page.locator("figure:visible").get_attribute("data-slide") == str(len(slides)-1)
                scenario("offline deck", "Disconnect network; open generated file deck; decode images and navigate with keyboard/contact sheet.",
                         "All images load offline and navigation works.", f"All {len(slides)} captures decoded; keyboard and contact sheet navigation passed.", ["index.html", "manifest.json"])
                browser.close()
        finally:
            server.shutdown()
            thread.join()
    record["skipped"] = ["live camera/model/license assessment", "human/physical repeatability, comfort, latency and activation studies",
                         "full Mojo/native suite and CI", "screen reader and additional browser testing"]
    (output / "browser-record.json").write_text(json.dumps(record, indent=2) + "\n")
    print(f"Passed {len(record['scenarios'])} Chrome scenarios; {len(slides)} captures. Evidence: {output}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=DEST)
    run(parser.parse_args().output)
