from adapters import field
from runtime import Pane, UI
from document import Document

struct Leaf(Pane):
    comptime Context = Document
    var count: Int
    def __init__(out self):
        self.count = 0
    def bump(mut self):
        self.count += 1
    def render(self, mut ui: UI[Self, Document], document: Document):
        ui.button("Bump", Self.bump)

struct Parent(Pane):
    comptime Context = Document
    var leaf: Leaf
    def __init__(out self):
        self.leaf = Leaf()
    def render(self, mut ui: UI[Self, Document], document: Document):
        field["leaf"](ui, self, document, key=1)

def main():
    var parent = Parent()
    var doc = Document()
    var ui = UI[Parent, Document]()
    parent.render(ui, doc)
    ui.declarations[1].action(parent, doc)
    print(parent.leaf.count)
