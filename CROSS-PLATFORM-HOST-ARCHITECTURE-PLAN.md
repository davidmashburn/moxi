# Moxi cross-platform host and renderer architecture plan

Status: proposed architecture for independent review

Planning baseline: October 4, 2026

Implementation baseline: Moxi `main` at `e3be517` (`canvas_mojo` upstream
v0.42.0, released Mojo 1.1.0); native Linux hosting is not yet claimed.

This plan is intentionally independent of the active Linux implementation
thread. It defines the boundaries that implementation should satisfy rather
than prescribing one toolkit as Moxi's core.

## Product position

Moxi should be a Mojo-native cross-platform UI and visualization
framework/runtime with:

- a portable semantic view tree;
- a retained runtime for identity, layout, focus, hit testing, and
  accessibility;
- a backend-neutral frame/scene representation; and
- replaceable host and renderer adapters.

Moxi should not become a windowing library, a graphics API wrapper, or a Qt,
GTK, wxWidgets, SDL, or AppKit compatibility layer. Those systems belong below
Moxi's host boundary.

The most useful reference is Xilem's separation between a reactive view tree,
the retained Masonry element tree, the native `winit` backend, and the DOM
backend. Xilem's architecture documents are:

- <https://github.com/linebender/xilem/blob/main/xilem/ARCHITECTURE.md>
- <https://github.com/linebender/xilem/blob/main/masonry/ARCHITECTURE.md>
- <https://docs.rs/xilem_web/latest/xilem_web/>

## Core contract decisions

1. **Application state is the source of truth.** Components own durable
   application state. Retained nodes own only interaction and render state
   that must survive a rebuild. Native handles, GPU resources, task
   executors, and host objects remain outside declarative values.

2. **One semantic tree, multiple projections.** Moxi's view/runtime tree is
   above rendering. It can project to a custom scene, a native-widget tree, a
   browser DOM/SVG tree, or a headless test representation. A `Scene` alone is
   not sufficient as the universal abstraction because it cannot provide the
   best web accessibility or native-control integration.

3. **Host and renderer are orthogonal.** A host owns windows, event loops,
   input, system services, and render surfaces. A renderer consumes a Moxi
   frame/scene and produces pixels. Neither may own application state.

4. **Native events are normalized once.** Wayland, X11, AppKit, UIKit,
   Android, and browser events become Moxi events before reaching components.
   Components must not receive native event objects or platform key codes.

5. **Frames are explicit transactions.** A frame contains viewport metrics,
   invalidation, scene/paint work, resource references, and a semantic
   snapshot or delta. The host schedules frames; Moxi decides whether a frame
   is needed.

6. **Resources cross the boundary by stable IDs.** Fonts, images, native
   widgets, clipboard leases, and platform surfaces are identified by Moxi
   values. Native pointers and toolkit objects never enter the stable scene or
   component API.

7. **Support claims require evidence.** Portable compilation, a buildable
   host, a linked runtime, input/IME behavior, accessibility behavior, and
   renderer parity are separate support fields. A Linux headless package is
   not a Linux desktop support claim.

8. **Examples are contract consumers.** Canonical scenarios must feed demos,
   headless tests, host event replays, visual goldens, accessibility checks,
   and benchmarks from one fixture definition.

## Layer model

```text
Application state / PlotSpec / Component
                    |
                    v
Moxi framework API
  components, actions, effects, tasks, view descriptions
                    |
                    v
Moxi UI runtime
  reconciliation, retained identity, layout, focus, hit testing,
  scrolling, semantics, accessibility, invalidation
                    |
          +---------+---------+
          |                   |
          v                   v
  Semantic projections   Frame/scene projection
  DOM/native widgets     PaintCommands/Scene/resources
          |                   |
          v                   v
   Web/GTK/Qt/wx lane   software/canvas/Metal/wgpu lane
          |                   |
          +---------+---------+
                    |
                    v
Moxi host adapter
  window, event loop, DPI, IME, clipboard, timers, vsync,
  accessibility bridge, render-surface lifecycle
                    |
                    v
Wayland/X11/AppKit/Win32/UIKit/Android/browser
```

