"""Replay the V06 consumer in installed Chrome and write its offline evidence."""
import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import platform
import subprocess
import sys
from tempfile import TemporaryDirectory

from playwright.sync_api import expect, sync_playwright

from build import build

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))
from demo_slideshows import load_manifest, render

DEMO = "motion-envelope"


def write_json(path, data):
    path.write_text(json.dumps(data, indent=2) + "\n")


def replay(browser, url, out, width, height):
    page = browser.new_page(viewport={"width": width, "height": height}, device_scale_factor=1)
    errors = []
    page.on("pageerror", lambda error: errors.append(str(error)))
    # Observe the oscillator's real scheduled start and independently decode score
    # time from the Moxi envelope marker after each animation update.
    page.add_init_script("""
        const start = OscillatorNode.prototype.start;
        window.performances = [];
        OscillatorNode.prototype.start = function(when) {
            const trace = {frames: [], rate: this.context.sampleRate};
            performances.push(trace);
            const ctx = this.context;
            const svg = document.querySelector('#gain svg');
            const knots = svg.querySelector('polyline').points;
            const dot = svg.querySelector('circle');
            const observer = new MutationObserver(() => {
                const clock = (ctx.currentTime - when) * 1000;
                const displayed = 2000 * (dot.cx.baseVal.value - knots[0].x) /
                                  (knots[2].x - knots[0].x);
                const path = document.querySelector('#path circle');
                if (clock >= 0 && clock < 2000) {
                    trace.frames.push([clock, displayed, path.cx.baseVal.value,
                                       path.cy.baseVal.value, dot.cy.baseVal.value]);
                }
                if (displayed >= 1999.99) observer.disconnect();
            });
            observer.observe(dot, {attributes:true, attributeFilter:['cx']});
            return start.call(this, when);
        };
    """)
    page.goto(url)
    slides = []

    def capture(phase, title, action, expected):
        if width < 500 and phase != "recovery":
            return
        name = f"{width}-{len(slides) + 1}.png"
        page.screenshot(path=out / name, full_page=True)
        slides.append(dict(phase=phase, caption=title, action=action, expected=expected,
                           capture_kind="browser", image=name, dimensions=[width, page.evaluate(
                               "Math.max(innerHeight, document.documentElement.scrollHeight)")]))
    slider = page.get_by_role("slider", name="Time to apex", exact=False)
    score = page.locator("#score")
    status = page.locator("#message")
    state = lambda: page.locator("circle").evaluate_all(
        "nodes => nodes.map(n => [n.cx.baseVal.value, n.cy.baseVal.value])")
    expect(score).to_contain_text("Revision 0 · Authored apex 1000 ms")
    original = state()
    capture("initial", "The point climbs as the voice grows", "Open the fixture.",
            "At 750 ms both markers are three quarters of the way to the apex.")
    bounds = slider.bounding_box()
    y = bounds["y"] + bounds["height"] / 2
    page.mouse.move(bounds["x"] + bounds["width"] / 2, y)
    page.mouse.down()
    page.mouse.move(bounds["x"] + bounds["width"] - 1, y, steps=8)
    expect(slider).to_have_value("1800")
    expect(score).to_contain_text("Revision 0")
    pointer = state()
    assert original != pointer and abs(pointer[0][1] - pointer[1][1]) < .01
    capture("interaction", "Stretch the climb", "Drag the apex to 1800 ms and hold.",
            "Both markers move down at the same inspection time. Revision stays zero.")
    page.keyboard.press("Escape")
    page.mouse.move(bounds["x"] + 1, y)
    page.mouse.up()
    expect(slider).to_have_value("1000")
    assert state() == original
    slider.press("ArrowRight")
    expect(slider).to_have_value("1010")
    slider.press("End")
    assert state() == pointer
    page.locator("#commit").click()
    expect(score).to_contain_text("Revision 1 · Authored apex 1800 ms")
    # Inspect actual rendered SVG marks at a fixed score time after each performance.
    page.locator("#save").click()
    capture("result", "One revision carries both edits", "Use End, commit, then set a checkpoint.",
            "The keyboard produces the pointer geometry and records the 1800 ms apex.")
    marks = []
    for i in range(2):
        page.locator("#play").click()
        expect(status).to_contain_text("Playing")
        page.wait_for_function("Number(document.querySelector('#seek').value) > 350 && Number(document.querySelector('#seek').value) < 1600")
        if i == 0:
            capture("interaction", "Audition the shared curve", "Play the committed phrase.",
                    "Both markers follow the rising portion of the 220 Hz voice envelope.")
        expect(status).to_have_text("Playback complete.")
        marks.append(state())
    assert marks[0] == marks[1]
    slider.press("Home")
    page.locator("#commit").click()
    expect(score).to_contain_text("Revision 2 · Authored apex 200 ms")
    page.locator("#restore").click()
    expect(score).to_contain_text("Revision 3 · Authored apex 1800 ms")
    seek = page.locator("#seek")
    expect(seek).to_have_value("750")
    assert state() == pointer
    capture("recovery", "Recover the stretched phrase", "Commit the 200 ms alternative, then restore the checkpoint.",
            "Revision three restores the saved apex and both saved marker positions.")
    assert page.evaluate("document.documentElement.scrollWidth <= innerWidth")
    assert not errors, errors
    live = []
    path_knots = page.locator("#path polyline").evaluate("p => Array.from(p.points, q => [q.x, q.y])")
    for trace in page.evaluate("performances"):
        frames = trace["frames"]
        assert len(frames) >= 2
        peak_frame = next(f[1] for f in frames if f[1] >= 1800)
        for _, shown, x, y, gain_y in frames:
            leg = int(shown > 1800)
            fraction = (shown - 1800) / 200 if leg else shown / 1800
            for axis, actual in enumerate((x, y)):
                a, b = path_knots[leg][axis], path_knots[leg + 1][axis]
                assert abs(actual - (a + fraction * (b - a))) < .001
            assert abs(gain_y - y) < .001
        live.append(dict(viewport=[width, height], sample_rate=trace["rate"],
                         frames=len(frames), first_frame_past_apex_ms=peak_frame - 1800,
                         max_clock_error_ms=max(abs(f[0] - f[1]) for f in frames)))
    assert len(live) == 2
    page.close()
    return slides, live


