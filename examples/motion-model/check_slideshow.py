"""Optional Playwright/Chrome check of the generated, offline evidence viewer."""
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import platform

from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "artifacts/demo-slideshows/motion-model"


def main():
    (OUT / "slideshow-check.json").unlink(missing_ok=True)
    manifest = json.loads((OUT / "manifest.json").read_text())
    count = len(manifest["slides"])
    errors = []
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(channel="chrome", headless=True)
        version = browser.version
        page = browser.new_page(viewport={"width": 1280, "height": 1000})
        page.on("pageerror", lambda error: errors.append(str(error)))
        page.goto((OUT / "index.html").as_uri())
        assert page.locator("figure[data-slide]").count() == count
        for index in range(count):
            assert page.locator("#counter").inner_text() == f"{index + 1} / {count}"
            image = page.locator("figure:visible img.shot")
            image.evaluate("image => image.decode()")
            assert image.evaluate("image => image.complete && image.naturalWidth > 0")
            page.locator("#next").click()
        assert page.locator("#counter").inner_text() == f"1 / {count}"
        page.keyboard.press("ArrowLeft")
        assert page.locator("#counter").inner_text() == f"{count} / {count}"
        page.keyboard.press("ArrowRight")
        assert page.locator("#counter").inner_text() == f"1 / {count}"
        page.locator("#prev").click()
        assert page.locator("#counter").inner_text() == f"{count} / {count}"
        page.get_by_text("Contact sheet", exact=True).click()
        assert not page.locator("[data-jump='5']").is_visible()
        page.get_by_text("Contact sheet", exact=True).click()
        page.locator("[data-jump='5']").click()
        assert page.locator("#counter").inner_text() == f"6 / {count}"
        page.reload()
        assert page.locator("#counter").inner_text() == f"1 / {count}"
        page.set_viewport_size({"width": 390, "height": 844})
        assert page.evaluate("document.documentElement.scrollWidth <= innerWidth")
        page.locator("#next").click()
        assert page.locator("#counter").inner_text() == f"2 / {count}"
        assert not errors, errors
        browser.close()
    record = dict(source_revision=manifest["revision"], chrome_version=version,
                  checked_at=datetime.now(timezone.utc).isoformat(),
                  viewer_sha256=hashlib.sha256((OUT / "index.html").read_bytes()).hexdigest(),
                  host=f"{platform.system()} {platform.release()} {platform.machine()}",
                  result="PASS", image_count=count, viewports=[[1280, 1000], [390, 844]],
                  checks=["Every full-size image decoded", "Next/previous wrap",
                          "Arrow navigation", "Thumbnail jump", "Reload", "Mobile width and navigation"],
                  page_errors=errors,
                  limits="Offline viewer only; native consumer outcomes are in verification.json")
    (OUT / "slideshow-check.json").write_text(json.dumps(record, indent=2) + "\n")
    print(f"PASS: {count} offline images; buttons, arrows, thumbnails, reload, mobile width")


if __name__ == "__main__":
    main()