| Layer | Moxi owns | It must not own |
| --- | --- | --- |
| Application/framework | State, components, actions, tasks, PlotSpec, view descriptions | Native callbacks or window objects |
| UI runtime | Reconciliation, layout, focus, hit testing, scrolling, semantics, invalidation | Toolkit widget classes |
| Frame/scene IR | Ordered commands, transforms, clips, resources, dirty regions, semantic IDs | Canvas structs, Metal handles, DOM nodes |
| Renderer | Software, `canvas_mojo`, Metal, future GPU implementations | Event loops or application state |
| Host adapter | Window lifecycle, event normalization, scale, IME, clipboard, accessibility transport, frame scheduling | Scene ownership or component mutation |
| OS/toolkit | Wayland/X11/AppKit/GTK/Qt/SDL/browser behavior | Moxi's portable state model |

## Moxi's current mapping and required cleanup

The current repository already contains most of the vocabulary:

- `Component`, `App`, and `ColumnRuntime` are the framework/runtime layer.
- `Event` and `AccessibilitySnapshot` are the beginnings of the normalized
  input and semantic contracts.
- `PaintCommands` is a higher-level UI paint stream.
- `Scene` and `SceneRenderer` are the lower-level scene/rendering contract.
- `WindowBackend` and `PlatformAdapter` are overlapping host seams.
- `canvas_mojo` is a renderer/export dependency, not a host abstraction.

The first architectural cleanup should not be a rewrite. It should make the
existing contracts explicit and testable:

1. Define a single host lifecycle contract and decide whether
   `PlatformAdapter` becomes the surface-level API while `WindowBackend`
   becomes a compatibility adapter, or vice versa.
2. Add a frame driver that calls `App.tick()` for timers/animations, consumes
   invalidation, commits layout/semantics, submits a frame, and waits for a
   host event or frame deadline.
3. Keep `PaintCommands` and `Scene` separate until their ownership is proven;
   document `PaintCommands -> Scene` as a projection rather than allowing
   renderers to reach into retained view state.
4. Make the semantic tree independently publishable to native accessibility,
   browser ARIA/DOM, and headless tests.
5. Extend backend capability records with host lifecycle, input/IME,
   accessibility, surface, renderer, and resource support separately.

## Proposed host and renderer contracts

The exact Mojo syntax can follow the existing traits, but the conceptual
interfaces should be equivalent to:

```text
HostBackend
  open(WindowConfig) -> HostSurface
  pump_events() -> [NativeEvent]
  normalize(NativeEvent) -> [MoxiEvent]
  metrics() -> SurfaceMetrics
  request_frame(FrameReason)
  wait_until_event_or_frame()
  publish_accessibility(AccessibilitySnapshot)
  clipboard / cursor / ime / drag_drop services
  close()

RenderBackend
  capabilities() -> RendererCapabilities
  begin_frame(SurfaceMetrics, Invalidation)
  submit(FramePacket or Scene)
  end_frame()
  present(HostSurface)
  release_resources(ResourceIDs)
```

The frame loop should be deterministic in headless mode and host-driven in
native mode:

```text
host.pump_events()
for event in host.events():
    app.dispatch(host.normalize(event))

app.tick(elapsed_seconds)

if app.needs_frame():
    frame = app.commit_frame()
    host.publish_accessibility(frame.semantics)
    renderer.render(frame.scene, frame.metrics)
    host.present()

host.wait_until_event_or_frame()
```

The host may schedule a frame for animation, a pending task, an invalidation,
or an accessibility/state update. The application should not busy-loop when
idle.

## Linux host options

### Recommended first lane: a small C-ABI host

SDL3 is the best initial fit if the immediate goal is a working custom-rendered
Moxi desktop window. It provides a C API and cross-platform access to windows,
keyboard, mouse, text input, and graphics surfaces without forcing Moxi to
adopt a C++ object model. The official SDL3 overview is:

<https://wiki.libsdl.org/SDL3/FrontPage>

The first SDL-style host should deliberately be narrow:

- Wayland and X11 window creation through SDL;
- normalized pointer, keyboard, text, resize, focus, and scale events;
- clipboard, cursor, and basic IME/text-input plumbing;
- software or Canvas rendering into a presentable surface;
- headless event replay using the same normalized event records; and
- explicit reporting that accessibility is not complete until the semantic
  bridge is implemented.

SDL is a host substrate, not a complete UI toolkit. Moxi must still own layout,
semantics, focus, accessibility data, and rendering policy.

### Native-integration lanes

