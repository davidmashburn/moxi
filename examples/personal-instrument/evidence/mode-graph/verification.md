# V12 mode graph verification

The ordinary Phrase desk now supports a bounded personal mode graph. The replay extracted Length from the same score's direct controls, authored Accent → Length / keep step and Length → Accent / advance, built custom responses, saved, reopened, and performed those changed transitions with both pointer and keyboard. The full resulting score was identical. This closes the scoped editable-graph omission and supplies this instrument's bounded I09 extraction and I12 build-retention scenarios; no central readiness record was modified.

Confidence: high for the observed local Chrome scenarios below. A failing replay against these source hashes, another platform's contrary behavior, or a requirement for broader extraction/calculation replacement would change that assessment. Human utility is unestablished.

## Environment and provenance

- Base/private branch: `5768f2bea7a6df160d176c075c721e81f1c179fd`, `t3/editable-phrase-graph`. Evidence was captured with the implementation uncommitted on this base. The [results](results.json) and [manifest](manifest.json) identify the exact app, HTML and test source SHA-256 hashes; documentation-only edits followed the replay. These content hashes identify the tested source independently of the later local commit.
- Capture: 2026-11-26 03:07:15–03:07:22 UTC (2026-11-25 evening Eastern).
- Server, from this private checkout: `PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=python python3 examples/personal-instrument/app.py --port 19192`. Loopback URL: `http://127.0.0.1:19192/`. The test checks the served template's SHA-256 against this checkout. The bounded build endpoint was exercised by real browser fetches and independent request/response checks. No known running/source mismatch remains.
- Browser: isolated headless Chrome 158.0.8127.37, Playwright Core; 1120 × 960 desktop and 390 × 844 mobile CSS pixels, scale 1. Both checks launch Chrome with `--mute-audio`. No hardware or external accounts/services were used. No user browser storage/profile changed.
- Fixture: repository CSV's first eight pitches and a synthetic score. A direct source control first changed step 2 length to 1; subsequent performance changed only step 3 length and step 4 accent. Fault injection and explicit storage resets distinguish recovery/equivalence setup from ordinary user actions.
- The shared T3 preview opened, but two snapshot attempts returned `Preview automation snapshot timed out after 15000ms`. Its tab was closed. All observations below came from the permitted Playwright Chrome fallback.

## Fail-first and repair evidence

The initial feature regression ran against the unmodified app/HTML at `5768f2b`. Its immediate normal-desk graph assertion failed with `0 !== 1`: [fail-first.log](fail-first.log). No app code had been changed before that baseline run. The same extraction/transition/save/reopen/perform sequence then passed after implementation. The regression was expanded into [graph-check.cjs](../../graph-check.cjs); the final full run passes 10 grouped scenarios: [replay.log](replay.log), [results.json](results.json).

Visual inspection of the first green replay caught a blank response plot after reopening a graph containing a custom midpoint. A new assertion reproduced that defect before repair: [plot-regression.log](plot-regression.log). Reusing the successfully rebuilt curves for the clean editor fixes it. A delayed startup rebuild also cannot replace a newer extracted draft or supply mismatched preview data. Both are covered in the final run. Earlier captures from before this repair are excluded from the final screenshot set.

For a baseline reproduction, copy the final graph check into this example in a separate checkout at `5768f2b`, serve that checkout, and run it there: the source match check passes and the missing-graph assertion fails. Do not run the legacy app against this implementation's different HTML and call that a baseline.

## Reproduce the final checks

Use an existing installed Chrome and `playwright-core`; if necessary set `NODE_PATH` to that existing node_modules directory. Run the server command above and, from the same checkout:

```sh
PORT=19192 node examples/personal-instrument/graph-check.cjs /tmp/phrase-graph
PORT=19192 node examples/personal-instrument/check.cjs /tmp/phrase-baseline
```

The original interaction check was adapted for the text midpoint field, explicit Length extraction, async save, and now-unsupported version 99. Its behavior checks still cover preview isolation, persistence, independent score recovery from invalid mapping, denied mapping/score writes, wrap, 390-pixel overflow and playback scheduling: [baseline.log](baseline.log).

## Scenario record

Each row records actual browser actions, expected outcome and observed outcome. All final assertions passed. The [machine-readable record](results.json) contains capture times and the exact expected/observed values for each group.

