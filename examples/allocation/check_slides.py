"""Check the delivered file offline in a fresh browser context (optional Playwright)."""
from pathlib import Path

from playwright.sync_api import sync_playwright

GALLERY = Path(__file__).resolve().parents[2] / "artifacts/demo-slideshows/allocation/index.html"


def main():
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(channel="chrome")
        page = browser.new_page(offline=True)
        errors = []
        page.on("pageerror", lambda error: errors.append(str(error)))
        page.goto(GALLERY.as_uri())
        assert page.locator("#counter").inner_text() == "1 / 7"
        images = page.locator("img")
        assert images.count() == 14
        images.evaluate_all("images => Promise.all(images.map(image => image.decode()))")
        assert images.evaluate_all("images => images.every(i => i.src.startsWith('data:image/png;'))")
        page.keyboard.press("ArrowRight")
        assert page.locator("#counter").inner_text() == "2 / 7"
        page.locator("[data-jump='6']").click()
        assert page.locator("figure:visible").get_attribute("data-slide") == "6"
        page.locator("#prev").click()
        assert page.locator("#counter").inner_text() == "6 / 7"
        page.keyboard.press("ArrowLeft")
        page.locator("#next").click()
        assert page.locator("#counter").inner_text() == "6 / 7"
        assert not errors, errors
        print(f"PASS offline Chrome {browser.version}: seven images, contact sheet and navigation")
        browser.close()


if __name__ == "__main__":
    main()
