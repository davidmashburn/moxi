# Moxi Playground

`pixi run demo` (or its explicit `pixi run demo-browser` alias) opens the
wxPython-inspired browser for the checked-in Moxi examples. It is a small
learning workbench: the catalog stays visible while the selected example gets
its own overview, source, and live/demo surface.

The manual `demo` and `demo-browser` build tasks reuse their executable when
their Mojo sources, native object, build command, and Pixi environment are
unchanged. Native compilation also tracks the host source, headers, and include
files. Changed inputs or missing outputs trigger a rebuild; the launch task
still runs every time. The first build after an edit can therefore take longer
than reopening an unchanged demo. After changing Xcode or the system SDK, remove
`native/macos_window.o`, `dist/moxi-demo`, and `dist/moxi-demo-browser` to force
fresh builds with the new system toolchain.

`data-workbench` also caches its executable and signed application bundle;
changes to its sources, packaging scripts, or bundle metadata rebuild it, as do
missing bundle files. Formula Editor's separate math build has its own content
cache, including HarfBuzz and toolchain inputs; see [the math editor guide](math-editor.md).

`pixi run demo-walkthrough` runs the exact same `examples/demo_browser.mojo`
host with a deterministic CapabilityBus event source. On macOS it launches the
walkthrough executable through a stable `Moxi Playground.app` bundle, so the
application and its native accessibility tree are discoverable by desktop
automation. It traverses the normal catalog and mounted components through
their ordinary event path, demonstrating the live Counter, Plot Gallery,
embedded Metal Scene, scrolling, selection, reorder, and approval-gated reset
without opening a second window. `pixi run demo` remains the manual-input
version of that host.

`pixi run demo-catalog-walkthrough` is a separate bus-driven sweep over every
`DemoCatalog` entry. It selects each item in the same window, showing the live
preview for embedded examples and the launch instructions for standalone entries.
It also increments Counter, toggles and streams Plot Gallery, and scrolls,
selects, and reorders the Interaction Lab; the curated walkthrough
remains the focused approval lesson.

`pixi run demo-record` runs that same walkthrough without agent or GUI
automation. It builds an isolated temporary app bundle, discovers the live
Playground window bounds, records a 30-second region capture, validates the
resulting H.264/60fps MOV, and cleans up its own process. Pass an output path as
the first argument or set `MOXI_RECORD_SECONDS` to override the defaults.

`pixi run demo-catalog-record` uses the same recorder for the full catalog
sweep. Its default 55-second capture leaves time for the completion status;
pass an output path or set `MOXI_RECORD_SECONDS` to change the capture.

For a non-GUI host gate, run `pixi run browser-check`. It starts a local
ephemeral-port server for `native/web/host_demo.html`, verifies the explicit
readiness and Canvas markers, replays normalized pointer/wheel input through
`MoxiWebHost`, checks the optional ARIA layer, and always tears down the server
and host. A real browser can inspect the same page's
`window.__MOXI_HOST_READY__` and `window.__MOXI_HOST_STATE__` markers.

The browser's implementation keeps catalog classification and search in
`moxi_demo.catalog_types`, entry metadata in `demo_entry`, and component mode
routing in `showcase`. Presentation helpers in `demo_style` depend only on core
controls and semantic dark-theme tokens. Each browser owns one catalog inventory
throughout its lifetime, so rendering and filtering reuse the same metadata. The
`moxi_demo` package continues to export the catalog IDs and category names for
consumers.

Typed previews use `ComponentSlot.mount(parent, parent_id, bounds, height)` to
build and embed with the slot's own identity and namespace. Child measurement
uses the available pane width after split spacing and padding.

Demos share `Event.is_activation()` for click, Enter/Space, and accessibility
press handling; each component still validates its routed target. Width-aware
body labels use core `LabelControl.wrapped_node(available_width)`, which combines
wrapping and intrinsic height while preserving normal theme inheritance and
explicit-style overrides. Callers supply the current measurement width when
rebuilding after a resize.

The window is organized like this:

- the catalog groups example names by area. Search matches names, descriptions,
  source paths, and Pixi tasks. Open the area selector to narrow the list;
- selecting an in-process example opens its live component immediately. The
  Playground starts on Hello Window, where resizing changes the displayed bounds.
  Hello Component mounts two instances of the same greeting. Counter and Form
  retain their state when you browse away and return;
- the Overview tab gives the lesson summary, command, and source path. The
  Source tab shows the excerpt. In ordinary live examples the preview sits
  alongside its source at wide window sizes and above it at narrow sizes;
- scene and plotting pages declare a real `Canvas` node in that component;
  the host renders the component's `Scene` into that node in the same window;
- `Editable Live Component` is a development page whose scene source is
  edited and explicitly rebuilt into that existing canvas with Run;
- `Capability Bus Walkthrough` is a ten-step live component whose navigation,
  typed handler execution, agent request, and trusted approval all cross the
  same in-process `CapabilityBus` boundary;
- **Formula Editor** (under **Text**) opens a separate native window with
  **Open workbench**. The direct command is `pixi run formula-editor-demo`.
  It uses HarfBuzz and the bundled math font. See the [math editor guide](math-editor.md)
  for prerequisites and the optional SymPy setup.

## Interaction model & responsive layout

