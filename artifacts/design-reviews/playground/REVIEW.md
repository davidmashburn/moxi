# Moxi Playground design review

At the default 1180 × 760 pt, the original catalog exposed four example names before scrolling. This review covers the launcher and those four examples. The visitor's task is to open an example, see what it demonstrates, and try its main interaction. Search, area filtering, and source inspection must remain reachable.

## Screenshots

| State | Before | After |
| --- | --- | --- |
| Playground opening on Hello Window | [Overview](before-playground.png) | [Live dimensions](after-playground.png) |
| Hello Window preview | [Demo tab](before-hello-window.png) | [Same preview on entry](after-playground.png) |
| Hello Component | [Description](before-hello-component.png) | [Two mounted greetings](after-hello-component.png) |
| Counter at zero | [Original](before-counter.png) | [Revised](after-counter.png) |
| Form before input | [Original](before-form.png) | [Revised](after-form.png) |
| Form at 900 × 650 pt | [Original](before-form-narrow.png) | [Revised](after-form-narrow.png) |

The [narrow Hello Window](after-hello-window-narrow.png) shows the preview above its source. The [submitted Form](after-form-submitted.png) shows the name and count after navigating away and back.

## Rubric

Scores use the [demo design rubric](../../../.agents/skills/review-demo-design/SKILL.md), from 0 for a blocker through 3 for a pass in the observed states.

| Criterion | Observations | Before → after |
| --- | --- | --- |
| Hierarchy | On entry, seven area buttons, three tabs, Run and Reset competed with an overview of Hello Window. The revised first screen opens the greeting, folds the filters into one Area chooser, and leaves Run and Reset off the greeting. Counter and Form each have one primary action inside their preview. | 1 → 3 |
| Legibility | Repeated summaries made the narrow catalog harder to scan. The revised list fits more names, with a highlight on the selected one. The example source remains small and the empty Form field has a faint border. | 2 → 2 |
| Layout | Repeated controls used the space above the original preview. Now the preview starts directly beneath the tabs. The narrow Form keeps its input and Submit visible together and puts its source below. | 1 → 3 |
| Interaction | Previously, selecting a name opened Overview, with Demo and Run offering two ways into the same example. Selection now shows the running example in one step. The revised form displays the submitted name, and the secondary controls remain reachable. | 2 → 3 |

## Verification

Native AppKit content-view captures at 2× on macOS 27.2.1 with Mojo 1.1.0, November 28, 2026 UTC. Baseline is commit `c8a6bf5`. Revised captures use the source committed with this review. Desktop images are 1180 × 760 pt unless marked narrow. All examples use local synthetic input. The baseline opening view has an empty query after clearing search. Its status line reflects that action.

| Gate and steps | Expected and observed | Result |
| --- | --- | --- |
| Open the Playground and resize Hello Window | The greeting was visible on entry. Its preview read 434 × 260 pt at desktop size and 492 × 260 pt after the source stacked at the narrow size. The standalone window updated from 560 × 320 to 650 × 400 pt. | Pass |
| Select Hello Component | The Playground and standalone showed both “Hello, Ada!” and “Hello, Lin!”. | Pass |
| Select Counter, increment, switch away and return, then reset | The count went from 0 to 1, stayed at 1 on return, and reset to 0. The standalone incremented to 1. | Pass |
| Enter Ada in Form, submit, switch away and return, then reset | Both hosts showed “Submitted: Ada (1)”. The Playground retained the confirmation on return and reset to zero. The authoring test separately checked Tab and Enter submission, Unicode text, and composition. | Pass |
| Open Area, choose Plotting, search for a nonexistent example, clear | Four plot entries appeared after the filter closed. The empty state offered Clear search, which restored the same four entries. | Pass |
| Open Source and return to Demo | The component tests checked tab selection and source content. The live-editor regression also exercised compilation, diagnostics, and reverting a draft. | Pass |

Verification used AppKit mouse events, native text insertion, accessibility actions, and the application's real executable. The screenshots capture window contents and omit OS title bars. The catalog inventory check covered all 28 entries. Visual review of the other 24, physical-keyboard use, VoiceOver, and other platforms were outside this pass.
