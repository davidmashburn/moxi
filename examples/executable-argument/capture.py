"""Capture and assert the offline reader journey in an isolated Chrome profile."""
import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import platform
import subprocess
from tempfile import TemporaryDirectory

from playwright.sync_api import expect, sync_playwright

from build import build

ROOT = Path(__file__).resolve().parents[2]
import sys
sys.path.insert(0, str(ROOT / "scripts"))
from demo_slideshows import load_manifest, render

DEMO = "v05-executable-argument"


def capture(output):
    output.mkdir(parents=True, exist_ok=True)
    slides = []
    errors = []
    with TemporaryDirectory() as tmp, sync_playwright() as pw:
        article = Path(tmp) / "argument.html"
        build(article)
        browser = pw.chromium.launch(channel="chrome")
        version = browser.version
        page = browser.new_page(viewport=dict(width=1120, height=1220))
        page.on("pageerror", lambda error: errors.append(str(error)))
        page.goto(article.as_uri())
        item = page.locator

        def shot(name, phase, action, expected):
            page.screenshot(path=output / (name + ".png"), animations="disabled")
            size = page.viewport_size
            slides.append(dict(phase=phase, image=name + ".png", capture_kind="browser",
                               caption=name.replace("-", " ").capitalize(), action=action,
                               expected=expected, dimensions=[size["width"], size["height"]]))

        expect(item("#result")).to_have_text("Shuttle saves $40 per run.")
        assert item("[data-moxi=plot] polyline").count() == 1
        shot("authored-argument", "initial", "Open the generated article.", "40 riders, $120 dispatch, $40 shuttle saving.")
        page.keyboard.press("Tab")
        expect(item("#next")).to_be_focused()
        for _ in range(3):
            page.keyboard.press("Enter")
        expect(item("#result")).to_have_text("Both proposals cost the same.")
        assert page.evaluate("""() => {
            const chart = document.querySelector('#chart');
            const point = chart.querySelector('circle');
            const zero = chart.querySelector('[stroke-dasharray]');
            return point.cy.baseVal.value === zero.y1.baseVal.value;
        }""")
        expect(item("#details")).to_have_attribute("open", "")
        shot("action-three", "interaction", "Tab to Next action and press Enter three times.", "At 30 riders costs tie; the synthetic fit is expanded.")
        item("#scrub").focus()
        page.keyboard.press("ArrowLeft")
        expect(item("#result")).to_have_text("Vouchers save $4 per run.")
        item("#dispatch").select_option("160")
        expect(item("#result")).to_have_text("Vouchers save $44 per run.")
        item("#note").fill("Test a quieter departure.")
        item("#save").click()
        item("#insert").click()
        shot("saved-alternative", "result", "Left arrow to 29 riders, select $160 dispatch, annotate, save and insert.",
             "The copy and inserted essay record both premises and $44 voucher saving.")
        item("#supported").uncheck()
        expect(item("#result")).to_contain_text("Conclusion unavailable")
        expect(item("#save")).to_be_disabled()
        expect(item("#insert")).to_be_disabled()
        expect(item("#costs")).to_be_empty()
        shot("withdrawn-premise", "interaction", "Withdraw the demand premise.", "The live result clears. The saved comparison is retained.")
        item("#reopen").click()
        expect(item("#note")).to_have_value("Test a quieter departure.")
        expect(item("#result")).to_have_text("Vouchers save $44 per run.")
        item("#riders").fill("61")
        expect(item("#result")).to_contain_text("0 to 60")
        expect(item("#insert")).to_be_disabled()
        item("#checkpoint").click()
        expect(item("#riders")).to_have_value("30")
        expect(item("#dispatch")).to_have_value("120")
        expect(item("#result")).to_have_text("Both proposals cost the same.")
        expect(item("#note")).to_have_value("")
        for expected in ["Vouchers save $40 per run.", "Shuttle saves $40 per run."]:
            item("#next").click()
            expect(item("#result")).to_have_text(expected)
        expect(item("#next")).to_be_disabled()
        item("#restore").click()
        expect(item("#riders")).to_have_value("40")
        expect(item("#inserted")).to_contain_text("Vouchers save $44")
        shot("restored-comparison", "recovery", "Resume actions four and five; restore original.",
             "The restored live argument and explicitly inserted alternative coexist.")
        page.get_by_role("link", name="Trace cost rates").focus()
        page.keyboard.press("Enter")
        expect(item("#source")).to_be_focused()
        with page.expect_download() as download:
            item("#export").click()
        export = Path(tmp) / "static.html"
        download.value.save_as(export)
        page.goto(export.as_uri())
        page.reload()
        expect(item("body")).to_contain_text("Vouchers save $44 per run.")
        expect(item("body")).to_contain_text("Fixture T1")
        assert item("script,input,button,select").count() == 0
        assert item("[data-moxi=plot] polyline").count() == 1
        shot("static-essay", "result", "Download, reopen and reload the standalone essay.",
             "Frozen inserted values, curve, original argument, fit, and limit survive reload.")
        page.set_viewport_size(dict(width=390, height=844))
        page.goto(article.as_uri())
        assert page.evaluate("document.documentElement.scrollWidth === innerWidth")
        item("#riders").fill("-1")
        expect(item("#result")).to_contain_text("0 to 60")
        item("#restore").click()
        expect(item("#result")).to_contain_text("Shuttle saves $40")
        assert not errors, errors
        browser.close()

    revision = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    manifest = dict(version=1, demo_id=DEMO, title="When does the shuttle cost less?",
                    scenario="V05 with I07, I08 and I16", host=platform.system() + " " + platform.machine(),
                    backend="Chrome " + version + " / Moxi Python SVG", scale=1, fixture="Synthetic T1 in build.py",
                    captured_at=datetime.now(timezone.utc).isoformat(), revision=revision,
                    reproduce="From examples/executable-argument: PYTHONPATH=../../python python capture.py OUTPUT/v05-executable-argument",
                    slides=slides)
    path = output / "manifest.json"
    path.write_text(json.dumps(manifest, indent=2) + "\n")
    (output / "index.html").write_text(render(load_manifest(path)))
    print(f"Passed browser scenario and generated {len(slides)} slides.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    if args.output.name != DEMO:
        parser.error("Use a destination directory named " + DEMO)
    capture(args.output)
