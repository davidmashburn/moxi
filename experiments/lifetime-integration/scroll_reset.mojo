"""Root lifetime includes App-retained scroll and pointer gesture state."""
from moxi import App, Rect
from moxi.view_node import ROOT_SCROLL_ID
from runtime import HandlerHost, Screen, UI, require, reset, update_model


struct LongPage(Screen):
    var count: Int
    def __init__(out self):
        self.count = 0
    def increment(mut self):
        self.count += 1
    def render(self, mut ui: UI[Self]):
        for _ in range(30):
            ui.button("Row", Self.increment)


def main():
    var app = App(HandlerHost(LongPage()), Rect(0, 0, 300, 120))
    require(app.view.scroll_max_offset(ROOT_SCROLL_ID) > 80.0, "scroll fixture overflows")
    app.remember_scroll(ROOT_SCROLL_ID, 80.0)
    app.scrollbar_pointer_id = 0
    app.scrollbar_target_id = ROOT_SCROLL_ID
    app.scrollbar_grab_offset = 3.0
    app.scrollbar_dragging = True
    update_model(app, LongPage.increment)
    require(app.scroll_offset_for(ROOT_SCROLL_ID) == 80.0, "ordinary update preserves scroll")
    require(app.scrollbar_dragging, "ordinary update preserves live root scrollbar gesture")
    reset(app, LongPage())
    require(app.scroll_offset_for(ROOT_SCROLL_ID) == 0.0, "new root starts at top")
    require(len(app.scroll_ids) == 0 and len(app.scroll_values) == 0, "new root releases old scroll records")
    require(not app.scrollbar_dragging and app.scrollbar_pointer_id == -1 and app.scrollbar_target_id == -1 and app.scrollbar_grab_offset == 0.0, "new root cancels old scrollbar capture")
    print("PASS assignment preserves scroll; root reset clears scroll and scrollbar gesture")
