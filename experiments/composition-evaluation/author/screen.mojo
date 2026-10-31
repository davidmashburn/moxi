"""Copied workbench with a keyed, remountable third editor pane."""
from domain import Services, Settings, Document
from editor import Editor
from runtime import Screen, UI
from bindings import Action
from workbench import Header, SettingsPanel, Activity, Scratchpad, Inspector, HEADER, LEFT, RIGHT, SETTINGS, HISTORY, SCRATCH, PREVIEW, INSPECTOR_BASE

comptime THIRD_BASE = 200

struct Workbench(Screen):
    var services: Services
    var header: Header
    var left: Editor
    var right: Editor
    var settings: SettingsPanel
    var history: Activity
    var scratch: Scratchpad
    var preview: Editor
    var inspector: Inspector
    var inspector_epoch: Int
    var third: Editor
    var third_epoch: Int
    var show_third: Bool
    var reverse_editors: Bool
    var show_notice: Bool

    def __init__(out self):
        self.services = Services()
        self.header = Header()
        self.left = Editor(self.services)
        self.right = Editor(self.services)
        self.settings = SettingsPanel()
        self.history = Activity()
        self.scratch = Scratchpad()
        self.preview = Editor(self.services)
        self.inspector = Inspector()
        self.inspector_epoch = 1
        self.third = Editor(self.services)
        self.third_epoch = 1
        self.show_third = False
        self.reverse_editors = False
        self.show_notice = False

    def preview_context(self) -> Services:
        # Explicit scope override. This currently copies document history too.
        var context = self.services
        context.settings.writable = False
        return context^

    def inspector_key(self) -> Int:
        return INSPECTOR_BASE + self.inspector_epoch

    def third_key(self) -> Int:
        return THIRD_BASE + self.third_epoch

    def toggle_third(mut self):
        if self.show_third:
            # Discard state from the hidden mount.
            self.show_third = False
            self.third = Editor(self.services)
        else:
            # A new mount snapshots the current shared document.
            self.third_epoch += 1
            self.third = Editor(self.services)
            self.show_third = True

    def route_header(mut self, key: Int, action: Action[Header]):
        if key != HEADER:
            return
        var was_visible = self.header.inspector_visible
        var context: NoneType = None
        action(self.header, context)
        if self.header.inspector_visible and not was_visible:
            self.inspector_epoch += 1
            self.inspector = Inspector()

    def route_left(mut self, key: Int, action: Action[Editor, Services]):
        if key == LEFT:
            action(self.left, self.services)
    def route_right(mut self, key: Int, action: Action[Editor, Services]):
        if key == RIGHT:
            action(self.right, self.services)
    def route_settings(mut self, key: Int, action: Action[SettingsPanel, Settings]):
        if key == SETTINGS:
            action(self.settings, self.services.settings)
    def route_history(mut self, key: Int, action: Action[Activity, Services]):
        if key == HISTORY:
            action(self.history, self.services)
    def route_scratch(mut self, key: Int, action: Action[Scratchpad]):
        if key == SCRATCH:
            var context: NoneType = None
            action(self.scratch, context)
    def route_preview(mut self, key: Int, action: Action[Editor, Services]):
        if key == PREVIEW:
            var context = self.preview_context()
            action(self.preview, context)
            # The scoped document is read-only and is never written back.
    def route_third(mut self, key: Int, action: Action[Editor, Services]):
        if self.show_third and key == self.third_key():
            action(self.third, self.services)
    def route_inspector(mut self, key: Int, action: Action[Inspector, Document]):
        if self.header.inspector_visible and key == self.inspector_key():
            action(self.inspector, self.services.document)

    def render(self, mut ui: UI[Self]):
        ui.child(self.header, None, Self.route_header, key=HEADER)
        ui.button("Toggle third pane", Self.toggle_third)
        if self.show_notice:
            ui.label("Changes remain local until Apply")
        if self.reverse_editors:
            ui.child(self.right, self.services, Self.route_right, key=RIGHT)
            ui.child(self.left, self.services, Self.route_left, key=LEFT)
        else:
            ui.child(self.left, self.services, Self.route_left, key=LEFT)
            ui.child(self.right, self.services, Self.route_right, key=RIGHT)
        ui.child(self.settings, self.services.settings, Self.route_settings, key=SETTINGS)
        ui.child(self.history, self.services, Self.route_history, key=HISTORY)
        ui.child(self.scratch, None, Self.route_scratch, key=SCRATCH)
        ui.child(self.preview, self.preview_context(), Self.route_preview, key=PREVIEW)
        if self.show_third:
            ui.child(self.third, self.services, Self.route_third, key=self.third_key())
        if self.header.inspector_visible:
            ui.child(self.inspector, self.services.document, Self.route_inspector, key=self.inspector_key())
