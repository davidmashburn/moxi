"""Exercise the running example with Chrome. Run with PYTHONPATH=python."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import subprocess
from threading import Thread
from http.server import ThreadingHTTPServer
from playwright.sync_api import expect, sync_playwright
from instrument import Handler, INITIAL, chart


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
    assert abs(tail - 0.4) < .012, (tail, bar, page.viewport_size)
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


def attachment_check(page, capture):
    page.reload()
    select = page.locator("#attachment")
    outcome = page.locator("#outcome")
    target = page.get_by_label("Requested P(x)")
    pin = page.get_by_label("Fix the committed mean")
    apply = page.get_by_role("button", name="Apply preview")
    probe = page.locator("#probe")
    pin.check()
    outcome.select_option("1")
    target.fill(".2")
    expect(apply).to_be_enabled()
    reading = "P(1) = 0.2 probability · committed reference 0.5 · change -0.3"
    expect(probe).to_have_text(reading)
    capture("plot")
    select.select_option("geometry")
    expect(probe).to_have_text(reading)
    expect(pin).to_be_checked()
    expect(outcome).to_have_value("1")
    expect(target).to_have_value(".2")
    expect(page.locator("#draft td")).to_have_text(["0.4", "0.2", "0.4", "1"])
    dot = page.locator("#triangle circle")
    expect(dot).to_have_attribute("cx", "266")
    expect(dot).to_have_attribute("cy", "121")
    capture("triangle")
    target.press("Enter")
    expect(probe).to_contain_text("committed reference 0.2 · change 0")
    outcome.select_option("2")

    # Halfway to the top vertex from the opposite edge gives P(2) = 0.5.
    triangle = page.locator("#triangle")
    pt = triangle.evaluate("""svg => {
        const p = new DOMPoint(300,105).matrixTransform(svg.getScreenCTM());
        return [p.x,p.y];
    }""")
    page.mouse.move(*pt)
    page.mouse.down()
    expect(page.locator("#draft td")).to_have_text(["0.5", "0", "0.5", "1"])
    page.keyboard.press("Escape")
    page.mouse.move(pt[0], pt[1] - 5)
    page.mouse.up()
    expect(apply).to_be_disabled()
    expect(page.locator("#draft td")).to_have_text(["—"] * 4)
    page.mouse.click(*pt)
    expect(apply).to_be_enabled()
    target.press("Enter")
    expect(page.locator("#saved td")).to_have_text(["0.5", "0", "0.5", "1"])
    target.fill(".8")
    expect(page.get_by_role("status")).to_contain_text("possible mean is 1.6 to 1.8")
    expect(apply).to_be_disabled()
    expect(probe).to_contain_text("P(2) = 0.5")
    capture("rejected")
    select.select_option("plot")
    expect(target).to_have_value(".8")
    expect(apply).to_be_disabled()
    expect(probe).to_contain_text("committed reference 0.5")
    assert page.evaluate("document.documentElement.scrollWidth <= innerWidth")
    page.reload()
    expect(page.locator("#saved td")).to_have_text(["0.25", "0.5", "0.25", "1"])
    expect(select).to_have_value("plot")

    # Unit triangle coordinates (P1=.3, P2=.2) map to (266,153).
    # A single pointer position measures three distinct basis coefficients.
    select.select_option("geometry")
    for k, expected in enumerate((.5, .3, .2)):
        outcome.select_option(str(k))
        xy = triangle.evaluate("""svg => {
            const p = new DOMPoint(266,153).matrixTransform(svg.getScreenCTM());
            return [p.x,p.y];
        }""")
        page.mouse.click(*xy)
        expect(apply).to_be_enabled()
        assert abs(float(target.input_value()) - expected) < .01
        assert page.evaluate("document.documentElement.scrollWidth <= innerWidth")
        expect(page.locator("#saved td")).to_have_text(["0.25", "0.5", "0.25", "1"])


def fractional_layout(page, capture):
    page.reload()
    values = ["0.2222222", "0.4444444", "0.3333333", "1.111111"]
    page.locator("#outcome").select_option("2")
    page.get_by_label("Requested P(x)").fill(".3333333333333333")
    expect(page.locator("#draft td")).to_have_text(values)
    capture("fractional-plot")
    page.locator("#attachment").select_option("geometry")
    expect(page.locator("#draft td")).to_have_text(values)
    expect(page.get_by_label("Requested P(x)")).to_have_value(".3333333333333333")
    expect(page.get_by_label("Fix the committed mean")).not_to_be_checked()
    capture("fractional-triangle")
    page.get_by_role("button", name="Apply preview").click()
    expect(page.locator("#saved td")).to_have_text(values)
    capture("fractional-committed")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--capture", type=Path)
    parser.add_argument("--capture-state", action="append", help="Retain only this width-state PNG; repeat as needed.")
    args = parser.parse_args()
    here = Path(__file__).resolve().parent
    record = {"startedAt": datetime.now(timezone.utc).isoformat(),
              "revision": subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip(),
              "sourceSha256": {name: hashlib.sha256((here / name).read_bytes()).hexdigest()
                               for name in ("instrument.py", "instrument.html", "triangle.json", "triangle.mojo", "check_browser.py")},
              "runs": []}
    with ThreadingHTTPServer(("127.0.0.1", 0), Handler) as server, sync_playwright() as pw:
        Thread(target=server.serve_forever, daemon=True).start()
        browser = pw.chromium.launch(channel="chrome")
        record["browser"] = "Chrome " + browser.version
        try:
            for width, height in ((1280, 800), (390, 844)):
                page = browser.new_page(viewport={"width": width, "height": height})
                errors = []
                page.on("pageerror", lambda error: errors.append(str(error)))
                response = page.goto(f"http://127.0.0.1:{server.server_port}/")
                expected_html = (here / "instrument.html").read_text().replace("<!--chart-->", chart(INITIAL)).replace("/*basis*/", (here / "triangle.json").read_text()).encode()
                assert response.body() == expected_html, "Running server must serve this checkout's HTML and geometry"
                run = {"viewport": page.viewport_size, "url": page.url, "servedHtmlSha256": hashlib.sha256(response.body()).hexdigest(),
                       "observations": [], "pageErrors": errors}
                record["runs"].append(run)
                def capture(state):
                    observation = {"state": state, "capturedAt": datetime.now(timezone.utc).isoformat(),
                                   "observed": page.evaluate("""() => ({
                        attachment: document.querySelector('#attachment').value,
                        outcome: document.querySelector('#outcome').value,
                        requested: document.querySelector('#target').value,
                        pinned: document.querySelector('input[type=checkbox]').checked,
                        committed: [...document.querySelectorAll('#saved td')].map(e => e.textContent),
                        preview: [...document.querySelectorAll('#draft td')].map(e => e.textContent),
                        probe: document.querySelector('#probe').textContent,
                        status: document.querySelector('#status').textContent,
                        applyDisabled: document.querySelector('#apply').disabled,
                        scrollWidth: document.documentElement.scrollWidth, innerWidth
                    })""")}
                    name = f"{width}-{state}"
                    if args.capture and (not args.capture_state or name in args.capture_state):
                        args.capture.mkdir(parents=True, exist_ok=True)
                        page.screenshot(path=args.capture / f"{name}.png", full_page=True)
                        observation["image"] = name + ".png"
                    run["observations"].append(observation)
                    assert page.evaluate("document.documentElement.scrollWidth <= innerWidth")
                capture("initial")
                exercise(page)
                attachment_check(page, capture)
                fractional_layout(page, capture)
                assert not errors, errors
                run["outcome"] = "PASS"
                print(f"PASS Chrome {browser.version}, {width} × {height}")
                page.close()
        finally:
            record["completedAt"] = datetime.now(timezone.utc).isoformat()
            if args.capture:
                args.capture.mkdir(parents=True, exist_ok=True)
                (args.capture / "results.json").write_text(json.dumps(record, indent=2) + "\n")
            browser.close()
            server.shutdown()
