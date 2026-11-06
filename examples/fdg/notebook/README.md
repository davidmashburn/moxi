# FDG notebook entry points (P03)

`../entrypoints.ipynb` defines one five-node graph and passes it to the existing
`render_svg` and nonblocking `view_graph` helpers. No widget, comm protocol,
packaging API, or core dependency is added.

## Run locally

From the repository root, on macOS ARM64 with Xcode command-line tools and Pixi:

```sh
bash examples/fdg/scripts/build.sh
uv venv --python 3.13 examples/fdg/.venv-notebook
uv pip install --python examples/fdg/.venv-notebook/bin/python \
  -r examples/fdg/notebook/requirements.txt
examples/fdg/.venv-notebook/bin/jupyter lab examples/fdg/entrypoints.ipynb
```

Python 3.11 or newer is needed for `tomllib`. The calling Python environment does
not load Mojo: both helpers execute the compiled binary. All notebook dependencies
are optional and isolated from the normal Moxi build. Use a **Python 3** kernel
from this environment. Run every cell in order. Run the launch cell twice and the
computation cell while both viewers are open. Close both windows normally; then
run reopen and cleanup. Finally use **Kernel → Restart Kernel and Run All Cells**.
Run All can finish without manual closes; cleanup terminates any remaining viewers.

The return value is a process handle, not a notebook-owned widget. A kernel restart
loses those handles and does not guarantee disposal of native processes. Run the
cleanup cell first, or close outstanding windows yourself. Each native call starts
fresh; edits to the Python dictionary do not update an existing viewer. Native
nonblocking errors use the process exit status and inherited stderr (which can
appear in the server log). SVG failures expose the compiled parser's diagnostic in
`CalledProcessError.stderr`; the notebook shows a missing-endpoint repair.

On a **remote kernel**, the native window opens on the **kernel machine**. SVG
travels back as notebook output and is displayed by the frontend. No actual remote
kernel was tested; this local result does not establish remote native support.

## Focused executable check

```sh
examples/fdg/.venv-notebook/bin/python examples/fdg/notebook/verify.py \
  > /tmp/moxi-p03-notebook-check.log 2>&1
python3 examples/fdg/tests/test_python.py > /tmp/moxi-p03-python-bridge.log 2>&1
```

`verify.py` uses a fresh real Python kernel and the actual built binary, executes
all eight code cells, repeats the launch cell, verifies two independent live
processes and a subsequent computation, closes both through AppKit's normal
`performClose:`, checks exit code 0, reopens, and cleans up. It restarts the same
kernel manager, verifies a different PID and absent old globals, then repeats the
sequence. It also checks missing-executable instructions and nonblocking invalid
input exit status. The final check verifies no observed viewer process survives.

The test-only `native_probe.m` is loaded with `DYLD_INSERT_LIBRARIES`. It observes
real AppKit windows, acknowledges commands in a private test directory, invokes
normal close callbacks, and captures live content views with `cacheDisplay`.
No core source or production binary is patched. Captures exclude window chrome,
desktop composition, and physical input. They are explicitly labeled in the
[slideshow evidence](../../../artifacts/demo-slideshows/fdg-notebook/README.md).

Executed notebooks, detailed evidence and the dylib stay under ignored
`examples/fdg/dist/notebook/`. Keep the tracked notebook output-free. It contains
synthetic data only; the verification report records versions and base revision,
while local PIDs and any local paths stay in ignored artifacts.

## Frontend and evidence

Open the executed notebook in actual JupyterLab to inspect the SVG. An externally
executed notebook is initially untrusted: run it yourself, or trust only the local
output you just generated before opening it:

```sh
examples/fdg/.venv-notebook/bin/jupyter trust \
  examples/fdg/dist/notebook/executed.ipynb \
  examples/fdg/dist/notebook/restarted.ipynb
examples/fdg/.venv-notebook/bin/jupyter lab --no-browser --ip=127.0.0.1 --port=8893
```

Use the token URL printed by Jupyter. Keep it out of tracked files and screenshots.
The T3 collaborative preview can capture the real notebook frontend. Save full
viewport PNGs after scrolling to the graph definition, SVG, diagnostic, and restart
result; do not replace outputs with screenshots or constructed HTML. Native PNGs
come from `verify.py`. If collaborative-preview interactions are unavailable,
`capture_frontend.py` provides a repeatable actual-Chrome fallback with the separate
optional `requirements-capture.txt`. See the slideshow README for exact commands
and finalization.

VoiceOver remains paused. These scripted checks and rendered output inspection do
not claim independent human usability, physical-input acceptance, remote-kernel
coverage, other notebook frontend compatibility, or Linux/Windows native support.

## Interactive inline example

For P04's optional inline graph, setup, real-browser checks and screenshot
evidence, see [INTERACTIVE.md](INTERACTIVE.md). The P03 example above remains
independent.