Use `Find an example` to search the full catalog. Expand or collapse `Examples`
to give the catalog more or less room while exploring. The catalog
is a clipped, wheel-scrollable portal, and the selected-example content pane
uses the same scrolling behavior for long source and demo pages. The `Clear`
button and the `Escape` key clear only the text query, preserving the selected
area filter.
Standalone and embedded component views inherit the same policy from their
root or linear slot, so content that exceeds its allocated box remains
reachable without a page-specific scroll wrapper.
Scrollable panes keep a visible track and thumb while their content overflows;
the shared event path supports wheel scrolling, track paging, and thumb
dragging. On macOS, wheel direction follows the system Natural scrolling
setting while the portable event model remains unchanged.
When no entry matches, the detail pane switches to an explicit empty state so
stale selection details are never mistaken for a result. The Demo tab offers
Reset on stateful in-process examples. The editable lesson has Run and Revert,
and standalone workbenches have their own launch action.

For details on how window resizing, geometry invalidation, and declarative reflow
function under the hood, see the [Responsive layout guide](responsive-layout.md).

The browser teaches the boundary between Moxi's declarative component tree and
the host: `Overview` explains the contract, `Source` shows a deterministic
excerpt and command, and `Demo` mounts the component. Every entry points to a
checked-in source and a runnable Pixi task;
`scripts/demo_catalog_check.sh` verifies both sides of that contract.

Counter, Form, Editors, Shared, and Workspace teach ordinary model fields,
methods, and pure `render`. Their shared models live in
`src/moxi_demo/authoring_examples/`; the standalone entrypoints import those
same models. Playground mounts them in `ComponentSlot[HandlerHost[...]]` and
retains each model while navigating. Reset replaces only the selected model
after the current native input batch finishes. Workspace's nested form remains
reachable through the content portal. See the
[authoring lessons](../examples/authoring/README.md) for the learning sequence,
reset contract, and retained lower-level examples.

The [Not implemented pattern](not-implemented-pattern.md) page demonstrates two
independent inert informational components, working surrounding controls, and
host-owned replacement by an implemented counter. It is a runnable lesson about
composition, not a substitute catalog entry for another unfinished feature.

## Editable scene source

`Editable Live Component` is one complete editable example. Its Source and Demo
tabs share the full `examples/editable_showcase.mojo` draft. The native multiline
editor supports selection, scrolling, clipboard operations, and undo. Click
`Run` (or Command/Control+Enter) to compile a snapshot in a private temporary
directory. Editing, tabs, and catalog navigation remain available during the
asynchronous build. A changed draft is identified separately from the running
snapshot. `Revert` restores the original source and rebuilds it; neither action
writes the example file. Drafts last only for the current browser session.

The example defines an ordinary `EditableShowcase(Component)` and exports:

```mojo
@export
def moxi_live_frame(x, y, width, height) abi("C") -> Int32:
    ...
```

A successful build replaces the scene in the existing component-owned canvas.
Compiler diagnostics appear below the editor, with file/line locations. Compiler
and missing-export failures retain the last successful scene. Only this explicit
scene ABI is reloaded: the browser's retained shell still owns layout, focus,
events, and accessibility, so editing `build()` does not replace shell widgets.
Run the browser from the repository with `pixi run demo` so the source, compiler,
and imports are available. Other examples retain their existing Source excerpts.

`pixi run live-editor-check` exercises the browser's draft/run/revert path with
the real compiler, including failure retention, edits during compilation, shared
tab drafts, and catalog state. `pixi run live-reload-check` continues to cover
the lower-level saved-file reload contract.

## Catalog coverage

The initial catalog covers the current repository scope:

- getting started: the minimal window and component lifecycle;
- components and input: counter, form, nested, composed, wx-style,
  interaction lab, capability-bus walkthrough, and editable live-component
  pages;
- layout and runtime: row, alignment, wrapped text, animation, and
  invalidation;
- interaction state: the live interaction lab combines stable-key table
  selection/reorder, tree disclosure, scrollbar geometry, and nested
  menu/modal popup layers;
- plotting: the portable scene, declarative gallery, and SVG export;
- rendering: offscreen Metal and the visible Metal window;
- text: CoreText and optional HarfBuzz shaping.

The catalog source of truth is [demo_entry.mojo](../src/moxi_demo/demo_entry.mojo)
(`DemoEntry`/`DemoCatalog`), with catalog-classification constants and
formatting helpers in [demo_style.mojo](../src/moxi_demo/demo_style.mojo) and
the browser component itself in
[demo_browser.mojo](../src/moxi_demo/demo_browser.mojo). Reusable page
implementations live in `src/moxi` and the opted-in
editable implementation lives in `examples/editable_showcase.mojo`. The
browser's own behavior is covered by
[tests/demo_browser.mojo](../tests/demo_browser.mojo), while the standalone
scripts remain independently runnable through the tasks listed in
[pixi.toml](../pixi.toml).

## wxPython relationship

The structure follows the actual wxPython Phoenix demo browser: a searchable
sample tree, a selected-sample work area, separate overview/source/demo
surfaces, and a distinction between the browser shell and the sample being
run. Moxi maps those ideas to its value-based component model, mounting typed
pages in-process. The editable page adds a session-local source editor and asynchronous
build/load loop for an explicit scene ABI. Persisting modified drafts remains
follow-up work.