- **GTK4:** choose this when Linux desktop accessibility, native controls,
  platform conventions, and integration with the GNOME stack are acceptance
  criteria from the first release. GTK's standard controls expose the
  `GtkAccessible` interface, but custom Moxi-rendered controls still need an
  explicit accessible implementation. See
  <https://docs.gtk.org/gtk4/section-accessibility.html>.
- **Qt6:** choose this when a product needs Qt's ecosystem, dialogs, menus,
  input methods, and desktop integration. QPA is a strong model for the host
  seam, and Qt Quick's scene graph/RHI is a strong model for a replaceable
  renderer. Qt's platform abstraction is documented at
  <https://doc.qt.io/qt-6/qpa.html>.
- **winit:** use primarily as an architectural reference or through an
  explicitly owned Rust/C bridge. It is a low-level window/event abstraction,
  not a UI toolkit; Xilem's use of it should not be interpreted as a reason to
  put Rust types in Moxi's public Mojo API.
- **Direct Wayland/X11:** defer until a concrete platform feature cannot be
  expressed through the host adapter. It creates a large compatibility and
  accessibility surface before Moxi's own contracts are stable.

Slint is a useful validation of the desired separation: it independently
selects a platform backend and renderer, including combinations such as a
`winit` host with a software renderer. See
<https://docs.slint.dev/latest/docs/slint/guide/backends-and-renderers/backends_and_renderers/>.

## Renderer strategy

1. **Headless software renderer:** remain the deterministic oracle for layout,
   scene structure, hit testing, semantics, and exact software goldens.
2. **Canvas renderer:** keep `canvas_mojo` as a portable raster/export backend
   behind Moxi's scene contract. It does not own a window, event loop, or
   accessibility tree.
3. **Linux first pixels:** use software/Canvas on the first Linux host so host
   and event contracts can be validated without simultaneously debugging GPU
   surfaces.
4. **GPU lane:** add a separate Linux renderer once the host surface contract
   is stable. `wgpu` is a candidate because it spans Vulkan, Metal, Direct3D,
   OpenGL, and WebGPU; its Rust/native packaging and Mojo FFI would need an
   explicit dependency decision. See <https://github.com/gfx-rs/wgpu>.
5. **Native widget portals:** support selected native controls for text input,
   accessibility, menus, and platform dialogs without making native widgets
   the representation of every Moxi node.

## Milestones and acceptance gates

### H0 — Freeze the boundaries

Deliver:

- an ADR for the host/frame/renderer split;
- a support matrix distinguishing portable, host-buildable, linked-runtime,
  and accessibility status;
- a `FramePacket` or equivalent test representation;
- a single canonical scenario for a form, a collection, and a plot scene; and
- an event/semantic replay format with no native object serialization.

Acceptance:

- the same scenario drives headless render, semantic snapshot, event replay,
  and benchmark output;
- no public core module imports GTK, Qt, SDL, AppKit, or platform headers; and
- the plan's host/renderer ownership table is reflected in module ownership.

### H1 — Host-neutral frame driver

Deliver a headless host that exercises the real frame loop, including resize,
pointer/key/text events, timers, invalidation, accessibility publication, and
idle waiting.

Acceptance:

- animation advances only through frame ticks;
- an idle app does not repaint continuously;
- a changed child produces a bounded frame update;
- semantic actions round-trip through the same event path; and
- the existing software visual and 71-file Mojo suite remain green.

### H2 — Linux software host

Implement the first Linux host adapter, preferably with SDL3 unless the native
Linux thread establishes GTK4 or Qt6 as a stronger product requirement.

Targets should include the host shim, Pixi/CI lane, and deterministic checks:

- `native/linux/` or an equivalent isolated host directory;
- `scripts/linux_host_check.sh`;
- Linux host tests for resize, scale, input, clipboard, text input, and close;
- normalized event replay fixtures shared with headless tests; and
- a Linux full-profile or quick-profile benchmark baseline, as appropriate.

Acceptance requires a real linked window host, not only `linux-64` package
resolution. Accessibility status must be explicit if it is not yet complete.

### H3 — IME, clipboard, and accessibility

Complete the host services that make a desktop UI usable: marked text,
replacement ranges, candidate-window positioning where applicable, clipboard,
focus transitions, semantic roles/actions, and screen-reader publication.

Acceptance should be behavior-first: event replay plus platform inspection,
not only screenshots.

### H4 — Linux GPU surface

