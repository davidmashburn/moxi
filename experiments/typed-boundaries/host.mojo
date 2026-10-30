"""Explicit application composition; cache type itself is independent of this tree."""
from domain import Services, Settings, Document
from workbench import Workbench, Header, SettingsPanel, Activity, Scratchpad, Inspector, HEADER, LEFT, RIGHT, SETTINGS, HISTORY, SCRATCH, PREVIEW
from editor import Editor
from boundary import Boundary, ID_STRIDE
from moxi import Component, ColumnView, Rect, Event
from runtime import available

struct Caches(ImplicitlyCopyable):
    var header: Boundary[Workbench, Header, NoneType]
    var left: Boundary[Workbench, Editor, Services]
    var right: Boundary[Workbench, Editor, Services]
    var settings: Boundary[Workbench, SettingsPanel, Settings]
    var history: Boundary[Workbench, Activity, Services]
    var scratch: Boundary[Workbench, Scratchpad, NoneType]
    var preview: Boundary[Workbench, Editor, Services]
    var inspector: Boundary[Workbench, Inspector, Document]
    def __init__(out self, root: Workbench):
        self.header = Boundary[Workbench, Header, NoneType](root.header, None, HEADER)
        self.left = Boundary[Workbench, Editor, Services](root.left, root.services, LEFT)
        self.right = Boundary[Workbench, Editor, Services](root.right, root.services, RIGHT)
        self.settings = Boundary[Workbench, SettingsPanel, Settings](root.settings, root.services.settings, SETTINGS)
        self.history = Boundary[Workbench, Activity, Services](root.history, root.services, HISTORY)
        self.scratch = Boundary[Workbench, Scratchpad, NoneType](root.scratch, None, SCRATCH)
        self.preview = Boundary[Workbench, Editor, Services](root.preview, root.preview_context(), PREVIEW)
        self.inspector = Boundary[Workbench, Inspector, Document](root.inspector, root.services.document, root.inspector_key())

struct WorkbenchHost[selective: Bool = True](Component):
    var root: Workbench
    var caches: Caches
    def __init__(out self):
        self.root = Workbench()
        self.caches = Caches(self.root)
        self.refresh()

    def refresh(mut self, target: Int = -1):
        var full = not Self.selective
        self.caches.header.refresh(self.root.header, None, Workbench.route_header, HEADER, force=full or target == HEADER)
        self.caches.left.refresh(self.root.left, self.root.services, Workbench.route_left, LEFT, force=full or target == LEFT)
        self.caches.right.refresh(self.root.right, self.root.services, Workbench.route_right, RIGHT, force=full or target == RIGHT)
        self.caches.settings.refresh(self.root.settings, self.root.services.settings, Workbench.route_settings, SETTINGS, force=full or target == SETTINGS)
        self.caches.history.refresh(self.root.history, self.root.services, Workbench.route_history, HISTORY, force=full or target == HISTORY)
        self.caches.scratch.refresh(self.root.scratch, None, Workbench.route_scratch, SCRATCH, force=full or target == SCRATCH)
        self.caches.preview.refresh(self.root.preview, self.root.preview_context(), Workbench.route_preview, PREVIEW, force=full or target == PREVIEW)
        self.caches.inspector.refresh(self.root.inspector, self.root.services.document, Workbench.route_inspector,
                                     self.root.inspector_key(), self.root.header.inspector_visible,
                                     force=full or target == self.root.inspector_key())

    def build(self, bounds: Rect) -> ColumnView:
        var view = ColumnView(bounds, 0, 0)
        self.caches.header.compose(view)
        self.caches.left.compose(view)
        self.caches.right.compose(view)
        self.caches.settings.compose(view)
        self.caches.history.compose(view)
        self.caches.scratch.compose(view)
        self.caches.preview.compose(view)
        self.caches.inspector.compose(view)
        view.layout()
        return view^

    def update(mut self, event: Event, view: ColumnView) -> Bool:
        var key = event.target // ID_STRIDE
        if not available(view, event.target):
            return False
        var handled = False
        handled = self.caches.header.dispatch(self.root, event) or handled
        handled = self.caches.left.dispatch(self.root, event) or handled
        handled = self.caches.right.dispatch(self.root, event) or handled
        handled = self.caches.settings.dispatch(self.root, event) or handled
        handled = self.caches.history.dispatch(self.root, event) or handled
        handled = self.caches.scratch.dispatch(self.root, event) or handled
        handled = self.caches.preview.dispatch(self.root, event) or handled
        handled = self.caches.inspector.dispatch(self.root, event) or handled
        if handled:
            self.refresh(key)
        return handled

    def reset_counts(mut self):
        self.caches.header.renders = 0
        self.caches.header.checks = 0
        self.caches.left.renders = 0
        self.caches.left.checks = 0
        self.caches.right.renders = 0
        self.caches.right.checks = 0
        self.caches.settings.renders = 0
        self.caches.settings.checks = 0
        self.caches.history.renders = 0
        self.caches.history.checks = 0
        self.caches.scratch.renders = 0
        self.caches.scratch.checks = 0
        self.caches.preview.renders = 0
        self.caches.preview.checks = 0
        self.caches.inspector.renders = 0
        self.caches.inspector.checks = 0

    def render_count(self) -> Int:
        return self.caches.header.renders + self.caches.left.renders + self.caches.right.renders + self.caches.settings.renders + self.caches.history.renders + self.caches.scratch.renders + self.caches.preview.renders + self.caches.inspector.renders
