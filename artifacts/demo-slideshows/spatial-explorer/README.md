# D06 geometry explorer evidence

Reproduce with `python3 examples/spatial-explorer/gallery.py`, then
`python3 scripts/demo_slideshows.py`. Open `index.html` in this directory.
The 17 PNGs and generated HTML are local ignored artifacts; the manifest,
source/binary hashes and raw timing samples are committed beside this note.

The parent rebuilt and replayed clean source `b24045c` on November 6, 2026.
All 138 scoped source hashes and 17 PNG hashes/dimensions/decode checks passed.
All captures were visually reviewed, and the browser loaded all 34 embedded
images and passed next/previous navigation. The master gallery validates 22
manifests. The images show actual AppKit content rendered via `cacheDisplay`,
with Metal geometry and synthetic native event callbacks. They are explicitly
classified as **offscreen-render**, not physical-input or compositor evidence.

The focused parent checks passed 1,832 portable contract assertions, 143 native
composition/Metal assertions, a clean packaged Mojo consumer, a direct public
composition consumer, portable address/undefined-behavior sanitizers, and the
existing F02 native lifecycle regression. Logs are under
`/tmp/moxi-d06-parent-{check,sanitizers,f02,gallery}.log`, with detailed consumer
logs named by `examples/spatial-explorer/check.sh`. Existing Mojo string API
deprecation warnings remain.

The 60 camera frames retained geometry, vertex uploads and surrounding controls;
all corresponding rebuild counters were zero. Idle submitted zero frames over
0.3 seconds. Recorded p50/p95/p99 milliseconds:

| Phase | p50 | p95 | p99 |
| --- | ---: | ---: | ---: |
| Process CPU | 3.713 | 4.321 | 4.592 |
| GPU command | 0.943 | 1.784 | 6.498 |
| Readback | 1.448 | 1.979 | 2.332 |
| Publication | 1.871 | 2.065 | 2.177 |
| Frame to host image | 5.460 | 8.450 | 10.622 |

Phases overlap and must not be added. p99 equals the maximum for 60 samples.
The total ends before AppKit end-frame, compositor and scanout. Other workers
were active. These observations do not resolve D05's production-renderer or
sustained performance gates.

The controls and inspector are readable in the fixed-size captures. Guides and
conservative bounding boxes intentionally draw over geometry; large transforms
produce overlaps. Physical input/IME, independent human usability,
screen-reader behavior, other platforms, cross-display behavior and sustained
capacity/leak/thermal trials remain unverified. VoiceOver remains paused.
The full repository suite, remote CI, GPU/native sanitizers and unchanged API
inventory were not rerun. Confidence is high for the exercised local contracts;
second-consumer reuse, sustained presentation measurements and human acceptance
could change the broader assessment.
