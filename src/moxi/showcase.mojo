"""Small embeddable components shared by the browser and standalone demos.

The showcase is intentionally ordinary Moxi code: each example is a
``Component`` with a normal view tree, and scene-oriented examples expose a
renderer-neutral ``Scene`` for a host canvas.  The demo browser mounts these
components through ``ComponentSlot``; it does not manufacture a preview that
looks like a widget while running something else in a sibling process.
"""

from .accessibility import ACTION_PRESS
from .animation import Animation, EASE_IN_OUT
from .component import Component
from .controls import ButtonControl, LabelControl
from .event import (
    ACTION_KIND,
    CLICK_KIND,
    FRAME_TICK_KIND,
    KEY_ENTER,
    KEY_SPACE,
    KEY_DOWN_KIND,
    Event,
)
from .geometry import Point, Rect
from .plot_data import PlotDataTable
from .plot_spec import (
    CHANNEL_COLOR,
    CHANNEL_OPACITY,
    CHANNEL_SIZE,
    CHANNEL_TOOLTIP,
    CHANNEL_X,
    PlotSpec,
    SCALE_TEMPORAL,
    TYPE_NOMINAL,
)
from .plot_view import PlotView
from .scenarios import make_plot_data_fixture, make_plot_scenario
from .scene import Scene
from .style import (
    Color,
    default_button_style,
    default_panel_style,
    default_surface_style,
)
from .text_shaping import PortableTextShaper
from .view import ColumnView


comptime SHOWCASE_HELLO_WINDOW = 1
comptime SHOWCASE_HELLO_COMPONENT = 2
comptime SHOWCASE_ANIMATION = 3
comptime SHOWCASE_PLOT = 4
comptime SHOWCASE_PLOT_GALLERY = 5
comptime SHOWCASE_PLOT_SVG = 6
comptime SHOWCASE_METAL_SCENE = 7
comptime SHOWCASE_METAL_WINDOW = 8
comptime SHOWCASE_CORETEXT = 9
comptime SHOWCASE_HARFBUZZ = 10

comptime SHOWCASE_TITLE_ID = 1
comptime SHOWCASE_BODY_ID = 2
comptime SHOWCASE_STATUS_ID = 3
comptime SHOWCASE_PROGRESS_ID = 4
comptime SHOWCASE_RESET_ID = 5
comptime SHOWCASE_CANVAS_ID = 6
comptime SHOWCASE_DETAIL_ID = 7
comptime SHOWCASE_PLOT_TOOLBAR_ID = 8
comptime SHOWCASE_PLOT_RESET_VIEW_ID = 9
comptime SHOWCASE_PLOT_CLEAR_SELECTION_ID = 10
comptime SHOWCASE_PLOT_TOGGLE_MARKS_ID = 11
comptime SHOWCASE_PLOT_STREAM_ID = 12
comptime SHOWCASE_PLOT_SPACER_ID = 13
comptime SHOWCASE_PLOT_STATUS_ID = 14


def _is_activation(event: Event) -> Bool:
    return (
        event.kind == CLICK_KIND
        or (
            event.kind == KEY_DOWN_KIND
            and (event.key == KEY_ENTER or event.key == KEY_SPACE)
        )
        or (event.kind == ACTION_KIND and event.action_id == ACTION_PRESS)
    )


def _panel_bounds(bounds: Rect) -> Rect:
    var width = bounds.width - 32.0
    var height = bounds.height - 32.0
    if width < 0.0:
        width = 0.0
    if height < 0.0:
        height = 0.0
    return Rect(bounds.x + 16.0, bounds.y + 16.0, width, height)


