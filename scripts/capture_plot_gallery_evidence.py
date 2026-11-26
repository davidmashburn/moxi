#!/usr/bin/env python3
"""Capture the scoped E02/E03 local HTML pages with headless Chrome.

Use after wave_b/evidence.py and wave_c/evidence.py; the server must serve
artifacts/demo-slideshows at --base-url. This never renders a substitute chart.
"""
import argparse
from datetime import datetime, timezone
import hashlib
from importlib.metadata import version
import json
from pathlib import Path
import platform
import shutil
from urllib.parse import urlparse

from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[1]
REVIEW = ROOT / 'artifacts/demo-slideshows/plot-wave-b-c-review'
METRICS = """() => ({innerWidth, innerHeight, devicePixelRatio,
  scrollWidth: document.documentElement.scrollWidth,
  scrollHeight: document.documentElement.scrollHeight,
  userAgent: navigator.userAgent,
  images: [...document.images].map(i => ({src: new URL(i.src).pathname,
    complete: i.complete, naturalWidth: i.naturalWidth,
    naturalHeight: i.naturalHeight}))})"""


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--base-url', default='http://127.0.0.1:8796/')
    parser.add_argument('--browser', help='Chrome/Chromium executable; otherwise locate local Chrome')
    parser.add_argument('--plan', type=Path, default=REVIEW/'capture-plan.json', help='Capture only this plan (default: historical batch plan)')
    parser.add_argument('--record', type=Path, default=REVIEW/'captures.json', help='Capture-provenance destination')
    args = parser.parse_args()
    assert urlparse(args.base_url).hostname in ('127.0.0.1', 'localhost'), 'Local evidence only'
    executable = args.browser or shutil.which('google-chrome') or shutil.which('chromium')
    mac_chrome = Path('/Applications/Google Chrome.app/Contents/MacOS/Google Chrome')
    if not executable and mac_chrome.exists():
        executable = str(mac_chrome)
    plan = json.loads(args.plan.read_text())
    records = []
    with sync_playwright() as pw:
        browser = pw.chromium.launch(headless=True, executable_path=executable)
        context = browser.new_context(device_scale_factor=1, color_scheme='light', locale='en-US')
        page = context.new_page()
        page.set_default_timeout(30000)
        errors, requests = [], []
        page.on('pageerror', lambda error: errors.append(str(error)))
        page.on('console', lambda message: errors.append(dict(text=message.text, location=message.location)) if message.type == 'error' else None)
        page.on('requestfailed', lambda request: requests.append(dict(url=request.url, failure=request.failure)))
        page.on('response', lambda response: requests.append(dict(url=response.url, status=response.status)) if response.status >= 400 else None)
        for entry in plan:
            errors.clear()
            requests.clear()
            target = ROOT / entry['target']
            assert target.parent.parent == ROOT/'artifacts/demo-slideshows'
            assert target.parent.name.startswith(('e02-', 'e03-'))
            page.set_viewport_size(dict(width=entry['width'], height=entry['height']))
            response = page.goto(args.base_url.rstrip('/')+'/'+entry['page'], wait_until='networkidle')
            assert response and response.status == 200
            page.evaluate('async () => { await document.fonts.ready; await Promise.all([...document.images].map(i => i.decode())); }')
            metrics = page.evaluate(METRICS)
            if metrics['scrollHeight'] > metrics['innerHeight']:
                page.set_viewport_size(dict(width=entry['width'], height=metrics['scrollHeight']))
                metrics = page.evaluate(METRICS)
            assert metrics['scrollWidth'] <= metrics['innerWidth'], entry
            assert metrics['scrollHeight'] <= metrics['innerHeight'], entry
            # Python's static server has no optional site icon. Chrome logs
            # that request outside Playwright's response/request events.
            ignored = [e for e in errors if isinstance(e, dict) and e['location'].get('url', '').endswith('/favicon.ico')]
            unexpected = [e for e in errors if e not in ignored]
            assert not unexpected and not requests, dict(entry=entry, errors=errors, failed_requests=requests)
            page.screenshot(path=str(target), full_page=False, scale='css', animations='disabled')
            records.append(dict(target=entry['target'], page_path=entry['page'],
                captured_at=datetime.now(timezone.utc).isoformat(),
                capture_tool=f'Playwright Python {version("playwright")} / local headless Chrome',
                browser_version=browser.version, platform=platform.platform(),
                requested_viewport=dict(width=entry['width'], height=entry['height']),
                page=dict(value=metrics), console_errors=unexpected, ignored_browser_errors=ignored, failed_requests=list(requests),
                sha256=hashlib.sha256(target.read_bytes()).hexdigest()))
        browser.close()
    args.record.write_text(json.dumps(records, indent=2)+'\n')
    print(f'Captured {len(records)} browser frames; no page errors or failed requests.')


if __name__ == '__main__':
    main()
