"""Run the shared editors lesson without a native window.

Model: src/moxi_demo/authoring_examples/editors.mojo
"""
from moxi import App, Rect
from moxi.authoring import HandlerHost
from moxi_demo.authoring_examples.editors import EDITORS, Editor, Workspace


def main():
    var app = App(HandlerHost(Workspace()), Rect(0, 0, 400, 300))
    print("Editors:", len(app.component.root.editors.entries))
