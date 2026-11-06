"""Run the shared workspace lesson without a native window.

Model: src/moxi_demo/authoring_examples/workspace.mojo
"""
from moxi import App, Rect
from moxi.authoring import HandlerHost
from moxi_demo.authoring_examples.workspace import GROUPS, DRAFTS, Group, Workspace


def main():
    var app = App(HandlerHost(Workspace()), Rect(0, 0, 560, 700))
    print("Workspace groups:", len(app.component.root.groups.entries))
