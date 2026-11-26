"""Replay a keyboard-only lesson in a fresh Chrome context and capture the checked states."""
import argparse
import hashlib
import json
import platform
import threading
from datetime import datetime, timezone
from html import escape
from pathlib import Path
from tempfile import TemporaryDirectory

from playwright.sync_api import expect, sync_playwright

from serve import Handler, ThreadingHTTPServer

parser = argparse.ArgumentParser()
parser.add_argument("output", type=Path)
out = parser.parse_args().output
out.mkdir(parents=True, exist_ok=True)
slides = []
server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
threading.Thread(target=server.serve_forever, daemon=True).start()
try:
    with sync_playwright() as pw, TemporaryDirectory() as temporary:
        browser = pw.chromium.launch(channel="chrome")
        page = browser.new_page(viewport={"width": 1000, "height": 850})
        errors = []
        page.on("pageerror", lambda err: errors.append(str(err)))
        page.goto(f"http://127.0.0.1:{server.server_port}/")
        def go(key):
            target = page.locator("#" + key)
            for _ in range(60):
                if target.evaluate("e => e === document.activeElement"):
                    return
                page.keyboard.press("Tab")
            raise AssertionError("Keyboard could not reach " + key)

        def press(key):
            go(key)
            page.keyboard.press("Enter")

        def enter(key, value):
            go(key)
            page.keyboard.press("Home")
            page.keyboard.press("Shift+End")
            page.keyboard.type(value)

        def slide(title, text, element):
            if element == "#detail":
                page.evaluate("window.scrollTo(0, 0)")
            else:
                page.locator(element).evaluate("e => e.scrollIntoView({block: 'center'})")
            name = f"{len(slides)+1:02d}.png"
            page.screenshot(path=out / name)
            slides.append((name, title, text))

        press("lock")
        expect(page.locator("#error")).to_contain_text("Enter a prediction")
        enter("prediction", "Four times the mass should double the period.")
        slide("Prediction", "Synthetic response before the trial is available.", "#prediction")
        press("lock")
        enter("m", "0")
        press("compare")
        expect(page.locator("#error")).to_contain_text("Mass (kg) must be between")
        expect(page.locator("#result")).to_be_hidden()
        slide("Rejected mass", "Zero mass is rejected before a run is created.", "#error")
        enter("m", "4")
        slide("Manipulate mass", "The corrected trial is ready to compare.", "#parameters")
        press("compare")
        expect(page.locator("#summary")).to_contain_text("2.000×")
        slide("Compare runs", "Reference and trial periods at the committed mass.", "#summary")
        enter("t", "0.5")
        press("sample")
        expect(page.locator("#point")).to_contain_text("0.270 m")
        go("column")
        page.keyboard.press("ArrowDown")
        expect(page.locator("#term")).to_contain_text("−Aω")
        enter("note", "Track the peak")
        page.keyboard.press("Shift+ArrowLeft")
        press("inspect")
        press("define")
        expect(page.locator("#definition")).to_be_visible()
        slide("Inspect notation", "The sampled motion leads to the angular-frequency definition.", "#detail")
        press("back")
        expect(page.locator("#note")).to_be_focused()
        assert page.locator("#note").evaluate("e => e.value.slice(e.selectionStart,e.selectionEnd)") == "k"
        press("branch")
        enter("a", "0")
        press("compare")
        expect(page.locator("#basis")).to_contain_text("Singular matrix")
        expect(page.locator("#point")).to_contain_text("0.000 m")
        slide("Collapsed basis", "Zero amplitude collapses the working copy to rest.", "#basis")
        press("insert")
        with page.expect_download() as download:
            press("download")
        file = Path(temporary) / "report.html"
        download.value.save_as(file)
        report = file.read_text()
        assert "<svg" in report and "Checkpoint: m = 4" in report and "A = 0 m" in report
        slide("Insert result", "The report records the copied trial, source checkpoint and trace.", "#report")
        press("restore")
        expect(page.locator("#checkpoint")).to_have_text("Checkpoint restored.")
        expect(page.locator("#a")).to_have_value("0.5")
        expect(page.locator("#point")).to_contain_text("0.270 m")
        expect(page.locator("#entry")).to_contain_text("A = 0 m")
        slide("Restore the checkpoint", "Restore the sampled trial while retaining the inserted result.", "#checkpoint")
        press("next")
        press("reveal")
        expect(page.locator("#answerError")).to_contain_text("Write an explanation")
        expect(page.locator("#feedback")).to_be_empty()
        enter("answer", "The mass to stiffness ratio matches the reference, so the period matches.")
        press("reveal")
        expect(page.locator("#feedback")).to_contain_text("1.571 s")
        slide("Unfamiliar case", "A keyboard-entered explanation precedes the model comparison.", "#feedback")
        # A pointer scrub must commit the same linked sample in the actual UI.
        slider = page.locator("#scrub")
        slider.scroll_into_view_if_needed()
        box = slider.bounding_box()
        slider.click(position={"x": box["width"] * .5, "y": box["height"] * .5})
        expect(page.locator("#t")).to_have_value("4")
        expect(page.locator("#point")).to_contain_text("At 4 s")
        page.set_viewport_size({"width": 390, "height": 844})
        assert page.evaluate("document.documentElement.scrollWidth <= innerWidth")
        page.reload()
        expect(page.locator("#result")).to_be_hidden()
        expect(page.locator("#prediction")).to_have_value("")
        assert not errors, errors
        info = dict(chrome=browser.version, python=platform.python_version(), platform=platform.system(),
                    viewport=[1000, 850], captured=datetime.now(timezone.utc).isoformat(),
                    sources={p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in
                             sorted(Path(__file__).parent.iterdir()) if p.suffix in {".py", ".html", ".css", ".js"}},
                    slides=slides, pageErrors=errors)
        browser.close()
finally:
    server.shutdown()
    server.server_close()
(out / "manifest.json").write_text(json.dumps(info, indent=2) + "\n")
frames = "".join(f'<figure id="s{i}"><figcaption><b>{i}. {escape(title)}</b> · {escape(text)}</figcaption>'
                 f'<img src="{name}" alt="{escape(text)}"></figure>' for i,(name,title,text) in enumerate(slides,1))
nav = " ".join(f'<a href="#s{i}">{i}</a>' for i in range(1,len(slides)+1))
(out / "index.html").write_text('<!doctype html><html lang="en"><meta charset=utf-8><title>Oscillator walkthrough</title>'
    '<meta name="viewport" content="width=device-width"><style>body{max-width:1000px;margin:auto;padding:16px;'
    'font:18px system-ui;background:#eff3ee;color:#183638}figure{margin:32px 0}img{width:100%}a{padding:5px}</style>'
    f'<h1>Oscillator walkthrough</h1><nav aria-label="Slides">{nav}</nav>{frames}</html>\n')
print(f"Verified {len(slides)} keyboard states and the static export.")
