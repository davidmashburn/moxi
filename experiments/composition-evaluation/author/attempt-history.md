# Attempt history

## Attempt 1 — initial implementation

Saved as `attempt1.mojo` before compiler or test feedback, then copied to
`screen.mojo`. The implementation adds a root toggle, a third `Editor` routed
with shared `Services`, and a mount-generation key. Hiding resets the stored
editor; showing increments the generation and constructs a fresh editor from
current services. The route checks visibility and the current generation so a
retained event from the previous mount should not reach the new pane.

No implementation corrections have been made; the later entries record check
corrections and strengthening only.

## Check correction — root control locator

The first check run reached the app but rejected its assumed `/p1` root path.
The generated control listing showed the root toggle at `/p0` (the header is a
keyed child at `/k1:1`). The variant was unchanged; `check.mojo` now locates
the observed `/p0` root control and no longer prints diagnostic paths.

## Check strengthening — shared settings and hidden-current-document case

The first passing check only observed that the settings field changed. It now
also applies through the third editor to verify the shared length limit and
permission affect that editor, and it changes the shared document after hiding
the pane so remount freshness is checked against the new document rather than
the initial `Ada` value. This is a check-only correction; `screen.mojo` was not
changed.

## Check correction — unsaved state before hide

The strengthened check initially hid the pane immediately after applying
`Grace`, so it incorrectly expected the initial document. It now edits an
unsaved `Unsaved` draft after the apply and expects hiding to reset the pane to
the current shared `Grace` document while clearing the private note.
