# Attempt history

## Repair attempt 1 — namespace correction

Copied the round-one `screen.mojo` into `attempt1.mojo` before running any
compiler or test. The parent finding showed that `THIRD_BASE + third_epoch`
was not a stable identity scheme: the unchanged inspector's positive counter
eventually reached the same integer. The candidate replaces that offset with a
named negative namespace while keeping the existing generation and route
guard.

`screen.mojo` is the candidate used by the repair checks and is byte-for-byte
identical to `attempt1.mojo` before verification.

## Verification strengthening

The copied `check.mojo` keeps all round-one behavior checks and adds 110
hide/show cycles for the third pane. Each cycle retains the old text action and
old text-input target, delivers both while hidden and after remount, and
asserts that neither can mutate the new editor. It also toggles the inspector
110 times while the third pane is mounted, checking that both counters remain
independent.

The unchanged parent-held-out source is run with `author-repair` first on the
import path; it is not copied or modified.

## Feedback status

The initial repair candidate compiled and passed the ordinary check; that first
run emitted only two unused loop-variable warnings. The loop binders in
`check.mojo` were changed to `_` as a test-only cleanup, and the rerun was
clean. No implementation correction was needed. The baseline failure remains
captured separately in `/tmp/moxi-author-round2-baseline-collision.log`.
