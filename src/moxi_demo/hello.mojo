"""The greeting components shared by the Playground and their native windows."""

from moxi import ColumnView, Component, Rect
from moxi.controls_basic import LabelControl
from moxi.layout import JUSTIFY_CENTER
from moxi.palette import light_tokens
from moxi.style import Theme


struct HelloWindow(Component):
    def __init__(out self):
        pass

    def build(self, bounds: Rect) -> ColumnView:
        var theme = Theme(light_tokens())
        var view = ColumnView(bounds, 24.0, 8.0)
        view.set_theme(theme)
        view.set_surface_style(theme.surface)
        view.set_main_alignment(JUSTIFY_CENTER)
        var title = theme.label
        title.font_size = 34.0
        view.add(LabelControl(1, "Hello from Moxi", 52.0,
            title).node())
        view.add(LabelControl(2, String(Int(bounds.width), " × ", Int(bounds.height), " pt"),
            24.0, theme.label).node())
        view.add(LabelControl(3, "Resize the window to change the view bounds.",
            0.0, theme.label).wrapped_node(bounds.width - 48.0))
        view.layout()
        return view^


struct Greeting(Component):
    var name: String

    def __init__(out self, name: String):
        self.name = name

    def build(self, bounds: Rect) -> ColumnView:
        var theme = Theme(light_tokens())
        var view = ColumnView(bounds, 12.0, 4.0)
        view.set_surface_style(theme.panel)
        var title = theme.label
        title.font_size = 24.0
        view.add(LabelControl(1, String("Hello, ", self.name, "!"), 36.0,
            title).node())
        view.layout()
        return view^


struct HelloComponent(Component):
    def __init__(out self):
        pass

    def build(self, bounds: Rect) -> ColumnView:
        var theme = Theme(light_tokens())
        var view = ColumnView(bounds, 20.0, 10.0)
        view.set_theme(theme)
        view.set_surface_style(theme.surface)
        view.set_main_alignment(JUSTIFY_CENTER)
        view.add(LabelControl(1, "One component, two names", 26.0, theme.label).node())
        var row = Rect(0.0, 0.0, bounds.width - 40.0, 60.0)
        view.add_component_view_to(-1, 2, Greeting("Ada").build(row), 100, row.height)
        view.add_component_view_to(-1, 3, Greeting("Lin").build(row), 200, row.height)
        view.layout()
        return view^
