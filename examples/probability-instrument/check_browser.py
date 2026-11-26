"""Exercise the running example with Chrome. Run with PYTHONPATH=python."""
from threading import Thread
from http.server import ThreadingHTTPServer
from playwright.sync_api import expect, sync_playwright
from instrument import Handler


def exercise(page):
    saved = page.locator("#saved td")
    draft = page.locator("#draft td")
    target = page.get_by_label("Requested P(x)")
    apply = page.get_by_role("button", name="Apply preview")
    pin = page.get_by_label("Fix the committed mean")
    initial = ["0.25", "0.5", "0.25", "1"]
    expect(saved).to_have_text(initial)
    pin.check()

    bar = page.locator("rect[data-mark]").nth(4).bounding_box()
    x = bar["x"] + bar["width"] / 2
    y = bar["y"] + bar["height"]
    page.mouse.move(x, bar["y"])
    page.mouse.down()
    page.mouse.move(x, y - 1.6 * bar["height"])
    expect(apply).to_be_enabled()
    page.keyboard.press("Escape")
    page.mouse.move(x, y - 1.4 * bar["height"])
    page.mouse.up()
    expect(page.get_by_role("status")).to_have_text("Preview discarded.")
    expect(draft).to_have_text(["—"] * 4)
    expect(saved).to_have_text(initial)
    expect(apply).to_be_disabled()

    page.mouse.move(x, bar["y"])
    page.mouse.down()
    page.mouse.move(x, y - 1.6 * bar["height"], steps=5)
    page.mouse.up()
    expect(apply).to_be_enabled()
    tail = float(target.input_value())
    assert abs(tail - 0.4) < .012
    expect(saved).to_have_text(initial)
    pointer_result = draft.all_text_contents()
    page.keyboard.press("Escape")
    expect(apply).to_be_disabled()
    target.fill(str(tail))
    expect(draft).to_have_text(pointer_result)
    target.press("Enter")
    expect(saved).to_have_text(pointer_result)
    target.fill("0.8")
    expect(page.get_by_role("status")).to_contain_text("possible mean is 1.6 to 1.8")
    expect(apply).to_be_disabled()
    expect(saved).to_have_text(pointer_result)
    page.get_by_role("button", name="Discard").click()
    pin.uncheck()
    target.fill("1")
    expect(draft).to_have_text(["0", "0", "1", "2"])
    apply.click()
    target.fill(".2")
    expect(draft).to_have_text(["0.4", "0.4", "0.2", "0.8"])
    assert page.evaluate("document.documentElement.scrollWidth <= innerWidth")


if __name__ == "__main__":
    with ThreadingHTTPServer(("127.0.0.1", 0), Handler) as server, sync_playwright() as pw:
        Thread(target=server.serve_forever, daemon=True).start()
        browser = pw.chromium.launch(channel="chrome")
        try:
            for width, height in ((1280, 800), (390, 844)):
                page = browser.new_page(viewport={"width": width, "height": height})
                page.goto(f"http://127.0.0.1:{server.server_port}/")
                exercise(page)
                print(f"PASS Chrome {browser.version}, {width} × {height}")
                page.close()
        finally:
            browser.close()
            server.shutdown()
