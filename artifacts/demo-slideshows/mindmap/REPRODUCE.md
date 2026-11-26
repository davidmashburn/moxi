# D04 native mind-map review

The November 23 replay already covered mixed-script editor sizing, destination previews, reflow clearance and the initial camera on a large map. The drawing/editor optimization based on `0da6f295b6d20cdf663aaf66a039a43e8fb66dd0` reduced the cyan fan and typing cost. The terminal-selection repair starts at `58609ab6e2bd02ac6366db0b60ea25968552d4a4` and fixes clicks stolen by differently spaced sibling trunks. The [capture manifest](manifest.json) identifies the clean implementation and the hashes of its inputs. The [validation record](validation.json) pairs each action with its observed result and capture.

## Dense branches and interaction

Compare the [expanded view](13-large-expanded.png) with the same file at baseline. When a parent has eight or more children, aligned ancestry edges use a common vertical trunk. Dense ancestry opts into nearest-terminal hit selection so a nearby sibling trunk cannot steal a distinct terminal click, including with unequal spacing at 1× and 0.5×. Exact terminal ties use snapshot order, as do shared trunks away from eligible terminals; coincident routes cannot identify a unique intended branch. Ports and objects retain priority, so their overlapping areas are not edge targets. Ordinary canvas edges and crosslinks retain their existing overlap policy. The layout and pointer regressions exercise both root sides. The application regression moves a child across the threshold, checks the live preview and commit, and verifies undo. Semantic previews accept the changed ancestry route while ordinary geometry-only previews retain their stricter validation.

The 1,000-topic capture uses an 1180 × 820 point viewport. The camera shows part of the expanded map at readable scale. At pixel row 245, the area between the columns (x = 900–1589) contains 4 cyan pixels, down from 83 at baseline. The color predicate appears in the validation record. Long headers still truncate and the minimap covers part of the lowest visible card. The replay also exercises the [text editor](02-mixed-edit.png), [pointer preview](08a-pointer-preview.png), [reflow start](06a-reflow-start.png), [reflow midpoint](06b-reflow-middle.png) and [save/recovery](10-save-recovery.png). The manifest distinguishes constructed AppKit F2/mouse events from public text and command inputs. Four added captures record left/right terminal selection at [1×](14-dense-left-1x.png) and [0.5×](16-dense-left-half.png) after native mouse handlers, queue delivery and public dispatch. These are deterministic native-route checks, not physical pointer tests.

## Measured cost of typing

The original drawing/editor paired run on Apple M4, macOS 27.2.1 arm64 and Mojo 1.1.0 measured text input through native frame submission in milliseconds. Other builds were running on the host.

| Interval | Build | p50 | p95 | Maximum |
| --- | --- | ---: | ---: | ---: |
| Main-thread CPU | Before | 27.37 | 29.09 | 29.63 |
| Main-thread CPU | After | 6.33 | 6.92 | 6.97 |
| Elapsed | Before | 27.40 | 29.10 | 29.66 |
| Elapsed | After | 6.33 | 6.96 | 6.97 |

The 1,000-topic benchmark viewport contained 37 ordinary commands. Clipped edge commands delivered to the native presenter fell from 4,851 to 17. The renderer submits aligned stems and trunks once, keeps each visible child stub and arrow, and paints the selected route last.

In that implementation run, text-input p95 main-thread CPU fell 76.2% and finished below the provisional 8 ms target for this event; this is not a repeatable budget pass. The reverse-order run measured 7.57 ms on the implementation and 30.42 ms on the baseline. Its slowest implementation sample took 9.92 ms. The edit reuses the retained controls and geometry while the editor stays the same size. Wrapped draft growth republishes geometry before the next hit test.

