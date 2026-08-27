# Moxi Project Plan

## First visible vertical slice

The first implementation proves one complete path through the library:

```text
Moxi view -> retained widget -> paint commands -> native window
```

### Core contract

* `View` is the declarative input and owns no platform handles.
* `Widget` is the retained runtime state with stable identity, bounds, and text.
* `Runtime` reconciles a view into a widget and asks the renderer to paint it.
* The renderer is an explicit backend boundary; the core must not depend on Cocoa,
  Metal, or a specific windowing API.

### First implementation

1. Add a minimal `View` trait and a concrete `Label` view.
2. Add a retained label widget with stable identity and rectangular bounds.
3. Add a small paint-command representation for a background and text label.
4. Add a native macOS demo executable that opens a window and displays
   “Hello from Moxi.”
5. Keep the package API and demo executable separate.

### Validation

* `pixi run build` produces the importable Mojo package.
* A package smoke test imports the public module and exercises reconciliation.
* A demo smoke test launches, presents a window, and exits cleanly.
* README commands and the implementation status describe only what is shipped.

### Explicit non-goals

GPU rendering, input routing, accessibility, text shaping, animation, threading,
serialization, and cross-platform backends are deferred until this vertical slice
has a stable contract and a visible acceptance test.
