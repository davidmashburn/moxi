# Native math editor slideshow

Open [index.html](index.html) after generating the local gallery. Twelve frames
show the actual Moxi AppKit workbench: notation entry, matrix editing, malformed
text recovery, selected asynchronous computation, stale rejection, result
application, undo and save/reopen.

Follow [dependency setup](../../../docs/math-editor.md), then run:

```sh
bash scripts/math/run.sh --capture artifacts/demo-slideshows/d02-native-math-editor
python3 scripts/demo_slideshows.py --check
python3 scripts/demo_slideshows.py
```

Set `MOXI_SYMPY_PYTHON` to the optional SymPy environment and
`MOJO_PYTHON_LIBRARY` as documented. These are live content-view renders,
classified as `offscreen-render`; no OS-compositor or physical-input evidence
is claimed. Some states load explicit notation fixtures. `manifest.json`
records the source commit/fingerprint and PNG hashes; `frames.json` records
actual notation, revisions and selection state. Generated PNGs/HTML remain
local and reproducible.

Parent validation at `5f9bb45` passed the focused native/editor/backend suite,
source-free package consumer, and existing API inventory. All twelve PNGs were
visually inspected; gallery navigation and all images passed. Physical IME,
VoiceOver (paused), typography, presentation latency, other platforms and full
repository CI remain unverified. See the [evidence report](../../../docs/math-editor-evidence.md).
