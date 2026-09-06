# Modular/Mojo Ecosystem Research

Research captured September 6, 2026, for Moxi project planning. The sources
below are first-party Modular forum posts, official Modular articles, or the
project repositories linked from those sources.

## Executive summary

Moxi occupies a relatively distinct position in the Mojo ecosystem: a
retained, backend-neutral view tree with typed components, native rendering,
headless tests, plots, Metal examples, and capability-bus-driven interaction.
The closest projects generally focus on one layer: immediate-mode HTML UI,
terminal UI, native toolkit bindings, 2D rendering, or GPU bindings.

The main opportunity is not to copy another toolkit. It is to make Moxi a
particularly good teaching and experimentation layer over Mojo’s compute and
graphics capabilities.

## Reconciliation with the audited implementation

The recommendations at the end of this research are evidence inputs, not a
second roadmap. Checked against `main` at `bd3722c`, their status is:

| Recommendation | Status in code | Planning treatment |
| --- | --- | --- |
| First-class themes and component overrides | Implemented: semantic tokens, four presets, recipes, theme showcase, tests, and component theme preservation | Protect with a public support classification and deterministic visual baselines. |
| Progressive source-connected walkthroughs | Substantially implemented in the Playground, component source panes, editable component, and capability walkthrough | Move reusable scenario metadata out of browser-specific constants. |
| Backend-neutral scene with incremental adapters | Implemented for software, SVG, AppKit, and a substantial Metal slice | Build a shared parity corpus before adding Cairo, wgpu, or more GPU breadth. |
| GPU-backed visualization | Implemented through the interactive fractal and dense plot packet paths | Treat these as canonical Mojo compute-to-visual scenarios and benchmark them repeatably. |
| Property and fuzz coverage | Deterministic property-style edge tests exist; mutation fuzzing and shrinking do not | Add replayable properties first, then pilot `mozz` when failures can become checked-in minimal cases. |
| Stable Mojo 1.x public surfaces | Not resolved: stable 0.5 and post-0.5 experimental names share a very large root export surface | Make API classification and compatibility policy the first planning gate. |

The active decisions and acceptance checks live in
[PROJECT-PLANNING.md](../PROJECT-PLANNING.md). This research remains the source
record for ecosystem context.

## Agentic engineering

### Primary references

