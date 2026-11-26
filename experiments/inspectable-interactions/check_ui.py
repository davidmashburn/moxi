"""Exercise the built checkout using a disposable loopback port and Chrome profile."""
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import subprocess
import sys
import tempfile
import threading

from playwright.sync_api import expect, sync_playwright

HERE = Path(__file__).resolve().parent


def exercise(page, url):
    errors = []
    page.on("pageerror", lambda error: errors.append(str(error)))
    page.goto(url)
    entry = page.get_by_role("spinbutton", name="Sample")
    status = page.locator("#status")
    stats = page.locator("#stats")
    inspect = page.locator("#inspect")
    marker = page.locator("svg circle")

    page.keyboard.press("Tab")
    expect(entry).to_be_focused()
    entry.fill("70")
    expect(inspect).to_contain_text("Origin 25 · Preview 70")
    entry.press("Escape")
    expect(entry).to_have_value("25")
    expect(stats).to_have_text("Revision 0 · Undo depth 0")

    def drag_to_middle():
        box = marker.bounding_box()
        plot = page.locator("svg").bounding_box()
        page.mouse.move(box["x"] + box["width"]/2, box["y"] + box["height"]/2)
        page.mouse.down()
        page.mouse.move(plot["x"] + plot["width"]/2, plot["y"] + plot["height"]/2, steps=12)

    drag_to_middle()
    expect(inspect).to_contain_text("Origin 25 · Preview 47")
    page.keyboard.press("Escape")
    page.mouse.move(100, 100)
    page.mouse.up()
    expect(entry).to_have_value("25")
    expect(page.locator("#commit")).to_be_disabled()
    drag_to_middle()
    page.mouse.up()
    expect(inspect).to_contain_text("Origin 25 · Preview 47")
    entry.press("Enter")
    expect(stats).to_have_text("Revision 1 · Undo depth 1")
    record = page.locator("#record").text_content()
    source_x = marker.bounding_box()["x"]
    page.locator("#undo").focus()
    page.keyboard.press("Enter")
    expect(stats).to_have_text("Revision 2 · Undo depth 0")
    expect(entry).to_have_value("25")
    expect(page.locator("#undo")).to_be_disabled()
    page.locator("#replay").click()
    expect(status).to_contain_text("Stale target")
    expect(stats).to_have_text("Revision 2 · Undo depth 0")

    page.reload()
    expect(page.locator("#record")).to_have_text(record)
    page.locator("#switchBoard").click()
    page.locator("#replay").click()
    expect(entry).to_have_value("47")
    expect(stats).to_have_text("Revision 1 · Undo depth 1")
    assert abs(source_x - marker.bounding_box()["x"]) > 50
    page.locator("#replay").click()
    expect(status).to_contain_text("Stale target")
    expect(stats).to_have_text("Revision 1 · Undo depth 1")
    expect(entry).to_have_value("47")

    page.set_viewport_size({"width": 390, "height": 844})
    assert page.evaluate("document.documentElement.scrollWidth <= innerWidth")
    entry.fill("101")
    expect(status).to_contain_text("whole sample from 0 to 100")
    entry.press("Enter")
    expect(page.locator("#commit")).to_be_disabled()
    entry.press("Escape")
    expect(entry).to_have_value("47")
    entry.fill("0")
    entry.press("Enter")
    expect(entry).to_have_value("0")
    expect(stats).to_have_text("Revision 2 · Undo depth 2")
    assert not errors, errors


if __name__ == "__main__":
    with tempfile.TemporaryDirectory() as dist, sync_playwright() as playwright:
        subprocess.run([sys.executable, HERE / "build.py", dist], check=True)
        handler = partial(SimpleHTTPRequestHandler, directory=dist)
        with ThreadingHTTPServer(("127.0.0.1", 0), handler) as server:
            threading.Thread(target=server.serve_forever, daemon=True).start()
            with playwright.chromium.launch(channel="chrome") as browser:
                page = browser.new_page(viewport={"width": 1100, "height": 1050})
                exercise(page, f"http://127.0.0.1:{server.server_port}")
                print(f"PASS · Chrome {browser.version} · wide and narrow cursor scenarios")
            server.shutdown()
