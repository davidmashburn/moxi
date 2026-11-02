"""Two local drafts edit one parent-owned document through explicit routes."""
from moxi.authoring import Action
from moxi import App, Rect
from moxi.authoring import HandlerHost, Pane, Screen, UI

comptime LEFT = 1
comptime RIGHT = 2


struct Document(ImplicitlyCopyable):
    var title: String

    def __init__(out self):
        self.title = "Shared title"


struct Draft(Pane):
    comptime Context = Document
    var text: String

    def __init__(out self, text: String):
        self.text = text

    def change(mut self, text: String):
        self.text = text

    def is_dirty(self, document: Document) -> Bool:
        return self.text != document.title

    def apply(mut self, mut document: Document):
        document.title = self.text

    def revert(mut self, document: Document):
        self.text = document.title

    def render(self, mut ui: UI[Self, Document], document: Document):
        var status = "Clean"
        if self.is_dirty(document):
            status = "Dirty"
        ui.label("Saved: " + document.title + " | Status: " + status)
        ui.text_input("Local draft", self.text, Self.change)
        ui.button("Apply", Self.apply)
        ui.button("Revert", Self.revert)


struct Desk(Screen):
    var document: Document
    var left: Draft
    var right: Draft

    def __init__(out self):
        self.document = Document()
        self.left = Draft(self.document.title)
        self.right = Draft(self.document.title)

    def route_left(mut self, key: Int, action: Action[Draft, Document]):
        if key == LEFT:
            action(self.left, self.document)

    def route_right(mut self, key: Int, action: Action[Draft, Document]):
        if key == RIGHT:
            action(self.right, self.document)

    def render(self, mut ui: UI[Self]):
        ui.child(self.left, self.document, Self.route_left, key=LEFT)
        ui.child(self.right, self.document, Self.route_right, key=RIGHT)


def main():
    var app = App(HandlerHost(Desk()), Rect(0, 0, 500, 400))
    print("Document:", app.component.root.document.title)
