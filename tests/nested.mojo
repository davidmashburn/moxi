"""0.5 nested-container and flat-tree layout contract test."""

from moxi import test_check
from moxi import (
    ALIGN_CENTER,
    App,
    BUTTON_KIND,
    CONTAINER_KIND,
    ColumnRuntime,
    ColumnView,
    Event,
    ROLE_CONTAINER,
    Rect,
    TEXT_INPUT_VIEW_KIND,
    TextInputEvent,
    NestedState,
)


def main():
    var root = ColumnView(Rect(0.0, 0.0, 400.0, 240.0), 10.0, 10.0)
    var body = root.add_column(10, 160.0, 8.0, 4.0)
    root.add_label_to(body, 11, "Nested content", 24.0)
    root.add_text_input_to(body, 12, "hello", 36.0)
    root.set_container_alignment(body, 0, ALIGN_CENTER)

    var actions = root.add_row(20, 0.0, 48.0, 8.0, 8.0)
    root.add_button_to(actions, 21, "One", 32.0)
    root.add_button_to(actions, 22, "Two", 32.0)
    root.set_fixed_width(21, 100.0)
    root.set_fixed_width(22, 100.0)
    root.layout()

    test_check(root.child(0).kind == CONTAINER_KIND)
    test_check(root.child(3).kind == CONTAINER_KIND)
    test_check(root.child(1).bounds.x == 18.0)
    test_check(root.child(1).bounds.y == 18.0)
    test_check(root.child(2).kind == TEXT_INPUT_VIEW_KIND)
    test_check(root.child(4).bounds.x == 18.0)
    test_check(root.child(5).bounds.x == 126.0)

    var runtime = ColumnRuntime()
    runtime.reconcile(root)
    var commands = runtime.paint()
    test_check(commands.count() == 5)
    test_check(commands.command(2).kind == TEXT_INPUT_VIEW_KIND)
    test_check(commands.command(3).kind == BUTTON_KIND)
    var semantics = runtime.accessibility()
    test_check(semantics.count() == 6)
    test_check(semantics.node(0).role == ROLE_CONTAINER)
    test_check(semantics.node(1).parent_id == body)
    test_check(semantics.node(4).parent_id == actions)

    var app = App[NestedState](NestedState(), Rect(0.0, 0.0, 480.0, 300.0))
    test_check(app.view.child(0).kind == CONTAINER_KIND)
    test_check(app.view.child(2).kind == TEXT_INPUT_VIEW_KIND)
    test_check(app.accessibility().node(2).parent_id == 10)
    test_check(app.dispatch(Event(TextInputEvent("Ada", 0, 6))))
    test_check(app.component.input.text == "Ada")
    print("Moxi nested test passed")
