# Scoped identity and retained storage follow-up

Status: experimental continuation of the [composition acceptance evaluation](composition-acceptance.md).
Implementation baseline: `feat/data-workbench` at `c4f259d`; the continuation passes seven typed-identity checks, both scale variants,
and five combined compatibility checks. Observed 2026-10-31 UTC (2026-10-30 local).

Implementation: [`3d26104`](https://github.com/davidmashburn/moxi/commit/3d261048f294ff04a2a9dd6360851b695b004e31).
Reproduction and results: [typed identity](https://github.com/davidmashburn/moxi/blob/3d261048f294ff04a2a9dd6360851b695b004e31/experiments/scoped-identity/README.md)
and [bounded retention](https://github.com/davidmashburn/moxi/blob/3d261048f294ff04a2a9dd6360851b695b004e31/experiments/bounded-retention/README.md).

## Decision being tested

Keep ordinary fields/methods and inferred `ui.child(...)` declarations. Remove
numeric range coordination from remountable siblings using `MountKey(slot,
generation)`. Independently reclaim unseen retained records and index path/ID
lookups without recycling event IDs. These mechanisms address demonstrated
failures; neither silently decides what assignment means for model lifetime.

## Typed identity

`experiments/scoped-identity` copies the experimental bindings/runtime and adapts
the first author's screen. The original 101-remount held-out fixture runs
unchanged. The two dynamic siblings also coexist through 110 equal-generation
remounts, rejecting old descriptors/events while another editor preserves focus,
nonempty selection, and active IME state. Nested routes use both overloads and
verify current-owner/context copies, reorder, and inner-generation rejection.

The application module is **110 versus 108** counted lines. Shared key encoding
adds 18 lines. It removes arithmetic coordination, not routes, unique sibling
slots, explicit generations, reset methods, or visibility guards. Int keys remain
supported in a disjoint namespace. No explicit generic arguments are required at
ordinary child declarations.

High confidence in this bounded collision fix; moderate confidence in it as an
improved authoring idiom. There has been no new unfamiliar-author or human trial.
A model extension without key-space coaching would be useful evidence next.

Legacy field/composition checks and six replacement observations are part of the
runner. The same three new-lifetime counterexamples must remain visible: resetting
collection keys, resetting root generations, and injecting an old ID into a new
host. Typed sibling identity does not close these policy gaps.

A direct nested-root field assignment crashed Mojo 1.1.0 during fixture work.
Prefix isolation localized the trigger; moving the assignment into an owner
method allowed the complete nested fixture to run. The compiler cause remains
undiagnosed. Treat this as a tooling obstacle, not a lifetime fix.

## Retained storage

The independent `experiments/bounded-retention` candidate keeps the Int-key API.
It removes unseen control records and rebuilds path/ID indexes, preserving live
records and monotonically increasing IDs. After 1,000 remount cycles with eight live panes, retained records fall from
4,032 to 32 while both next IDs reach 4,033. Both variants pass visible
10/100/300/1,000 and churn 0/100/1,000 correctness checks. The parent reviewed the
runtime/tests/runner, independently reran candidate correctness, verified hashes,
and recomputed medians.

O3, two warmups/five samples; compilation and other checks finished before serial
measurement (baseline then candidate). Median update+paint, milliseconds:

| Minimal panes | Baseline | Candidate |
| --- | ---: | ---: |
| 10 | 0.045 | 0.037 |
| 100 | 0.557 | 0.329 |
| 300 | 2.737 | 1.273 |
| 1,000 | 22.072 | 7.347 |

At 1,000 panes, update medians are 21.199/6.512 ms and paint 0.902/0.835 ms.
Combined medians use each sample's sum. The 1,000-remount batch drops from
93.565 to 53.302 ms, with two frames per cycle. These are minimal input/button
panes, not the complete editor workload; the machine is unisolated and the
variant order is fixed. Record counts are measured, allocated bytes are not.

A generated temporary runtime combines typed identity and reclamation. Five
checks pass, including the unchanged collision regression, nested routing,
nonempty selection/IME during churn and focused-editor reorder, all-record/index
removal, same-path remount with a fresh ID, focus clearing, discarded IME, and
copied-index isolation. Combined performance was not measured.

High confidence in bounded records for this workload; moderate confidence in
transferring the approximately 3x large-tree speedup. No application authoring
changes are needed for the retention optimization.

## Remaining boundaries

No production edits or merge are included. The full production suite, CI repair,
main integration, native event queues/pixels, and human usability evaluation are
outside this continuation. Prior production paint results remain inherited
evidence. Do not stabilize the authoring API until reset/session policy is clear;
do not confuse record reclamation with descriptor lifetime invalidation.


## Next decision

Prefer these runtime improvements beneath ordinary fields/methods. The evidence
supports progress on performance and eliminating a specific identity trap; it
does not support calling the API universally easy. Keep the typed-key convention
experimental until a fresh author can use it without key-space coaching.

The next bounded question is a lifetime contract: ordinary assignment preserves
logical ownership; an explicit new-lifetime/reset operation must invalidate both
descriptors and event IDs, including collection/root and host-session boundaries.
Define and test that distinction before adding another authoring abstraction.
Remaining scans merit representative workload measurements, but do not require
reopening the framework inventory now. Whole-branch merge readiness remains
separate from these successful experiments.
