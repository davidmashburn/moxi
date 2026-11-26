"""Exercise the storyboard against a fresh server and browser context."""
import argparse
import json
from pathlib import Path
from threading import Thread

from playwright.sync_api import sync_playwright, expect

from app import Handler, ThreadingHTTPServer

STEPS = json.loads(Path(__file__).with_name("storyboard.json").read_text())


def verify(page, index):
    selected = [(), (), ("S-14",), (), ("S-14",), ("S-14",), ("S-14", "S-38"),
                ("S-14", "S-38"), ("S-38",), (), (), (), ("T-19",), ("T-19",),
                ("T-02", "T-19")][index]
    for selector in ("tbody a.picked", ".canvas a.picked"):
        assert page.locator(selector).all_text_contents() == list(selected)
    expect(page.locator("circle.picked")).to_have_count(int(bool(selected)))
    count = [4, 4, 4, 3, 4, 2, 2, 2, 2, 2, 2, 4, 4, 2, 2][index]
    expect(page.locator("#plot a")).to_have_count(count)
    if index == 1:
        expect(page.locator("tbody a").first).to_be_focused()
    if index == 3:
        expect(page.locator(".status")).to_contain_text("S-14 (filtered)")
    if index == 7:
        expect(page.get_by_role("alert")).to_have_text("Choose one visible source to delete.")
    if index in (9, 10):
        expect(page.locator(".status")).to_contain_text("S-38 (deleted)")
        expect(page.locator("#plot a").first).to_have_attribute("aria-label", "Select S-14")


def run(output):
    if output:
        output.mkdir(parents=True, exist_ok=True)
    with ThreadingHTTPServer(("127.0.0.1", 0), Handler) as server, sync_playwright() as pw:
        Thread(target=server.serve_forever, daemon=True).start()
        browser = pw.chromium.launch()
        page = browser.new_page(viewport={"width": 1280, "height": 800}, device_scale_factor=2)
        errors = []
        page.on("pageerror", lambda error: errors.append(str(error)))
        origin = f"http://127.0.0.1:{server.server_port}/"
        for index, (_, operation, selector, action, _) in enumerate(STEPS):
            if operation == "open":
                page.goto(origin)
            elif operation == "tab":
                for _ in range(10):
                    page.keyboard.press("Tab")
                    if page.locator(selector).first.evaluate("el => el === document.activeElement"):
                        break
            elif operation == "enter":
                with page.expect_navigation():
                    page.keyboard.press("Enter")
            elif operation == "reload":
                page.reload()
            elif operation == "click":
                with page.expect_navigation():
                    page.locator(selector).first.click()
            else:
                raise ValueError(operation)
            page.wait_for_load_state()
            verify(page, index)
            if output:
                page.screenshot(path=output / f"step-{index + 1:02}.png")
            print("PASS", action)
        page.set_viewport_size({"width": 390, "height": 844})
        assert page.evaluate("document.documentElement.scrollWidth <= innerWidth")
        page.locator(".canvas a").last.click()
        expect(page.locator(".status")).to_contain_text("T-68 (visible)")
        assert page.goto(origin + "?domain=transit&selected=S-14").status == 400
        for suffix in ("filtered=1", "selected=", "grouped=2"):
            response = page.goto(origin + "?selected=S-14&filtered=1&delete=1&" + suffix)
            assert response.status == 400
        assert not errors, errors
        browser.close()
        server.shutdown()
        print("PASS narrow canvas selection and cross-domain rejection")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, help="save the fifteen replay frames")
    run(parser.parse_args().output)
