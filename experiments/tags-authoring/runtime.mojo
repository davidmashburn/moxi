"""Native editing adapter used only by the tags authoring experiment."""
from moxi import (
    ColumnView, Event, TextInputControl, TextInputState,
    CLICK_KIND, ACTION_KIND, KEY_DOWN_KIND, TEXT_INPUT_KIND,
    COMPOSITION_UPDATE_KIND, COMPOSITION_END_KIND, KEY_ENTER, KEY_SPACE,
)


def available(view: ColumnView, target: Int) -> Bool:
    for i in range(view.child_count()):
        if view.child(i).id == target:
            return view.child(i).enabled
    return False


def activated(event: Event) -> Bool:
    return event.kind == CLICK_KIND or event.kind == ACTION_KIND or (
        event.kind == KEY_DOWN_KIND and (event.key == KEY_ENTER or event.key == KEY_SPACE)
    )


def edit(mut state: TextInputState, event: Event) -> Bool:
    if event.kind == COMPOSITION_UPDATE_KIND:
        state.set_composition(event.text, event.selection_start, event.selection_end)
        return True
    if event.kind == COMPOSITION_END_KIND:
        if not state.has_composition():
            return False
        state.clear_composition()
        return True
    if event.kind == TEXT_INPUT_KIND:
        if event.replacement_start >= 0 and event.replacement_end >= 0:
            return state.replace_text_range(event.text, event.replacement_start, event.replacement_end)
        return state.insert_text(event.text)
    if event.kind == KEY_DOWN_KIND:
        return state.handle_key(event.key, event.modifiers)
    return False


def add_input(mut view: ColumnView, id: Int, state: TextInputState):
    var control = TextInputControl(id, state.text, state.cursor, state.anchor, 34.0)
    control.set_composition(state.composition, state.composition_selection_start, state.composition_selection_end)
    view.add(control.node())
