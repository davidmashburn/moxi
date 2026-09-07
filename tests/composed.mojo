"""Typed component-slot and stable action-routing contract test."""

from moxi import test_check
from moxi import (
    App,
    ActionEvent,
    CLICK_KIND,
    ClickEvent,
    ColumnView,
    Component,
    ComponentSlot,
    CompositionEvent,
    COMPOSED_COUNTER_ID_OFFSET,
    COMPOSED_COUNTER_SLOT_ID,
    ComposedState,
    COUNTER_INCREMENT_ACTION,
    Event,
    FormState,
    INTERACTION_SHOWCASE_MENU_ID,
    InteractionShowcaseState,
    KeyedSubtreeDescriptor,
    PANEL_KIND,
    Point,
    POINTER_DOWN_KIND,
    POINTER_UP_KIND,
    PointerEvent,
    Rect,
    ROOT_SCROLL_ID,
    ScrollEvent,
)


comptime PRESERVATION_FORM_SLOT_ID = 30
comptime PRESERVATION_FORM_ID_OFFSET = 1000
comptime PRESERVATION_INTERACTION_SLOT_ID = 40
comptime PRESERVATION_INTERACTION_ID_OFFSET = 2000


struct LocalizedPreservationHost(Component):
    """Exercise localized recomposition with independent retained children."""

    var form: ComponentSlot[FormState]
    var interaction: ComponentSlot[InteractionShowcaseState]

    def __init__(out self):
        self.form = ComponentSlot(
            FormState(),
            KeyedSubtreeDescriptor(
                1,
                PRESERVATION_FORM_SLOT_ID,
                1,
                1,
                PRESERVATION_FORM_ID_OFFSET,
            ),
        )
        self.interaction = ComponentSlot(
            InteractionShowcaseState(),
            KeyedSubtreeDescriptor(
                2,
                PRESERVATION_INTERACTION_SLOT_ID,
                2,
                2,
                PRESERVATION_INTERACTION_ID_OFFSET,
            ),
        )

    def _compose(self, bounds: Rect) -> ColumnView:
        var root = ColumnView(bounds, 8.0, 6.0)
        root.add_label(1, "Localized state host", 24.0)
        var child_width = bounds.width - 16.0
        if child_width < 0.0:
            child_width = 0.0
        var form = self.form.build(
            Rect(bounds.x, bounds.y, child_width, 180.0)
        )
        var interaction = self.interaction.build(
            Rect(bounds.x, bounds.y, child_width, 280.0)
        )
        root.add_component_view_to(
            -1,
            PRESERVATION_FORM_SLOT_ID,
            form,
            PRESERVATION_FORM_ID_OFFSET,
            180.0,
        )
        root.add_component_view_to(
            -1,
            PRESERVATION_INTERACTION_SLOT_ID,
            interaction,
            PRESERVATION_INTERACTION_ID_OFFSET,
            280.0,
        )
        root.add_label(2, "Localized tail", 40.0)
        root.layout()
        return root^

    def supports_localized_execution(self) -> Bool:
        return True

    def localized_view(mut self, bounds: Rect) -> ColumnView:
        return self._compose(bounds)

    def localized_dispatch(mut self, event: Event, view: ColumnView) -> Int:
        if self.form.contains(event.target, view):
            return 2 if self.form.route(event, view) else 1
        if self.interaction.contains(event.target, view):
            return 2 if self.interaction.route(event, view) else 1
        return 0

    def build(self, bounds: Rect) -> ColumnView:
        return self._compose(bounds)

    def update(mut self, event: Event, view: ColumnView) -> Bool:
        return False


