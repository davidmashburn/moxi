"""Coverage tests for the expanded control descriptors and semantics."""

from moxi import (
    ColumnRuntime,
    ColumnView,
    IMAGE_KIND,
    MULTILINE_TEXT_KIND,
    RADIO_KIND,
    ROLE_IMAGE,
    ROLE_RADIO,
    ROLE_SLIDER,
    ROLE_SWITCH,
    SLIDER_KIND,
    SWITCH_KIND,
)
from moxi.testing import test_check
from moxi.geometry import Rect


def main():
    var view = ColumnView(Rect(0.0, 0.0, 480.0, 320.0), 8.0, 6.0)
    view.add_slider(1, "Volume", 0.5, 28.0)
    view.add_switch(2, "Notifications", True, 28.0)
    view.add_radio(3, "Automatic", True, 28.0)
    view.add_image(4, "Preview", 42, 72.0)
    view.add_multiline_text(5, "A longer editable note", 80.0)
    view.layout()

    test_check(view.children[0].kind == SLIDER_KIND)
    test_check(view.children[1].kind == SWITCH_KIND)
    test_check(view.children[2].kind == RADIO_KIND)
    test_check(view.children[3].kind == IMAGE_KIND)
    test_check(view.children[4].kind == MULTILINE_TEXT_KIND)
    test_check(view.children[0].semantics.role == ROLE_SLIDER)
    test_check(view.children[1].semantics.role == ROLE_SWITCH)
    test_check(view.children[2].semantics.role == ROLE_RADIO)
    test_check(view.children[3].semantics.role == ROLE_IMAGE)
    test_check(view.children[1].semantics.value == "checked")
    test_check(view.children[3].resource_id == 42)

    var runtime = ColumnRuntime()
    runtime.reconcile(view)
    test_check(runtime.focus_id() == 1)
    var commands = runtime.paint()
    test_check(commands.count() == 6)
    test_check(commands.command(1).kind == SLIDER_KIND)
    test_check(commands.command(2).kind == SWITCH_KIND)
    test_check(commands.command(3).kind == RADIO_KIND)
    test_check(commands.command(4).resource_id == 42)
    test_check(commands.command(5).kind == MULTILINE_TEXT_KIND)
    print("Moxi extended-controls test passed")