def checkpoint_lesson(browser, url):
    """Replay the same five semantic actions with and without an interruption."""
    outcomes = []
    for interrupt in (False, True):
        page = browser.new_page()
        page.goto(url)
        apex = page.get_by_role("slider", name="Time to apex")
        seek = page.get_by_role("slider", name="Inspect phrase")
        def pose():
            return page.locator("circle").evaluate_all(
                "nodes => nodes.map(n => [n.cx.baseVal.value, n.cy.baseVal.value])")

        # 1. Place the peak. 2. Author it. 3. Seek to its rising slope.
        apex.fill("1370")
        page.get_by_role("button", name="Commit edit").click()
        seek.fill("500")
        saved = pose()
        page.get_by_role("button", name="Set checkpoint").click()
        if interrupt:
            apex.fill("200")
            page.get_by_role("button", name="Commit edit").click()
            seek.fill("1900")
            assert pose() != saved
            page.get_by_role("button", name="Restore checkpoint").click()
            expect(apex).to_have_value("1370")
            expect(seek).to_have_value("500")
            assert pose() == saved
        # 4. Seek to the peak. 5. Follow the descent. Record the parameter curve.
        curve = [saved]
        for ms in (1370, 1750):
            seek.fill(str(ms))
            curve.append(pose())
        assert curve[1][0][1] < min(curve[0][0][1], curve[2][0][1])
        outcomes.append(curve)
        page.close()
    assert outcomes[0] == outcomes[1]
    return dict(apex_ms=1370, sample_times_ms=[500, 1370, 1750],
                uninterrupted=outcomes[0], restored=outcomes[1])


def main(out):
    out.mkdir(parents=True, exist_ok=True)
    with TemporaryDirectory() as directory, sync_playwright() as pw:
        target = Path(directory) / "index.html"
        build(target)
        browser = pw.chromium.launch(channel="chrome")
        slides = []
        live = []
        for width, height in [(1280, 800), (390, 844)]:
            captures, traces = replay(browser, target.as_uri(), out, width, height)
            slides.extend(captures)
            live.extend(traces)
        lesson = checkpoint_lesson(browser, target.as_uri())
        probe = browser.new_page()
        probe.goto(target.as_uri() + "#measure")
        results = {}
        # Repeated absolute scheduling reveals both fixed offset and accumulated drift.
        for rate in [44100, 48000]:
            beats = [200, 750, 1000, 1370, 1800] * 8
            run = lambda: probe.evaluate("([rate, beats]) => measurePhrase(rate, beats)", [rate, beats])
            rows = run()
            assert rows == run()
            for row in rows:
                assert abs(row["errorSamples"]) <= 1.01 and abs(row["amplitude"] - .25) < .00005
                assert row["landing"] < .00005
            results[rate] = rows
        revision = subprocess.check_output(["git", "log", "-1", "--format=%H", "--",
                                            "build.py", "instrument.js", "editor.html"],
                                           cwd=Path(__file__).parent, text=True).strip()
        manifest = dict(version=1, demo_id=DEMO, title="Motion phrase", scenario="V06 · I07 · I14 · I17",
                        revision=revision, host=f"{platform.system()} {platform.release()} · Chrome {browser.version}",
                        backend="Moxi Figure SVG / Web Audio", scale=1, fixture="Two-second three-knot flight",
                        reproduce="PYTHONPATH=python python3 examples/motion-envelope/check_browser.py",
                        slides=slides)
        write_json(out / "manifest.json", manifest)
        write_json(out / "timing.json", dict(measured_at=datetime.now(timezone.utc).isoformat(),
                                             host=manifest["host"], revision=revision, live=live, checkpoint_lesson=lesson, runs=results))
        (out / "index.html").write_text(render(load_manifest(out / "manifest.json")))
        probe.context.set_offline(True)
        probe.goto((out / "index.html").resolve().as_uri())
        probe.keyboard.press("ArrowRight")
        expect(probe.locator("#counter")).to_have_text(f"2 / {len(slides)}")
        probe.locator("#prev").click()
        probe.locator("[data-jump]").last.click()
        expect(probe.locator("figure:visible img")).to_be_visible()
        assert probe.locator("figure:visible img").evaluate("i => i.complete && i.naturalWidth === 390")
        print(f"PASS desktop, narrow, checkpoint, input equivalence, repeat playback, "
              f"{len(slides)} offline slides; 2 × 40 peaks at each sample rate")
        browser.close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, default=ROOT / "artifacts/demo-slideshows" / DEMO)
    main(parser.parse_args().out)
