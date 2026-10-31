# Composition acceptance evaluation

Status: the three bounded evaluations are complete; identity/lifetime and scale
limitations prevent stabilizing the experimental authoring API unchanged.
Observed 2026-10-31 UTC (2026-10-30 local), implementation branch
`feat/data-workbench` at `af3b547643068c76e56dae22441a22edb95f5a51`.
Evidence is committed in [the composition evaluation](https://github.com/davidmashburn/moxi/tree/c4f259dfedf368123d3e3234ed11461e74edc1ae/experiments/composition-evaluation)
at `c4f259d` on that implementation branch. Production code and API were not modified.

## Decision

Keep ordinary owned fields, direct methods, typed contexts, and full-declaration
composition as the reference. **Moderate confidence** that routine authoring is
understandable: an unfamiliar smaller-model author completed a meaningful pane
addition using application examples without changing its first implementation.

**High confidence:** the current hand-managed identity and lifetime conventions
are not ready as a universally easy production contract. A held-out test found a
real collision copied from the example idiom. Root/collection replacement exposes
semantic stale-delivery counterexamples. Large-tree cost and retained-slot growth
are measured limitations. These call for bounded engineering work, not another
framework survey or a change to a new authoring language.

## Smaller-model author

GPT-5.6-Luna at maximum reasoning received the screen, domain/editor, pane sources,
and an extension brief, without our conclusions or runtime internals. It saved
its first implementation before feedback, then read probe/build helpers to write
checks. The requested third editor has private draft/note, shared settings and
Apply, a root hide/show toggle, discard-on-hide, and old-action/event rejection.
Its ordinary behavior checks pass. Root/composition code grows from 85 to 108
lines, excluding blank lines/comments/docstrings. No implementation corrections
were needed; its test locator and expectations did need corrections.

The parent's held-out test mounts the new pane and toggles the inspector 101
times. Their independent `base + epoch` ranges meet at key 202 and rendering
aborts: `duplicate identity: /k3:202`. This undermines the example convention,
not merely this particular model's competence.

An assisted second round assigns the new pane negative generation keys. It passes
the unchanged held-out test, ordinary checks, and 110 remounts of each dynamic
pane. It remains 108 code lines. This is a valid bounded repair, but future
siblings still need coordinated key spaces. The repair author read identity and
binding internals. Do not count assisted repair as another blinded success.

The author correctly identified ownership and routing but initially blurred the
note's lifetime: the note stays private even after Apply. Its final explanation
is clearer. One example-assisted model study establishes neither human comfort
nor equivalence to Marko's Tags API. Parent verification preserves both first
attempts and the original failure in `author-results.json`.

## Replacement and session boundaries

Six executed observations distinguish retained Action descriptors from queued
Event IDs (`replacement-results.json`):

- Same-owner field update: both old deliveries intentionally remain usable.
- Remove/append with a surviving Keyed allocator: both are rejected.
- Replace the whole collection and restart keys: both reach the new child.
- Replace the root and reuse its initial generation: both reach the new root.
- Fresh root generation within the existing HandlerHost: both are rejected.
- New HandlerHost with fresh model generation: the old descriptor is rejected,
  but an injected old Event hits the newly reused control ID.

The unsafe cases are counterexamples to interpreting replacement as an automatic
new lifetime. They are not memory-safety findings. Same-logical-owner assignment
can legitimately preserve identity; the application must currently make that
choice. The cross-host event case is synthetic delivery, not a demonstrated
native event-queue bug. A session policy must prevent forwarding or identify and
reject events from the old session.

A Mojo 1.1.0 compiler crash in the fixture's nested field assignment was avoided
by moving the same replacement into an owner method / mut-root helper. The
compiler failure was not diagnosed; no runtime fix was needed for execution.

## Scale and churn

O3, two warmups/five samples, macOS arm64, Mojo 1.1.0. Preparation and timing were
separate; no experiment/compiler work overlapped measurement. Each minimal pane
has a text input and button, producing four retained slots and three view leaves.
This is a different workload from the earlier complete editor benchmarks.

Median real update + paint: 10 panes **0.041 ms**, 100 **0.496 ms**, 300 **2.493 ms**,
1,000 **21.327 ms**. At 1,000 the medians are 20.493 ms update and 0.834 ms paint.
Update work dominates. This does not isolate the several declaration/list-scan
costs or prove a universal complexity law.

Eight live panes retain 32 active slots. After 0/100/1,000 remount cycles, total
slots are 32/432/4,032 and next IDs are 33/433/4,033. Inactive slot records remain
although their action/editor payloads are cleared. Memory bytes were not measured.
Accumulated update+paint for 100 cycles is 5.340 ms; 1,000 cycles is 92.945 ms
(range 92.485–133.954). These are batches of two frames per cycle, not single-frame
latency. The zero-cycle timing is an empty-batch control.

Correctness passes through 1,000 children and 1,000 remount cycles, preserving a
survivor's text, focus, caret/anchor and active IME composition/range, while old
IDs/actions cannot affect the replacement. A nonempty ordinary selection range
was not exercised here. A 960 by 20,000 logical viewport and backend-neutral paint
commands do not establish native rendering latency or physical-screen usability.
`scale/prepared.json` and `scale/results.json` retain hashes, commands and samples;
the parent reviewed tests, reran preparation with the stronger churn case,
verified hashes and independently recomputed medians.

## Next bounded work and acceptance

1. Make sibling identity and mount lifetime collision-free without application
   integer-range arithmetic. Keep the failing first attempt as a regression and
   retain the readable fields/methods surface. A namespace or allocator is a
   candidate mechanism, not a settled new public abstraction.
2. Define same-owner replacement versus new lifetime, including collection/root
   resets and host-session delivery. Validate both descriptors and event IDs.
3. Bound retained records and reduce measured update scans. Preserve active editor
   state and stale-event rejection; naive ID reuse is not an acceptable shortcut.
4. Rerun these tests, then ask an unfamiliar author for another extension without
   key-space coaching. That evidence would raise confidence in the default API.

This completes the requested evaluations. It does not complete those fixes.
Do not stabilize the prototype unchanged. Production paint changes may still be
reviewed independently, with the authoring experiments explicitly experimental.

Whole-branch merge readiness is separate. The prior inspection found the branch
three commits behind main and locked-environment CI setup failures at the current
HEAD ([CI run](https://github.com/davidmashburn/moxi/actions/runs/41148213290)).
Those checks were not refreshed here. Main integration, CI repair/rerun, the full
production suite, native event queues/pixel tests, and a human usability study
were skipped in this bounded evaluation. Earlier 82-test/paint results remain
inherited evidence. The evidence is published separately from any implementation fix. No merge was performed.


## Follow-up

The [scoped identity and retained storage experiment](scoped-identity-retention.md)
addresses sibling range collisions and retained-record growth. Seven typed-key
checks and five combined checks pass; the retention candidate keeps 32 records
after 1,000 remounts and improves the new same-workload large-tree timing from
22.072 to 7.347 ms. Root/collection/session lifetime policy remains unresolved.
The findings above preserve the original acceptance baseline.
