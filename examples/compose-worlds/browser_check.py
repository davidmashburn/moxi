"""Run after build.py. Requires Playwright for Python and installed Chrome."""
from pathlib import Path
from playwright.sync_api import sync_playwright

page_path = Path(__file__).resolve().parents[2] / "dist/compose-worlds/index.html"
with sync_playwright() as driver:
    browser = driver.chromium.launch(channel="chrome")
    page = browser.new_page(viewport={"width": 1180, "height": 1050})
    errors = []
    page.on("pageerror", lambda error: errors.append(str(error)))
    page.goto(page_path.as_uri())

    def pixels(element):
        return page.locator(element).evaluate("canvas => canvas.toDataURL()")

    rule = page.locator("#rule")
    run = page.get_by_role("button", name="Run comparison")
    origin = pixels("#reference")
    assert pixels("#branch") == origin
    rule.focus()
    rule.press("End")
    run.click()
    result = pixels("#branch")
    reference = pixels("#reference")
    assert reference != result and reference != origin
    assert "21.11% grazers" in page.locator("#branchStats").inner_text()
    season = page.locator("#season")
    season.press("Home")
    assert pixels("#branch") == pixels("#reference") == origin
    season.press("ArrowRight")
    assert pixels("#branch") != origin
    page.get_by_role("button", name="Reset beds").click()
    assert rule.input_value() == "50" and pixels("#branch") == origin
    page.locator("#prediction").select_option("equal")
    run.click()
    assert "Prediction matched" in page.locator("#status").inner_text()
    assert pixels("#branch") == reference
    page.get_by_role("button", name="Replay trial 1").click()
    assert rule.input_value() == "100" and page.locator("#prediction").input_value() == "more"
    assert pixels("#reference") == reference and pixels("#branch") == result
    assert page.locator("#history li").count() == 2
    page.set_viewport_size({"width": 390, "height": 844})
    assert page.evaluate("document.documentElement.scrollWidth <= innerWidth")
    page.get_by_role("button", name="Replay trial 2").click()
    assert pixels("#branch") == reference
    page.reload()
    assert pixels("#branch") == origin and page.locator("#history li").count() == 0
    assert not errors, errors
    print("PASS: offline load, rule edit, season inspection, reset, multi-trial replay, narrow layout and reload")
    browser.close()