def _title_for_mode(mode: Int) -> String:
    if mode == SHOWCASE_HELLO_WINDOW:
        return "Hello Window"
    if mode == SHOWCASE_HELLO_COMPONENT:
        return "Hello Component"
    if mode == SHOWCASE_ANIMATION:
        return "Animation & Invalidation"
    if mode == SHOWCASE_PLOT:
        return "Plot Scene"
    if mode == SHOWCASE_PLOT_GALLERY:
        return "Plot Gallery"
    if mode == SHOWCASE_PLOT_SVG:
        return "Plot SVG Export"
    if mode == SHOWCASE_METAL_SCENE:
        return "Metal Scene"
    if mode == SHOWCASE_METAL_WINDOW:
        return "Metal Window"
    if mode == SHOWCASE_CORETEXT:
        return "CoreText Shaping"
    return "HarfBuzz Shaping"


def _body_for_mode(mode: Int) -> String:
    if mode == SHOWCASE_HELLO_WINDOW:
        return "A real Moxi component mounted in a native window. The standalone example and the Playground use this same component source."
    if mode == SHOWCASE_HELLO_COMPONENT:
        return "The smallest reusable component: state owns a view builder and the host owns the window and renderer lifecycle."
    if mode == SHOWCASE_ANIMATION:
        return "A frame-clock-driven component. The progress control is rebuilt in place as the animation advances and invalidates its content."
    if mode == SHOWCASE_PLOT:
        return "A renderer-neutral Plot scene mounted in a Moxi canvas. The canvas is part of this component, not a screenshot or a separate window."
    if mode == SHOWCASE_PLOT_GALLERY:
        return "The gallery shares the same plot scene seam used by the plotting library. The surrounding controls remain ordinary composable Moxi views."
    if mode == SHOWCASE_PLOT_SVG:
        return "The same component scene can be sent to a native canvas, the software renderer, or the SVG serializer without changing the component."
    if mode == SHOWCASE_METAL_SCENE:
        return "A scene component that can be consumed by a GPU scene renderer when the host selects Metal, with a visible canvas fallback here."
    if mode == SHOWCASE_METAL_WINDOW:
        return "The visible-window example is represented as a component-owned scene so it can be embedded in a larger application."
    if mode == SHOWCASE_CORETEXT:
        return "Portable shaped-run metadata stays in the component contract; a macOS host can replace the shaper with CoreText at the backend boundary."
    return "Portable shaped-run metadata stays in the component contract; a host can replace the shaper with HarfBuzz without changing the view tree."


def _is_scene_mode(mode: Int) -> Bool:
    return (
        mode == SHOWCASE_PLOT
        or mode == SHOWCASE_PLOT_GALLERY
        or mode == SHOWCASE_PLOT_SVG
        or mode == SHOWCASE_METAL_SCENE
        or mode == SHOWCASE_METAL_WINDOW
    )


def _is_interactive_plot_mode(mode: Int) -> Bool:
    return mode == SHOWCASE_PLOT or mode == SHOWCASE_PLOT_GALLERY


def _simple_plot_data() -> PlotDataTable:
    """Build the small source table used by the interactive plot lesson."""
    var data = PlotDataTable()
    for index in range(12):
        var x = Float32(index)
        var y = 0.5 + Float32((index * 7) % 5) * 0.35
        _ = data.append(x, y)
    return data^


def _plot_data_for_mode(mode: Int) -> PlotDataTable:
    if mode == SHOWCASE_PLOT_GALLERY:
        # Keep the gallery tied to the same fixture as the standalone recipe
        # demo and analytics benchmark.
        return make_plot_data_fixture()
    return _simple_plot_data()


