"""Contract tests for style composition and theme replacement."""

from moxi import Color, ColumnView, Rect, Theme, default_button_style, test_check


def main():
    var base = default_button_style()
    var border = base.with_border(Color(1.0, 1.0, 1.0, 1.0), 2.0)
    var translucent = border.with_opacity(0.5)
    test_check(border.border_width == 2.0)
    test_check(translucent.opacity == 0.5)
    test_check(translucent.fill.red == base.fill.red)

    var theme = Theme()
    theme.with_button(translucent)
    test_check(theme.button.opacity == 0.5)

    var catalog = ColumnView(Rect(0.0, 0.0, 400.0, 400.0), 4.0, 4.0)
    catalog.add_combo_box(1, "Combo", 28.0)
    catalog.add_list(2, "List", 60.0)
    catalog.add_table(3, "Table", 60.0)
    catalog.add_tree(4, "Tree", 60.0)
    catalog.add_menu(5, "Menu", 28.0)
    catalog.add_dialog(6, "Dialog", 60.0)
    catalog.add_tabs(7, "Tabs", 28.0)
    catalog.add_canvas(8, "Canvas", 60.0)
    catalog.add_separator(9)
    var catalog_style = default_button_style().with_opacity(0.25)
    theme.with_combo_box(catalog_style)
    theme.with_list(catalog_style)
    theme.with_table(catalog_style)
    theme.with_tree(catalog_style)
    theme.with_menu(catalog_style)
    theme.with_dialog(catalog_style)
    theme.with_tabs(catalog_style)
    theme.with_canvas(catalog_style)
    theme.with_separator(catalog_style)
    catalog.set_theme(theme)
    for index in range(catalog.child_count()):
        test_check(catalog.child(index).style.opacity == 0.25)
    print("Moxi style-theme test passed")
