# Linked notebook consumer evidence

[Open the local slideshow](index.html). Ten genuine browser captures show the
installed Mojo-backed consumer through selection, keyboard navigation, filtering,
data replacement, failure, recovery, narrow layout, restart and saved offline output.

The parent rebuilt and captured clean source `dc2b6c1` on November 6, 2026.
[Evidence](evidence.json) records 177 source hashes, binary/wheel/runtime/FDG Wasm
hashes, package versions, checks and timing samples. All source and screenshot
hashes were independently verified; every PNG decoded and was visually reviewed.
The browser loaded all 20 gallery images and passed next/previous navigation;
all 26 master-gallery manifests validated.
The earlier worker T3 preview is retained in `t3-evidence.json` with its original
hashes and explicit precursor scope; it is not the parent recapture.

## Reproduce

Follow [the consumer instructions](../../../examples/linked_notebook/README.md).
The optional wheel contains Python and JavaScript. A separate local macOS ARM64
bundle contains the executable and three Mojo runtime libraries. Parent loader
verification and installed Python/JavaScript hashes passed. The clean notebook
kernel imports from its installed wheel, outside the repository. Capture runs
with Python `-I`; unchanged FDG assets are copied solely for co-display isolation.
No public binary distribution or general notebook adapter is claimed.

## Verified behavior

Parent validation passed 45 Python tests, the 10,000-update bounded-channel test,
and the three FDG notebook protocol tests plus its channel/closed-comm checks.
The review added native point/selection identity validation, preserving the last
valid frame for malformed native responses, and automatic capture-log token redaction.

Actual local Jupyter/Chrome checks passed: independent linked outputs plus FDG;
mark/table selection and semantic state; Tab/arrows/Home/Enter/Space and retained
focus; filtering/empty results/data replacement; backend and executable failure;
2,001 coalesced selections while the kernel executes; capture loss and explicitly
synthetic cancellation; 620 CSS pixels at emulated DPR2; stale identity rejection;
64 records; rerun, clear, disposal, actual kernel restart and offline saved HTML.
The unresponsive-kernel check suspends/resumes only its owned test kernel. Retry
reconciles the in-flight action that later applied and discards the unsent action.
There were no frontend page errors. The owned notebook server was stopped after capture.

Limits are 64 records, finite coordinates in [0,100], 4 KiB requests, 128 KiB frames,
one outstanding and one latest state, 120 timing samples, a two-second process
deadline and four-second comm lease. Scheduling can extend lease detection.
Keys are row indices within a data generation. Saved fallback represents the
initial SVG and full visible table, not later interactive changes.

## Local observations

| Phase / unit | Samples | Median | Max |
| --- | ---: | ---: | ---: |
| domMs | 26 | 0.600 | 2.700 |
| inputToDomMs | 19 | 34.100 | 4191.200 |
| frameBytes | 26 | 7432.000 | 8705.000 |
| layoutMs | 26 | 0.084 | 1.485 |
| sceneMs | 26 | 0.060 | 0.206 |
| svgMs | 26 | 0.112 | 0.158 |
| processMs | 26 | 26.005 | 73.274 |
| roundtripMs | 28 | 31.500 | 423.000 |
| serializeMs | 29 | 0.000 | 0.100 |
| bytes | 29 | 199.000 | 202.000 |
| Chrome main-thread Paint ms | 72 | 0.060 | 0.762 |

Capacity: 64 records, 20,602 bytes,
31.473 ms native subprocess.
Timing samples mix initial, filtered, recovery and deliberately stalled cases.
Input-to-DOM ends at an acknowledged DOM update; its maximum can span failed input
and Retry. Comm samples exclude requests that never ACK. Paint is main-thread
browser work, not GPU/compositor completion or display latency. These observations
are not sustained performance guarantees.

## Remaining gates

General adapter extraction remains contingent on evidence: P04 owns browser Wasm
state; P05 owns kernel-rendered full frames. No common public contract is asserted.
Actual remote hosts/network/dependency installation, physical input, independent
human usability, screen readers (VoiceOver paused), other notebook frontends,
other browsers and Linux/Windows runtime are unverified. Full core/native suites
and remote CI were skipped because P05 changes no shared source. The existing
plot renderer's dense tick formatting remains visible in filtered screenshots.

Confidence is high for the tested local consumer and its bounded lifecycle.
Remote execution, another frontend or independent accessibility/usability findings
could change that assessment. Logs remain under `/tmp/moxi-p05-parent-*`.
