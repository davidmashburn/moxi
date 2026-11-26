"""Replay V03 through a temporary Chrome profile and verify each saved state."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys

from playwright.sync_api import expect, sync_playwright

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]


def replay(page, url, output):
    def shot(name):
        page.locator("#curve").evaluate("(img) => img.decode()")
        if output:
            page.screenshot(path=output / f"{name}.png")

    def saved():
        return json.loads(page.evaluate("localStorage.getItem('moxi.v03.score.v1')"))

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
            assert not errors, errors
            print(f"PASS · Chrome {browser.version} · V03 / I01 / I12 · wide and narrow · no page exceptions")
            browser.close()
    finally:
        server.terminate()
        server.wait()
