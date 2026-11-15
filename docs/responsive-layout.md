# Responsive UI and window resize

Moxi supports responsive layout through the normal component lifecycle: a window
resize becomes an ordinary event, `App` rebuilds the declarative view with the
new root bounds, layout recomputes geometry, and the host repaints. Applications
do not subscribe to resize notifications; the host reports the new size and the
lifecycle handles it.

## What happens on resize

1. The native host compares the canvas width, height, and backing scale during
   its event pump and queues `MOXI_EVENT_WINDOW_RESIZED` when any of them
   changes (`native/macos_window.m`). The web host does the same from a window
   `resize` listener and a `ResizeObserver` (`native/hosts/moxi_web_host.mjs`).
2. `NativeWindow.poll_event` decodes that packet as `Event(ResizeEvent(size))`,
   which sets `WINDOW_RESIZED_KIND` (kind `4`).
3. `App.dispatch` short-circuits resize events into `App.resize` instead of
   routing them to the component:

   ```mojo
   if event.kind == WINDOW_RESIZED_KIND:
       return self.resize(
           Rect(
               self.root_bounds.x,
               self.root_bounds.y,
               event.size.width,
               event.size.height,
           )
       )
   ```

4. `App.resize` keeps the origin, ignores an unchanged rectangle, and rebuilds:

   ```mojo
   def resize(mut self, bounds: Rect) -> Bool:
       """Update the root geometry and rebuild if the size changed."""
       if (
           self.root_bounds.x == bounds.x
           and self.root_bounds.y == bounds.y
           and self.root_bounds.width == bounds.width
           and self.root_bounds.height == bounds.height
       ):
           return False
       self.root_bounds = bounds
       self.rebuild()
       return True
   ```

5. `App.rebuild()` runs the ordinary rebuild path: `Component.build(root_bounds)`,
   reapply retained scroll offsets (clamped to the new maxima), reconcile the
   retained runtime against the new view, then invalidate the whole root rect
   with `INVALIDATE_ALL`.
6. `App.run` repaints when dispatch reported a change, so the resized frame is
   drawn once with the new geometry.

The canvas adapter adds one pass: after `App.dispatch` handles a resize it calls
`App.rebuild_localized()`, which recomposes the parent view around retained
keyed children (`CanvasView.localized_view`) before the same full-root
invalidation. That pass is what refreshes canvas mounts at the new size.

## Rebuild, not re-render

Resize invalidates geometry, not model state. Two consequences matter when
designing a screen:

- In the `Component` API, `build(bounds)` is the resize hook. Branch on
  `bounds.width`/`bounds.height` there; the view is rebuilt from scratch on
  every size change.
- In the `moxi.authoring` API, `HandlerHost.build(bounds)` does not call
  `render()`; it clones the retained declaration view, applies the new bounds,
  and lays it out. `render()` runs when model state changes. Authoring screens
  therefore reflow on resize but do not change structure on resize unless a
  state change refreshes them. Structure that must follow the window size
  belongs in a `Component`.

Model state survives the rebuild because it is owned by the component, and
scroll offsets are retained by the `App` and reapplied by stable id. Focus,
selection, and cursor state live in the retained runtime and survive a rebuild
as long as the same node ids remain.

## Primitives that respond to width

`Component`-built views are declared fresh on every size change, so adaptive
structure is ordinary control flow over the incoming bounds. Authoring views keep
their declarations and are re-laid out at the new bounds, as described above.

- Root axis: `ColumnView` defaults to `COLUMN_AXIS`; `set_row_layout()` (or
  `set_horizontal_layout()`) switches a view to a horizontal row. There is no
  `set_column_layout()`; assign `view.axis = COLUMN_AXIS` to switch back.
- Nested containers: `add_column_to`, `add_row_to`, `add_split_to`, and
  `add_grid_to` create children with their own axis, padding, and spacing.
  `set_container_layout(id, LAYOUT_STACK)` and friends change a nested
  container's policy by stable id.
- Splits: `add_split_to(parent_id, id, width, height, axis, fraction, ...)`
  allocates two panes by fraction; the demo browser swaps a horizontal split
  for stacked columns when the page narrows.
- Sizing policy: `set_sizing(id, width, height)` with `AxisSize.fill(weight)`,
  `AxisSize.fixed(value)`, or `AxisSize.content()`. Content sizing measures the
  child, including wrapped text height against the available width;
  `set_intrinsic_height(id, True)` opts a leaf into measured height and
  `set_wrap_text(id, True)` enables wrapping.
- Bounds guards: `set_min_width`, `set_max_width`, `set_min_height`, and
  `set_max_height` constrain a child across sizes.
- Flexible space: `add_flexible_spacer(id)` and
  `add_flexible_spacer_to(parent_id, id)` absorb remaining width in a row;
  `add_spacer` and `add_spacer_to` reserve a fixed slot.
- Distribution: `main_alignment` and `cross_alignment` on a view, or
  `set_container_alignment(id, main, cross)` for a nested container, accept
  `JUSTIFY_START`/`JUSTIFY_CENTER`/`JUSTIFY_END`/`JUSTIFY_SPACE_BETWEEN` and
  `ALIGN_START`/`ALIGN_CENTER`/`ALIGN_END`/`ALIGN_STRETCH`.

### A breakpoint in practice

`src/moxi_demo/demo_browser.mojo` implements its narrow-window layout by
comparing the page width and choosing different container declarations:

```mojo
var stacked = authoring_height > 0.0 and page_width < 720.0
var story: Int
if stacked:
    story = root.add_column_to(
        parent_id, DEMO_STORY_SPLIT_ID,
        page_height + 312.0, 4.0, 12.0,
    )
else:
    story = root.add_split_to(
        parent_id, DEMO_STORY_SPLIT_ID, 0.0, page_height,
        ROW_AXIS, 0.58, 4.0, 12.0,
    )
```

The same `build` method also floors derived widths below usable values, for
example clamping `page_width` to `240.0` and `main_width` to `240.0`. Width
arithmetic that subtracts fixed chrome should be clamped (or expressed as
`AxisSize.fill`) rather than allowed to go negative when the window narrows.

## What is not provided

- No breakpoint, media-query, or container-query API. Thresholds are plain
  comparisons against the bounds passed to `build`; the 720-point stack in the
  demo browser is the reference pattern, not a framework feature.
- No hysteresis or transition state for breakpoints. A width that crosses the
  threshold flips the layout on that frame. Layout `Animation` and frame ticks
  exist, but resize itself is not animated.
- No partial invalidation for resize. `App.resize` performs a full root
  rebuild and a full-root invalidation; `TypedSubtreeExecutor` narrows work for
  content and dependency changes, not for window geometry.
- No scale-only notification. A backing-scale change enqueues the same resize
  event; `App.resize` returns `False` when the rectangle is unchanged, so no
  rebuild happens for DPI alone.
- The adaptive policy in [the layout design](design/layout-system.md#adaptive-layouts-animation-and-canvas)
  (locale, text scale, explicit hysteresis, animated transitions) describes
  intended direction; the implemented contract is the event path above.

## Validation

- `tests/component.mojo` resizes a `CounterState` root from 384 to 480 and
  asserts `resize()` reports a change, increments the build counter, and gives
  the padded child the new width.
- `tests/native_demo_authoring.mojo` enqueues a resize during the native input
  reset transaction and asserts it survives as retained geometry.
- [features.md](features.md) states the public contract: `build(bounds)` receives
  the current root rectangle and `resize()` reports whether `App` rebuilt.
