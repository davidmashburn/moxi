# Lifetime integration decision

Observed 2026-10-31 on `feat/data-workbench`. Evidence: experiment
[`58ef995`](https://github.com/davidmashburn/moxi/tree/58ef995/experiments/lifetime-integration),
production request-scope retention fix
[`becd2ba`](https://github.com/davidmashburn/moxi/commit/becd2ba), and the preceding
[explicit contract](explicit-lifetime-contract.md). This is a tested candidate,
not a stabilized production authoring API or a merge-readiness declaration.

## Recommendation

Keep ordinary fields and methods. Assignment changes values in the same logical
owner; explicit reset starts a new lifetime. Stable keys identify dynamic children.
External model commands publish synchronously before delivery resumes. The host,
not each application model, owns native ingress invalidation, retained-state reset,
and cancellation of work attached to retired controls.

Confidence is **high for the tested mechanisms**, **moderate for author comfort**.
The unfamiliar model author wrote a working two-editor example after three compiler
fixes and no runtime changes. That is useful evidence, but not a human usability
study or evidence that all developers will infer assignment/reset semantics.

## What the integration changed

| Question | Evidence and outcome | Remaining boundary |
| --- | --- | --- |
| Can request ownership reuse existing runtime machinery? | Adapter uses App's RequestScheduler; stale ready/pending results, supersession, foreign numeric handles, overflow and repeated reset pass | Successful parameterless completion prototype; one queue consumer; no final general effects API |
| Is retained request state bounded after reset? | Found 103 scope records after 100 resets; production fix removes cancelled scopes/bindings; regression covers 1,000 unmount and 1,000 direct-cancel cycles | Per-key generation state remains until scope closes; use stable operation keys |
| Does root reset clear state outside the model? | Scroll probe initially failed; experimental reset now clears App scroll records and scrollbar drag | Production reset must include the same host-level state |
| Do old native packets mutate a replacement root? | Actual macOS queue → Mojo poll → App reproduces unaddressed stale text; generated native lifetime prototype rejects old input and preserves resize | Headless fixture, not OS-generated input or production native integration |
| Does the policy break normal input ordering? | Tab → activate → Tab → type and click → type batches follow dispatch-time focus without an intermediate render | Input within one root remains sequential; no claim that every packet binds to render-time focus |
| What about gestures/callbacks already in flight? | Active App button press retires; fresh release cannot activate replacement. Native AX callbacks invoked after reset carry current epoch but retired IDs and cannot mutate replacement | External AX clients, native AX tree reuse and OS IME cancellation remain untested |
| What does copying mean? | Moving App preserves pending actions/requests; copying its host preserves values but creates an independent delivery owner | Copying a Mojo host does not clone or safely rebind a process-global native window |
| Can a fresh author use it? | Preserved first attempt, three compiler corrections, independently rerun behavioral checks | One model author, assisted correction; no human comfort claim |

The native reviewer independently traced the production path and identified
already-active pointer capture, late accessibility callbacks, and Linux deferred
queues as risks. The parent added and ran the first two cases. The reviewer performed
source inspection, not an independent native execution or final adapter code review.

## Contract in practice

Ordinary handlers keep using assignments such as `self.title = value`. A collection
owner can call `self.editors.reset()` and append fresh children inside its published
command. An external caller uses `update_model(app, Workspace.reset_editors)` so
reconciliation completes before pending deliveries resume.

A new document/session is an explicit host reset. The production host should expose
one transaction beneath that operation:

1. Retire the current native input lifetime and clear native gesture/composition state.
2. Cancel only work owned by the outgoing root/controls, preserving unrelated App work.
3. Replace the root, retire controls, clear root scroll/captures, rebuild and republish.
4. Resume delivery; old envelopes fail ownership/target validation.

The experiment assembles this transaction in its adapter. The earlier
`reset(app, Root())` helper alone handles model/retained/App state, not the native
window or request queue. No production caller should infer otherwise from its short
name. There must be one integrated entry point during extraction.

This is also why both a native lifetime and stable target identities are needed:
old queued packets must fail before routing, while late callbacks from old retained
objects can enter the *new* queue and must fail the target check.

## Performance and complexity

No new benchmark measures delivery-marker/refcount/bridge/native-epoch overhead.
The prior paint and scoped-retention timing results remain their own evidence, not
an end-to-end measurement of this combined prototype. Reset correctness does not
require adding reactive wrappers to ordinary fields.

The bridge introduces adapter complexity and linear scans. It is not evidence of
constant-time request routing at large scale. The application author's remaining
concepts are ordinary state ownership, stable dynamic identity, and assignment
versus reset. The first unfamiliar author stumbled over App copying; the contract
README now shows the explicit host-copy constructor. Target lookup by kind/ordinal
belongs to test/adapter scaffolding, not ordinary render methods.

## Verification and stopping point

Parent verification: ten preceding lifetime programs, four integration programs,
six selected production regressions, and the actual native queue/poll program pass
(21 executable checks), plus Objective-C compilation and Mojo native build. Checked
source/generated hashes match recorded evidence. The tests retain the raw-delivery
negative controls rather than treating them as solved. No main merge occurred.

Skipped: full production suite, CI, real window/input/pixels, Linux execution,
concurrency, integer exhaustion, native lifetime overhead benchmarks, and human
usability. Native input from an OS composition session after reset is particularly
not established by merely clearing the backend's marked-text variable.

The bounded evaluation has reached a useful decision boundary. More synthetic
callback/field variants are unlikely to tell us whether the contract feels natural.
The evidence supports selecting this contract for a production pilot; it does not
support silently promoting the experimental toolkit or merging all research code.

Production extraction remains a separate implementation scope: the prototype has a
small control vocabulary, private routing/storage, a limited completion adapter, and
no connection to App's native run loop. Extraction must establish a single supported
host reset, integrate request delivery without competing queue consumers, implement
platform-specific input invalidation and snapshot publication, and verify real IME/AX
behavior. That work should follow an explicit pilot/API decision rather than another
unbounded research inventory.

Evidence that would change the recommendation: a human author repeatedly confusing
value replacement with reset after the short guide; a realistic composition needing
manual generations in ordinary model code; OS input violating the proposed reset
transaction; or meaningful end-to-end overhead from the ownership machinery. Until
then, keep this as the leading candidate and keep public API/merge claims provisional.
