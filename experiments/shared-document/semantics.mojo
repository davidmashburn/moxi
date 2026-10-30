"""Handle-specific semantics, including limitations that the common suite cannot assert."""
from application import Application, Workspace
from editor import Editor
from document_handle import DocumentHandle
from runtime import HandlerHost, Screen, UI
from moxi import App, Rect, test_check


def survivor() -> Editor:
    var workspace = Workspace()
    return workspace.editors[0]


def current_label(app: App[HandlerHost[Application]], text: String) -> Bool:
    for index in range(app.view.child_count()):
        if app.view.child(index).text == "Current: " + text:
            return True
    return False


struct MutatingScreen(Screen):
    var document: DocumentHandle

    def __init__(out self, document: DocumentHandle):
        self.document = document

    def render(self, mut ui: UI[Self]):
        self.document.undo()
        ui.label(self.document.name())


def main():
    var source = Application()
    source.shell.workspace.editors[0].set_draft("Grace")
    source.shell.workspace.editors[0].apply()
    var copied_root = source
    var snapshot = source.shell.workspace.document.snapshot()
    source.shell.workspace.document.undo()
    source.shell.workspace.editors[0].set_note("changed")
    source.shell.workspace.editors[0].set_draft("other")
    source.shell.workspace.editors[0].mounted = False
    test_check(copied_root.shell.workspace.document.name() == "Ada")
    test_check(snapshot.name == "Grace")
    test_check(len(snapshot.history) == 1)
    test_check(copied_root.shell.workspace.editors[0].note == "")
    test_check(copied_root.shell.workspace.editors[0].draft == "Grace")
    test_check(copied_root.shell.workspace.editors[0].mounted)
    print("PASS root copies share committed state but isolate local drafts; explicit snapshots isolate value/history")

    var retained = survivor()
    retained.set_draft("Lin")
    retained.apply()
    test_check(retained.document.name() == "Lin")
    test_check(retained.error == "")
    print("PASS editor retains a usable document after workspace destruction; no release/leak measurement")

    var app = App(HandlerHost(Application()), Rect(0, 0, 640, 2000))
    var external = app.component.root.shell.workspace.document
    test_check(external.rename("Grace", 0) == "")
    test_check(app.component.root.shell.workspace.editors[0].document.name() == "Grace")
    test_check(current_label(app, "Ada"))
    test_check(not current_label(app, "Grace"))
    _ = app.resize(Rect(0, 0, 700, 2000))
    test_check(not current_label(app, "Grace"))
    var renders = app.component.renders
    app.component.refresh()
    app.rebuild()
    test_check(app.component.renders == renders + 1)
    test_check(current_label(app, "Grace"))
    test_check(app.component.root.shell.workspace.editors[0].draft == "Ada")
    print("PASS limitation: external handle writes need explicit host refresh; resize does not refresh data")

    var replacement = Application()
    replacement.shell.workspace.editors[0].set_draft("Grace")
    var old = replacement.shell.workspace.document
    replacement.shell.workspace.document = DocumentHandle()
    replacement.shell.workspace.editors[0].apply()
    test_check(old.name() == "Grace")
    test_check(replacement.shell.workspace.document.name() == "Ada")
    test_check(replacement.shell.workspace.editors[1].document.name() == "Grace")
    print("PASS negative control: replacing workspace handle does not rebind existing editors")

    var removed = App(HandlerHost(Application()), Rect(0, 0, 640, 2000))
    var detached = removed.component.root.shell.workspace.editors.pop()
    removed.component.refresh()
    removed.rebuild()
    detached.set_draft("Detached")
    detached.apply()
    test_check(removed.component.root.shell.workspace.document.name() == "Detached")
    test_check(current_label(removed, "Ada"))
    print("PASS limitation: removing editor does not revoke a separately retained editor/document handle")

    var render_document = DocumentHandle()
    test_check(render_document.rename("Grace", 0) == "")
    test_check(render_document.rename("Lin", 1) == "")
    var mutating_host = HandlerHost(MutatingScreen(render_document))
    test_check(render_document.name() == "Grace")
    mutating_host.refresh()
    test_check(render_document.name() == "Ada")
    print("PASS negative control: owner-method facade permits mutations from render(self)")
