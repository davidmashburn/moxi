# Moxi Force Graph

A self-contained Mojo/Moxi example port of the graph-exploration workflow in
[render_d3_fdg](https://github.com/davidmashburn/render_d3_fdg).

The force solver belongs to this application: `src/layout.mojo` imports only
Mojo's standard library. Moxi supplies controls, events, scenes, SVG rendering,
and the native window. A separate graph-layout package is a reasonable next
home once a second consumer establishes the shared API. This implementation
does not promise D3 API compatibility or identical numerical layouts.

## Build and run

Requires macOS ARM64, Xcode command-line tools, Pixi, and a Moxi source checkout
with its Mojo 1.1.0 environment installed. Build scripts use the containing
Moxi checkout by default; `MOXI_SOURCE_DIR` can override it. This example is
not a separately published package.

```sh
cd examples/fdg  # From the Moxi repository root
bash scripts/check.sh
bash scripts/build.sh
bash scripts/integration-check.sh --native
bash scripts/check-native-frame.sh
./dist/moxi-fdg
./dist/moxi-fdg examples/triangle.json
./dist/moxi-fdg examples/triangle.json --export /tmp/triangle.svg
./dist/moxi-fdg --smoke
```

The build also creates an ad-hoc signed `dist/Moxi Force Graph.app`. Open the
bundle to explore the built-in 36-node synthetic graph. The build records the
Moxi revision in `dist/moxi-revision.txt`; it does not change that checkout.

## From Python and Jupyter

After building, add this example directory to your Python path (or run Python
from it).
The wrapper uses only Python's standard library and launches the compiled
viewer; no Mojo installation is needed in the calling Python environment.

```python
import sys
sys.path.insert(0, "/path/to/moxi/examples/fdg")
from moxi_fdg import view_graph, fdg, render_svg

graph = {
    "nodes": [{"id": "A", "group": 0}, {"id": "B", "group": 1}],
    "links": [{"source": "A", "target": "B", "value": 1}],
}
viewer = view_graph(graph)  # Returns a subprocess.Popen; Python keeps running.
# view_graph(graph, wait=True)  # Instead, wait until the window closes.

# The original fdg(nodes, links) tuple calling convention also works:
viewer = fdg([("A", 0), ("B", 1)], [("A", "B", 1)])
```

Input goes directly over stdin. Each call opens a separate window with a graph
snapshot; later Python mutations do not update it. Check `viewer.poll()` or
`viewer.wait()` for its exit status. Viewer validation errors go to inherited
stdout/stderr; `wait=True` raises on a nonzero exit. Template/JavaScript options
from the original library are not accepted. To select a different build, pass
`executable="/path/to/moxi/examples/fdg/dist/moxi-fdg"` or set `MOXI_FDG_EXECUTABLE`.

In a local Python notebook, `view_graph(graph)` opens the same native window.
For a static inline result, without opening a window:

```python
from IPython.display import SVG, display
display(SVG(render_svg(graph)))
```

`render_svg` returns SVG text after 400 deterministic layout steps; invalid
graphs raise `subprocess.CalledProcessError` with diagnostics in `.stderr`.
The default export timeout is 30 seconds (`timeout=120` increases it). The
current JSON parser can be slow on large payloads, including ignored metadata;
pass only the graph data you need.
This is not an interactive notebook widget. The executable currently requires
macOS ARM64; a remote notebook kernel cannot open a window on your laptop.
Neither helper installs or builds the executable automatically.

## Explore and export

- Drag a node to pin it temporarily; releasing it resumes simulation. Drag the
  background to pan. Scroll zooms around the pointer.
- Pause/resume, reheat, fit, toggle labels, and adjust repulsion using the toolbar.
- Select a node to see its ID and degree. Neighbors filters to the selected node
  and its immediate neighbors. Search matches a case-sensitive ID substring and
  cycles through matches.
- With the canvas focused, left/right select nodes, Enter toggles neighbors,
  and Escape clears selection and filtering.
- Export SVG opens a native Save dialog for the current camera/selection/filter
  state. CLI `--export PATH` writes directly to that path (replacing it if present)
  after 400 deterministic layout steps and fitting the settled graph.

## Input and limits

Input uses the original `nodes`/`links` JSON shape; see `examples/triangle.json`.
Each node needs a unique `id`, optionally a `group`. Each link needs `source`
and `target` IDs, optionally a nonnegative numeric `value` (default 1). Groups
choose colors; link values choose stroke widths, not spring strengths. Self
links render as loops and do not exert force. Parallel links are preserved.

The first version bounds inputs to 256 nodes, 1,024 links, 256K JSON characters,
and a 1 MiB file read. Repulsion is exact O(n²); there is no Barnes–Hut approximation.
Unknown JSON properties are ignored. Invalid JSON, duplicate IDs, missing
endpoints, unsupported control characters, and invalid weights produce errors.
String and number IDs are accepted as text; prefer strings for stable identity.

This slice includes no original JavaScript template hooks,
PNG/PDF export, graph editing, an input file picker, or package-only installation.
Other operating systems and screen-reader workflows require verification.

## Verification

`scripts/check.sh` runs pure layout, JSON-loading, and App event-routing tests,
then parses a shared-scene SVG as XML. `--smoke` opens the native window,
submits frames, checks native command capacity, and closes automatically.
These checks do not substitute for physical pointer/keyboard inspection.

After building, `python3 tests/test_python.py` checks the Python bridge against
the real executable, including SVG/Unicode output, validation failures, and
native launch/exit through the viewer's smoke mode. It requires a desktop
session. Notebook frontend rendering itself has not been verified.

`scripts/check-native-frame.sh` instruments every AppKit draw during 60 frames
of control clicks, node selection, and simulation updates. It rejects any
presentation missing the graph, including intermediate frames that a screenshot
after an interaction would miss. Controls and graph are submitted together
before the single native presentation boundary.

During standalone development against Moxi `c8c7cbb` on macOS ARM64,
native input inspection covered node dragging, background
pan, wheel zoom, arrow-key selection, search, neighborhood filtering, pause,
window resize, close, and the Save dialog's cancel/save paths. A dialog export
was parsed as XML and contained exactly the selected node and its three
neighbors. CLI export was also checked with the original project's 77-node,
254-link example. `scripts/integration-check.sh --native` verifies repeatable
256-node/1,024-link exports, rejection of oversized files, and native submission
at the capacity limit. Other platforms and screen-reader navigation were not
tested; no numerical comparison against D3 was performed. On integration into
`main`, the layout/JSON/event tests, signed build, Python bridge tests, native
frame regression, and capacity checks were rerun. The complete manual input
and Save dialog walkthrough was not repeated.

Run the synthetic benchmark with:

```sh
pixi run --manifest-path ../../pixi.toml mojo run \
  -I ../../src -I src tests/benchmark.mojo
```

Historical standalone-consumer measurements against Moxi `c8c7cbb`, on an
Apple M4 Mac, Mojo 1.1.0 with default optimization, 30 warmup and
200 measured iterations produced the following single-run means. Alpha was
reset before every step so cooled simulations could not become no-op samples.

| Nodes / links | Layout step | Scene construction |
| --- | ---: | ---: |
| 77 / 254 | 15 µs | 30 µs |
| 256 / 1,024 | 169 µs | 115 µs |

These are synthetic workloads, not D3 comparisons or end-to-end frame times.
They exclude parsing, control rebuilding, GPU/native painting, and display
latency. Re-measure before changing the capacity limits.