Independent review repeated the same culled 1,000-total-topic benchmark on the retained implementation executable. It measured **6.22 ms** CPU p95 initially and **9.07 ms** immediately after a sequential baseline run; elapsed p95 was 6.222 and 9.095 ms. The paired baseline CPU p95 was 50.503 ms. The first current run overlapped reviewer compilation; the final pair did not overlap reviewer compiler/test work, but other host activity was not measured. Both current runs retained 37 ordinary / 17 clipped edge commands and passed commit/undo assertions. The above-budget replicate is retained in [validation.json](validation.json), alongside the faster run. Confidence is high in command reduction and observed improvement, moderate in absolute timing portability, and insufficient for the 8 ms gate. Controlled reference-host repeats and end-to-display measurements would change that assessment.

These timing runs use 1,000 expanded **total** topics in a culled readable viewport. They do not measure 1,000 simultaneously visible topics, all hot interactions, physical input, or display presentation. The broader plan's 1,000-visible-topic target remains unaccepted.

The headless application benchmark times different work through paint-list generation. On the same host its 21-sample elapsed p95 for semantic label commit changed from 115.79 to 89.47 ms. Move preview plus commit changed from 317.65 to 277.82 ms. The all-visible probe produced 4,013 ordinary commands and skipped native submission.

## Reproduce the paired native benchmark

Use a macOS checkout with the D04 changes. The ordinary app build supplies the shared AppKit objects. Both timing binaries use the driver from the original density study. Its benchmark works with both source revisions. The current app driver also imports a fixture for the newer branch-picking replay.

```sh
pixi run d04-mindmap-probe
mkdir -p dist/d04-before
git archive 0da6f295b6d20cdf663aaf66a039a43e8fb66dd0 src | tar -x -C dist/d04-before
git show 58609ab6e2bd02ac6366db0b60ea25968552d4a4:examples/mindmap_native_app.mojo > dist/d04-before/driver.mojo
build_benchmark() {
  pixi run mojo build -I "$1" \
    -Xlinker "$PWD/dist/mindmap-window.o" -Xlinker "$PWD/dist/mindmap-text.o" \
    -Xlinker -framework -Xlinker CoreText -Xlinker "$PWD/dist/mindmap-storage.o" \
    -Xlinker "$PWD/dist/mindmap-capture.o" -Xlinker -framework -Xlinker Cocoa \
    -Xlinker -framework -Xlinker QuartzCore dist/d04-before/driver.mojo -o "$2"
}
build_benchmark dist/d04-before/src dist/native-before
build_benchmark src dist/native-after
dist/native-before --benchmark-input
dist/native-after --benchmark-input
# Repeat in reverse order to check the ordering effect.
dist/native-after --benchmark-input
dist/native-before --benchmark-input
```

Each trial selects topic 501 in an expanded 1,000-topic map with 25 labeled crosslinks and mixed-script labels. F2 opens its ordinary text control. Timing starts with a public text event inserting 語 and ends when the shared AppKit presenter returns. Enter must commit the exact new text and undo must restore it before the next trial. Each invocation discards four warmups and reports nearest-rank percentiles over 21 samples. Text entry is timed separately from editor entry, commit, undo, and the window pump. The CPU clock measures the calling thread. The elapsed clock includes scheduling delays. Neither measures end-to-display latency.

With the same extracted baseline, reproduce the headless semantic update and move comparisons separately.

```sh
pixi run mojo build -I dist/d04-before/src tests/mindmap/app_benchmark.mojo -o dist/d04-broad-before
pixi run mojo build -I src tests/mindmap/app_benchmark.mojo -o dist/d04-broad-after
dist/d04-broad-before
dist/d04-broad-after
```

## Reproduce the GUI and contracts

Run these commands on macOS from the repository root.

```sh
pixi run d04-mindmap-contract
pixi run d04-mindmap-replay
open artifacts/demo-slideshows/mindmap/index.html
```

The replay builds the MindMapApp executable, captures its AppKit content view at 2× and embeds the 24 PNGs into a single offline HTML file. To regenerate the HTML directly from the checked-in evidence on an individual checkout, use the same renderer.