| Steps | Expected | Observed / evidence |
| --- | --- | --- |
| Open Phrase controls; use the real Length source slider's Home/Right; extract Length; edit both curves and Next edges; Build preview | Source edit writes only the selected score value; extraction/draft/build do not install or mutate score | PASS. Step 2 length became 1. Installed Accent self-loop and both storage records stayed unchanged during authoring. Both curve/transition nodes appear in [authored draft](authored-draft.png). |
| Save; reload at same origin | Graph, panel, custom curve calculation and score reopen; input/selection reset to 50/step 1; response plot present | PASS. v2 configuration contains Accent midpoint 75 → Length/keep and Length midpoint 37 → Accent/advance, start Accent. Score retained. [Reopened graph](reopened-graph.png). |
| Select step 3; physically click Input near 67% width; click Next/Apply/Next/Apply | Authored transitions affect the intended steps and operations | PASS. Actual thumb value was 68%. First Next reached Length at step 3; Apply set length to 60. Second Next reached Accent at step 4; Apply set accent to 84. Other fields/notes unchanged. [Pointer performance](pointer-performance.png). |
| Reset only the score fixture/reload; select step 3; focus pad; real Up keys to 68; Right/Space/Right/Space; reload | Exact full score and installed mapping match pointer route; pad retains focus; score persists | PASS. Full score bytes matched the pointer route, then survived reload. [Keyboard performance](keyboard-performance.png). The oracle independently expects `round-even(37 + 63×18/50) = 60` and `round-even(75 + 25×18/50) = 84`. |
| Modified Right; Right outside pad; two transitions from step 8 | No unrelated/modified shortcut; keep then advance wraps correctly | PASS. Modified/outside Right left selection/mode unchanged. Step 8 Accent → step 8 Length → step 1 Accent. |
| Edit Length midpoint to 41; Ctrl+Enter; then enter `not-a-number`; Ctrl+Enter; reload | Successful build replaces the calculation without losing score/focused editor/pad nodes; failed calculation build retains the prior active/stored panel | PASS. Custom 41 result became active and reopened. Invalid calculation produced actual `/build` HTTP 400. Active Length remained 41%, storage/score and focused input node remained unchanged. [Failed calculation build](failed-build.png). |
| Load ten invalid/unsupported JSON configurations via visible configuration editor | Missing/duplicate/unknown modes, invalid start/edge/action, unsupported schema/calculation version and out-of-range midpoint reject atomically | PASS. All imports rejected; prior mapping, score and active Length mode unchanged. Copy saved → Load draft recovers authoring. [Rejected configuration](invalid-configuration.png). |
| Throw from Storage.setItem; Save, Restore, Apply; reload; make builder return 500; edit draft during delayed build | No failed/stale action replaces saved/active graph or score | PASS. Mapping/score records survived save, restore and apply denial, renderer 500, and stale result. Reload removed the synthetic storage fault. |
| Seed malformed JSON, unsupported schema, and dangling-edge storage; reload; explicitly Restore defaults; reload | Defaults recover performance without silently overwriting bad record or valid score; explicit repair changes only mapping | PASS. Each raw bad record remained until repair; valid score stayed intact; restored mapping reopened without warning. [Stored recovery](stored-recovery.png). |
| Fail a custom saved calculation rebuild on opening; remove fault/reload; deny storage reads; remove fault/reload | Temporary fallback cannot erase the valid saved panel/score | PASS. Valid custom panel and edited score reappeared after faults were removed. Both storage records remained intact. |
| Seed each Accent/Length × 25/50/75 v1 configuration; reopen; Right from step 8; explicitly Save final case | All legacy mappings keep their old response and advance/wrap semantics; read does not migrate storage; Save emits v2 | PASS. Six legacy cases. Byte-for-byte v1 storage retained until explicit Save. Conversion produced one Length node, midpoint 75, self-edge/advance, versioned calculation 1. Score retained. |
| POST valid and invalid bounded calculation definitions; compare all outputs to independent integer-rational oracle | Correct half-even values and SVG; unsupported types/versions/ranges/counts reject | PASS. 707 values across midpoints 0,25,37,41,50,75,100 match; eight invalid requests receive HTTP 400. No executable input is accepted. |
| Reopen a one-mode custom Length panel with delayed rebuild; extract Accent before response; release/build preview | Startup response does not erase new draft or use incomplete curves for it | PASS. Draft has 2 modes, installed panel still 1, correct rebuilt plot, stored panel/score retained. |
| Resize to 390 × 844; open source palette; inspect layout and labels | No overflow; all 8 names and exactly one selected note; usable mode/editor states | PASS. Overflow assertion, accessible names and selection pass; [narrow screenshot](narrow-graph.png) visually inspected. Desktop reopened and failed-build states were visually inspected too. |
| Run the existing interaction check with muted Chrome playback | Existing score editing/persistence/recovery and audio scheduling flow remain operable | PASS. [Baseline log](baseline.log). Scheduling completed without an audio error; audibility was not evaluated. |
| Listen for uncaught errors throughout graph replay | No uncaught browser errors | PASS. `pageErrors: []` in results. HTTP 400/500 fault cases are intentional and awaited. |

## Scope audit and remaining gates

Changes are confined to this example: Python build endpoint, ordinary desk HTML, existing interaction-check adaptation, graph regression/replay, documentation and local evidence. No shared Moxi runtime, central master/gallery/planning files, human tests, external communications or pushes. The local commit follows staged diff/name/content and targeted secret/context audits. The parent can integrate the local commit after its own review.

Not verified: human configuration authoring or repeat-use utility, motor comfort, audibility or physical/custom hardware; screen-reader/switch-device behavior; cross-browser/device/native-host/multi-tab behavior; broad repository tests, packaging, GitHub CI or central gallery integration. No independent worker review was requested or launched: this implementation sub-agent performed the source review and browser verification itself. I09 beyond these fixed supported controls and I12 arbitrary code/plugin/compiler replacement are not established by this bounded example.
