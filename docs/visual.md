# Moxi visual documentation

The wx-style showcase remains the component-level visual acceptance surface.
The full Moxi Playground is the repository's workbench acceptance surface: it
deliberately exposes the catalog, source/task metadata, real embedded
component pages, editable live reload, and standalone plot/rendering/text
entrypoints in one native AppKit window.

Run the browser with:

```sh
pixi run demo-browser
```

`pixi run demo` is the default alias for the same browser; use
`pixi run hello-window-demo` for the minimal renderer-only window.

The browser interaction model and catalog policy are documented in
[demo-browser.md](demo-browser.md).

Every catalog entry is mounted in the browser through a real component. Scene
and plot entries declare a canvas and send their renderer-neutral scene to the
active host renderer in that same window. The `Editable Live Component`
entry watches `examples/editable_showcase.mojo` and swaps a rebuilt module into
its existing canvas when the file is saved. Standalone tasks remain available
as companion commands from the terminal.

Inspect the component-level showcase separately with:

```sh
pixi run wx-style-demo
```

The source-controlled [showcase reference](wx-style-showcase.svg) records the
intended composition and labels the behavior that should be visible when the
demo runs. The [advanced reference](wx-style-advanced.svg) records the catalog,
scrolling, native-image, and scene-rendering surface. These references use
representative post-interaction states so the pending approval path,
determinate progress, and stateful controls are visible together:

![Moxi wx-style showcase reference](wx-style-showcase.svg)

![Moxi advanced catalog reference](wx-style-advanced.svg)

- Frame → Panel → vertical and horizontal BoxSizer-like containers.
- A text field, checkbox, determinate progress indicator, and routed actions.
- Slider, switch, radio, combo, list, table, tree, menu, dialog, tabs, canvas,
  separator, and image/resource descriptors in the shared catalog surface.
- A clipped portal with persistent scroll state and fixed/variable-extent
  visible-range math.
- A deterministic software scene surface covering basic shapes, gradients,
  clipping, opacity layers, and transforms.
- Backend, text-layout, rich-text, conversation, and capability status.
- The blocked `Agent reset` request followed by the trusted `Approve reset`
  action.
- The typed embedded counter component and the explanatory event-flow copy.

The post-0.5 visual surfaces use the same scene contract:

The plotting API and its current renderer/host limits are described in
[plotting.md](plotting.md).

- `pixi run plot-demo` renders the first plotting library slice through the
  deterministic software scene path.
- `pixi run plot-gallery` exercises the supported declarative plot surface;
  the [gallery reference](plot-gallery.svg) shows its two facet panels,
  layered line/dot marks, categorical color, and size variation.
- The [statistical gallery reference](plot-analytics.svg) records the current
  histogram/density, box, heatmap, regression, and linked-selection slice.
  `pixi run plot-analytics-benchmark` exercises the same recipes from the
  shared typed fixture.
- `pixi run plot-svg` serializes that plot as browser-compatible SVG, which is
  the current Web-target visual export surface.
- `pixi run metal-window-demo-build` compiles the experimental native Metal
  window; launch the resulting binary on macOS to inspect Retina-aware
  CAMetalLayer presentation.

This SVG is a deterministic design reference, not a fabricated runtime
screenshot. Native screenshots should be captured on macOS after launching the
demo, because AppKit font metrics, window chrome, scale factor, and accessibility
behavior are platform output. The headless counterpart is covered by
`tests/wx_style.mojo`, `tests/wx_advanced.mojo`,
`tests/scene_renderer.mojo`, and `tests/package_consumer.mojo`. The SVGs are
checked as well-formed XML by `pixi run check`.