def _plot_spec_for_mode(mode: Int) -> PlotSpec:
    var title = "Moxi plotting preview"
    var spec = PlotSpec(title)
    var line = spec.add_line(
        "signal",
        "x",
        "y",
        Color(0.25, 0.72, 1.0, 1.0),
    )
    var dots = spec.add_dot(
        "samples",
        "x",
        "y",
        Color(1.0, 0.45, 0.25, 1.0),
    )
    if mode == SHOWCASE_PLOT_GALLERY:
        title = "Telemetry gallery"
        spec.title = title
        _ = spec.encode(line, CHANNEL_COLOR, "series", TYPE_NOMINAL)
        _ = spec.set_tooltip_fields(line, "time,value,series,region")
        _ = spec.encode(dots, CHANNEL_COLOR, "series", TYPE_NOMINAL)
        _ = spec.encode(dots, CHANNEL_SIZE, "size")
        _ = spec.encode(dots, CHANNEL_OPACITY, "opacity")
        _ = spec.encode(dots, CHANNEL_TOOLTIP, "time,value,series")
        spec.set_scale(CHANNEL_X, SCALE_TEMPORAL)
        spec.set_facet("region")
    _ = spec.add_hover(True, True)
    _ = spec.add_brush()
    _ = spec.add_pan_zoom()
    _ = spec.add_click_select()
    _ = spec.add_lasso()
    _ = spec.add_keyboard()
    return spec^