- [How I built a pure Mojo app and 10 libraries with AI agents](https://www.modular.com/blog/how-i-built-a-pure-mojo-app-and-10-libraries-with-ai-agents)
- [mozz: mutation and property-based testing for Mojo](https://github.com/ehsanmok/mozz)
- [Translating to Mojo via AI Agents](https://www.modular.com/blog/translating-to-mojo-via-ai-agents)
- [Three trends from MLSys 2026](https://www.modular.com/blog/three-trends-from-mlsys-2026)
- [Modular Mojo agent skills](https://github.com/modular/skills)

The recurring workflow is human-led architecture and API taste, followed by
agent-led implementation of boilerplate, tests, documentation, and repetitive
cross-repository maintenance. The human remains responsible for design,
tradeoffs, review, and validation.

`mozz` provides two especially relevant testing ideas: mutation fuzzing for
inputs that must not crash, and property-based testing with automatic shrinking
to a minimal failing case.

### Implications for Moxi

- Fuzz layout invariants, hit testing, pointer sequences, scroll bounds,
  capability-bus routing, and deterministic recording inputs.
- Keep humans responsible for the component API, rendering model, and demo
  narrative; let agents generate repetitive test matrices and adapters.
- Standardize project structure, test commands, and demo commands so an agent
  can validate changes consistently.
- Make every demo a copyable, runnable example rather than hiding its behavior
  behind constants or showcase-only helpers.

## Related Mojo UI projects

- [ui-terminal-mojo forum thread](https://forum.modular.com/t/ui-terminal-mojo/1371)
- [ui-terminal-mojo repository](https://github.com/rd4com/ui-terminal-mojo)

  A pure POSIX terminal UI using linear measurement, a flat list, cursor-relative
  layout, and event handling without callbacks. Its progressive walkthrough and
  simple interaction model are useful references for Moxi’s teaching demos.

- [mojo-ui-html forum thread](https://forum.modular.com/t/mojo-ui-html-immediate-mode-gui/196)
- [mojo-ui-html repository](https://github.com/rd4com/mojo-ui-html)

  An immediate-mode HTML/CSS UI driven by a simple event loop. Its base CSS
  theme plus per-instance style overrides are a useful model for making Moxi
  themes extensible while retaining semantic tokens.

- [CombustUI / FLTK bindings](https://forum.modular.com/t/combustui-gui-bindings-for-mojo/573)

  A native toolkit-binding approach with basic widgets, event handling, and
  later flex-layout work. It demonstrates the value and cost of putting the
  widget model in an external toolkit.

- [Mojo-GTK autogenerated bindings](https://forum.modular.com/t/mojo-gtk-autogenerated-gtk-bindings-for-mojo/2581)

  Generated bindings expose broad native widget coverage and several demos,
  while the discussion shows the practical linker and platform-path problems
  that accompany toolkit wrappers.

- [Mojo GUI lessons learned](https://forum.modular.com/t/while-making-a-mojo-gui-ui-lessons-learned/1539)
- [Another Mojo GUI using C for rendering](https://forum.modular.com/t/a-mojo-gui-ui-c-calls-for-rending-everything-else-in-mojo-as-ffi-is-still-not-functional-in-mojo/1573)

  These projects reinforce a conservative FFI boundary: pass simple scalar
  values, keep complex state on one side, and avoid exposing arrays or complex
  structs directly across C interfaces.

- [MojoFlow declarative UI/full-stack framework](https://forum.modular.com/t/introducing-mojoflow-ai-native-full-stack-framework-for-mojo/2956)

  An early all-Mojo framework combining declarative UI, backend APIs, agent
  workflows, and CLI tooling. It is adjacent conceptually, but not a direct
  rendering competitor.

## Graphics and visualization projects

- [Graphics library discussion](https://forum.modular.com/t/graphics-library-for-mojo/1666)

  The practical near-term direction discussed is interoperability with existing
  graphics stacks; a fully native cross-vendor graphics layer would be a much
  larger commitment.

- [Cairo-mojo](https://forum.modular.com/t/cairo-mojo-cairo-bindings-high-level-2d-rendering-api-for-mojo/2990)

  A high-level Cairo API that can target vector graphics and SVG/PNG/PDF-style
  output. It could inform a future export renderer for Moxi’s scene IR.

- [wgpu-mojo](https://forum.modular.com/t/wgpu-mojo-wgpu-native-bindings/2957)

  wgpu-native bindings demonstrate a portable GPU rendering path, beginning
  with a triangle and compute example. This is a possible future backend for a
  Moxi scene or paint stream.

- [canvas_mojo and dataviz_mojo](https://forum.modular.com/t/data-visualization-in-pure-mojo-canvas-mojo-and-dataviz-mojo/3434)
- [canvas_mojo repository](https://github.com/randyzwitch/canvas_mojo)
- [dataviz_mojo repository](https://github.com/randyzwitch/dataviz_mojo)

  These projects split low-level drawing from a grammar-of-graphics plotting
  layer with many quickplot functions. They suggest future Moxi plot demos for
  richer chart composition, geospatial visualization, and export.

- [Apple Silicon GPU support in Mojo](https://forum.modular.com/t/apple-silicon-gpu-support-in-mojo/2295)

  Mojo’s Apple GPU support is progressing through Metal/AIR compilation and a
  `MetalDeviceContext`. It is a strong reason for Moxi to keep GPU demos
  separate from the platform-neutral UI core.

## Official Modular direction

- [Modular 26.5: Mojo 1.0 is here](https://www.modular.com/blog/modular-26-5-mojo-1-0-is-here)
- [The path to Mojo 1.0](https://www.modular.com/blog/the-path-to-mojo-1-0)

  Mojo 1.0 establishes a stability and ecosystem-interoperability target. Moxi
  should distinguish stable public APIs from experimental renderer and host
  integrations, and use semantic versioning deliberately.

- [Modular 25.7: safer GPU programming and Apple GPU support](https://www.modular.com/blog/modular-25-7-faster-inference-safer-gpu-programming-and-a-more-unified-developer-experience)

  The emphasis on type checking, clearer diagnostics, sanitizers, and testing
  aligns with Moxi’s headless command-stream tests and should extend to fuzzing
  and interaction-property tests.

- [What’s new in Mojo 24.2](https://www.modular.com/blog/whats-new-in-mojo-24-2-mojo-nightly-enhanced-python-interop-oss-stdlib-and-more)

  The example-driven, copy/pasteable presentation style is a good model for
  Moxi’s source panels and walkthroughs. Python interoperability also provides
  a path for demos that compare pure Mojo rendering with Python plotting or
  data preparation.

- [Mojo is finally here](https://www.modular.com/blog/mojo-its-finally-here)

  Modular’s original positioning emphasizes progressive adoption: familiar
  Python-like code first, with systems-level and accelerator features added as
  needed.

- [Modverse #48](https://www.modular.com/blog/modverse-48)
- [Modverse #54](https://www.modular.com/blog/modverse-54-amd-ai-devday-new-modular-offices-and-a-community-that-keeps-shipping)

  These ecosystem roundups identify the surrounding activity: terminal UI,
  GPU renderers, wgpu, Cairo, raylib, FFmpeg, data visualization, and other
  Mojo libraries. Moxi should integrate with this ecosystem where useful rather
  than reimplement every adjacent capability.

## Original research recommendations

These are retained as the conclusions of the research pass. Their current
implementation status and active planning treatment are mapped above.

1. Make themes first-class context: semantic tokens, a base theme, and explicit
   per-component overrides. The recent embedded-surface fix is part of this
   boundary.
2. Add a progressive “build this component” walkthrough to each demo, with the
   live preview and actual source kept visibly connected.
3. Preserve the backend-neutral paint/scene IR and add adapters incrementally:
   native AppKit/Metal first, then export or portable GPU paths where they add
   real value.
4. Add a GPU-backed visualization demo—such as a live heatmap, particle field,
   or GPU-generated plot—so the UI showcases Mojo’s differentiator rather than
   only generic widgets.
5. Add property and fuzz coverage for layout, hit targets, event sequences,
   capability-bus dispatch, and recording reproducibility.
6. Stabilize the public `Component`, `Theme`, paint, and capability-bus APIs as
   Mojo 1.x-compatible surfaces while marking experimental backends clearly.
