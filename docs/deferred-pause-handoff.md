# Deferred implementation integration checkpoint

The started work is preserved and integrated on `feat/deferred-proposals`. The
November 6 review found eight P2 issues; all eight now have local fixes and
regression coverage. No push, PR, merge, package publication or production write
has occurred. VoiceOver remains paused. No untouched proposal was started.

The [delivery ledger](deferred-implementation.json) retains the approved 50-plan
scope and outstanding acceptance gates. This checkpoint does not mark all plans
complete. Original worker worktrees and ignored screenshot artifacts remain
intact; obsolete pause details are recoverable in the previous Git revision.

## Commits and review fixes

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

## Verified locally

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

## Remaining acceptance and publication gates

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

## Content review and confidence

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
