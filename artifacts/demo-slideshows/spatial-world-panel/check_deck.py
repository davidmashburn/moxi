#!/usr/bin/env python3
"""Exercise the actual local D08 HTML in offline Chrome; requires Playwright."""
from datetime import datetime, timezone
from pathlib import Path
import hashlib
import importlib.metadata
import json
import signal

from playwright.sync_api import sync_playwright

HERE = Path(__file__).resolve().parent
TIMEOUT_SECONDS = 90
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"


def sha(data):
    return hashlib.sha256(data).hexdigest()


def main():
    def timeout(_signal, _frame):
        raise TimeoutError(f"Offline deck check exceeded {TIMEOUT_SECONDS}s")

    signal.signal(signal.SIGALRM, timeout)
    signal.alarm(TIMEOUT_SECONDS)
    manifest = json.loads((HERE / "manifest.json").read_text())
    frames = manifest["slides"]
    record = {
        "revision": manifest["revision"],
        "recorded_at": datetime.now(timezone.utc).isoformat(),
        "html_sha256": sha((HERE / "index.html").read_bytes()),
        "checker_sha256": sha(Path(__file__).read_bytes()),
        "playwright_version": importlib.metadata.version("playwright"),
        "timeout_seconds": TIMEOUT_SECONDS,
        "url": "file://<repo>/artifacts/demo-slideshows/spatial-world-panel/index.html",
        "offline": True,
        "isolated_profile": True,
        "viewports": [],
    }
    errors, failures, network = [], [], []
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(executable_path=CHROME, headless=True)
        try:
            record["browser"] = browser.version
            for width, height in ((1440, 1000), (390, 844)):
                context = browser.new_context(
                    viewport={"width": width, "height": height},
                    device_scale_factor=1, offline=True)
                page = context.new_page()
                page.set_default_timeout(10000)
                page.on("pageerror", lambda error: errors.append(str(error)))
                page.on("requestfailed", lambda request: failures.append(request.url))
                page.on("request", lambda request: network.append(request.url)
                        if request.url.startswith(("http:", "https:")) else None)
                page.goto((HERE / "index.html").as_uri(), wait_until="load")
                # Decode all twelve real embedded images, including the contact sheet.
                images = page.evaluate("""async () => {
                  const result=[];
                  for (const img of document.images) {
                    await img.decode();
                    const bytes=await (await fetch(img.src)).arrayBuffer();
                    const digest=await crypto.subtle.digest('SHA-256', bytes);
                    result.push({width:img.naturalWidth, height:img.naturalHeight,
                      sha256:[...new Uint8Array(digest)].map(x=>x.toString(16).padStart(2,'0')).join('')});
                  }
                  return result;
                }""")
                expected = [{"width": frame["dimensions"][0],
                             "height": frame["dimensions"][1],
                             "sha256": frame["png_sha256"]} for frame in frames]
                assert images == expected + expected
                checks = []

                def state(index, action):
                    assert page.locator("#counter").inner_text() == f"{index + 1} / 6"
                    assert page.locator("figure:visible").count() == 1
                    assert page.locator("figure:visible").get_attribute("data-slide") == str(index)
                    checks.append({"action": action, "scenario_id": frames[index]["scenario_id"]})

                state(0, "open actual file offline")
                for index in (1, 2, 3, 4, 5, 0):
                    page.locator("#next").click()
                    state(index, "Next, including wrap")
                for index in (5, 4, 3, 2, 1, 0):
                    page.locator("#prev").click()
                    state(index, "Previous, including wrap")
                page.keyboard.press("ArrowLeft")
                state(5, "ArrowLeft wrap")
                page.keyboard.press("ArrowRight")
                state(0, "ArrowRight wrap")
                page.keyboard.press("Control+ArrowRight")
                state(0, "modified arrow leaves state unchanged")
                for index in range(6):
                    page.locator(f"[data-jump='{index}']").click()
                    state(index, "contact sheet button")
                page.reload(wait_until="load")
                state(0, "reload resets to first slide")
                assert page.evaluate("document.documentElement.scrollWidth <= innerWidth")
                page.locator("[data-jump='2']").click()
                state(2, "projected range selected for appearance inspection")
                page.evaluate("scrollTo(0,0)")
                screenshot = f"deck-{width}.png"
                page.screenshot(path=str(HERE / screenshot), full_page=True)
                record["viewports"].append({
                    "width": width, "height": height, "device_scale_factor": 1,
                    "embedded_images": images, "checks": checks,
                    "horizontal_overflow": False, "screenshot": screenshot,
                    "screenshot_sha256": sha((HERE / screenshot).read_bytes()),
                })
                context.close()
        finally:
            browser.close()
    assert not errors and not failures and not network, (errors, failures, network)
    record.update(page_errors=errors, failed_requests=failures, http_requests=network)
    (HERE / "deck-check.json").write_text(json.dumps(record, indent=2) + "\n")
    signal.alarm(0)
    print("PASS offline file deck: 12 image hashes; 24 states per viewport; wide/narrow; no HTTP")


if __name__ == "__main__":
    main()
