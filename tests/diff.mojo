"""Identity-based retained-node reconciliation contract test."""

from moxi import test_check
from moxi import BUTTON_KIND, ColumnRuntime, ColumnView, Rect


def make_view(mode: Int, label_text: String) -> ColumnView:
    var view = ColumnView(Rect(0.0, 0.0, 360.0, 180.0), 12.0, 6.0)
    if mode == 0:
        view.add_label(10, label_text, 24.0)
        view.add_button(20, "Save", 36.0)
        view.add_label(30, "Footer", 24.0)
    elif mode == 1:
        view.add_label(30, "Footer", 24.0)
        view.add_label(10, label_text, 24.0)
        view.add_button(20, "Save", 36.0)
    elif mode == 2:
        view.add_label(10, label_text, 24.0)
        view.add_label(30, "Footer", 24.0)
    else:
        view.add_label(10, label_text, 24.0)
        view.add_button(40, "New", 36.0)
        view.add_label(30, "Footer", 24.0)
    view.layout()
    return view^


def main():
    var runtime = ColumnRuntime()
    var initial = make_view(0, "Initial")
    runtime.reconcile(initial)

    test_check(runtime.widget_count() == 3)
    test_check(runtime.retained_count() == 3)
    test_check(runtime.last_created() == 3)
    test_check(runtime.last_reused() == 0)
    test_check(runtime.last_updated() == 0)
    test_check(runtime.last_removed() == 0)
    test_check(runtime.last_moved() == 0)

    var label_slot = runtime.retained_index(10)
    var button_slot = runtime.retained_index(20)
    var footer_slot = runtime.retained_index(30)

    var unchanged = make_view(0, "Initial")
    runtime.reconcile(unchanged)
    test_check(runtime.last_created() == 0)
    test_check(runtime.last_reused() == 3)
    test_check(runtime.last_updated() == 0)
    test_check(runtime.last_removed() == 0)
    test_check(runtime.last_moved() == 0)
    test_check(runtime.retained_index(10) == label_slot)
    test_check(runtime.retained_index(20) == button_slot)
    test_check(runtime.retained_index(30) == footer_slot)

    var edited = make_view(0, "Edited")
    runtime.reconcile(edited)
    test_check(runtime.last_created() == 0)
    test_check(runtime.last_reused() == 3)
    test_check(runtime.last_updated() == 1)
    test_check(runtime.widget(0).text == "Edited")
    test_check(runtime.retained_index(10) == label_slot)

    var reordered = make_view(1, "Edited")
    runtime.reconcile(reordered)
    test_check(runtime.widget(0).id == 30)
    test_check(runtime.widget(1).id == 10)
    test_check(runtime.widget(2).id == 20)
    test_check(runtime.last_created() == 0)
    test_check(runtime.last_reused() == 3)
    test_check(runtime.last_moved() == 3)
    test_check(runtime.retained_index(10) == label_slot)
    test_check(runtime.retained_index(20) == button_slot)
    test_check(runtime.retained_index(30) == footer_slot)

    var removed_slot = runtime.retained_index(20)
    var trimmed = make_view(2, "Edited")
    runtime.reconcile(trimmed)
    test_check(runtime.widget_count() == 2)
    test_check(runtime.retained_count() == 3)
    test_check(runtime.last_created() == 0)
    test_check(runtime.last_reused() == 2)
    test_check(runtime.last_removed() == 1)
    test_check(runtime.retained_index(20) == -1)

    var replaced = make_view(3, "Edited")
    runtime.reconcile(replaced)
    test_check(runtime.widget_count() == 3)
    test_check(runtime.retained_count() == 3)
    test_check(runtime.last_created() == 1)
    test_check(runtime.last_reused() == 2)
    test_check(runtime.last_removed() == 0)
    test_check(runtime.retained_index(40) == removed_slot)
    test_check(runtime.widget(1).kind == BUTTON_KIND)
    print("Moxi identity diff test passed")
