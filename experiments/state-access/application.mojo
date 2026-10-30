"""Field adapters remove intermediate routes; the services boundary stays explicit."""
from adapters import field, Keyed
from bindings import Action
from domain import Services
from editor import Editor
from runtime import Screen, Pane, UI

struct Workspace(Pane):
    comptime Context = Services
    var group: Keyed[Editor]
    def __init__(out self, services: Services, count: Int = 2):
        self.group = Keyed[Editor]()
        for _ in range(count):
            _ = self.group.append(Editor(services))

    def render(self, mut ui: UI[Self, Services], services: Services):
        field["group"](ui, self, services, key=1)

struct Shell(Pane):
    comptime Context = Services
    var workspace: Workspace
    def __init__(out self, services: Services, count: Int = 2):
        self.workspace = Workspace(services, count)

    def render(self, mut ui: UI[Self, Services], services: Services):
        field["workspace"](ui, self, services, key=1)

struct Application(Screen):
    var services: Services
    var shell: Shell
    def __init__(out self, count: Int = 2):
        self.services = Services()
        self.shell = Shell(self.services, count)

    def route_shell(mut self, key: Int, action: Action[Shell, Services]):
        action(self.shell, self.services)

    def remove(mut self, key: Int):
        self.shell.workspace.group.remove(key)

    def add(mut self) -> Int:
        return self.shell.workspace.group.append(Editor(self.services))

    def replace_document(mut self, identity: Int, name: String):
        self.services.replace_document(identity, name)

    def set_writable(mut self, writable: Bool):
        self.services.settings.writable = writable

    def set_max_length(mut self, limit: Int):
        self.services.settings.max_length = limit

    def undo(mut self):
        self.services.document.undo(self.services.settings)

    def apply_first(mut self):
        self.shell.workspace.group.entries[0].value.apply(self.services)

    def render(self, mut ui: UI[Self]):
        ui.child(self.shell, self.services, Self.route_shell, key=1)
