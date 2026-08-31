# Moxi demo browser

`pixi run demo` (or its explicit `pixi run demo-browser` alias) opens the
wxPython-inspired browser for the checked-in Moxi examples. The window is
organized like a small workbench:

- the left catalog groups runnable examples by domain and filters them by
  name, description, source path, or Pixi task;
- the right side provides `Overview`, `Source`, and `Demo` tabs;
- `Run in browser` mounts a stateful `Component` page in-process, preserving
  the same event, focus, clipboard, and component-slot contracts as its
  standalone example;
- `Run script` launches a scene, plotting, GPU, or text example's exact
  `pixi run …` task as a sibling process;
- the status line reports launch and exit status while the child inherits the
  browser's terminal output stream.

The browser never evaluates arbitrary command text. The catalog supplies a
task name, the browser emits a request for that name, and the macOS host
runner accepts only task-name characters before invoking `pixi run <task>`.
Only one sibling task is launched at a time. Moxi's core `App` contract still
owns one typed component; process launching remains an explicit macOS host
adapter rather than a hidden core-runtime side effect. Every entry points to a
real `examples/` file and a checked-in Pixi task;
`scripts/demo_catalog_check.sh` verifies both sides of that contract.

## Catalog coverage

The initial catalog covers the current repository scope:

- getting started: the minimal window and component lifecycle;
- components and input: counter, form, nested, composed, and wx-style pages;
- layout and runtime: row, alignment, wrapped text, animation, and
  invalidation;
- plotting: the portable scene, declarative gallery, and SVG export;
- rendering: offscreen Metal and the visible Metal window;
- text: CoreText and optional HarfBuzz shaping.

The source of truth is [demo_browser.mojo](../src/moxi/demo_browser.mojo), not
a second copy of the examples. The browser's own behavior is covered by
[tests/demo_browser.mojo](../tests/demo_browser.mojo), while the standalone
scripts remain independently runnable through the tasks listed in
[pixi.toml](../pixi.toml).

## wxPython relationship

The structure follows the actual wxPython Phoenix demo browser: a searchable
sample tree, a selected-sample work area, separate overview/source/demo
surfaces, and a distinction between the browser shell and the sample being
run. Moxi maps those ideas to its value-based component model, mounting typed
pages in-process and launching standalone tasks through the host adapter. The
full source editor, modified-source persistence, and arbitrary dynamic module
loading remain follow-up work; the current source tab gives a deterministic
excerpt and an operational path to the real checked-in file.
