# ADR-001: Keep Scene backend-neutral

Status: accepted for the convergence program.

## Decision

Moxi owns `Scene`, `SceneCommand`, and `SceneRenderer`. Backend packages,
including `canvas_mojo`, consume that contract through adapters. No canvas
struct, Metal handle, AppKit object, or SVG serializer type enters a scene
command or the stable plot model.

## Consequences

- the software renderer remains the deterministic oracle;
- one scene can be compared across software, SVG, canvas, and native paths;
- backend-specific gaps are reported as fallback/unsupported behavior;
- the scene contract may need typed paths, text styles, and resources, but
  those are Moxi-owned neutral values; and
- canvas can be replaced or made optional without changing `PlotSpec`.

