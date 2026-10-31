"""Minimal keyed Pane collection shared by baseline and candidate probes."""
from std.collections import List

from bindings import Action
from runtime import HandlerHost, Pane, Screen, UI, require
from moxi import App


struct ScalePane(Pane):
    comptime Context = NoneType

    var key: Int
    var text: String
    var clicks: Int
    var mounted: Bool

    def __init__(out self, key: Int):
        self.key = key
        self.text = ""
        self.clicks = 0
        self.mounted = True

    def set_text(mut self, value: String):
        self.text = value

    def clicked(mut self):
        self.clicks += 1

    def render(self, mut ui: UI[Self, NoneType], context: NoneType):
        ui.text_input("Item " + String(self.key), self.text, Self.set_text)
        ui.button("Click " + String(self.clicks), Self.clicked)


struct ScaleScreen(Screen):
    var children: List[ScalePane]
    var next_mount_key: Int

    def __init__(out self, count: Int):
        self.children = List[ScalePane]()
        for i in range(count):
            self.children.append(ScalePane(i + 1))
        self.next_mount_key = 100000

    def __init__(out self, *, copy: Self):
        self.children = copy.children.copy()
        self.next_mount_key = copy.next_mount_key

    def route_child(mut self, key: Int, action: Action[ScalePane, NoneType]):
        # Route guards remain necessary: a retained descriptor may outlive its
        # mounted child, and the runtime does not infer application lifetimes.
        for i in range(len(self.children)):
            if self.children[i].mounted and self.children[i].key == key:
                var context: NoneType = None
                action(self.children[i], context)
                return

    def render(self, mut ui: UI[Self]):
        for i in range(len(self.children)):
            if self.children[i].mounted:
                ui.child(self.children[i], None, Self.route_child, key=self.children[i].key)

    def hide_first(mut self):
        require(len(self.children) > 0, "hide requires a child")
        self.children[0].mounted = False

    def remount_first(mut self) -> Int:
        require(len(self.children) > 0, "remount requires a child")
        var key = self.next_mount_key
        self.next_mount_key += 1
        self.children[0].key = key
        self.children[0].text = ""
        self.children[0].clicks = 0
        self.children[0].mounted = True
        return key

    def reorder_first_and_third(mut self):
        require(len(self.children) > 2, "reorder requires three children")
        var first = self.children[0]
        self.children[0] = self.children[2]
        self.children[2] = first

    def active_children(self) -> Int:
        var count = 0
        for i in range(len(self.children)):
            if self.children[i].mounted:
                count += 1
        return count


def path_for(key: Int, position: Int) -> String:
    return "/k" + String(String(key).byte_length()) + ":" + String(key) + "/p" + String(position)


def control_id(
    mut app: App[HandlerHost[ScaleScreen]],
    key: Int,
    position: Int,
) -> Int:
    var path = path_for(key, position)
    for item in app.component.ui.controls:
        if item.active and item.path == path:
            return item.id
    require(False, "missing active control: " + path)
    return -1


def control_index(mut app: App[HandlerHost[ScaleScreen]], id: Int) -> Int:
    return app.component.ui.index(id)


def active_slots(mut app: App[HandlerHost[ScaleScreen]]) -> Int:
    var count = 0
    for item in app.component.ui.controls:
        if item.active:
            count += 1
    return count


def total_slots(mut app: App[HandlerHost[ScaleScreen]]) -> Int:
    return len(app.component.ui.controls)


def assert_visible_counts(
    mut app: App[HandlerHost[ScaleScreen]],
    expected_children: Int,
):
    # One child scope plus label, text input and button declarations; only the
    # three leaf declarations become ColumnView children.
    require(
        active_slots(app) == expected_children * 4,
        "active slot count for visible population " + String(expected_children),
    )
    require(
        total_slots(app) == expected_children * 4,
        "retained slot count for fresh visible population " + String(expected_children),
    )
    require(
        app.component.ui.next_id == expected_children * 4 + 1,
        "next id for fresh visible population " + String(expected_children),
    )
    require(
        app.view.child_count() == expected_children * 3,
        "tree leaf count for visible population " + String(expected_children),
    )


def assert_churn_counts(
    mut app: App[HandlerHost[ScaleScreen]],
    cycles: Int,
):
    # Total retained storage differs intentionally between baseline and
    # candidate; the Python runner checks that differential after each binary.
    var expected_active = 8 * 4
    require(active_slots(app) == expected_active, "active slots after churn")
    require(
        app.component.ui.next_id == expected_active + cycles * 4 + 1,
        "next id after churn",
    )
    require(app.view.child_count() == 8 * 3, "tree leaves after churn")
