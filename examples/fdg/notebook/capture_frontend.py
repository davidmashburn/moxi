#!/usr/bin/env python3
"""Capture an actual JupyterLab session in Chrome, including kernel restart.

Optional fallback for unavailable collaborative-preview interactions. Uses the
installed Google Chrome browser in a separate temporary profile; never mocks UI.
"""
import hashlib
import json
import os
from pathlib import Path
import secrets
import shutil
import subprocess
import sys
import time
from urllib.request import urlopen

from playwright.sync_api import sync_playwright

EXAMPLE = Path(__file__).resolve().parents[1]
ROOT = EXAMPLE.parents[1]
DESTINATION = ROOT / "artifacts/demo-slideshows/fdg-notebook"
DIST = EXAMPLE / "dist/notebook"


def main():
    DIST.mkdir(parents=True, exist_ok=True)
    DESTINATION.mkdir(parents=True, exist_ok=True)
    target = DIST / "frontend-capture.ipynb"
    shutil.copyfile(EXAMPLE / "entrypoints.ipynb", target)
    token = secrets.token_hex(24)
    # Bind only loopback, keep authentication, and fail rather than stealing a port.
    port = int(os.environ.get("MOXI_NOTEBOOK_PORT", "8894"))
    base = f"http://127.0.0.1:{port}"
    logfile = Path("/tmp/moxi-p03-frontend-server.log")
    with logfile.open("w") as log:
        server = subprocess.Popen([
            sys.executable, "-m", "jupyterlab", "--no-browser", "--ip=127.0.0.1",
            f"--port={port}", "--ServerApp.port_retries=0", f"--ServerApp.root_dir={ROOT}",
            f"--IdentityProvider.token={token}", "--LabApp.expose_app_in_browser=True",
        ], cwd=ROOT, stdout=log, stderr=subprocess.STDOUT)
        try:
            deadline = time.monotonic() + 30
            while True:
                if server.poll() is not None:
                    raise RuntimeError(f"Jupyter server exited; see {logfile}")
                try:
                    with urlopen(f"{base}/api?token={token}", timeout=1) as response:
                        if response.status == 200:
                            break
                except OSError:
                    pass
                if time.monotonic() > deadline:
                    raise TimeoutError(f"Jupyter startup timed out; see {logfile}")
                time.sleep(0.2)
            with sync_playwright() as playwright:
                browser = playwright.chromium.launch(channel="chrome", headless=True)
                page = browser.new_page(viewport={"width": 1600, "height": 1200}, device_scale_factor=1)
                page.goto(f"{base}/lab/workspaces/p03-{token[:8]}/tree/examples/fdg/dist/notebook/frontend-capture.ipynb?token={token}")
                page.wait_for_function("window.jupyterapp?.shell.currentWidget?.context?.path === 'examples/fdg/dist/notebook/frontend-capture.ipynb' && window.jupyterapp.shell.currentWidget.content.widgets.length === 14")
                page.evaluate("async () => { await window.jupyterapp.shell.currentWidget.sessionContext.ready; }")
                page.evaluate("async () => { await window.jupyterapp.commands.execute('notebook:run-all-cells'); }")
                initial = page.evaluate("window.jupyterapp.shell.currentWidget.content.widgets.filter(c=>c.model.type==='code').map(c=>({count:c.model.executionCount,outputs:c.model.outputs.toJSON()}))")
                errors = [o for c in initial for o in c["outputs"] if o["output_type"] == "error"]
                assert not errors, errors
                assert initial[-1]["count"] == 8, initial

                # Actual cell outputs, not fabricated screenshot annotations.
                outputs = page.evaluate("window.jupyterapp.shell.currentWidget.content.widgets.filter(c=>c.model.type==='code').map(c=>({count:c.model.executionCount,outputs:c.model.outputs.toJSON()}))")
                assert [c["count"] for c in outputs] == list(range(1, 9))
                assert not any(o["output_type"] == "error" for c in outputs for o in c["outputs"])
                assert any("Viewer running: True" in o.get("text", "") for c in outputs for o in c["outputs"])
                for label in ("No", "Ignore all updates"):
                    button = page.get_by_role("button", name=label, exact=True)
                    if button.is_visible():
                        button.click()
                # Hide file browser using Jupyter's command, preserving normal UI.
                page.evaluate("window.jupyterapp.commands.execute('application:toggle-left-area')")

                def capture(index, name):
                    page.evaluate("async i => {const n=window.jupyterapp.shell.currentWidget.content; n.activeCellIndex=i; await n.scrollToItem(i, 'start');}", index)
                    page.wait_for_timeout(200)  # Let virtualized cells finish browser layout.
                    if index == 13:
                        page.mouse.move(1400, 800)
                        page.mouse.wheel(0, 2400)
                        page.get_by_text("All retained viewers closed. Ready for kernel restart and Run All.", exact=True).scroll_into_view_if_needed()
                        page.wait_for_timeout(200)
                    page.screenshot(path=str(DESTINATION / name))

                capture(3, "00-graph.png")
                capture(4, "01-svg.png")
                image = page.locator(".jp-RenderedSVG img")
                assert image.evaluate("i=>i.complete && i.naturalWidth===1100 && i.naturalHeight===720")
                labels = image.evaluate("i=>[...new DOMParser().parseFromString(decodeURIComponent(i.src.split(',')[1]),'image/svg+xml').querySelectorAll('text')].map(t=>t.textContent)")
                assert labels == ["Data", "Python", "Mojo", "Moxi", "SVG & μ"]
                capture(7, "03-error.png")
                def kernel_pid():
                    return page.evaluate("""async () => {
                        const kernel = window.jupyterapp.shell.currentWidget.sessionContext.session.kernel;
                        const future = kernel.requestExecute({code:'import os; print(os.getpid())',store_history:false});
                        let pid;
                        future.onIOPub = message => { if(message.header.msg_type === 'stream') pid=Number(message.content.text.trim()); };
                        const reply = await future.done;
                        if(reply.content.status !== 'ok' || !pid) throw new Error('Kernel PID query failed');
                        return pid;
                    }""")

                before_pid = kernel_pid()
                # Exercise the frontend's own menu and confirmation dialog.
                page.get_by_role("menuitem", name="Kernel", exact=True).click()
                page.get_by_role("menuitem", name="Restart Kernel and Run All Cells…", exact=True).click()
                with page.expect_response(lambda r: r.url.split("?", 1)[0].endswith("/restart") and r.status == 200):
                    page.get_by_text("Restart", exact=True).click(timeout=5000)
                print("Frontend restart response received", flush=True)
                page.wait_for_function("window.jupyterapp.shell.currentWidget.sessionContext.kernelDisplayStatus === 'idle' && window.jupyterapp.shell.currentWidget.content.widgets[13].model.executionCount === 8")
                # Wait for the restart request, not merely the old idle state.
                page.wait_for_function("window.jupyterapp.shell.currentWidget.content.widgets[1].model.executionCount === 1")
                after_pid = kernel_pid()
                assert before_pid != after_pid
                capture(13, "06-restart.png")
                final = page.evaluate("window.jupyterapp.shell.currentWidget.content.widgets.filter(c=>c.model.type==='code').map(c=>({count:c.model.executionCount,outputs:c.model.outputs.toJSON()}))")
                assert [c["count"] for c in final] == list(range(1, 9))
                assert not any(o["output_type"] == "error" for c in final for o in c["outputs"])
                page.evaluate("async () => {await window.jupyterapp.shell.currentWidget.context.save();}")
                evidence = dict(browser=browser.version, viewport={"width":1600,"height":1200}, scale=1,
                                labels=labels, frontend_run_all="8 code cells passed",
                                frontend_restart_run_all="8 code cells passed via Kernel menu",
                                kernel_pids=[before_pid, after_pid], notebook="frontend-capture.ipynb",
                                notebook_sha256=hashlib.sha256((EXAMPLE / "entrypoints.ipynb").read_bytes()).hexdigest(),
                                capture_script_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest())
                (DIST / "frontend-evidence.json").write_text(json.dumps(evidence, indent=2) + "\n")
                print(json.dumps(evidence, indent=2))
                browser.close()
        finally:
            server.terminate()
            try:
                server.wait(timeout=15)
            except subprocess.TimeoutExpired:
                server.kill()
                server.wait()


if __name__ == "__main__":
    main()