Add a GPU renderer behind the same `FramePacket`/`Scene` contract. Compare
software and GPU outputs structurally and use tolerance policies only for
platform-dependent pixels, fonts, color spaces, or GPU behavior.

Do not make a GPU backend a prerequisite for the first Linux host milestone.

### H5 — Cross-platform host matrix

Promote the host contract to AppKit, Linux, Android, iOS, and browser lanes.
Each target needs its own host artifact, event/IME/accessibility evidence,
renderer capability record, and benchmark classification. Shared Moxi code may
be considered portable only when it remains independent of all host imports.

## Shared scenario and validation strategy

The scenario registry remains the source of fixtures. Each platform lane should
consume the same records for:

- form editing and IME composition;
- focus, popup, pointer capture, and clipboard;
- long collection scrolling and reorder;
- plot rendering and selection;
- resize and scale-factor changes;
- accessibility tree and semantic actions; and
- animation/task scheduling.

Required commands should eventually include:

```text
pixi run headless-check
pixi run host-check
pixi run linux-host-check
pixi run visual-check
pixi run benchmark-quick
pixi run benchmark-full
pixi run package-consumer
```

The Linux lane should use repeated benchmark results and committed machine
metadata. A single workstation timing must not become a universal performance
claim. This follows the existing benchmark policy and the repository's
deterministic software-golden approach.

## Explicit non-goals

- Do not make Qt, GTK, wxWidgets, SDL, or Rust a required dependency of Moxi
  core.
- Do not equate a Canvas export backend with a desktop UI backend.
- Do not promise native-looking widgets on every platform before a native
  widget projection is designed and tested.
- Do not claim Linux desktop support from a headless Linux package alone.
- Do not add a GPU renderer before the host surface and scene/resource
  contracts are stable.
- Do not serialize closures, native handles, renderer caches, or live task
  objects across package or host boundaries.
- Do not use screenshots as the only evidence for input, IME, accessibility,
  or lifecycle behavior.

## Primary failure modes and mitigations

| Failure mode | Mitigation |
| --- | --- |
| Host and renderer become inseparable | Keep `HostBackend`, `RenderBackend`, and `FramePacket` as separate contracts; require headless implementations |
| Toolkit types leak into core | Enforce module/dependency boundaries and keep native shims under host directories |
| Linux support means only “it builds” | Require a linked host, real event loop, input/IME, accessibility status, and CI evidence |
| Scenarios drift between demos and tests | Registry-owned fixtures feed demos, tests, goldens, and benchmarks |
| Native font/GPU pixels cause endless parity churn | Compare semantics/structure exactly; use explicit platform tolerance policies for pixels |
| Accessibility is postponed until after rendering | Treat semantic tree publication as a first-class frame output from H0 |
| Event-loop reentrancy causes lost or duplicate frames | Normalize events, queue actions, and make frame scheduling observable in tests |
| FFI/package updates silently break consumers | Add clean package-consumer tests and record compiler/dependency revisions in every support lane |

## Reference set

- Xilem/Masonry: <https://github.com/linebender/xilem>
- React Native Fabric: <https://reactnative.dev/architecture/fabric-renderer>
- React Native render/commit/mount: <https://reactnative.dev/architecture/render-pipeline>
- Flutter framework/engine/embedder: <https://docs.flutter.dev/resources/architectural-overview>
- Qt platform abstraction: <https://doc.qt.io/qt-6/qpa.html>
- Qt Quick scene graph: <https://doc.qt.io/qt-6.12/qtquick-visualcanvas-scenegraph.html>
- wxWidgets native-control model: <https://wxwidgets.org/about/>
- Slint backend/renderer split: <https://docs.slint.dev/latest/docs/slint/guide/backends-and-renderers/backends_and_renderers/>
- Iced runtime/renderer/windowing split: <https://github.com/iced-rs/iced>
- SDL3 host substrate: <https://wiki.libsdl.org/SDL3/FrontPage>
- winit window/event substrate: <https://github.com/rust-windowing/winit/blob/master/FEATURES.md>
- wgpu renderer substrate: <https://github.com/gfx-rs/wgpu>
- egui immediate-mode contrast: <https://github.com/emilk/egui>

## Appendix A — Full architecture handoff

The `canvas_mojo` update is complete and pushed:

- `81f7ae5` — upstream `canvas_mojo` v0.42 with released Mojo 1.1
- `e3be517` — refreshed benchmark baseline
- `pixi run check` passes; worktree is clean

