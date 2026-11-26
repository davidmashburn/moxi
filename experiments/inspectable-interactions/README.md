# I19 · Inspectable signal cursor

Move one cursor along a synthetic signal. The Python build uses this checkout's public Moxi PlotSpec, plot and Figure.to_svg APIs. The browser uses the resulting polyline's 101 projected vertices for both cursor placement and pointer input. A single consumer-local session accepts either exact sample entry or a drag. Pointer release leaves the preview available for inspection. Enter in Sample or Commit move accepts it. Escape discards it, including during pointer capture.

Each successful move records a versioned JSON command with target identity, expected revision, origin and destination in samples. Each trace has its own cursor, revision and undo history. Undo increments the revision even when it restores the original value. The compact copy begins at the same baseline with a narrower plot. Reload initializes both traces at the position, revision and undo history immediately before the last recorded move. Each trace can then replay it once. Older recordings restore the position and revision but lack earlier undo entries.

## Run locally

From the repository root, use a fresh browser profile and the printed loopback port.

```sh
demo=experiments/inspectable-interactions
dist=$(mktemp -d)
python3 "$demo/build.py" "$dist"
python3 -m http.server 0 --bind 127.0.0.1 --directory "$dist"
```

## Reproduce the checks

The core tests need Node. The browser check requires installed Google Chrome and Playwright. It builds into a temporary directory, starts its own loopback server and creates a disposable browser context.

```sh
demo=experiments/inspectable-interactions
node --test "$demo/test.mjs"
envdir=$(mktemp -d)
python3 -m venv "$envdir"
"$envdir/bin/pip" install playwright==1.56.0
"$envdir/bin/python" "$demo/check_ui.py"
python3 "$demo/gallery.py"
```

The [capture manifest](../../artifacts/demo-slideshows/i19-inspectable-interactions/manifest.json) records the source revision, viewport, renderer, actions and expected states. Follow its ten actions in order on a fresh origin to repeat the capture. The original PNGs travel with the manifest. The last command validates them and generates the [offline slideshow](../../artifacts/demo-slideshows/i19-inspectable-interactions/index.html) locally.

## Observations

At implementation revision `854e38e`, both core tests passed. The collaborative browser captured a numeric preview at 70, Escape restoring 25, and a pointer preview at 47. Commit produced exactly one undo entry. Undo restored 25 and advanced the revision to 2. The compact copy replayed the recording at 47 and rejected its second application with revision 1 and undo depth 1 intact. Entering 101 disabled commit and displayed the valid range.

An independent Chrome 158 run exercised cancellation while the mouse was still held, keyboard commit and undo, stale rejection after undo had restored the original value, and replay from browser storage after reload. At 390 × 844 the page fit horizontally, rejected 101 and accepted the lower endpoint 0. The run reported zero page exceptions. Chrome requested an optional favicon and received HTTP 404. The captured slideshow loaded all ten original images and responded to arrow-key and thumbnail navigation.

The experiment covers one consumer-local transform with a single fixed target and a Python reference SVG backend. Generalization to a second operation, native Mojo canvas or spatial integration, other browsers, assistive technology, and participant evaluation remain open. The repository-wide suite was skipped.
