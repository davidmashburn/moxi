"""Replay V03 through a temporary Chrome profile and verify each saved state."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
from urllib.parse import urlsplit

from playwright.sync_api import expect, sync_playwright

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
SCORE_KEY = "moxi.v03.score.v1"
RECOVERY_KEY = SCORE_KEY + ".recovery"


def replay(page, url, output):
    def shot(name):
        page.locator("#curve").evaluate("(img) => img.decode()")
        if output:
            page.screenshot(path=output / f"{name}.png")

    def saved():
        return json.loads(page.evaluate("key => localStorage.getItem(key)", SCORE_KEY))

    page.goto(url)
    expect(page.locator("#summary")).to_have_text("0 motions · 0 ticks")
    shot("01-definition")
    page.locator("#add-motion").click()
    page.locator("#add-group").click()
    page.locator("#slot-2").press("ArrowDown")
    expect(page.locator("#slot-3")).to_be_focused()
    page.locator("#add-motion").click()
    page.keyboard.press("Enter")
    expect(page.locator("#summary")).to_have_text("3 motions · 4 ticks")
    shot("02-compose")

    page.get_by_label("Sequence order").select_option("reverse")
    page.get_by_label("Ticks per beat").press("ArrowUp")
    expect(page.locator("#candidate")).to_have_text("Proposed score · 6 ticks")
    shot("03-candidate")
    apply = page.get_by_role("button", name="Apply revision")
    before = saved()
    apply.press("Enter")
    expect(apply).to_be_focused()
    after = saved()
    assert before["root"] == after["root"] and before["selected"] == after["selected"] == 3
    expect(page.locator("#timeline div")).to_have_text(
        ["#4 Sweep 0 → 3", "#5 Sweep 0 → 3", "#2 Sweep 3 → 6"])
    shot("04-replaced")

    capacity = page.get_by_label("Parallel group capacity")
    capacity.fill("1")
    capacity.press("Enter")
    expect(capacity).to_be_focused()
    expect(page.locator("#status")).to_contain_text("Group #3 has 2 slots")
    assert saved() == after
    shot("05-rejected")
    page.reload()
    assert saved() == after
    expect(page.locator("#slot-3")).to_have_attribute("aria-pressed", "true")
    expect(page.locator("#revision")).to_have_text("rev 2")

    page.locator("#formal").click()
    page.locator("#radius").press("ArrowUp")
    page.locator("#tick").press("Home")
    page.keyboard.press("PageUp")
    expect(page.locator("#readout")).to_contain_text("70.5°")
    assert saved()["sketch"]["arm"] == 41
    shot("06-joint")
    page.locator("#undo").click(click_count=1)
    page.locator("#undo").press("Enter")
    assert saved() == after
    expect(page.locator("#formal")).to_be_visible()
    shot("07-undo")
    page.set_viewport_size({"width":390, "height":844})
    page.reload()
    assert page.evaluate("document.documentElement.scrollWidth === innerWidth")
    expect(page.locator("#summary")).to_have_text("3 motions · 6 ticks")
    assert page.request.post(url + "/curve", data="{}").status == 400


def recovery_replay(page, output):
    def stored(key=SCORE_KEY):
        return page.evaluate("key => localStorage.getItem(key)", key)

    def seed(raw):
        page.evaluate("([key, recovery, raw]) => { localStorage.removeItem(recovery); localStorage.setItem(key, raw); }",
                      [SCORE_KEY, RECOVERY_KEY, raw])
        page.reload()
        expect(page.locator("#summary")).to_have_text("0 motions · 0 ticks")
        expect(page.locator("#status")).to_contain_text("Saved score could not be opened")

    def shot(name):
        if output:
            page.locator("#curve").evaluate("img => img.decode()")
            page.screenshot(path=output / f"{name}.png", full_page=True)

    page.set_viewport_size({"width":1280, "height":800})
    source = json.loads(stored())
    unsupported = {**source, "format":99}
    incompatible = json.loads(stored())
    incompatible["schema"]["capacity"] = 1
    for name, raw in [
        ("malformed", ' \r\n {"unfinished": "original ☀️ source"'),
        ("unsupported", json.dumps(unsupported, indent=2) + "\r\n"),
        ("incompatible", json.dumps(incompatible, indent=2) + "\r\n"),
    ]:
        seed(raw)
        assert stored() == raw and stored(RECOVERY_KEY) is None
        page.locator("#slot-1").click()
        assert json.loads(stored(RECOVERY_KEY)) == [raw]
        page.locator("#add-motion").click()
        page.locator("#note").fill("Recoverable starter edit")
        page.locator("#note").press("Tab")
        edited = stored()
        page.reload()
        assert stored() == edited and json.loads(stored(RECOVERY_KEY)) == [raw]
        expect(page.locator("#summary")).to_have_text("1 motions · 2 ticks")
        expect(page.locator("#note")).to_have_value("Recoverable starter edit")
        with page.expect_download() as pending:
            page.locator("#recovery-links a").click()
        download = pending.value
        assert Path(download.path()).read_bytes() == raw.encode("utf-8")
        if output:
            download.save_as(output / f"recovered-{name}.json")
        shot(f"08-recovery-{name}")

    raw = json.dumps(incompatible, indent=2) + "\r\n"
    for failed_key in (RECOVERY_KEY, SCORE_KEY):
        seed(raw)
        page.evaluate("""key => {
            const original = Storage.prototype.setItem;
            window.restoreStorage = () => { Storage.prototype.setItem = original; };
            Storage.prototype.setItem = function(k, value) {
                if (k === key) throw new DOMException('Injected storage write failure', 'QuotaExceededError');
                return original.call(this, k, value);
            };
        }""", failed_key)
        page.locator("#slot-1").click()
        expect(page.locator("#status")).to_contain_text("Injected storage write failure")
        page.locator("#add-motion").click()
        expect(page.locator("#status")).to_contain_text("Edit rejected")
        expect(page.locator("#summary")).to_have_text("0 motions · 0 ticks")
        expect(page.locator("#undo")).to_be_disabled()
        assert stored() == raw
        assert stored(RECOVERY_KEY) is None if failed_key == RECOVERY_KEY else json.loads(stored(RECOVERY_KEY)) == [raw]
        shot("09-failed-recovery-write" if failed_key == RECOVERY_KEY else "10-failed-active-write")
        page.reload()  # Removes the injected fault and retries from the retained source.
        assert stored() == raw
        page.locator("#add-motion").click()
        assert json.loads(stored(RECOVERY_KEY)) == [raw]
        baseline = stored()

    # A failed selection, edit or undo must also leave an already-valid active score intact.
    page.evaluate("""key => {
        const original = Storage.prototype.setItem;
        window.restoreStorage = () => { Storage.prototype.setItem = original; };
        Storage.prototype.setItem = function(k, value) {
            if (k === key) throw new Error('Injected active write failure');
            return original.call(this, k, value);
        };
    }""", SCORE_KEY)
    page.locator("#slot-2").click()
    expect(page.locator("#slot-1")).to_have_attribute("aria-pressed", "true")
    page.locator("#note").fill("Rejected note")
    page.locator("#note").press("Tab")
    expect(page.locator("#note")).to_have_value(source["sketch"]["note"])
    page.locator("#undo").click()
    expect(page.locator("#status")).to_contain_text("Injected active write failure")
    expect(page.locator("#undo")).to_be_enabled()
    expect(page.locator("#summary")).to_have_text("1 motions · 2 ticks")
    assert stored() == baseline and json.loads(stored(RECOVERY_KEY)) == [raw]
    page.evaluate("window.restoreStorage()")
    page.locator("#undo").click()
    page.reload()
    expect(page.locator("#summary")).to_have_text("0 motions · 0 ticks")
    assert json.loads(stored(RECOVERY_KEY)) == [raw]
    page.set_viewport_size({"width":390, "height":844})
    assert page.evaluate("document.documentElement.scrollWidth === innerWidth")
    expect(page.locator("#recovery-links a")).to_be_visible()
    shot("11-recovery-narrow")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--images", type=Path, help="Optional destination for fresh PNGs")
    args = parser.parse_args()
    if args.images:
        args.images.mkdir(parents=True, exist_ok=True)
    server = subprocess.Popen([sys.executable, str(HERE / "app.py"), "--port", "0"],
                              stdout=subprocess.PIPE, text=True, env={**os.environ, "PYTHONPATH": str(ROOT / "python")})
    try:
        url = server.stdout.readline().strip()
        with sync_playwright() as pw:
            browser = pw.chromium.launch(channel="chrome")
            page = browser.new_page(viewport={"width":1280,"height":800}, device_scale_factor=2)
            errors = []
            page.on("pageerror", lambda error: errors.append(str(error)))
            replay(page, url, args.images)
            recovery_replay(page, args.images)
            retained = page.evaluate("keys => keys.map(key => localStorage.getItem(key))", [SCORE_KEY, RECOVERY_KEY])
            server.terminate()
            server.wait()
            server = subprocess.Popen([sys.executable, str(HERE / "app.py"), "--port", str(urlsplit(url).port)],
                                      stdout=subprocess.PIPE, text=True, env={**os.environ, "PYTHONPATH": str(ROOT / "python")})
            assert server.stdout.readline().strip() == url
            page.reload()
            expect(page.locator("#summary")).to_have_text("0 motions · 0 ticks")
            expect(page.locator("#recovery-links a")).to_be_visible()
            assert page.evaluate("keys => keys.map(key => localStorage.getItem(key))", [SCORE_KEY, RECOVERY_KEY]) == retained
            assert not errors, errors
            print(f"PASS · Chrome {browser.version} · {url} · V03 / I01 / I12 · recovery downloads, select/edit/reload, failed writes and undo · same-origin host restart · wide and narrow · no page exceptions")
            browser.close()
    finally:
        server.terminate()
        server.wait()
