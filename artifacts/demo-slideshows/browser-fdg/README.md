# Browser FDG capture sequence

Open [index.html](index.html) after running the
[browser check](../../../experiments/browser-moxi/README.md). It embeds every
PNG, works offline, and provides previous/next buttons, arrow-key navigation,
captions, per-capture metadata, and a contact sheet. Original PNGs stay alongside
it. [manifest.json](manifest.json) supplies the shared gallery contract;
[captures.json](captures.json) records exact per-capture provenance; [evidence.json](evidence.json)
records verification and timing evidence. Large images, the generated slideshow,
and the raw Chrome paint trace stay local and are ignored by Git.

The sequence is initial → selected/held drag → pan/zoom/resize → pause/reheat →
typed search with two isolated instances → disposal → recreation/stale handle
rejection → forced unsupported runtime. Captures use the existing 36-node,
71-link `sample_graph`, initialized by real Mojo solver steps.

The collaborative preview first ran native parity successfully in Chromium 154
and captured initial/selection states. Its drag operation then failed with
`Preview automation drag timed out after 15000ms.` and, on a corrected retry,
`Preview automation drag timed out after 5000ms.` The complete reproducible
sequence therefore uses local headless Chrome via Playwright. These are actual
browser screenshots of the compiled Moxi application; they are not native-app
captures or screen-reader/physical-display latency evidence.

Run `python3 scripts/demo_slideshows.py` from the repository root to rebuild the
shared offline gallery from this sequence and the other available captures.
