# Deferred implementation integration checkpoint

## November 23 follow-through

The gallery review led to fixes in the mindmap branch preview and reflow, mixed-script editing, plot layout, scalar colors and ridgeline peak clipping. The [catalog audit](../artifacts/demo-slideshows/CATALOG-AUDIT.md) distinguishes locally available frames from frames retained in Git. The [contour and radial comparisons](../artifacts/demo-slideshows/plot-contour-followup/README.md) and [ridgeline comparison](../artifacts/demo-slideshows/plot-ridgeline-followup/README.md) record the reference revisions, tolerances and remaining visual differences.

The [SeedWater replay](../artifacts/demo-slideshows/sws-native/README.md) covers the packaged consumer, scientific fixtures and native image sampling. The [installed Python wheel review](../artifacts/demo-slideshows/e04-python-native/REVIEW.md) covers raster text, searchable PDF and interpreter-specific builds. Redistribution remains unresolved.

The browser host centered its canvas with equal left and right margins of 210, 70 and 16 CSS pixels at widths of 1180, 900 and 390 in Chrome 158 and Playwright WebKit 27.2. At all three sizes, the canvas accepted pointer and keyboard input, and a wheel gesture left the page at its origin with no nested scrollable region. These checks exercised the JavaScript host. The pinned Mojo compiler does not provide a browser WASM target here.

The [packaged workbench record](workbench-native-acceptance.md) covers import, selection, export and reopening. Physical IME and sustained presentation timing still need a desktop session, and independent authoring needs a human participant. VoiceOver testing remains paused. The [world-panel probe](../examples/spatial-world-panel/README.md) measured a misplaced native caret and keeps the screen editor available.

## Published main verification — November 20, 2026

