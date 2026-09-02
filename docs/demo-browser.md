# Moxi Playground

`pixi run demo` (or its explicit `pixi run demo-browser` alias) opens the
wxPython-inspired browser for the checked-in Moxi examples. It is a small
learning workbench: the catalog stays visible while the selected example gets
its own overview, source, and live/demo surface.

The window is organized like this:

- the left playground rail groups runnable examples by domain, shows a short
  description for each entry, and filters by name, description, source path,
  or Pixi task;
- the right side provides `Overview`, `Source`, and `Demo` tabs;
- `Run live page` mounts the selected `Component` page in-process, preserving
  the same event, focus, clipboard, and component-slot contracts as its
  standalone example;
- ordinary live-component pages use a Storybook-style `Demo` surface: the
  mounted `LIVE PREVIEW` sits beside a `COMPONENT USAGE` code panel showing
  the snippet that constructs and mounts that component;
- scene and plotting pages declare a real `Canvas` node in that component;
  the host renders the component's `Scene` into that node in the same window;
- `Editable Live Component` is a development page whose Mojo component is
  rebuilt and swapped into that existing canvas when its source file changes;
- standalone Pixi tasks remain available as companion commands, but the
  browser does not replace a page with a fake preview or a sibling window.

## Interaction model

Use `Find an example` to search the full catalog. Expand or collapse `Browse
examples` to give the catalog more or less room while exploring. The catalog
is a clipped, wheel-scrollable portal, and the selected-example content pane
uses the same scrolling behavior for long source and demo pages. The `Clear`
button and the `Escape` key clear only the text query, preserving the selected
area filter.
Standalone and embedded component views inherit the same policy from their
root or linear slot, so content that exceeds its allocated box remains
reachable without a page-specific scroll wrapper.
Scrollable panes keep a static track and thumb visible while their content
overflows. On macOS, wheel direction follows the system Natural scrolling
setting while the portable event model remains unchanged.
When no entry matches, the detail pane switches to an explicit empty state so
stale selection details are never mistaken for a result. `Reset` is enabled
only for live in-browser components; standalone tasks remain the source of
truth for their own state.

The browser teaches the boundary between Moxi's declarative component tree and
the host: `Overview` explains the contract, `Source` shows a deterministic
excerpt and command, and `Demo` mounts the component. Every entry points to a
real `examples/` file and a checked-in Pixi task;
`scripts/demo_catalog_check.sh` verifies both sides of that contract.

## Editable source and hot reload

`examples/editable_showcase.mojo` is the first explicitly reloadable script.
It defines an ordinary `EditableShowcase(Component)` and exports this small
development ABI:

```mojo
@export
def moxi_live_frame(x, y, width, height) abi("C") -> Int32:
    ...
```

When `pixi run demo` has that page selected, the macOS host watches the source
mtime. Saving the file runs `mojo build --emit shared-lib`, loads the new
module, and calls the exported frame function into the existing component-owned
canvas. The old module remains active if the rebuild fails, so a syntax error
does not blank the window. The retained Moxi view tree still owns layout,
events, focus, and accessibility; the reloadable module contributes the scene
inside its declared canvas.

This is an explicit opt-in ABI, not arbitrary runtime reflection. The Source
tab remains a read-only, deterministic excerpt; edit the checked-in file in
your editor and save it. The native integration contract can be exercised
without a GUI with `pixi run live-reload-check`.

## Catalog coverage

The initial catalog covers the current repository scope:

- getting started: the minimal window and component lifecycle;
- components and input: counter, form, nested, composed, wx-style,
  interaction lab, and editable live-component pages;
- layout and runtime: row, alignment, wrapped text, animation, and
  invalidation;
- interaction state: the live interaction lab combines stable-key table
  selection/reorder, tree disclosure, scrollbar geometry, and nested
  menu/modal popup layers;
- plotting: the portable scene, declarative gallery, and SVG export;
- rendering: offscreen Metal and the visible Metal window;
- text: CoreText and optional HarfBuzz shaping.

The catalog source of truth is [demo_browser.mojo](../src/moxi/demo_browser.mojo),
while reusable page implementations live in `src/moxi` and the opted-in
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
pages in-process. The editable page adds a real source-watch/build/load loop
for an explicit ABI; a full in-browser source editor and modified-source
persistence remain follow-up work.
