# Example authoring migration, preserving Moxi Playground

Status: implemented locally on `feat/playground-authoring` through `fa42b6f`.
Manual launcher acceptance and CI remain unverified; see the reconciliation below.

Observed November 2, 2026 against implementation `main` at
[`ba8fc93`](https://github.com/davidmashburn/moxi/tree/ba8fc93e3a16b4113bec4f2c9adc8e5713aa1fc2).
Both implementation and planning worktrees were clean at inspection. This plan
does not depend on uncommitted implementation changes.

## Outcome and boundaries

Make the examples teach the simplest supported style appropriate to their
subject. Recommend ordinary fields, methods, and pure `render` for application
behavior. Keep explicit components, layout, scenes, and backend calls where
those mechanisms are the lesson or are required for the example's behavior.

Preserve the wxPython-inspired central launcher: `pixi run demo`, the catalog,
search and category filters, Overview/Source/Demo tabs, in-process live pages,
and the existing standalone companion commands. Keep `DemoBrowserState` as a
lower-level `Component`; the launcher does not need to use the same authoring
style as every hosted page. Preserve `wx_style.mojo` as a broad widget lesson.

The deliverable is a coherent learning path and working examples, not a target
percentage of files converted. Do not add a language, generic plugin framework,
automatic dependency tracking, or broad widget/layout wrappers to make every
example fit `UI`. Do not remove public demo components or their regression
fixtures merely because a teaching entrypoint now uses an authoring model.
Retain backend and platform scope; this work does not promise new platform
support or make every standalone example embeddable.

## Original evidence and the first technical gate

- [The launcher contract](https://github.com/davidmashburn/moxi/blob/ba8fc93/docs/demo-browser.md)
  requires real in-process previews, not substitute screenshots or sibling
  windows. Its `ComponentSlot` fields, event routing, code panel, and reset path
  are in `src/moxi_demo/demo_browser.mojo`.
- [HandlerHost](https://github.com/davidmashburn/moxi/blob/ba8fc93/src/moxi/authoring/runtime.mojo)
  implements `Component`. `ComponentSlot[HandlerHost[Model]]` is therefore the
  first integration candidate, not a new page abstraction. This nested-host
  combination has not been compiled or behaviorally verified for this plan.
- The current authoring declarations cover labels, buttons, text inputs,
  checkboxes, and scoped/keyed children. They do not expose the full row/grid,
  custom scene, theme, or collection-widget APIs used by the demos.
- The launcher currently resets pages by replacing their component values.
  Authoring reset also has delivery-scope, editor, request, and native ingress
  semantics. Root-level `reset(app, ...)` cannot simply be applied to one child
  page: that could reset the entire launcher or discard unrelated queued work.
- `FormState` sets accessibility hints and manually handles editor/clipboard
  behavior. The new declarations must preserve that behavior before replacing
  the form's entrypoint; fewer lines alone are insufficient evidence.
- Catalog source excerpts are stored in `DemoEntry`; some accompanying prose
  assumes every page teaches `build`. The current catalog checker only matches
  flat `examples/*.mojo` paths and hard-codes tasks. Adding nested authoring
  examples requires checking their real paths and runnable tasks too.

**Gate:** prove one authoring counter mounted inside the unchanged launcher,
then one editable form. Check routing, clipping, focus, clipboard, selection,
page switching, and page-local reset. If the existing contracts cannot express
safe child lifetimes, record and implement the smallest necessary runtime
change as a separate reviewed slice before migrating more pages. Do not use
private `HandlerHost._reset` calls in examples or call whole-App reset to fake
a page-local operation.

## Example-by-example decisions

Paths below are relative to `examples/`. Grouped paths share the same decision;
every current top-level Mojo example is accounted for.

### Application authoring: convert or expose prominently

- `counter.mojo`: make the ordinary fields/methods authoring counter the default
  Counter lesson, both standalone and in the launcher. Reuse the model from
  `authoring/counter.mojo`; retain `CounterState` for lifecycle examples and
  existing public consumers. Add functionality to the shared model only if
  needed to preserve the existing Counter lesson's actions.
- `form.mojo`: migrate to a named form model with string fields and methods,
  hosted by `HandlerHost`, once the editable-page gate passes. Preserve submit
  count, labels/hints, keyboard activation, clipboard, selection, and IME.
  Compare visual presentation and explicitly review any changed layout. If
  a required accessibility or presentation capability is missing, keep the
  existing form until a narrowly scoped API addition is justified; do not
  silently simplify away behavior.
- `authoring/counter.mojo`, `authoring/editors.mojo`, `authoring/shared.mojo`,
  `authoring/workspace.mojo`: retain the new style and expose the four lessons
  through the launcher. Counter is the same lesson as the migrated default,
  not a duplicate catalog entry. The others teach keyed children, shared
  context, and a larger application respectively. Preserve the current domain
  methods and iterator-based group actions; avoid index-driven mutation where
  iteration already expresses the operation.
- `authoring/window.mojo`, `authoring/workspace_window.mojo`: keep thin native
  hosts. `authoring/check.mojo`, `authoring/workspace_check.mojo`, and
  `authoring/draft_revert_check.mojo` remain headless checks, not catalog pages.
  `authoring/run.py` remains the quick route through all authoring lessons.

### Preserve explicit components because they teach a mechanism

- `hello_component.mojo`: retain as the minimal `Component` lifecycle lesson;
  label it lower-level and link beginners first to the authoring Counter.
- `hello_window.mojo`: retain its explicit native host and view/layout setup;
  present it as the window/component boundary, not the recommended shortest
  application. Its wrapping and intrinsic sizing are part of the example.
- `composed.mojo`: retain typed slots and localized execution. It demonstrates
  a runtime/composition mechanism distinct from authoring `Pane`/`Keyed`.
  Cross-link the Editors lesson rather than rewriting away the subject.
- `nested.mojo`, `row.mojo`, `alignment.mojo`, `wrapped_text.mojo`: retain the
  explicit container/layout APIs they teach. Clarify that `nested` means nested
  layout containers, not the recommended application-model composition pattern.
- `wx_style.mojo`, `theme_showcase.mojo`, `interaction_showcase.mojo`: retain
  lower-level widget, style, and interaction coverage. Explain the broader
  control surface rather than hiding it behind a partial authoring facade.
- `animation.mojo`: retain frame ticks, invalidation, and progress rendering.
  Do not disguise animation scheduling as a button-handler example.
- `capability_bus.mojo`: retain typed capability requests and trusted approval
  routing as the lesson. Cross-link authoring methods where helpful without
  bypassing the authorization boundary.

### Preserve specialized rendering, host, and acceptance examples

- `plot.mojo`, `plot_gallery.mojo`, `plot_svg.mojo`, `canvas_scene.mojo`: retain
  their plotting/scene/export APIs, including headless entrypoints.
- `interactive_fractal.mojo`: retain the interactive scene/component contract.
- `metal_scene.mojo`, `metal_window.mojo`, `metal_wavetable_window.mojo`: retain
  scene and Metal host paths, frame scheduling, and pointer handling.
- `coretext.mojo`, `harfbuzz.mojo`: retain shaping/backend probes; they are not
  application-authoring tutorials.
- `layout_workbench.mojo`, `layout_workbench_linux.mojo`,
  `native_layout_workbench.mojo`: retain platform adapters and the shared
  acceptance scenario. `paragraph_layout.mojo` and
  `paragraph_layout_policy.mojo` retain the custom layout-policy contract.
- `editable_showcase.mojo` and `live_script_demo.mojo`: retain the explicit
  reloadable component ABI and its headless probe. Do not couple this migration
  to a new authoring hot-reload system.
- `demo_browser.mojo`, `demo_walkthrough.mojo`: retain the central host and its
  deterministic automation entrypoint. Their models and catalog change only
  as needed to host and describe the selected lessons.

### Larger applications: retain now, assess a bounded mixed approach later

- `data_workbench.mojo` and `src/moxi_demo/data_workbench.mojo`: retain the
  existing component, plotting, file/data, and paint-cache paths. After basic
  authoring pages work in the launcher, assess one independently editable
  settings/form region as a possible authoring child. Proceed only if the
  boundary reduces author code without duplicating state or degrading linked
  selection, layout, rendering, or update cost. Whole-app conversion is not a
  prerequisite for completing this plan.
- `fdg/src/main.mojo`, `fdg/src/graph_app.mojo`, and the remaining `fdg/` module:
  retain graph simulation, scene rendering, I/O, save-panel, and Python entry
  paths. An authoring inspector is only a later candidate after the same child
  boundary works elsewhere. Keep graph-specific tests and benchmarks intact.
- The Marko translator under `experiments/tags-authoring/` already targets the
  authoring API. Keep it an experiment; no new language-facing work is needed
  for the example migration.

## Ordered implementation slices

1. **Baseline and embedded Counter.** Start an implementation branch from
   current `main`, not this planning branch. Capture launcher selection/reset
   behavior and relevant existing tests. Mount a shared authoring Counter via
   a typed slot; preserve `counter-demo` and central-launcher commands. Prove
   stable, namespaced IDs and action routing. Keep low-level Counter fixtures
   available. Commit the integration and focused regression tests together.
2. **Editable-page and lifetime gate.** Migrate Form only after standalone and
   embedded editing have parity. Explicitly preserve the existing page-state
   persistence policy on selection changes. Reset affects only the selected
   page: old captured actions and queued input cannot change its replacement,
   while launcher search, selection, other page state, and window lifecycle
   continue to work. Requests created by a page must not outlive its intended
   lifetime; test this before claiming nested request support. Record any
   runtime/API gap separately with a reproducer and focused fix.
3. **Expose the remaining authoring lessons.** Add Editors, Shared, and Workspace
   to the existing catalog and source/demo views. Use one model implementation
   for each standalone and embedded lesson. Make model code importable through
   the demo/example build paths without copying it or exporting examples as
   new production API. Add thin runnable commands where needed. Update the
   catalog checker to cover nested source paths and the actual registered
   tasks. Keep the same single-window mounting and native event path.
4. **Clarify the learning path.** In overview text, source excerpts, docs, and
   example descriptions, distinguish application authoring, component/layout
   mechanics, and rendering/backend examples. Keep domain filters useful;
   architecture labels supplement them. If a style field is needed in code,
   use a named finite type rather than repeated string policy values. Show
   `render` plus methods for authoring pages and `build`/routing where that is
   the lesson; retain the host snippet separately. Link each lower-level
   lesson to the closest authoring lesson without labeling supported APIs
   obsolete. Update README and `docs/demo-browser.md` to match delivered scope.
5. **Assess larger applications and close.** Inspect one Data Workbench region
   for a useful mixed-style boundary, record the decision, and stop if it adds
   ceremony or loses capabilities. Do not force a graph-app conversion. Run
   integration checks, review the actual launcher UI, and reconcile this plan
   with the resulting commits. Rebase onto current `main`; do not merge the
   orphan planning history into implementation.

## Completion evidence

- Counter and, subject to the parity gate, Form use ordinary fields and
  methods in both standalone and embedded paths. All four existing authoring
  lessons are reachable through the central launcher. Every retained example
  has a clear teaching purpose and an accurate source/task reference.
- Tests cover embedded routing and cross-page isolation, selection away/back,
  reset, stale callbacks/input, text/IME and clipboard, focus, scrolling and
  resize. Include a copied or replaced owner case when exercising captured
  actions. A test that only constructs `HandlerHost` is insufficient.
- Run `python3 examples/authoring/run.py`, `pixi run demo-catalog-check`, the
  affected `tests/demo_browser.mojo` checks, and the relevant native authoring
  tests/builds. Run `pixi run --locked check` once the complete slice is ready.
  Validate graph, hot-reload, layout, or plotting checks when their integration
  paths change; do not rerun unrelated benchmarks after prose-only changes.
- Manually inspect the real launcher: search, tabs, code readability, live
  interactions, resize, keyboard traversal, accessibility names/hints, page
  switching, and reset. Exercise the existing deterministic walkthrough after
  adapting its targets to the new model. Preserve real canvas pages and the
  CapabilityBus approval boundary. Record screenshots or a walkthrough when
  useful and record any unavailable native/manual checks explicitly.
- For a proposed large-app region conversion, compare identical actions and
  state before/after, model/adapter code length, duplicate state, declaration
  and paint work, and local update timings. Do not infer speed from fewer
  source lines. Human readability feedback is separate from mechanical parity.
- Review commits for destination-appropriate content, commit and push in
  coherent slices under the standing authorization, and check CI after the
  latest implementation push before calling the migration verified.

## Original confidence and verification limits

High confidence in preserving the launcher and in retaining specialized
lower-level examples: the current code establishes both needs. Moderate
confidence in the Counter/Form migration sequence: `HandlerHost` has the right
component shape, but embedded reset, request ownership, native editing, and
accessibility parity need execution evidence. Failure of those gates would
delay a page conversion or justify a small explicit integration change, not
justify dropping behavior. Large-app conversion remains a conditional idea.

This planning pass inspected source, module descriptions, catalog/task wiring,
the authoring declaration surface, and existing documentation. No builds,
runtime tests, GUI checks, performance measurements, or CI runs were performed
for the plan. Earlier production validation remains historical evidence, not
validation of these proposed migrations.


## November 5 implementation reconciliation

The implementation branch starts from `main` at `ba8fc93` and contains these
local commits; none has been pushed:

- `122d13c`: public embedded model reset, with retired actions, controls,
  delivery scopes, and owned requests tested independently of sibling work.
- `e9d6130`: shared Counter model mounted through `ComponentSlot[HandlerHost]`.
- `777ed3c`: authoring editor hints and disjoint ID strides for embedded hosts.
- `529f479`: shared Editors, Shared document, and Workspace models with thin
  standalone runners.
- `fa42b6f`: authoring Form, the three additional Playground pages, deferred
  native-batch resets, clipboard/event forwarding, responsive previews,
  catalog/source updates, regression tests, and the revised learning path.

The fetched `origin/main` remained `ba8fc93` on November 5 and is an ancestor
of the implementation head; no rebase was necessary. Planning history stays
separate from implementation.

### Delivered scope and decisions

The Counter and Form gate passed local behavior checks. All five authoring
pages share their model implementation with standalone examples and preserve
state across navigation. Reset replaces the selected model after the native
input batch drains, retaining unrelated navigation, resize, and ready results.
Monotonic IDs in disjoint residue classes prevent old controls from addressing
another embedded host after repeated reset or child replacement.

Form retains its name/hint, submission count, Unicode editor, selection,
clipboard, composition, and keyboard activation. Its visible presentation
intentionally adopts the authoring column's 16-pixel padding and standard
control heights. Native-rendered fixtures were inspected at 1180 and 900 pixels;
the narrow layout stacks source below the preview, and Workspace uses the outer
portal without an additional clipped scrollbar.

The existing launcher, specialized pages, lower-level public components, and
fixtures remain. Data Workbench's toolbar/filter/import region was inspected
and left unchanged: its parsing, filtering, table reset, plot refresh, clipboard,
and compact row layout would require a new adapter without a simpler ownership
boundary. The graph app also remains unchanged. These are completed assessment
decisions, not unfinished conversions.

Embedded asynchronous completion delivery is **not** claimed. Host reconciliation
retires stale owned requests, but the current target-based page route does not
route live task results by owner. The migrated lessons schedule no requests.
Adding asynchronous work to a lesson requires an explicit completion route that
works independently of focused or visible controls. See the implemented
[embedding contract](https://github.com/davidmashburn/moxi/blob/fa42b6f/docs/authoring/application-guide.md#mounting-a-model-inside-a-component-application).

### Validation and remaining acceptance

The shared example runners/checks and standalone Form/Playground builds pass
locally. The complete `pixi run check` suite passed on the final implementation
sources with a clean implementation checkout. This includes catalog/API checks,
portable/headless tests, embedded editing/layout regressions, scenario mapping,
the deterministic walkthrough, native screenshot tolerances, authoring lifecycle
and page-lifetime probes, package builds, and live reload. The native page probe
covers queued reset/text/composition/click ordering, retired accessibility
callbacks, navigation/resize preservation, and unrelated ready results.
The run emitted existing `as_c_string_slice` deprecation warnings.

The new tests are
[embedded authoring](https://github.com/davidmashburn/moxi/blob/fa42b6f/tests/demo_authoring.mojo)
and [native page lifetimes](https://github.com/davidmashburn/moxi/blob/fa42b6f/tests/native_demo_authoring.mojo).
The retained lower-level examples and Workbench decision are documented in the
[lesson guide](https://github.com/davidmashburn/moxi/blob/fa42b6f/examples/authoring/README.md).

Computer-use attachment to the launched native window failed with
`cgWindowNotFound`. Offscreen AppKit rendering and injected native queue probes
provide useful evidence but do not replace interactive launcher acceptance,
physical IME, or VoiceOver checks. No performance study, graph benchmark rerun,
human readability evaluation, push, or CI verification was performed. Publication
and CI are outside the current local-commit request.

Confidence is high in the locally tested model, routing, and reset behavior;
manual accessibility/input acceptance remains unverified. A failing real IME,
VoiceOver, or launcher navigation/reset session would change that assessment
and should be resolved before calling the migration fully verified.