def main():
    var app = App[ComposedState](
        ComposedState(),
        Rect(0.0, 0.0, 480.0, 360.0),
    )
    test_check(app.view_is_valid())
    test_check(app.view.child(1).id == COMPOSED_COUNTER_SLOT_ID)
    test_check(app.view.child(2).id == COMPOSED_COUNTER_ID_OFFSET + 1)
    test_check(app.view.child(4).id == COMPOSED_COUNTER_ID_OFFSET + 3)
    test_check(app.component.counter.key == 1)
    test_check(app.component.counter.namespaced_id(3) == COMPOSED_COUNTER_ID_OFFSET + 3)
    test_check(app.action_id(COMPOSED_COUNTER_ID_OFFSET + 3) == COUNTER_INCREMENT_ACTION)

    var button = app.view.child(4).bounds
    var click = Event()
    click.kind = CLICK_KIND
    click.position = Point(
        button.x + button.width * 0.5,
        button.y + button.height * 0.5,
    )
    test_check(app.dispatch(click))
    test_check(app.component.counter.component.count == 1)
    var work = app.execution_work_counters()
    test_check(work.root_fallbacks == 0)
    test_check(work.component_builds == 1)
    test_check(work.parent_builds == 1)
    test_check(app.runtime.focus_id() == COMPOSED_COUNTER_ID_OFFSET + 3)
    test_check(app.view.child(4).text == "Increment")
    var commands = app.paint()
    test_check(commands.command(3).kind == PANEL_KIND)
    test_check(commands.command(3).id == COMPOSED_COUNTER_SLOT_ID)
    test_check(commands.command(6).action_id == COUNTER_INCREMENT_ACTION)
    test_check(app.runtime.widget_count() == 5)

    var local = app.component.counter.project_view(app.view)
    test_check(local.child(2).id == 3)
    test_check(local.child(2).text == "Increment")

    # A localized recomposition must not discard state owned by sibling
    # children or by the App/runtime around them. This host intentionally
    # overflows its root so the scroll offset exercises App-owned retention,
    # while the interaction child keeps a live popup stack.
    var preserved_app = App[LocalizedPreservationHost](
        LocalizedPreservationHost(),
        Rect(0.0, 0.0, 520.0, 160.0),
    )
    test_check(preserved_app.view.scroll_max_offset(ROOT_SCROLL_ID) > 0.0)
    test_check(preserved_app.dispatch(Event(ScrollEvent(
        Point(8.0, 8.0),
        Point(0.0, 64.0),
    ))))
    var preserved_scroll = preserved_app.view.scroll_offset_for(ROOT_SCROLL_ID)
    test_check(preserved_scroll > 0.0)

    var input_bounds = preserved_app.view.bounds_for(
        PRESERVATION_FORM_ID_OFFSET + 2
    )
    _ = preserved_app.dispatch(Event(ClickEvent(Point(
        input_bounds.x + 2.0,
        input_bounds.y + 2.0,
    ))))
    test_check(
        preserved_app.focus_id() == PRESERVATION_FORM_ID_OFFSET + 2
    )
    var input_id = PRESERVATION_FORM_ID_OFFSET + 2
    var input_point = Point(input_bounds.x + 2.0, input_bounds.y + 2.0)
    var accessibility_before = preserved_app.accessibility()
    test_check(accessibility_before.is_valid())
    test_check(accessibility_before.node_for_id(input_id).id == input_id)
    test_check(accessibility_before.node_for_id(input_id).parent_id != -1)

    # Pointer capture and semantic identity must survive a local child
    # recomposition; the release must still terminate the original stream.
    test_check(preserved_app.dispatch(Event(PointerEvent(
        POINTER_DOWN_KIND,
        input_point,
        9,
        1,
    ))))
    test_check(preserved_app.pressed_id() == input_id)
    test_check(preserved_app.dispatch(Event(CompositionEvent("かな", 1, 2))))
    test_check(
        preserved_app.component.form.component.input.composition == "かな"
    )
    test_check(
        preserved_app.focus_id() == PRESERVATION_FORM_ID_OFFSET + 2
    )
    test_check(preserved_app.pressed_id() == input_id)
    test_check(
        preserved_app.view.scroll_offset_for(ROOT_SCROLL_ID) == preserved_scroll
    )
    var accessibility_after = preserved_app.accessibility()
    test_check(accessibility_after.is_valid())
    test_check(accessibility_after.node_for_id(input_id).id == input_id)
    test_check(accessibility_after.node_for_id(input_id).focused)
    test_check(preserved_app.dispatch(Event(PointerEvent(
        POINTER_UP_KIND,
        input_point,
        9,
        0,
    ))))
    test_check(preserved_app.pressed_id() == -1)

    # The interaction child owns a nested menu stack. A recomposition of its
    # sibling must preserve both popup layers, not only the top-level entry.
    var menu = Event(ActionEvent(INTERACTION_SHOWCASE_MENU_ID))
    menu.set_target(
        PRESERVATION_INTERACTION_ID_OFFSET + INTERACTION_SHOWCASE_MENU_ID
    )
    test_check(preserved_app.dispatch(menu))
    test_check(preserved_app.component.interaction.component.popups.depth() == 2)
    test_check(preserved_app.dispatch(Event(CompositionEvent("名前", 0, 2))))
    test_check(
        preserved_app.component.form.component.input.composition == "名前"
    )
    test_check(preserved_app.component.interaction.component.popups.depth() == 2)
    test_check(
        preserved_app.component.interaction.component.popups.top_id() == 101
    )
    test_check(
        preserved_app.view.scroll_offset_for(ROOT_SCROLL_ID) == preserved_scroll
    )
    var preserved_work = preserved_app.execution_work_counters()
    test_check(preserved_work.root_fallbacks == 0)
    test_check(preserved_work.parent_builds >= 2)

    print("Moxi composed-component test passed")
