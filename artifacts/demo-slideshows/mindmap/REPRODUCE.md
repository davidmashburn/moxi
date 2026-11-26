# D04 native mind-map review

The November 23 replay already covered mixed-script editor sizing, destination previews, reflow clearance and the initial camera on a large map. This change addresses the remaining cyan fan beside a dense parent and the cost of typing into the real mounted editor. It starts from `0da6f295b6d20cdf663aaf66a039a43e8fb66dd0`. The [capture manifest](manifest.json) identifies the clean implementation and the hashes of its inputs. The [validation record](validation.json) pairs each action with its observed result and capture.

## Dense branches and interaction

Compare the [expanded view](13-large-expanded.png) with the same file at baseline. When a parent has eight or more children, aligned ancestry edges use a common vertical trunk with individually hittable horizontal stubs. Crosslinks keep their curved routes. The layout regression exercises hits at the stubs on both sides of the root. The application regression moves a child across the threshold, checks the live preview and commit, and verifies undo. Semantic previews accept the changed ancestry route while ordinary geometry-only previews retain their stricter validation.

The 1,000-topic capture uses an 1180 × 820 point viewport. The camera shows part of the expanded map at readable scale. At pixel row 245, the area between the columns (x = 900–1589) contains 4 cyan pixels, down from 83 at baseline. The color predicate appears in the validation record. Long headers still truncate and the minimap covers part of the lowest visible card. The replay also exercises the [text editor](02-mixed-edit.png), [pointer preview](08a-pointer-preview.png), [reflow start](06a-reflow-start.png), [reflow midpoint](06b-reflow-middle.png) and [save/recovery](10-save-recovery.png). The manifest distinguishes the queued AppKit F2 event from deterministic public pointer, text and command inputs.

## Measured cost of typing

The paired run on Apple M4, macOS 27.2.1 arm64 and Mojo 1.1.0 measured text input through native frame submission in milliseconds. Other builds were running on the host.

| Interval | Build | p50 | p95 | Maximum |
| --- | --- | ---: | ---: | ---: |
| Main-thread CPU | Before | 27.37 | 29.09 | 29.63 |
| Main-thread CPU | After | 6.33 | 6.92 | 6.97 |
| Elapsed | Before | 27.40 | 29.10 | 29.66 |
| Elapsed | After | 6.33 | 6.96 | 6.97 |

The 1,000-topic benchmark viewport contained 37 ordinary commands. Clipped edge commands delivered to the native presenter fell from 4,851 to 17. The renderer submits aligned stems and trunks once, keeps each visible child stub and arrow, and paints the selected route last.

Text-input p95 main-thread CPU fell 76.2% and finished below the provisional 8 ms target for this event. The reverse-order run measured 7.57 ms on the implementation and 30.42 ms on the baseline. Its slowest implementation sample took 9.92 ms. The edit reuses the retained controls and geometry while the editor stays the same size. Wrapped draft growth republishes geometry before the next hit test.

The headless application benchmark times different work through paint-list generation. On the same host its 21-sample elapsed p95 for semantic label commit changed from 115.79 to 89.47 ms. Move preview plus commit changed from 317.65 to 277.82 ms. The all-visible probe produced 4,013 ordinary commands and skipped native submission.

## Reproduce the paired native benchmark

Use a macOS checkout of the implementation revision shown in the capture manifest. Build the ordinary MindMapApp executable and its native objects. For the baseline, compile the identical benchmark driver against the previous revision's Mojo sources. Both executables link the same AppKit objects, including the thread CPU clock probe.

```sh
pixi run d04-mindmap-probe
mkdir -p dist/d04-before
git archive 0da6f295b6d20cdf663aaf66a039a43e8fb66dd0 src | tar -x -C dist/d04-before
pixi run mojo build -I dist/d04-before/src \
  -Xlinker "$PWD/dist/mindmap-window.o" -Xlinker "$PWD/dist/mindmap-text.o" \
  -Xlinker -framework -Xlinker CoreText -Xlinker "$PWD/dist/mindmap-storage.o" \
  -Xlinker "$PWD/dist/mindmap-capture.o" -Xlinker -framework -Xlinker Cocoa \
  -Xlinker -framework -Xlinker QuartzCore examples/mindmap_native_app.mojo -o dist/native-before
dist/native-before --benchmark-input
dist/moxi-mindmap --benchmark-input
# Repeat in reverse order to check the ordering effect.
dist/moxi-mindmap --benchmark-input
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

The replay builds the MindMapApp executable, captures its AppKit content view at 2× and embeds the 20 PNGs into a single offline HTML file. To regenerate the HTML directly from the checked-in evidence on an individual checkout, use the same renderer.

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

The six mind-map contracts and the 70-command inventory passed during implementation. The application and shared geometry regressions were rerun on the captured revision after the final drawing change. The four shared canvas contracts and the AppKit layer/clip/capacity regression passed. All 20 PNGs passed SHA-256 and dimension checks against their manifest, and its 186 source hashes matched the captured Git revision. Eighteen rasters match the November 23 replay. The folded fixture adds the dense root’s other port. The expanded fixture displays the new trunk and stubs. With Chrome offline, all slides decoded and Next, Previous, wrapping, both arrow keys and thumbnail navigation worked.

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
assert len(manifest['slides']) == 20 and not manifest['scoped_dirty_source']
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
