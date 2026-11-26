"""Record through ordinary controls in Chrome; retain bounded V06 evidence."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import math
from pathlib import Path
import platform
import struct
import subprocess
from tempfile import TemporaryDirectory

from playwright.sync_api import expect, sync_playwright

from build import build

ROOT = Path(__file__).resolve().parents[2]
SOURCE = Path(__file__).resolve().parent

# Observe actual oscillator lifetimes and displayed marks, without authoring a take.
OBSERVE = """
window.starts = [];
window.failures = [];
window.addEventListener('error', event => failures.push(event.message));
const originalStart = OscillatorNode.prototype.start;
const originalStop = OscillatorNode.prototype.stop;
OscillatorNode.prototype.start = function(when) {
    const trace = {start:when, frames:[], rate:this.context.sampleRate, stops:[]};
    starts.push(trace);
    const node = this;
    const gain = document.querySelector('#gain');
    const path = document.querySelector('#path');
    const dot = gain.querySelector('circle');
    const observer = new MutationObserver(() => {
        const clock = node.context.currentTime - when;
        const read = section => {
            const line = section.querySelector('polyline').points;
            const marker = section.querySelector('circle');
            return [marker.cx.baseVal.value, marker.cy.baseVal.value];
        };
        if (clock >= 0 && clock <= 2) trace.frames.push([clock, ...read(path), ...read(gain)]);
    });
    observer.observe(dot, {attributes:true, attributeFilter:['cx']});
    this.addEventListener('ended', () => observer.disconnect());
    this.v06Trace = trace;
    return originalStart.call(this, when);
};
OscillatorNode.prototype.stop = function(when) {
    if (this.v06Trace) this.v06Trace.stops.push(when ?? this.context.currentTime);
    return originalStop.call(this, when);
};
"""


def points(page, section="gain"):
    return page.locator(f"#{section} polyline").evaluate(
        "p => Array.from(p.points, q => [q.x, q.y])")


def state(page):
    return page.evaluate("""() => ({
        curves: [...document.querySelectorAll('polyline')].map(p => p.getAttribute('points')),
        marks: [...document.querySelectorAll('circle')].map(p => [p.cx.baseVal.value,p.cy.baseVal.value]),
        seek: document.querySelector('#seek').value,
        score: document.querySelector('#score').textContent
    })""")


def seek(page, ms):
    page.get_by_role("slider", name="Inspect phrase").fill(str(ms))


def normalized(points_, ground, peak):
    return [(x - points_[0][0], (y - ground) / (peak - ground)) for x, y in points_]


def height_at(heights, seconds):
    position = max(0, min(200, seconds * 100))
    index = min(199, int(position))
    return heights[index] + (position - index) * (heights[index + 1] - heights[index])


def capture(page, out, width, name):
    path = out / f"{width}-{name}.png"
    page.screenshot(path=path, full_page=True)
    assert page.evaluate("document.documentElement.scrollWidth <= innerWidth")
    return path.name


def drag_height(page, fraction, release=True):
    control = page.get_by_role("slider", name="Height", exact=False)
    control.scroll_into_view_if_needed()
    bounds = control.bounding_box()
    y = bounds["y"] + bounds["height"] / 2
    page.mouse.move(bounds["x"] + bounds["width"] / 2, y)
    page.mouse.down()
    page.mouse.move(bounds["x"] + 8 + fraction * (bounds["width"] - 16), y, steps=5)
    if release:
        page.mouse.up()
    return bounds, y


def replay(browser, url, out, width, height):
    page = browser.new_page(viewport={"width": width, "height": height}, device_scale_factor=1)
    page_errors = []
    page.on("pageerror", lambda error: page_errors.append(str(error)))
    page.add_init_script(OBSERVE)
    page.goto(url + "#measure")
    status = page.locator("#message")
    height_control = page.get_by_role("slider", name="Height", exact=False)
    baseline = points(page)
    ground, peak = baseline[0][1], baseline[1][1]
    images = [capture(page, out, width, "ready")]
    height_control.fill("0.2")
    page.get_by_role("button", name="Record gesture", exact=True).click()
    expect(status).to_contain_text("Recording ·")
    expect(page.locator("#seek")).to_be_disabled()
    expect(page.locator("#commit")).to_be_disabled()
    expect(page.locator("#save")).to_be_disabled()
    page.wait_for_function("Number(document.querySelector('#seek').value) >= 250")
    drag_height(page, .85)
    # A held height is retained after releasing the pointer; keyboard is equivalent input.
    page.wait_for_function("Number(document.querySelector('#seek').value) >= 750")
    height_control.press("Home")
    for _ in range(12):
        height_control.press("ArrowRight")
    page.wait_for_function("Number(document.querySelector('#seek').value) >= 1100")
    images.append(capture(page, out, width, "recording"))
    expect(status).to_contain_text("Gesture captured", timeout=15000)
    expect(page.locator("#beat")).to_be_disabled()
    expect(page.locator("#commit")).to_be_enabled()
    expect(page.locator("#score")).to_contain_text("Revision 0 · Authored apex 1000 ms")
    captured = points(page)
    assert len(captured) == 201
    heights = [p[1] for p in normalized(captured, ground, peak)]
    assert abs(heights[0]) < 1e-10 and abs(heights[-1]) < 1e-10
    assert all(-1e-10 <= h <= 1 + 1e-10 for h in heights)
    assert max(heights) > .75 and any(.1 < h < .15 for h in heights)
    flight_heights = [p[1] for p in normalized(points(page, "path"), ground, peak)]
    assert max(abs(a - b) for a, b in zip(flight_heights, heights)) < 1e-10
    seek(page, 750)
    before_edit = points(page)
    height_control.fill("0.73")
    page.get_by_role("button", name="Set height at inspection time").click()
    edited = points(page)
    assert edited[:75] == before_edit[:75] and edited[76:] == before_edit[76:]
    assert abs((edited[75][1] - ground) / (peak - ground) - .73) < 1e-6
    page.locator("#commit").click()
    expect(page.locator("#score")).to_have_text("Revision 1 · Authored recorded gesture · 201 samples")
    expect(page.locator("#commit")).to_be_disabled()
    page.locator("#save").click()
    saved = state(page)
    images.append(capture(page, out, width, "edited-committed"))
    # Stopped inspection is a deterministic view of this same authored take.
    poses = []
    for _ in range(2):
        row = []
        for ms in (0, 350, 750, 1250, 2000):
            seek(page, ms)
            row.append(state(page)["marks"])
        poses.append(row)
    assert poses[0] == poses[1]
    seek(page, 0)
    expect(page.locator("#set-height")).to_be_disabled()
    seek(page, 2000)
    expect(page.locator("#set-height")).to_be_disabled()
    # Repeat actual live playback; verify every observed marker against the authored curve.
    heights = [(p[1] - ground) / (peak - ground) for p in edited]
    first_trace = page.evaluate("starts.length")
    ends = []
    for _ in range(2):
        page.locator("#play").click()
        expect(status).to_contain_text("Playing")
        expect(status).to_have_text("Playback complete.")
        ends.append(state(page)["marks"])
    assert ends[0] == ends[1]
    live = []
    for trace in page.evaluate("starts")[first_trace:]:
        assert len(trace["frames"]) >= 10
        errors = []
        clock_errors = []
        for clock, px, py, gx, gy in trace["frames"]:
            seconds = (gx - edited[0][0]) / (edited[-1][0] - edited[0][0]) * 2
            expected = ground + height_at(heights, seconds) * (peak - ground)
            errors.append(max(abs(gy - expected), abs(py - expected), abs(px - gx)))
            clock_errors.append(abs(clock - seconds) * 1000)
        assert max(errors) < .001
        assert max(clock_errors) < 50
        live.append(dict(frames=len(errors), max_svg_error=max(errors), max_clock_error_ms=max(clock_errors)))
    assert len(live) == 2
    # Render actual PCM with the production scheduler, using this UI-created curve.
    offline = []
    for rate in (44100, 48000):
        run = lambda: page.evaluate("rate => measureGesture(rate)", rate)
        samples = run()
        assert samples == run()
        error = max(abs(value - .25 * height_at(heights, i / rate - .125))
                    for i, value in enumerate(samples))
        assert error < 1e-6, error
        assert max(abs(v) for v in samples[:int(rate * .125)]) == 0
        assert max(abs(v) for v in samples[math.ceil(rate * 2.125):]) == 0
        pcm = struct.pack(f"<{len(samples)}f", *samples)
        offline.append(dict(sample_rate=rate, samples=len(samples), max_gain_error=error,
                            repeat_pcm_identical=True, sha256=hashlib.sha256(pcm).hexdigest()))
    # Replacement cancellation preserves the complete prior authored take and stopped pose.
    seek(page, 750)
    assert state(page) == saved
    for reason in ("button", "escape-held-pointer", "pointercancel", "blur"):
        before = state(page)
        old_height = height_control.input_value()
        page.locator("#record").click()
        expect(status).to_contain_text("Recording ·")
        bounds, y = drag_height(page, .95, release=False)
        if reason == "button":
            page.mouse.up()
            page.get_by_role("button", name="Cancel recording").click()
        elif reason == "escape-held-pointer":
            page.keyboard.press("Escape")
            page.mouse.move(bounds["x"] + 9, y, steps=5)
            page.mouse.up()
        elif reason == "pointercancel":
            height_control.dispatch_event("pointercancel", {"pointerId": 1})
            page.mouse.move(bounds["x"] + 9, y, steps=5)
            page.mouse.up()
        else:
            page.evaluate("dispatchEvent(new Event('blur'))")
            page.mouse.move(bounds["x"] + 9, y, steps=5)
            page.mouse.up()
        expect(status).to_contain_text("cancelled")
        assert state(page) == before
        assert height_control.input_value() == old_height
        assert page.evaluate("starts.at(-1).stops.length") >= 2
    images.append(capture(page, out, width, "cancelled-replacement"))
    # A cancelled replacement cannot finish later and overwrite the restored curve.
    page.wait_for_timeout(2100)
    assert state(page) == saved
    # Stop a replay and restore the precise pre-playback inspection state.
    page.locator("#play").click()
    expect(status).to_contain_text("Playing")
    page.get_by_role("button", name="Stop playback").click()
    assert state(page) == saved
    # A replacement also preserves an uncommitted point edit, not only the score.
    height_control.press("Home")
    height_control.fill("0.44")
    page.locator("#set-height").click()
    uncommitted = state(page)
    assert uncommitted != saved
    page.locator("#record").click()
    expect(status).to_contain_text("Recording ·")
    page.locator("#cancel").click()
    assert state(page) == uncommitted
    page.locator("#discard").click()
    assert state(page) == saved
    # Retry after cancellation, discard a complete replacement, then recover checkpoint.
    height_control.press("End")
    page.locator("#record").click()
    expect(status).to_contain_text("Gesture captured")
    assert points(page) != edited
    page.locator("#discard").click()
    assert points(page) == edited
    seek(page, 750)
    page.locator("#flight").click()
    page.locator("#commit").click()
    expect(page.locator("#score")).to_contain_text("Revision 2 · Authored apex 1000 ms")
    page.locator("#restore").click()
    expect(page.locator("#score")).to_contain_text("Revision 3 · Authored recorded gesture")
    assert points(page) == edited and page.locator("#seek").input_value() == "750"
    images.append(capture(page, out, width, "checkpoint-restored"))
    assert not page.evaluate("failures")
    # This feature is session-local, like the original checkpoint; reload resets it.
    page.reload()
    assert points(page) == baseline
    expect(page.locator("#score")).to_have_text("Revision 0 · Authored apex 1000 ms")
    assert not page_errors, page_errors
    page.close()
    return dict(viewport=[width, height], captures=images, authored_heights=heights,
                live_replays=live, stopped_replay_identical=True, offline=offline,
                cancellation=["button", "Escape while dragging + subsequent input", "injected pointercancel", "injected window blur"],
                checkpoint_restores_curve_and_inspection=True, reload="fresh session", page_errors=page_errors)


def audio_failures(browser, url, out):
    outcomes = []
    for pending in (False, True):
        page = browser.new_page(viewport={"width": 390, "height": 844})
        page_errors = []
        page.on("pageerror", lambda error: page_errors.append(str(error)))
        page.add_init_script(OBSERVE)
        if pending:
            page.add_init_script("""
                const resume = AudioContext.prototype.resume;
                let first = true;
                AudioContext.prototype.resume = function() {
                    if (!first) return resume.call(this);
                    first = false;
                    return new Promise(resolve => {window.releaseAudio = () => resume.call(this).then(resolve)});
                };
            """)
        else:
            page.add_init_script("AudioContext.prototype.resume = () => Promise.reject(new Error('synthetic unavailable'))")
        page.goto(url)
        page.locator("#beat").press("ArrowRight")
        before = state(page)
        page.locator("#record").click()
        if pending:
            expect(page.locator("#message")).to_have_text("Starting audio…")
            capture(page, out, 390, "pending-audio")
            page.locator("#cancel").click()
            page.evaluate("releaseAudio()")
            assert not page.evaluate("starts")
            assert state(page) == before
            # A later attempt can resume and record normally after the stale promise settles.
            page.locator("#record").click()
            expect(page.locator("#message")).to_contain_text("Recording ·")
            page.evaluate("Object.defineProperty(document, 'hidden', {value:true, configurable:true}); document.dispatchEvent(new Event('visibilitychange'))")
            expect(page.locator("#message")).to_contain_text("page hidden")
            assert state(page) == before
        else:
            expect(page.locator("#message")).to_contain_text("Audio unavailable · synthetic unavailable")
            capture(page, out, 390, "audio-unavailable")
            assert state(page) == before
            assert not page.evaluate("starts")
        assert not page.evaluate("failures")
        assert not page_errors, page_errors
        outcomes.append("cancel pending resume, ignore stale result, retry + injected hidden-page cancel" if pending else "rejected audio resume preserves uncommitted draft")
        page.close()
    return outcomes


def main(out):
    out.mkdir(parents=True, exist_ok=True)
    with TemporaryDirectory() as directory, sync_playwright() as pw:
        target = Path(directory) / "index.html"
        build(target)
        browser = pw.chromium.launch(channel="chrome")
        evidence = dict(captured_at=datetime.now(timezone.utc).isoformat(),
                        revision=subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
                        source_sha256={name: hashlib.sha256((SOURCE / name).read_bytes()).hexdigest()
                                       for name in ("build.py", "editor.html", "instrument.js", "gesture.mjs", "check_gesture_browser.py")},
                        dirty_status=subprocess.check_output(["git", "status", "--short"], cwd=ROOT, text=True).strip().splitlines(),
                        environment=f"{platform.system()} {platform.release()} · Chrome {browser.version} · Playwright",
                        url="file://<temporary directory>/index.html#measure", role="local author; synthetic gesture, no account",
                        scenarios=[], failure_cases=[],
                        open=["speaker/display/input physical timing", "artist trials", "screen-reader operation", "cross-session storage", "real touch device"])
        for width, height in ((1280, 800), (390, 844)):
            evidence["scenarios"].append(replay(browser, target.as_uri(), out, width, height))
        evidence["failure_cases"] = audio_failures(browser, target.as_uri(), out)
        (out / "evidence.json").write_text(json.dumps(evidence, indent=2) + "\n")
        browser.close()
    print(f"PASS recorded gesture: desktop + narrow, stopped edit, repeat live/PCM, cancellation, checkpoint, audio failure; evidence {out}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, required=True, help="Fresh evidence directory; no shared gallery writes")
    main(parser.parse_args().out)
