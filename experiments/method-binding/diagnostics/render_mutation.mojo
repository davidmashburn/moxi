"""Expected compile rejection: render has no mutable access to model or document."""
from editor import Editor
from document import Document
from runtime import UI


def invalid_render(editor: Editor, mut ui: UI[Editor, Document], document: Document):
    editor.apply(document)


def main():
    var document = Document()
    var editor = Editor(1, document)
    var ui = UI[Editor, Document]()
    invalid_render(editor, ui, document)
