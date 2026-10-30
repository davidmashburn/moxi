"""Current-state replacement negative control; this is not desired product behavior."""
from application import Application
from document import Document
from editor import apply_draft
from runtime import HandlerHost
from moxi import App, Rect, test_check


def main():
    var app = Application()
    app.shell.workspace.editors[0].set_draft("Grace")
    app.shell.workspace.document = Document()
    app.route_editor(1, apply_draft, "")
    test_check(app.shell.workspace.document.name == "Grace")
    test_check(app.shell.workspace.document.commits == 1)
    print("PASS negative control: current route targets replacement; same revision permits old draft in new document")

    var host = App(HandlerHost(Application()), Rect(0, 0, 640, 2000))
    test_check(host.component.root.shell.workspace.document.rename("Grace", 0) == "")
    test_check(host.view.child(0).text == "Document: Ada")
    _ = host.resize(Rect(0, 0, 700, 2000))
    test_check(host.view.child(0).text == "Document: Ada")
    host.component.refresh()
    host.rebuild()
    test_check(host.view.child(0).text == "Document: Grace")
    print("PASS limitation: external current-state writes also need explicit host refresh")