The architecture conclusion is:

> Moxi should be a cross-platform UI framework/runtime with a backend-neutral semantic view tree and scene representation. It should not be a windowing toolkit, graphics library, or Qt/wx wrapper.

## Recommended layers

```text
Application state / PlotSpec / Components
                 ↓
Moxi framework API
  actions, effects, tasks, components, view descriptions
                 ↓
Moxi UI runtime
  reconciliation, retained identity, layout, focus, hit testing,
  scrolling, semantics, accessibility, invalidation
                 ↓
        ┌────────┴────────┐
        │                 │
  Semantic projection   Scene/frame projection
  DOM/native widgets   PaintCommands/Scene/resources
        │                 │
   Web/GTK/Qt/wx       Software/canvas/Metal/wgpu
        │                 │
        └────────┬────────┘
                 ↓
        Moxi host adapter
  window, event loop, DPI, IME, clipboard, timers, vsync,
  accessibility bridge, render surface
                 ↓
        Wayland/X11/AppKit/Win32/UIKit/Android/browser
```

Moxi therefore sits roughly at the same conceptual level as Xilem plus its underlying Masonry engine:

- Xilem’s view tree is short-lived and diffed into a retained element tree. Native Xilem targets Masonry; `xilem_web` targets the DOM. That is the most important architectural lesson for Moxi: the shared abstraction should be above both DOM/native widgets and custom rendering. [Xilem architecture](https://github.com/linebender/xilem/blob/main/xilem/ARCHITECTURE.md)
- Masonry deliberately separates widget-tree passes, accessibility, painting, and the platform event loop. [Masonry architecture](https://github.com/linebender/xilem/blob/main/masonry/ARCHITECTURE.md)
- React Native makes the analogous pipeline explicit: render → commit/layout → mount. Its immutable shadow tree is converted into host views only at the platform boundary. [React Native render pipeline](https://reactnative.dev/architecture/render-pipeline)
- Flutter’s framework/engine/embedder/runner split is also very applicable: framework owns UI semantics, engine owns rendering/runtime, embedder owns the OS event loop and surfaces. [Flutter architecture](https://docs.flutter.dev/resources/architectural-overview)

## What Moxi should own

Moxi should own:

- Component/view descriptions
- Reconciliation and retained identity
- Layout and measurement
- Focus, hit testing, gestures, scrolling
- Backend-neutral accessibility semantics
- Invalidation and frame scheduling requests
- A portable `Scene`/frame IR
- Resource identifiers, not native resource handles
- The application/task/action model

Moxi should not own:

- Wayland, X11, GTK, Qt, SDL, or AppKit types
- Native window objects
- GPU command buffers
- Platform event-loop internals
- Platform-specific accessibility object lifetimes
- A particular graphics API

The current code already points in this direction: `App`, `ColumnRuntime`, `Event`, `AccessibilitySnapshot`, `PaintCommands`, `Scene`, `WindowBackend`, and `PlatformAdapter` are the beginnings of these layers. The main architectural cleanup would be to make the boundaries more explicit:

1. `WindowBackend` and `PlatformAdapter` should eventually converge into a clearer host contract.
2. `PaintCommands` should be treated as a higher-level UI paint stream, while `Scene` is the lower-level render IR.
3. `App.run()` should become host/frame driven, including timers, animation ticks, invalidation, and vsync—not only input-event driven.
4. Accessibility should be published from Moxi’s semantic tree independently of the renderer.

## How examples map

| Project | useful boundary | implication |
|---|---|---|
| Xilem | shared view tree diffed into different retained targets | Moxi should own the view/reconcile layer and let hosts choose DOM, native widgets, or custom scene projection |
| React Native | render/commit/mount around an immutable shadow tree | Moxi should make frame transactions explicit without copying the JavaScript bridge model |
| Flutter | framework/engine/embedder/runner | Moxi should separate framework/runtime, renderer, host adapter, and application runner |
| Qt | QPA host abstraction plus Qt Quick scene graph/RHI | Moxi needs independent host and renderer interfaces |
| wxWidgets | native controls and platform utilities | native controls should be an optional Moxi projection, not the core representation |
| Slint | selectable platform backend and renderer | validate that host and renderer choices can vary independently |
| Iced | renderer-agnostic runtime plus windowing shell | keep runtime, renderer, and shell independently testable |
| egui | immediate-mode frame generation | use as a contrast; Moxi’s retained runtime remains better suited to stable identity, accessibility, and large lists |

## Linux host design

I would define a Linux host adapter with these responsibilities:

```text
LinuxHostBackend
  open_window(config)
  pump_events()
  normalize_event()
  request_frame()
  wait_for_event_or_frame()
  expose_size_and_scale()
  manage_clipboard/IME/cursor
  publish_accessibility(snapshot)
  create_render_surface()
  present()
```

The event translation should produce Moxi events such as:

- pointer/touch/mouse
- keyboard and text input
- IME composition
- resize and scale-factor changes
- focus changes
- scroll/drag/drop
- frame ticks
- accessibility actions

The host should never call application components directly. It should normalize native events into Moxi events, and Moxi should return state changes, invalidation, semantic updates, and render work.

### Linux backend choices

| Option | Best use | Assessment |
|---|---|---|
| SDL3 | First minimal custom-rendered desktop host | Strong candidate: C ABI, window/input/surface support, easy Mojo FFI. SDL3 is intentionally low-level, so accessibility and rich IME need separate work. [SDL3](https://wiki.libsdl.org/SDL3/FrontPage) |
| GTK4 | Native Linux integration/accessibility | Strong if accessibility and desktop integration are first-class immediately. GTK controls are accessible by default, but a custom-rendered Moxi widget still needs an explicit accessibility implementation. [GTK accessibility](https://docs.gtk.org/gtk4/section-accessibility.html) |
| Qt6 | Full desktop product integration | Excellent architecture, with QPA for window-system integration and Qt Quick’s scene graph/RHI split. Heavy C++ ABI and packaging cost for Mojo. [Qt QPA](https://doc.qt.io/qt-6/qpa.html), [Qt scene graph](https://doc.qt.io/qt-6.12/qtquick-visualcanvas-scenegraph.html) |
| winit | Architectural reference or Rust bridge | Very good host abstraction, but it is Rust-native and intentionally only handles windows/events; Xilem uses it as a host layer, not as the UI framework. [winit scope](https://github.com/rust-windowing/winit/blob/master/FEATURES.md) |
| Direct Wayland/X11 | Maximum control | Too much surface, input, clipboard, decoration, and compatibility work for the first implementation |
| Slint-style selectable backend | Design reference | Especially relevant because Slint explicitly separates OS backends from renderers and supports combinations such as `winit-software`. [Slint backends/renderers](https://docs.slint.dev/latest/docs/slint/guide/backends-and-renderers/backends_and_renderers/) |

My default recommendation:

- Start with an SDL3-like minimal Linux host to prove the Moxi host contract.
- Keep GTK4 or Qt6 as optional integration lanes if native accessibility/widgets become a requirement.
- Use `canvas_mojo` or the software renderer first for deterministic Linux validation.
- Add a GPU renderer later behind a separate `RenderSurface` contract. `wgpu-native`/`wgpu` is a reasonable long-term candidate, but its Rust/native bridge should not leak into Moxi core. [wgpu](https://github.com/gfx-rs/wgpu)

## The key design decision

Moxi should not choose between “native widgets” and “custom canvas” globally.

It should support both projections:

- Custom-rendered controls and plots → `Scene`/renderer backend
- Accessibility- or platform-sensitive controls → native-widget/DOM host projection

That is the combined lesson from Xilem, React Native, Qt, wxWidgets, Flutter, and Slint:

- Xilem: shared view abstraction, different retained targets
- React Native: shadow tree before host-view mounting
- Flutter: framework separate from engine and embedder
- Qt: platform abstraction separate from scene graph/rendering
- wxWidgets: native controls are valuable, but they are a toolkit strategy rather than a universal scene model. [wxWidgets overview](https://wxwidgets.org/about/)
- Slint/Iced: configurable runtime, renderer, and platform shell
- egui: the immediate-mode model is simple, but Moxi’s retained runtime is a better fit for accessibility, large lists, stable identity, and localized invalidation. [Iced](https://github.com/iced-rs/iced), [egui](https://github.com/emilk/egui)

So the clean abstraction level for Moxi is:

> Above layout/rendering primitives, below application code, with host and renderer adapters beneath it.

That gives the Linux thread a stable target without forcing Linux details into Moxi’s core.
