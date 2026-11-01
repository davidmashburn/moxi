# Authoring documentation and production extraction

Decision accepted November 1, 2026. The user selected the ordinary-fields,
methods, stable-child-identity and explicit-reset strategy, requested practical
documentation, then authorized production extraction as a separate change.
Approval selects the direction; it does not add correctness or usability evidence.

Implementation baseline: `feat/data-workbench` at
[`9d6da90`](https://github.com/davidmashburn/moxi/commit/9d6da90).
The [authoring guide](https://github.com/davidmashburn/moxi/blob/9d6da90/docs/authoring/README.md)
provides counter, keyed-editor and shared-document examples, a general application
guide, and primary-source framework comparisons. Three examples plus a behavioral
check compile and run against the prototype. These checks cover reorder, shared
versus local state, assignment, and root/collection reset. Full production tests,
native UI and CI were not rerun for that documentation-only slice.

## Extraction contract

Make the same model API available from the production package without experiment
include paths. Integrate it with existing `App` event and request delivery; preserve
the lower-level `Component` API. Promote the bounded control vocabulary already
exercised (labels, buttons, checkboxes, text inputs, scoped children), not a universal
widget toolkit or automatic field-dependency tracker.

Retain one request queue consumer in `App.advance_tasks`. Host-owned completions
must validate lifetime and live target; request scopes retire with their controls.
Root reset cancels only owned requests, clears App interaction/scroll capture,
invalidates native input, and publishes fresh output before delivery resumes.
Keep headless reset explicitly named so it cannot be mistaken for native reset.
No new general-purpose application wrapper is required if these guarantees fit
existing lifecycle hooks. If that approach fails integration tests, revisit the
boundary before adding an adapter that competes for queue ownership.

Acceptance scenarios: the guide examples use package imports; queued/captured
work rejects retired roots and controls; ordinary replacement/reorder preserves
owners; copied hosts reject foreign completions; superseded and bounded-queue
requests do not retain callbacks; native reset drops old input but preserves resize
and close policy; sequential focus/input and late addressed callbacks behave
correctly; existing Component, scheduler, input, paint and clipboard paths pass.
Native tests must use the real production backend without source patching.

Platform scope: implement and verify headless and macOS integration here. Do not
silently offer a no-op native reset on unsupported backends. Linux requires a
separate executed GTK/IME validation before claiming equivalent native support.
No dependency change, broad unrelated cleanup, main merge or PR is included.

Confidence before implementation: high in the bounded mechanics established by
the [lifetime integration](lifetime-integration-decision.md) experiments; moderate
in production integration and application-scale comfort. Real OS IME behavior,
human author feedback, and combined end-to-end timing remain distinct evidence.

Status: documentation complete and pushed; production extraction in progress.
