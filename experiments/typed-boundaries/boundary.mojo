"""Generic cache of an entire typed value input; intentionally not read tracking."""
from runtime import Pane, UI, RetainedUI, require
from bindings import Action
from selective import equal_value
from moxi import ColumnView, Rect, Event

comptime ID_STRIDE = 4096

struct Boundary[Root: ImplicitlyCopyable, Child: Pane & Deinitable, C: ImplicitlyCopyable & Deinitable](ImplicitlyCopyable):
    var model: Self.Child
    var context: Self.C
    var ui: RetainedUI[Self.Root]
    var key: Int
    var mounted: Bool
    var initialized: Bool
    var checks: Int
    var renders: Int

    def __init__(out self, model: Self.Child, context: Self.C, key: Int):
        comptime assert Self.C == Self.Child.Context, "Boundary context must match the pane Context"
        self.model = model
        self.context = context
        self.ui = RetainedUI[Self.Root]()
        self.key = key
        self.mounted = False
        self.initialized = False
        self.checks = 0
        self.renders = 0

    def refresh(mut self, model: Self.Child, context: Self.C,
                route: def(mut Self.Root, Int, Action[Self.Child, Self.Child.Context]) thin -> None,
                key: Int, mounted: Bool = True, force: Bool = False):
        self.checks += 1
        if not mounted:
            if self.mounted:
                var empty = UI[Self.Root]()
                self.ui.rebuild(empty.declarations)
            self.mounted = False
            return
        require(not self.initialized or key >= self.key, "boundary mount keys must increase")
        require(not self.initialized or self.mounted or key > self.key,
                "remount requires a fresh increasing key")
        var changed = force or not self.initialized or not self.mounted or key != self.key
        if not changed:
            changed = not equal_value(self.model, model)
            comptime if Self.C != NoneType:
                changed = changed or not equal_value(self.context, context)
        if changed:
            # A new mount gets a new namespace, not reused event identities.
            if key != self.key:
                self.ui = RetainedUI[Self.Root]()
            var ui = UI[Self.Root]()
            ui.child(model, rebind[Self.Child.Context](context), route, key=key)
            self.ui.rebuild(ui.declarations)
            require(self.ui.next_id < ID_STRIDE, "boundary ID namespace exhausted")
            self.model = model
            self.context = context
            self.key = key
            self.initialized = True
            self.renders += 1
        self.mounted = True

    def compose(self, mut view: ColumnView):
        if self.mounted:
            view.add_component_view_to(-1, self.key * ID_STRIDE, self.ui.view, self.key * ID_STRIDE)

    def dispatch(mut self, mut root: Self.Root, event: Event) -> Bool:
        if not self.mounted or self.key != event.target // ID_STRIDE:
            return False
        var local = event
        local.set_target(event.target - self.key * ID_STRIDE)
        var child_view = self.ui.view.clone()
        return self.ui.dispatch(root, local, child_view)
