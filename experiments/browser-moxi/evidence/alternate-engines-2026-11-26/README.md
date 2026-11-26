# P01 alternate engines: normal interactive FDG app

The bounded alternate-engine gate passes for **Firefox 159.0 on Linux arm64**
and **Playwright WebKit 27.2 on macOS arm64**. Both ran the normal
`experiments/browser-moxi/` FDG app from published main
`d582d177011dafd4e2a30a07116b586c0ba218a9`, then the documented
`?unsupported` path. This is the existing `App[GraphApp]`, event dispatch,
scene/SVG and semantics pipeline, not the earlier standalone solver.

No app, host, runtime, feature detector, compiler conversion or solver code was
changed. The only executable addition is [engine-check.mjs](../../engine-check.mjs).
The original Chrome replay and entire `artifacts/demo-slideshows/browser-fdg`
directory remain byte-for-byte unchanged. Chrome was not rerun here.

## Environment and provenance

| Run | Engine / automation | Host and service | Capture interval (UTC) | Result |
| --- | --- | --- | --- | --- |
| [WebKit record](webkit.json) | WebKit 27.2, revision 2388; Node 26.10.0 | macOS 27.2.1 arm64; shipped `serve.py`, loopback port 18765 | 2026-11-26 05:01:39–05:01:44 | 11 scenarios passed |
| [Firefox record](firefox.json) | Firefox 159.0, revision 1572; Node 22.22.2 | private Debian 12 Linux aarch64 container; shipped `serve.py`, container loopback port 18765 | 2026-11-26 05:01:38–05:01:49 | 11 scenarios passed |

Both used fresh headless contexts, 1440×1100 CSS pixels, scale 1, and default
Playwright launches with no custom browser flags or preference overrides.
The shipping memory64 probe returned **true** in each engine. Nothing bypassed
or replaced the feature gate. User-agent architecture strings are engine
defaults; the host architectures above were checked separately.

The Linux container mounted only this isolated checkout read-only plus private
evidence/browser/tool directories. External networking was disconnected before
the replay; its HTTP service was bound to `127.0.0.1`. Git metadata was not
mounted. Its source revision is explicitly asserted in the JSON; **every
recorded source hash and the Wasm hash was independently compared with the
macOS checkout and WebKit record and matched**. Both replays also hashed the
served Wasm and five runtime/host modules against their local files, verifying
the service used the intended code. The only working source addition at capture
time was the recorded test harness; subsequent edits are documentation/evidence.

[build.json](build.json) records the fresh native/Node and runtime checks and
fixture hashes. The pinned build passed with Mojo 1.1.0 (8189361e), Apple Clang
21.0.0 and LLD 24.0.0. The Wasm is 567,765 bytes, SHA-256
`7788db5f2bb10786b3c72732e639387cbb974b1ac32320eb5d48bed46995c694`.
The direct official Wasm target still fails as documented; the existing
experimental retargeting route was used unchanged.

## Scenarios and observations

Each row passed independently in both engines. The JSON records steps,
expected results, observed results, timestamps and capture hashes.

| Scenario / steps | Expected and directly observed |
| --- | --- |
| Source identity: hash Wasm and runtime/host responses from loopback | All six served hashes match the local checkout |
| Initial normal URL | Two paused 36-node apps, two SVGs, normal live status |
| Click node-0; focus A; ArrowRight | Mojo selection changes 0 → 1 |
| Drag node-0 +80/+45 CSS pixels; release | Position changes; pinned while held, unpinned after release |
| Drag empty canvas −90/−40; wheel −160; Resize A | Mojo pan and zoom change; SVG height becomes 720 |
| Resume; wait ≥3 frames; Pause; Reheat; wait ≥3 frames; Pause | Default animation loop draws in both runs; Mojo paused state restored |
| Click Moxi search; type `node-12`; Enter | Mojo selection=12 and semantic query=`node-12`; B selection and all 36 node x/y positions unchanged |
| Dispose A; Recreate A; destroy using old handle | A SVG and semantics removed; B SVG remains; new handle and initial selection; stale handle returns −1 |
| Click Verify in the normal app | 6,515 native numeric comparisons plus SVG structure/text parity; maximum absolute error 0.000200000000177; 100 lifecycle cycles; zero tracked live allocations |
| Reload after interaction/verification | Two fresh apps, selections=−1, no runtime failure |
| Load `?unsupported` | `Runtime unavailable`, explicit memory64/no-JavaScript-fallback diagnostic; no app global, graph or semantics; rejection before fetching app Wasm |

Both runs had zero page exceptions and zero failed requests. Verification
also exercises invalid operations, instance/capacity boundaries, UTF-8,
stale/forged handles and poisoned/OOM recovery through the existing fixture.
The fresh comparison count (6,515) differs from the historical Chrome report
(6,371); the old report and captures were preserved, not relabeled as this run.

Representative full-page evidence:

| State | WebKit | Firefox |
| --- | --- | --- |
| Initial normal app | [PNG](webkit-initial.png) | [PNG](firefox-initial.png) |
| Node held during drag | [PNG](webkit-dragging.png) | [PNG](firefox-dragging.png) |
| A disposed, B retained | [PNG](webkit-disposed.png) | [PNG](firefox-disposed.png) |
| Forced unavailable | [PNG](webkit-forced-unavailable.png) | [PNG](firefox-forced-unavailable.png) |

Screenshots substantiate appearance; the interaction and lifecycle assertions
substantiate behavior. Full verbose browser/build/install logs and additional
captures remain private outside tracked source.

## Reproduction and harness gaps

Use the [build/server/engine replay recipe](../../README.md#firefox-and-webkit-replay).
For the captured runs, the URL was
`http://127.0.0.1:18765/experiments/browser-moxi/`. The original records omit the automation package version. The
independent replay used Playwright 1.65.1 with the same browser revisions. The Linux invocation additionally set
`MOXI_SOURCE_REVISION=d582d177011dafd4e2a30a07116b586c0ba218a9` because
the checkout was mounted without host Git metadata. Build artifacts and native
fixtures were generated on macOS, then read unchanged by Linux Firefox; this
does not validate a Linux Mojo build toolchain.

The cached macOS Firefox 159.0 exited before navigation with
`Could not find profile folder`, including a retry with the matching
Playwright revision and a private temporary profile root. No macOS Firefox
app success/failure is claimed. Linux supplied the actual Firefox app run.
An initial mismatched Playwright 1.56.0 / WebKit 2388 probe stalled before
app navigation and was terminated; the recorded WebKit replay subsequently passed.
Container dependency installation initially required root inside the disposable
container; no host permission or system preference was changed.

## Confidence and limits

**High confidence** in this bounded P01 app on the two tested engine/OS
combinations: unchanged runtime sources, matching served hashes, real inputs,
native parity, lifecycle checks and screenshots agree. A failure with the same
source/Wasm hashes and matching engines would change that conclusion.

**Safari was not tested**; a WebKit user agent containing “Safari” does not
establish Safari application coverage. Neither tested engine naturally lacked
memory64, so only the documented forced-unavailable browser path was exercised;
no natural unsupported-engine success is claimed. The runtime's direct
unsupported check remains part of the existing verification fixture.

Skipped: a fresh Chrome run/CDP paint trace, macOS Firefox interactions (launch
blocked), other browser versions, headed/long-session runs, responsive/mobile
viewports, performance/display latency, alternate compilation toolchains,
screen readers/VoiceOver, IME and hardware experiments. No broader web-platform,
Safari, accessibility or cross-engine performance claim follows. No pushes,
external communications, shared-worktree edits or global ledger/index updates
were performed.