struct ShowcaseState(Component):
    """A small, genuinely embeddable sample component.

    ``mode`` selects the lesson while preserving one stable component
    boundary.  Plot and GPU lessons additionally expose ``scene(bounds)``;
    hosts may render that scene beside the ordinary retained view tree.
    """

    var mode: Int
    var animation: Animation
    var frame_count: Int
    var plot_data: PlotDataTable
    var plot_view: PlotView
    var plot_streaming: Bool
    var plot_stream_elapsed: Float32
    var plot_stream_index: Int
    var plot_update_count: Int
    var plot_points_visible: Bool

    def __init__(out self, mode: Int = SHOWCASE_HELLO_WINDOW):
        self.mode = mode
        self.animation = Animation(0.0, 1.0, 1.0, EASE_IN_OUT)
        self.frame_count = 0
        var initial_data = _plot_data_for_mode(mode)
        var initial_spec = _plot_spec_for_mode(mode)
        self.plot_data = initial_data^
        self.plot_view = PlotView(
            initial_spec,
            self.plot_data,
            Rect(0.0, 0.0, 640.0, 420.0),
        )
        self.plot_streaming = False
        self.plot_stream_elapsed = 0.0
        self.plot_stream_index = self.plot_data.row_count()
        self.plot_update_count = 0
        self.plot_points_visible = True

    def set_mode(mut self, mode: Int):
        """Switch the shared component to a catalog lesson and reset it."""
        if self.mode == mode:
            return
        self.mode = mode
        self.animation = Animation(0.0, 1.0, 1.0, EASE_IN_OUT)
        self.frame_count = 0
        var next_data = _plot_data_for_mode(mode)
        var next_spec = _plot_spec_for_mode(mode)
        self.plot_data = next_data^
        self.plot_view.replace_spec(next_spec, self.plot_data)
        self.plot_streaming = False
        self.plot_stream_elapsed = 0.0
        self.plot_stream_index = self.plot_data.row_count()
        self.plot_update_count = 0
        self.plot_points_visible = True

    def reset(mut self):
        """Restore the mode's initial state without replacing the host slot."""
        self.animation = Animation(0.0, 1.0, 1.0, EASE_IN_OUT)
        self.frame_count = 0
        if _is_interactive_plot_mode(self.mode):
            self.plot_view.reset_view()
            self.plot_view.clear_selection()
            self.plot_view.clear_hover()
            self.plot_streaming = False
            self.plot_stream_elapsed = 0.0
            self.plot_update_count = 0
            self.plot_points_visible = True
            if self.plot_view.runtime.plot.series_count() > 1:
                var points_id = self.plot_view.runtime.plot.series[1].id
                _ = self.plot_view.runtime.plot.set_series_visible(points_id, True)

    def plot_status(self) -> String:
        """Return the compact live status shown beside plot controls."""
        var hover = "none"
        if self.plot_view.runtime.hovered.found():
            hover = String("key ", self.plot_view.runtime.hovered.row_key)
        var stream = "paused"
        if self.plot_streaming:
            stream = "streaming"
        return String(
            "selected ",
            self.plot_view.selected_count(),
            " · hover ",
            hover,
            " · ",
            stream,
            " · updates ",
            self.plot_update_count,
        )

    def has_scene(self) -> Bool:
        return _is_scene_mode(self.mode)

    def build(self, bounds: Rect) -> ColumnView:
        var root = ColumnView(bounds, 24.0, 12.0)
        root.set_surface_style(default_surface_style())
        root.set_panel(0, _panel_bounds(bounds), default_panel_style())

        root.add(LabelControl(
            SHOWCASE_TITLE_ID,
            _title_for_mode(self.mode),
            34.0,
        ).node())
        root.add(LabelControl(
            SHOWCASE_BODY_ID,
            _body_for_mode(self.mode),
            0.0,
        ).node())
        root.set_preferred_width(SHOWCASE_BODY_ID, bounds.width - 64.0)
        root.set_wrap_text(SHOWCASE_BODY_ID)
        root.set_intrinsic_height(SHOWCASE_BODY_ID)

        if self.mode == SHOWCASE_ANIMATION:
            root.add_progress(
                SHOWCASE_PROGRESS_ID,
                String("Frame ", self.frame_count),
                self.animation.progress(),
                36.0,
            )
            var reset = ButtonControl(
                SHOWCASE_RESET_ID,
                "Restart animation",
                36.0,
                default_button_style(),
            )
            root.add(reset.node())
            root.set_intrinsic_width(SHOWCASE_RESET_ID)
            root.add_label(
                SHOWCASE_STATUS_ID,
                String(
                    "Animation value: ",
                    self.animation.value(),
                    " · invalidation frame ",
                    self.frame_count,
                ),
                28.0,
            )
        elif _is_scene_mode(self.mode):
            var has_plot_controls = _is_interactive_plot_mode(self.mode)
            if has_plot_controls:
                var toolbar = root.add_row(
                    SHOWCASE_PLOT_TOOLBAR_ID,
                    0.0,
                    36.0,
                    0.0,
                    6.0,
                )
                var reset_view = ButtonControl(
                    SHOWCASE_PLOT_RESET_VIEW_ID,
                    "Reset view",
                    34.0,
                )
                root.add_to(toolbar, reset_view.node())
                root.set_intrinsic_width(SHOWCASE_PLOT_RESET_VIEW_ID)
                root.set_accessibility_label(
                    SHOWCASE_PLOT_RESET_VIEW_ID,
                    "Reset plot view",
                )
                var clear_selection = ButtonControl(
                    SHOWCASE_PLOT_CLEAR_SELECTION_ID,
                    "Clear selection",
                    34.0,
                )
                root.add_to(toolbar, clear_selection.node())
                root.set_intrinsic_width(SHOWCASE_PLOT_CLEAR_SELECTION_ID)
                root.set_accessibility_label(
                    SHOWCASE_PLOT_CLEAR_SELECTION_ID,
                    "Clear plot selection",
                )
                var marks_text = "Hide dots"
                if not self.plot_points_visible:
                    marks_text = "Show dots"
                var marks = ButtonControl(
                    SHOWCASE_PLOT_TOGGLE_MARKS_ID,
                    marks_text,
                    34.0,
                )
                root.add_to(toolbar, marks.node())
                root.set_intrinsic_width(SHOWCASE_PLOT_TOGGLE_MARKS_ID)
                root.set_accessibility_label(
                    SHOWCASE_PLOT_TOGGLE_MARKS_ID,
                    "Toggle sample marks",
                )
                var stream_text = "Start stream"
                if self.plot_streaming:
                    stream_text = "Pause stream"
                var stream = ButtonControl(
                    SHOWCASE_PLOT_STREAM_ID,
                    stream_text,
                    34.0,
                )
                root.add_to(toolbar, stream.node())
                root.set_intrinsic_width(SHOWCASE_PLOT_STREAM_ID)
                root.set_accessibility_label(
                    SHOWCASE_PLOT_STREAM_ID,
                    "Toggle reactive data stream",
                )
                root.add_flexible_spacer_to(toolbar, SHOWCASE_PLOT_SPACER_ID)
                root.add_to(
                    toolbar,
                    LabelControl(
                        SHOWCASE_PLOT_STATUS_ID,
                        self.plot_status(),
                        34.0,
                    ).node(),
                )
                root.set_preferred_width(
                    SHOWCASE_PLOT_STATUS_ID,
                    bounds.width - 430.0,
                )
                root.set_accessibility_label(
                    SHOWCASE_PLOT_STATUS_ID,
                    "Plot interaction status",
                )
                root.set_accessibility_value(
                    SHOWCASE_PLOT_STATUS_ID,
                    self.plot_status(),
                )

            var canvas_height = bounds.height - 176.0
            if has_plot_controls:
                canvas_height -= 50.0
            if canvas_height < 190.0:
                canvas_height = 190.0
            root.add_canvas(
                SHOWCASE_CANVAS_ID,
                String("Live scene · ", _title_for_mode(self.mode)),
                canvas_height,
            )
            root.set_accessibility_label(
                SHOWCASE_CANVAS_ID,
                String(_title_for_mode(self.mode), " canvas"),
            )
            root.set_accessibility_value(
                SHOWCASE_CANVAS_ID,
                "Renderer-neutral scene mounted in place",
            )
            root.add_label(
                SHOWCASE_DETAIL_ID,
                (
                    "Drag to pan · scroll to zoom · shift-drag to brush · option-drag to lasso · click or use the arrow keys to select."
                    if has_plot_controls
                    else "Scene output is owned by this component and rendered by the active host canvas."
                ),
                28.0,
            )
        else:
            var detail = "This page is an ordinary Moxi view tree: compose it under another container or mount it as the application root."
            if self.mode == SHOWCASE_CORETEXT or self.mode == SHOWCASE_HARFBUZZ:
                var shaper = PortableTextShaper()
                var shaped = shaper.shape(
                    "Moxi • שלום • مرحبا • नमस्ते • 🙂",
                    default_button_style(),
                    0.0,
                    0,
                )
                detail = String(
                    "Portable shaping seam · glyphs ",
                    shaped.glyph_count(),
                    " · runs ",
                    shaped.run_count(),
                    " · width ",
                    shaped.measurement.size.width,
                    " · host-native shaping may replace this adapter.",
                )
            root.add_label(SHOWCASE_DETAIL_ID, detail, 0.0)
            root.set_preferred_width(SHOWCASE_DETAIL_ID, bounds.width - 64.0)
            root.set_wrap_text(SHOWCASE_DETAIL_ID)
            root.set_intrinsic_height(SHOWCASE_DETAIL_ID)

        root.layout()
        return root^

    def update(mut self, event: Event, view: ColumnView) -> Bool:
        if _is_interactive_plot_mode(self.mode):
            if event.kind == FRAME_TICK_KIND and self.plot_streaming:
                self.plot_stream_elapsed += event.delta_seconds
                if self.plot_stream_elapsed >= 0.25:
                    self.plot_stream_elapsed = 0.0
                    if self._append_stream_sample():
                        self.plot_update_count += 1
                        return True

            var canvas = view.bounds_for(SHOWCASE_CANVAS_ID)
            var canvas_targeted = event.target == SHOWCASE_CANVAS_ID
            var canvas_positioned = canvas.contains(event.position)
            if canvas_targeted or (
                event.target == -1
                and canvas_positioned
                and event.kind != FRAME_TICK_KIND
            ):
                self.plot_view.set_bounds(canvas)
                return self.plot_view.dispatch(event)

            if event.target == SHOWCASE_PLOT_RESET_VIEW_ID and _is_activation(event):
                self.plot_view.reset_view()
                self.plot_view.clear_hover()
                return True
            if event.target == SHOWCASE_PLOT_CLEAR_SELECTION_ID and _is_activation(event):
                self.plot_view.clear_selection()
                return True
            if event.target == SHOWCASE_PLOT_TOGGLE_MARKS_ID and _is_activation(event):
                self.plot_points_visible = not self.plot_points_visible
                if self.plot_view.runtime.plot.series_count() > 1:
                    var points_id = self.plot_view.runtime.plot.series[1].id
                    _ = self.plot_view.runtime.plot.set_series_visible(
                        points_id,
                        self.plot_points_visible,
                    )
                return True
            if event.target == SHOWCASE_PLOT_STREAM_ID and _is_activation(event):
                self.plot_streaming = not self.plot_streaming
                self.plot_stream_elapsed = 0.0
                return True

        if self.mode == SHOWCASE_ANIMATION and event.kind == FRAME_TICK_KIND:
            if self.animation.finished():
                self.animation.restart()
            _ = self.animation.advance(event.delta_seconds)
            self.frame_count += 1
            return True
        if event.target == SHOWCASE_RESET_ID and _is_activation(event):
            self.reset()
            return True
        return False

    def _append_stream_sample(mut self) -> Bool:
        """Append one deterministic row and refresh the retained plot view."""
        var sample = self.plot_stream_index
        var value = 1.0 + Float32((sample * 11) % 17) * 0.35
        var key = self.plot_data.append(Float32(sample), value)
        var row = self.plot_data.row_index(key)
        if self.mode == SHOWCASE_PLOT_GALLERY and row >= 0:
            _ = self.plot_data.set_int_field(
                "time",
                row,
                Int64(1700000000 + sample * 3600),
            )
            _ = self.plot_data.set_float_field("value", row, value)
            _ = self.plot_data.set_float_field(
                "size",
                row,
                4.0 + Float32(sample % 5) * 1.5,
            )
            _ = self.plot_data.set_category_field(
                "series",
                row,
                "A" if sample % 2 == 0 else "B",
            )
            _ = self.plot_data.set_category_field(
                "region",
                row,
                "north" if sample % 24 < 12 else "south",
            )
        self.plot_data.rollover(64)
        self.plot_stream_index += 1
        var refreshed = self.plot_view.replace_data(self.plot_data)
        if refreshed and not self.plot_points_visible:
            if self.plot_view.runtime.plot.series_count() > 1:
                var points_id = self.plot_view.runtime.plot.series[1].id
                _ = self.plot_view.runtime.plot.set_series_visible(
                    points_id,
                    False,
                )
        return refreshed

    def scene(mut self, bounds: Rect) -> Scene:
        """Return the current scene for a component-owned canvas."""
        var scene = Scene()
        if not self.has_scene():
            return scene^

        if _is_interactive_plot_mode(self.mode):
            self.plot_view.set_bounds(bounds)
            return self.plot_view.build_scene()

        if self.mode == SHOWCASE_PLOT_SVG:
            var plot = make_plot_scenario(bounds)
            plot.set_title("SVG export scene")
            return plot.build_scene()

        scene.append_rounded_rect(
            1,
            bounds,
            Color(0.055, 0.085, 0.15, 1.0),
            16.0,
        )
        scene.append_text(
            2,
            _title_for_mode(self.mode),
            Rect(bounds.x + 22.0, bounds.y + 18.0, bounds.width - 44.0, 28.0),
            Color(0.82, 0.92, 1.0, 1.0),
        )
        for index in range(18):
            var x = bounds.x + 28.0 + Float32(index) * 14.0
            var top = bounds.y + 72.0
            var bottom = bounds.y + bounds.height - 24.0 - Float32(index % 5) * 18.0
            scene.append_line(
                100 + index,
                Point(x, top),
                Point(bounds.x + bounds.width - 28.0 - Float32(index) * 9.0, bottom),
                Color(0.25, 0.75, 1.0, 0.84),
                2.0,
            )
        return scene^
