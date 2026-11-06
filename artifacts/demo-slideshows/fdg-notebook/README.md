# FDG notebook slideshow (P03)

This sequence contains actual JupyterLab/Chrome screenshots and live native AppKit
content-view captures: graph → SVG → native viewer → actionable parser diagnostic
→ reopened native viewer → new-kernel viewer → frontend restart and Run All.
The images are independent captures of those states, even where the deterministic
graph renders identically. PNGs and generated HTML remain local ignored artifacts;
the manifest and reproduction instructions are tracked.

From the repository root on macOS ARM64 with Google Chrome installed:

```sh
bash examples/fdg/scripts/build.sh > /tmp/moxi-p03-build.log 2>&1
uv venv --python 3.13 examples/fdg/.venv-notebook
uv pip install --python examples/fdg/.venv-notebook/bin/python \
  -r examples/fdg/notebook/requirements-capture.txt
examples/fdg/.venv-notebook/bin/python examples/fdg/notebook/verify.py \
  > /tmp/moxi-p03-notebook-check.log 2>&1
examples/fdg/.venv-notebook/bin/python examples/fdg/notebook/capture_frontend.py \
  > /tmp/moxi-p03-frontend-check.log 2>&1
examples/fdg/.venv-notebook/bin/python examples/fdg/notebook/gallery.py
python3 examples/fdg/tests/test_python.py > /tmp/moxi-p03-python-bridge.log 2>&1
python3 tests/demo_slideshows_test.py
open artifacts/demo-slideshows/fdg-notebook/index.html
```

The optional capture script starts an authenticated JupyterLab server bound only to
127.0.0.1:8894, creates a separate Chrome profile, executes all eight cells through
JupyterLab, inspects the actual SVG renderer, and uses the Kernel menu and Restart
confirmation before capturing the completed rerun. It verifies different kernel
PIDs. It stops its server and browser afterward. Set `MOXI_NOTEBOOK_PORT` if that
port is occupied. Server diagnostics are in `/tmp/moxi-p03-frontend-server.log`;
keep its token private. Executed notebooks and machine evidence are under ignored
`examples/fdg/dist/notebook/`.

Prefer the T3 collaborative preview for manual browser checks. The captured run
used the scripted actual-Chrome fallback after repeated preview click timeouts;
the initial T3 inspection also rendered the SVG. No UI is simulated or drawn by the
capture script. No image generation is used. At 1600×1200 CSS pixels, the browser
shows the full 1100×720 SVG with all five labels, including `SVG & μ`.

Native evidence uses the unmodified compiled viewer with an injected test-only
AppKit observer. It captures the actual running `NSWindow.contentView` using
`cacheDisplay`, at backing scale 2. Desktop window lookup returned exit code 1 and
no window while both child processes were alive; these are **content-view captures,
not desktop screenshots**. They exclude title bars/compositor effects. Closing is
an AppKit `performClose:` call with exit code 0, not a physical click. Reopen and
restart are separate process launches. The notebook's unattended cleanup uses
termination, which is tested separately from normal window closure.

The manifest uses `scripts/demo_slideshows.py` validation and HTML generation,
including all four required phases. `gallery.py` checks this sequence alone;
repository-wide validation also needs the other demos' local PNGs. Scale differs
between browser and native slides and is recorded per slide.

The manifest records the capture revision, executable-source dirty status, source
and binary fingerprints, and per-image hashes. Regenerate evidence after source
changes; never hand-edit the revision to imply newer provenance. Raw process IDs
remain in the ignored machine evidence, while the manifest records the verified
kernel-restart outcome.

Not tested: actual remote kernels, other frontends/platforms, desktop compositor or
physical-input behavior, and independent human usability. **VoiceOver stays paused.**
Native windows open on the kernel machine; SVG travels inline to the frontend.
