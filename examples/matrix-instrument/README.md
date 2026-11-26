# I02 · Matrix instrument

One 2×2 matrix, its two basis columns and its transformed unit square, rendered
by the repository's actual `moxi.PlotSpec` / `moxi.plot` Python reference backend.
The HTML controls own a single matrix and one shared undo/redo history. The
loopback service projects that matrix; it holds no document state.

From the repository root, with Python 3.10 or later:

```sh
PYTHONPATH=python python3 examples/matrix-instrument/serve.py
```

Open the printed loopback URL. No build, native extension, account or remote
service is required. `--port 8768` selects a fixed port if wanted.

1. Enter `1.25, 0.5, 0.25, 2` in row-major order and **Apply entries** (or Enter).
   The last focused column and its plotted vector share selection.
2. Click u's plotted endpoint, or focus its vector button. Right moves x by
   0.1; Shift+Up moves y by 0.01. The entries follow the same matrix. Tab moves
   between controls; arrow keys in an entry keep their normal text behavior.
3. Undo the keyboard moves and numeric edit. Redo restores both representations
   and their selected column. Selection alone does not add an undo step.
4. Apply `2, 1, 2, 1`: collinear columns, determinant zero. Focus v and press Up
   to restore an independent basis. Undo returns to the singular state.
5. Apply all zeroes. The separate basis controls remain reachable at coincident
   endpoints. **Identity** restores a spanning frame and is itself undoable.

Entries are decimal values in `[-3, 3]`, with up to three decimal places. The
canonical matrix stores integer thousandths; arrow steps do not accumulate
binary floating-point drift. All four draft entries apply atomically. Invalid
drafts leave the committed frame intact. Discard or Escape restores the committed
text; apply/discard drafts before moving vectors or using history. The last 100
edits are retained. This is session state: reload starts fresh at `2I`.

The determinant is computed exactly from the integer entries. Zero is singular;
a nonzero determinant satisfying `100 × |det ticks| ≤ max(|entry ticks|)²`
is labelled near singular. This is a disclosed scale-relative warning, not a
condition-number estimate. No inverse or constraint solver runs, and entries
never snap. Negative determinants retain their sign; area uses the absolute value.

Moxi fits line layers independently. This consumer gives every layer identical
domain anchors, pads columns to equal length, then removes those anchors and
padding from the rendered strokes. Its fixed view includes every possible
transformed corner. Equal x/y unit scales, singular rendering and geometry are
checked by `test_matrix.py`; no core renderer is modified. Clickable endpoint
and label annotations use Moxi's projected coordinates. Persistent HTML vector
buttons preserve focus when the SVG is replaced and remain usable at zero.
During a render or after a request failure, stale geometry and metrics are
hidden. The current entries and history survive; **Retry drawing** redraws them.
Aborted/old or mismatched responses cannot replace the latest matrix.

## Verification and captures

Model / HTTP boundary checks need only Python:

```sh
PYTHONPATH=python python3 -m unittest discover -s examples/matrix-instrument -p test_matrix.py -v
```

Browser checks use Playwright and an installed Google Chrome. Keep tooling in a
temporary virtual environment, for example:

```sh
python3 -m venv /tmp/moxi-i02-tools
/tmp/moxi-i02-tools/bin/pip install playwright
PYTHONPATH=python /tmp/moxi-i02-tools/bin/python -m unittest discover -s examples/matrix-instrument -p 'test_*.py' -v
/tmp/moxi-i02-tools/bin/python examples/matrix-instrument/capture.py
```

`capture.py` runs the regressions, retains genuine Chrome screenshots and writes
a navigable [offline deck](../../artifacts/demo-slideshows/matrix-instrument/index.html)
plus a source/environment/scenario manifest. Logs go to a printed temporary path.
`--out /tmp/moxi-i02-captures` keeps regenerated artifacts outside the repository.
The default desktop viewport is 1366×1100; the narrow flow uses 390×844.

This implements the bounded I02 experiment from the public `project-planning`
branch (`ea6f70d`, `ideas/i02-tangible-mathematics.md`) and the matrix gap in the
`d1da7c0` concept crosswalk. It leaves V01, V07 and V08 source and all global
planning/gallery indexes untouched. Determinant constraints, dragging, arbitrary
precision, general symbolic editing and cross-session persistence are outside
this bounded consumer. VoiceOver remains paused. Captures do not establish
assistive-technology, physical-input, native-host, learner or cross-browser results.
