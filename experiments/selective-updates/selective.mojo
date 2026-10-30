"""App-integrated, editor-boundary caching experiment; not a public API.

The four state-access authoring files remain unchanged. This adapter knows
their ownership tree, but fields, setters, commands and render do not know it.
It assumes a child action can mutate that child and its Services only.
Unknown root mutations use refresh(), the conservative full fallback.
"""
from std.collections import List
from application import Application
from domain import Services
from editor import Editor
from bindings import Action
from runtime import UI, RetainedUI, available
from moxi import Component, ColumnView, Rect, Event, KeyEvent, TextInputEvent, KEY_X, MOD_COMMAND, TEXT_INPUT_VIEW_KIND
from moxi.execution import IntIndex

comptime ID_STRIDE = 1024


def equal_value[T: AnyType](a: T, b: T) -> Bool:
    """Value comparison for this value-owned model; no pointer graph tracking."""
    comptime if conforms_to(T, Equatable):
        return a == b
    else:
        comptime assert len(reflect[T].field_types()) > 0, "Opaque values need an explicit equality contract"
        comptime for i in range(len(reflect[T].field_types())):
            if not equal_value(reflect[T].field_ref[i](a), reflect[T].field_ref[i](b)):
                return False
        return True


trait SharedInputs(ImplicitlyCopyable, Deinitable):
    def __init__(out self, services: Services): ...
    def matches(self, services: Services) -> Bool: ...


struct AllInputs(SharedInputs):
    """Zero field lists: compare all shared value state, including history."""
    var snapshot: Services
    def __init__(out self, services: Services):
        self.snapshot = services
    def matches(self, services: Services) -> Bool:
        return equal_value(self.snapshot, services)


struct DisplayInputs(SharedInputs):
    """Optional optimization: author-maintained list of shared render inputs."""
    var name: String
    var writable: Bool
    def __init__(out self, services: Services):
        self.name = services.document.name
        self.writable = services.settings.writable
    def matches(self, services: Services) -> Bool:
        return self.name == services.document.name and self.writable == services.settings.writable


def route_editor(mut app: Application, key: Int, action: Action[Editor, Services]):
    # Use the existing membership/current-state route. This still linearly
    # searches Keyed.entries; cache selection does not make dispatch O(1).
    app.shell.workspace.group.route(app.services, key, action)


struct Region(ImplicitlyCopyable):
    var key: Int
    var ui: RetainedUI[Application]
    def __init__(out self, key: Int):
        self.key = key
        self.ui = RetainedUI[Application]()
    def refresh(mut self, editor: Editor, services: Services) -> Int:
        var ui = UI[Application]()
        ui.child(editor, services, route_editor, key=self.key)
        self.ui.rebuild(ui.declarations)
        # Namespace bound fails closed rather than colliding with a sibling.
        from runtime import require
        require(self.ui.next_id < ID_STRIDE, "region exhausted its experimental ID namespace")
        return len(ui.declarations)


struct SelectiveHost[Inputs: SharedInputs = AllInputs](Component):
    var root: Application
    var regions: List[Region]
    var lookup: IntIndex
    var inputs: Self.Inputs
    var editor_renders: Int
    var declarations: Int
    var shared_checks: Int
    var full_fallbacks: Int

    def __init__(out self, root: Application):
        self.root = root
        self.regions = List[Region]()
        self.lookup = IntIndex()
        self.inputs = Self.Inputs(self.root.services)
        self.editor_renders = 0
        self.declarations = 0
        self.shared_checks = 0
        self.full_fallbacks = 0
        self.refresh()

    def __init__(out self, *, copy: Self):
        self.root = copy.root
        self.regions = copy.regions.copy()
        self.lookup = IntIndex()
        for i in range(len(self.regions)):
            _ = self.lookup.set(self.regions[i].key, i)
        self.inputs = copy.inputs
        self.editor_renders = copy.editor_renders
        self.declarations = copy.declarations
        self.shared_checks = copy.shared_checks
        self.full_fallbacks = copy.full_fallbacks

    def render_region(mut self, index: Int):
        self.declarations += self.regions[index].refresh(
            self.root.shell.workspace.group.entries[index].value, self.root.services)
        self.editor_renders += 1

    def refresh(mut self):
        """Unknown mutation/topology: enumerate all children and rebuild safely."""
        self.full_fallbacks += 1
        var regions = List[Region]()
        for entry in self.root.shell.workspace.group.entries:
            var old = self.lookup.find(entry.key)
            if old >= 0:
                regions.append(self.regions[old])
            else:
                regions.append(Region(entry.key))
        self.regions = regions^
        self.lookup = IntIndex()
        for i in range(len(self.regions)):
            _ = self.lookup.set(self.regions[i].key, i)
            self.render_region(i)
        self.inputs = Self.Inputs(self.root.services)

    def reconcile(mut self, local_index: Int = -1):
        """Known child action or service-only transaction, not arbitrary writes."""
        self.shared_checks += 1
        if not self.inputs.matches(self.root.services):
            for i in range(len(self.regions)):
                self.render_region(i)
            self.inputs = Self.Inputs(self.root.services)
        elif local_index >= 0:
            self.render_region(local_index)

    def services_changed(mut self):
        """Refresh service-dependent caches; an owning App must then rebuild.

        Event dispatch already triggers App rebuilding when update returns True.
        Outside events, call app.component.services_changed(); app.rebuild().
        """
        self.reconcile()

    def reset_counts(mut self):
        self.editor_renders = 0
        self.declarations = 0
        self.shared_checks = 0
        self.full_fallbacks = 0

    def build(self, bounds: Rect) -> ColumnView:
        # Parent composition, layout and App reconciliation are STILL broad.
        var view = ColumnView(bounds, 0, 0)
        for region in self.regions:
            var offset = region.key * ID_STRIDE
            view.add_component_view_to(-1, offset, region.ui.view, offset)
        view.layout()
        return view^

    def update(mut self, event: Event, view: ColumnView) -> Bool:
        if event.target < ID_STRIDE:
            return False
        var key = event.target // ID_STRIDE
        var i = self.lookup.find(key)
        if i < 0 or not available(view, event.target):
            return False
        var local = event
        local.set_target(event.target - key * ID_STRIDE)
        var dispatches = self.regions[i].ui.dispatches
        var child_view = self.regions[i].ui.view.clone()
        if not self.regions[i].ui.dispatch(self.root, local, child_view):
            return False
        if dispatches != self.regions[i].ui.dispatches:
            self.reconcile(i)
        else:
            # Cursor/composition updates need retained editor state projected.
            self.render_region(i)
        return True

    def clipboard_copy(mut self, target: Int, view: ColumnView) -> String:
        var key = target // ID_STRIDE
        var i = self.lookup.find(key)
        if i < 0 or not available(view, target):
            return ""
        var c = self.regions[i].ui.index(target - key * ID_STRIDE)
        if c < 0 or self.regions[i].ui.controls[c].kind != TEXT_INPUT_VIEW_KIND:
            return ""
        return self.regions[i].ui.controls[c].editor.selected_text()

    def clipboard_cut(mut self, target: Int, view: ColumnView) -> String:
        var text = self.clipboard_copy(target, view)
        if text != "":
            var event = Event(KeyEvent(KEY_X, MOD_COMMAND))
            event.set_target(target)
            _ = self.update(event, view)
        return text

    def clipboard_paste(mut self, target: Int, text: String, view: ColumnView) -> Bool:
        var event = Event(TextInputEvent(text))
        event.set_target(target)
        return self.update(event, view)
