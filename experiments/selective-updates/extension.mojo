"""Run only with check.py's generated richer editor module."""
from application import Application
from selective import SelectiveHost, SharedInputs, AllInputs, DisplayInputs, equal_value
from domain import Services
from check import control_id, replace, matches_full, visible_count
from moxi import App, Rect, test_check

struct LimitInputs(SharedInputs):
    var display: DisplayInputs
    var limit: Int
    def __init__(out self, services: Services):
        self.display = DisplayInputs(services)
        self.limit = services.settings.max_length
    def matches(self, services: Services) -> Bool:
        return self.display.matches(services) and self.limit == services.settings.max_length

def main():
    var app = App(SelectiveHost[AllInputs](Application()), Rect(0, 0, 640, 2400))
    replace(app, 1, 9, "Reviewer")
    test_check(app.component.root.shell.workspace.group.entries[0].value.reviewer == "Reviewer")
    test_check(app.component.root.shell.workspace.group.entries[1].value.reviewer == "")
    test_check(matches_full(app.component))
    app.component.root.set_max_length(7)
    app.component.services_changed()
    test_check(app.component.editor_renders == 3)
    test_check(matches_full(app.component))
    # A cache refresh alone is not an App frame update outside event dispatch.
    test_check(visible_count(app, "Limit: 24") == 2)
    app.rebuild()
    test_check(visible_count(app, "Limit: 7") == 2)
    test_check(visible_count(app, "Limit: 24") == 0)
    print("PASS new local field/setter/control and shared limit label: conservative host unchanged")
    print("PASS external service transaction updates actual App view after explicit App rebuild")

    var narrow = SelectiveHost[DisplayInputs](Application())
    test_check(matches_full(narrow))
    narrow.reset_counts()
    narrow.root.set_max_length(7)
    narrow.services_changed()
    test_check(narrow.editor_renders == 0)
    test_check(not matches_full(narrow))
    print("EXPECTED LIMIT omitted shared dependency leaves stale UI; full-render oracle catches it")
    narrow.refresh()
    test_check(matches_full(narrow))

    var repaired = SelectiveHost[LimitInputs](Application())
    repaired.root.set_max_length(7)
    repaired.services_changed()
    test_check(matches_full(repaired))
    print("PASS explicit projection repair includes new shared dependency")

    var services = Services()
    for i in range(10000):
        services.document.history.append(String(i))
    var snapshot = AllInputs(services)
    test_check(snapshot.matches(services))
    services.document.history[9999] = "changed"
    test_check(not snapshot.matches(services))
    test_check(snapshot.snapshot.document.history[9999] == "9999")
    services.document.history[9999] = "9999"
    test_check(snapshot.matches(services))
    services.settings.unrelated += 1
    test_check(not snapshot.matches(services))
    print("PASS reflective equality and owned snapshot cover a late mutation in 10000 history entries")