```sh
python3 - <<'PY'
from pathlib import Path
import sys
sys.path.insert(0, 'scripts')
from demo_slideshows import load_manifest, render
gallery = Path('artifacts/demo-slideshows/mindmap')
(gallery / 'index.html').write_text(render(load_manifest(gallery / 'manifest.json')))
PY
```

The terminal repair at `37c098525245805abb768e4e4e2f5ac4855eefea` passed seven mind-map contracts, the 70-command inventory and all four shared canvas contracts. Before the fix, both public pointer dispatch and the instrumented native replay selected edges 8/16 instead of 7/15 at both zooms. The same native handlers/queue path now selects 7/15, with exactly one down/up pair per click. Filtered [before](logs/terminal-native-before.log) and [after](logs/terminal-native-after.log) results are retained. The geometry contract also covers ordinary overlap precedence, cache invalidation, semantic preview/commit/undo, tolerance and inherently coincident terminals.

Each of the four terminals wins all 101 sampled centerline geometry hits. Excluding higher-priority ports and objects leaves 76 eligible samples per terminal at 1× and 52 at 0.5×. These are geometry samples, not 101 delivered native clicks. The four native midpoint clicks and four public pointer midpoint clicks provide the interaction checks. The 24 PNG hashes/dimensions and 187 captured source hashes match the clean implementation and its Git blobs; all original 20 PNGs are byte-identical to `58609ab`. The four new captures were visually inspected. The regenerated offline HTML matches the existing renderer, but browser navigation was not repeated. Performance, packaged-consumer and native capacity tests were not rerun for this terminal repair.

D03 capacity/index/native presenter files remain untouched here. A scratch overlay of D03's earlier index candidate passed the complete shared geometry contract, independently checking query membership and explicit ordering. At final inspection D03 had withdrawn that index optimization: its index was byte-identical to this branch's already-tested index. This does not establish combined native capacity acceptance.

The earlier six mind-map contracts and 70-command inventory passed during the drawing implementation. That revision also passed its application and shared geometry regressions. The four shared canvas contracts and the AppKit layer/clip/capacity regression passed. Its original 20 PNGs passed SHA-256 and dimension checks against their manifest, and its 186 source hashes matched the captured Git revision. Eighteen rasters match the November 23 replay. The folded fixture adds the dense root's other port. The expanded fixture displays the new trunk and stubs. In that earlier Chrome offline run, all 20 slides decoded and Next, Previous, wrapping, both arrow keys and thumbnail navigation worked. These remain historical checks, distinct from this repair's verification above.

To verify a retained D04 gallery from its captured source checkout or an evidence-only successor, run the following from the repository root.

```sh
python3 - <<'PYTHON'
import hashlib
import subprocess
import sys
from pathlib import Path
sys.path[:0] = ['scripts', 'scripts/mindmap']
from demo_slideshows import load_manifest
from manifest import snapshot
gallery = Path('artifacts/demo-slideshows/mindmap')
manifest = load_manifest(gallery / 'manifest.json')
assert len(manifest['slides']) == 24 and not manifest['scoped_dirty_source']
assert snapshot()['source_sha256'] == manifest['source_sha256']
for name, expected in manifest['source_sha256'].items():
    blob = subprocess.check_output(['git', 'show', manifest['revision'] + ':' + name])
    assert hashlib.sha256(blob).hexdigest() == expected, name
for slide in manifest['slides']:
    assert hashlib.sha256((gallery / slide['image']).read_bytes()).hexdigest() == slide['sha256']
print('D04 source and frame hashes verified')
PYTHON
```

## Remaining gates

The 1,024 ordinary-command limit still blocks native submission of the all-visible stress fixture. Expanded 10,000-topic native capacity, other interaction budgets, presentation pacing, allocation and retained-memory counts, GPU work, and sustained energy/thermal behavior remain open. Physical keyboard, pointer, IME, capture loss, chooser, VoiceOver, live reference parity and independent usability acceptance require separate exercises. The full repository and remote CI suites were outside this local run.
