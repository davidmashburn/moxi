"""Run the shared-document lesson without a native window.

Model: src/moxi_demo/authoring_examples/shared.mojo
"""
from moxi import App, Rect
from moxi.authoring import HandlerHost
from moxi_demo.authoring_examples.shared import LEFT, RIGHT, Document, Draft, Desk


def main():
    var app = App(HandlerHost(Desk()), Rect(0, 0, 500, 400))
    print("Document:", app.component.root.document.title)
