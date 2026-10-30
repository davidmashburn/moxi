"""Experimental host variant: parent must refresh after routing and settlement.

Same storage/build/clipboard behavior as HandlerHost, except update dispatches
without immediately refreshing. This is a scheduling contract, not a proposed
second public host type. Keeping it here preserves the earlier experiment.
"""
from moxi import Component, ColumnView, Event, KeyEvent, Rect, TextInputEvent, KEY_X, MOD_COMMAND, TEXT_INPUT_VIEW_KIND
from runtime import Screen, UI, available


struct DeferredHost[Root: Screen & Deinitable](Component):
    var root: Self.Root
    var ui: UI[Self.Root]
    var renders: Int

    def __init__(out self, root: Self.Root):
        self.root = root
        self.ui = UI[Self.Root]()
        self.renders = 0
        self.refresh()

    def refresh(mut self):
        self.ui.begin()
        self.root.render(self.ui)
        self.ui.finish()
        self.renders += 1

    def build(self, bounds: Rect) -> ColumnView:
        var view = self.ui.view.clone()
        view.layout_spec.bounds = bounds
        view.row_layout.bounds = bounds
        view.layout()
        return view^

    def update(mut self, event: Event, view: ColumnView) -> Bool:
        return self.ui.dispatch(self.root, event, view)

    def clipboard_copy(mut self, target: Int, view: ColumnView) -> String:
        var i = self.ui.index(target)
        if i < 0 or not available(view, target) or self.ui.controls[i].kind != TEXT_INPUT_VIEW_KIND:
            return ""
        return self.ui.controls[i].editor.selected_text()

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
