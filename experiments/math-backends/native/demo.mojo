"""A real Moxi App with asynchronous symbolic workers, using unchanged renderers."""
from std.python import Python, PythonObject
from std.ffi import external_call
from moxi import App, Rect, WindowConfig, ColumnView
from moxi.component import Component
from moxi.event import Event, CLICK_KIND, FRAME_TICK_KIND, KEY_DOWN_KIND, KEY_ENTER, KEY_SPACE, NONE_KIND
from moxi.macos import MacOSRenderer, MacOSWindow
from moxi.style import default_surface_style, default_panel_style, default_label_style

comptime NEXT = 10
comptime RUN = 11
comptime APPLY = 12
comptime EDIT = 13
comptime SLOW = 14
comptime CANCEL = 15
comptime SWITCH = 16
comptime TEXT_EDIT = 17

struct Comparison(Component):
    var session: PythonObject
    var lines: List[String]

    def __init__(out self, session: PythonObject) raises:
        self.session = session
        self.lines = List[String]()
        self.refresh()

    def __init__(out self, *, copy: Self):
        self.session = copy.session
        self.lines = copy.lines.copy()

    def refresh(mut self) raises:
        var values = self.session.lines()
        self.lines.clear()
        for i in range(len(values)):
            self.lines.append(String(values[i]))

    def build(self, bounds: Rect) -> ColumnView:
        var view = ColumnView(bounds, 18.0, 8.0)
        view.set_surface_style(default_surface_style())
        view.set_panel(0, Rect(10, 10, bounds.width - 20, bounds.height - 20), default_panel_style())
        for i in range(len(self.lines)):
            var style = default_label_style()
            style.font_size = 18.0
            if i == 0:
                style.font_size = 26.0
            view.add_label_styled(100 + i, self.lines[i], 34.0, style)
        var row = view.add_row(30, 0.0, 42.0, 8.0, 8.0)
        view.add_button_to(row, NEXT, "Next fixture", 42)
        view.add_button_to(row, RUN, "Run", 42)
        view.add_button_to(row, APPLY, "Apply result", 42)
        view.add_button_to(row, EDIT, "Edit: +1", 42)
        var second = view.add_row(31, 0.0, 42.0, 8.0, 8.0)
        view.add_button_to(second, SLOW, "Slow expansion", 42)
        view.add_button_to(second, CANCEL, "Cancel / kill", 42)
        view.add_button_to(second, SWITCH, "Switch engine", 42)
        view.add_button_to(second, TEXT_EDIT, "Text edit 1/2 -> 3/4", 42)
        view.set_clip_to_bounds()
        return view^

    def update(mut self, event: Event, view: ColumnView) -> Bool:
        try:
            if event.kind == FRAME_TICK_KIND:
                if Bool(self.session.tick()):
                    self.refresh()
                    return True
            elif event.kind == CLICK_KIND or (event.kind == KEY_DOWN_KIND and (event.key == KEY_ENTER or event.key == KEY_SPACE)):
                if event.target >= NEXT and event.target <= TEXT_EDIT:
                    self.session.action(event.target)
                    self.refresh()
                    return True
        except e:
            print("D01 demo error:", e)
        return False


def main() raises:
    var module = Python.import_module("moxi_math_probe.demo")
    var session = module.Session()
    var window = MacOSWindow()
    var renderer = MacOSRenderer()
    window.open(WindowConfig("Moxi D01 · Symbolic backend comparison", 1100, 760))
    window.pump()
    session.window_id = external_call["moxi_math_window_id", Int64]()
    var app = App(Comparison(session), Rect(0, 0, 1100, 760))
    app.request_animation_frames()
    # Same public App dispatch/tick/render contract as App.run, with a finite
    # screenshot mode. No offscreen or mock renderer is used for these captures.
    var clock = Python.import_module("time")
    var previous = window.clock_nanoseconds()
    while window.is_open() and not Bool(session.finished):
        window.pump()
        var event = window.poll_event()
        while event.kind != NONE_KIND:
            _ = app.dispatch(event)
            event = window.poll_event()
        var now = window.clock_nanoseconds()
        _ = app.tick(Float32(now - previous) / 1000000000.0)
        previous = now
        if app.needs_frame():
            app.render(renderer)
        if Bool(session.capture_pending):
            var path = String(session.capture_pending)
            var c_path = path.as_c_string_span()
            session.captured(external_call["moxi_math_capture_window", Int32](c_path.ptr()) != 0)
        clock.sleep(0.016)
    session.close()
