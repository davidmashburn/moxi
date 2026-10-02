# Layout delivery evidence

The optional candidate implements retained flow/grid, CoreText paragraphs,
transactional Kiwi regions, variable extent collections, fitted overlays and a
composed native workbench. It remains outside the root public exports.

`pixi run layout-candidate-check` checks the strategy contracts, composed screen
and native ordered painting/editor clipping. `pixi run layout-workbench-benchmark`
records complete warm-frame timings, including native bitmap paint, against a
16.67 ms p95 budget on the recorded reference host.

Promotion is pending the representative frame budget, independent packaged
consumer, full repository regression suite, supported-target CI, and explicit
VoiceOver and Japanese input-method checks. The initial timing run exceeded the
budget in native submission; no performance or public promotion pass is claimed.