The deferred integration is published on `main`. Its November 6 publication at
[`b2361c2`](https://github.com/davidmashburn/moxi/tree/b2361c2d4131cb6bbc25ebf5e4816e2fe347250b)
was followed by [CI run 42307044304](https://github.com/davidmashburn/moxi/actions/runs/42307044304):
five jobs passed, but `package-consumer` failed with
`native/macos_window.m:230:10: fatal error: 'macos_window_state.h' file not found`.
The original local checkpoint below predates that publication and CI result.

[CI run 44825872712](https://github.com/davidmashburn/moxi/actions/runs/44825872712) is now **completed / success**
for exact published `main` commit
[`d7fa3ed563948860f4baf18bcc9f3eb279197135`](https://github.com/davidmashburn/moxi/tree/d7fa3ed563948860f4baf18bcc9f3eb279197135),
event `push`, attempt 1. Verified at `2026-11-20T22:25:38.343056+00:00` using one bounded
`gh run watch --exit-status`, which exited 0, followed by the terminal run and
complete job list. All six declared jobs completed successfully:

| Job | Conclusion |
| --- | --- |
| [headless-linux](https://github.com/davidmashburn/moxi/actions/runs/44825872712/job/136598204860) | success |
| [validate](https://github.com/davidmashburn/moxi/actions/runs/44825872712/job/136598204274) | success |
| [package-consumer](https://github.com/davidmashburn/moxi/actions/runs/44825872712/job/136606750179) | success |
| [retained-layout-linux](https://github.com/davidmashburn/moxi/actions/runs/44825872712/job/136598204703) | success |
| [native-layout-linux](https://github.com/davidmashburn/moxi/actions/runs/44825872712/job/136598205562) | success |
| [layout-candidate-macos](https://github.com/davidmashburn/moxi/actions/runs/44825872712/job/136598204797) | success |

The native package inputs were repaired in
[`9d15954`](https://github.com/davidmashburn/moxi/commit/9d15954cf5874767c223db215af929c42b244bfc),
with the live/source editor includes added in `d7fa3ed`.
The hosted `package-consumer` log confirms a native package build and
`Installed native layout package consumer passed`: archives were built into a
temporary local channel and installed into a fresh consumer environment. This
closes the missing-header packaging blocker on this revision. `validate` also
passed `pixi run check`, the repeated quick benchmark and its
host-independent contract; the other job conclusions are reported separately
above. Hosted host checks built the Android APK and iOS simulator app; direct
Mojo/WASM packaging remains blocked by the pinned compiler target set. These
are build/harness results, without physical mobile-device acceptance.

### Aggregate coverage and remaining acceptance

The [delivery ledger](deferred-implementation.json) preserves the original
per-track checks and “full suite/CI not run” observations. Those describe the
individual integrations; the later aggregate hosted result covers the commands
in [this revision's workflow](https://github.com/davidmashburn/moxi/blob/d7fa3ed563948860f4baf18bcc9f3eb279197135/.github/workflows/ci.yml).
It does not establish every experimental runtime path or new per-track coverage.
All 50 plan states and their acceptance gates remain unchanged.

Separate local replays at `d7fa3ed` produced 20 [mindmap frames](../artifacts/demo-slideshows/mindmap/validation.json)
and 14 [spatial assembly frames](../artifacts/demo-slideshows/spatial-assembly/validation.json).
Frame hashes and source provenance passed for both galleries. Visual review
recorded four partial outcomes in the mindmap and three in spatial assembly.
The [D08 review](../artifacts/demo-slideshows/spatial-world-panel/REVIEW.md)
verified six offscreen frames. Four scenarios passed and two text-input
scenarios had partial visual outcomes. World-panel promotion remains rejected.
The [E04 review](../artifacts/demo-slideshows/e04-python-native/REVIEW.md)
verified five frames and eight exports from the installed native extension and
comparison facade. Three scenarios passed. Renderer comparison and
packaging/timing had partial outcomes; raster text, vector PDF and fresh-host
distribution remain open.
The [E02/E03 review](../artifacts/demo-slideshows/plot-wave-b-c-review/RESULTS.md)
covers 26 plot families and 170 slideshow frames. All families passed the
tested geometry, source-key and event checks. Of 156 scenarios, 114 passed,
36 were partial and six lacked upstream references for comparison.
Physical input/IME/chooser
interaction, independent usability/scientific acceptance, broader hosts and
runtime redistribution remain open. VoiceOver remains paused. The separate
`moxi-sws` app is outside this Moxi push and CI run. The original local SDK/WASM
skips and worker evidence below remain historical; no full local runtime suite
or new manual/browser acceptance was performed for this documentation
reconciliation. Hosted results apply to `d7fa3ed` before these documentation
edits.

This reconciles the published-checkpoint and ledger context required by
[planning section 1](https://github.com/davidmashburn/moxi/blob/2e46d93667166d077e47311277689c54d35942dc/PROJECT-PLANNING.md#1-repair-package-ci-and-reconcile-the-published-checkpoint).

## Original local checkpoint — November 6, 2026

The dated record below is retained as historical evidence. Its local-only,
publication and CI statements refer to that checkpoint and are superseded by
the published verification above. Remaining manual and per-track acceptance
gates still apply.

The started work is preserved and integrated on `feat/deferred-proposals`. The
November 6 review found eight P2 issues; all eight now have local fixes and
regression coverage. No push, PR, merge, package publication or production write
has occurred. VoiceOver remains paused. No untouched proposal was started.

The [delivery ledger](deferred-implementation.json) retains the approved 50-plan
scope and outstanding acceptance gates. This checkpoint does not mark all plans
complete. Original worker worktrees and ignored screenshot artifacts remain
intact; obsolete pause details are recoverable in the previous Git revision.

### Commits and review fixes

| Scope | Integrated/checkpoint commits | Result |
| --- | --- | --- |
| E02 / E03 plotting | `45cc7cf`, `9664137`, `6a8b784` | Reconciled glyph identity and typed source keys, retained Wave A compatibility; resize remaps stable-key selection; JSON objects respect quoted braces/escapes |
| D03 / D04 native editing | `3c288b9` | Canvas creation reserves retained mount IDs; transactional Save/Save As preserves the current destination and draft recovery on failure |
| E04 and Python attribution | `f68c965`, `95d6615` | Native extension rebuilt against integrated plots; facade MIT notice and exact installed runtime notices accompany built distributions |
| D08 world-panel experiment | `511b60b` | Integrated probe and screen-space alternative; world-panel promotion remains rejected |
| P07 sampling hooks | `dbd145e` | Integrated explicit image sampling |
| Separate watershed app | `moxi-sws`: `440abc2`, `3ac37ef` | Checkpointed app; explicit startup recovery saves to a new destination; accepted results survive matching undo/redo states |

The six original checkpoint commits also remain on their worker branches:
E02 `5439d4b`, E03 `bd86363`, E04 `56e4813`, D08 `9916f68`, P07 hooks
`90ef14d`, and the app's initial `440abc2`. The app is a separate local repository;
its code is not included by pushing the Moxi branch.

### Verified locally

- Plotting: 315 combined Python tests; native A/B/C contracts for 9/14/12
  families; 89 B boundaries and 91 negative/10 positive C boundaries; parser,
  resize, legacy view/runtime/selection/spec, API inventory and scenario checks.
- Native editing: four canvas suites, six mindmap Mojo suites, the 70-command
  inventory, native storage/import and production save-session regressions;
  native app build. Save-session tests use real native storage without a chooser.
- Native Python: 46 tests and 315 facade regressions in a clean installed-wheel
  consumer; independent dependency/notice inspection; exact compiled-source
  hashes match current source. Two build-notice tests and facade wheel/sdist
  notice and clean-consumer checks pass.
- Spatial: integrated world-panel checks pass, including source-free public
  consumers and native explorer/assembly replays. These are synthetic native
  checks, not physical interaction or compositor evidence.
- Watershed: 33 app tests, native build against integrated Moxi, and 18 independent
  pinned-original comparisons pass with partition and stable-ID equality.
- Slideshow tooling: four tests pass. This verifies tooling, not fresh captures.

The full check passed its portable lane and all 89 core test files, then exposed
an outdated rectangle-equivalence test call. Commit `d5f2b32` supplies the full
rectangle range; its output is byte-identical at both scales. Rerunning from that
check through the remaining native, package/doc, host, HarfBuzz and live-reload
steps completed successfully. Already-passing steps were not repeated for this
test-only correction. Android/iOS checks were skipped for unavailable SDKs; the
pinned compiler does not provide the WASM target. Remote CI has not run.

Local logs: `/tmp/moxi-review-full-check.log`, `/tmp/moxi-review-check-tail.log`,
`/tmp/moxi-review-spatial-integration.log`, `/tmp/moxi-review-native-build.log`,
`/tmp/moxi-review-native-check.log`, and `/tmp/moxi-sws-integrated-science.json`.
These temporary logs may expire; the outcomes above are the durable record.

### Remaining acceptance and publication gates

1. Complete remote CI and human review before merging. The local native extension
   remains an experiment; preserving notices does not approve runtime redistribution.
2. Fresh integrated-source galleries and visual review remain pending. D04's
   20-frame and D07's 14-frame candidate manifests remain untracked and are not
   certified evidence. Other integrated manifests retain original worker provenance;
   do not present them as captures of this fixed integration.
3. Physical input/IME, chooser interaction, VoiceOver, independent usability,
   scientific acceptance with real stacks, other hosts and controlled sustained
   performance remain open. Watershed smoke/replay was not rerun because its
   scripts open and activate a native window. Power-loss behavior is unverified.
4. D08 cannot be promoted while native IME/semantic geometry remains source-local.
   E02 contour and E03 tricontour references are absent at the pinned upstream;
   full upstream parity is unproven. E04 native raster text and vector PDF remain
   unsupported, with ABI/other-host/sanitizer gates open.
5. Untouched P08–P11, E05–E06, V01–V15 and I10/I11/I13/I15/I18/I19/I20 remain
   deferred. Resume them only under a new implementation decision.

### Content review and confidence

Source changes, filenames and commit messages were reviewed before the local
commits. The outgoing-history scan includes intermediate file versions; targeted
private-context and credential checks found no matches. Tracked binaries are
licensed STIX and original test fonts, not the bundled proprietary runtimes.
Native wheels and runtime libraries remain ignored local outputs.

Confidence is high for the named regression paths and moderate for absence of
obvious private-source leakage. This was not an employer-corpus comparison,
exhaustive screenshot OCR, legal review or complete transitive-license audit.
A newly failing regression, matching private source or additional distribution
contents would change that assessment. Keep unrelated edits and worktrees intact.
