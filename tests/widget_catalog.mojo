"""Headless coverage test for Moxi's broader semantic widget catalog."""

from moxi import (
    CANVAS_KIND,
    COMBO_BOX_KIND,
    ColumnRuntime,
    ColumnView,
    DIALOG_KIND,
    LIST_KIND,
    MENU_KIND,
    ROLE_CANVAS,
    ROLE_COMBO_BOX,
    ROLE_DIALOG,
    ROLE_LIST,
    ROLE_MENU,
    ROLE_SEPARATOR,
    ROLE_TAB_GROUP,
    ROLE_TABLE,
    ROLE_TREE,
    SEPARATOR_KIND,
    TABLE_KIND,
    TABS_KIND,
    TREE_KIND,
    Rect,
    test_check,
)


def main():
    var view = ColumnView(Rect(0.0, 0.0, 640.0, 480.0), 8.0, 4.0)
    view.add_combo_box(1, "Theme", 32.0)
    view.add_list(2, "Files", 96.0)
    view.add_table(3, "Results", 96.0)
    view.add_tree(4, "Outline", 96.0)
    view.add_menu(5, "Actions", 32.0)
    view.add_dialog(6, "About Moxi", 120.0)
    view.add_tabs(7, "Overview", 32.0)
    view.add_canvas(8, "Plot", 120.0)
    view.add_separator(9)
    view.layout()

    test_check(view.child(0).kind == COMBO_BOX_KIND)
    test_check(view.child(1).kind == LIST_KIND)
    test_check(view.child(2).kind == TABLE_KIND)
    test_check(view.child(3).kind == TREE_KIND)
    test_check(view.child(4).kind == MENU_KIND)
    test_check(view.child(5).kind == DIALOG_KIND)
    test_check(view.child(6).kind == TABS_KIND)
    test_check(view.child(7).kind == CANVAS_KIND)
    test_check(view.child(8).kind == SEPARATOR_KIND)
    test_check(view.child(0).semantics.role == ROLE_COMBO_BOX)
    test_check(view.child(1).semantics.role == ROLE_LIST)
    test_check(view.child(2).semantics.role == ROLE_TABLE)
    test_check(view.child(3).semantics.role == ROLE_TREE)
    test_check(view.child(4).semantics.role == ROLE_MENU)
    test_check(view.child(5).semantics.role == ROLE_DIALOG)
    test_check(view.child(6).semantics.role == ROLE_TAB_GROUP)
    test_check(view.child(7).semantics.role == ROLE_CANVAS)
    test_check(view.child(8).semantics.role == ROLE_SEPARATOR)

    var runtime = ColumnRuntime()
    runtime.reconcile(view)
    test_check(runtime.focus_id() == 1)
    test_check(runtime.paint().count() == 11)
    print("Moxi widget-catalog test passed")
