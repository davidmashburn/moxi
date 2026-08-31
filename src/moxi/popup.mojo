"""Shared popup-layer state for menus, combos, context menus, and dialogs."""

from std.collections import List

from .event import (
    KEY_DOWN,
    KEY_END,
    KEY_ENTER,
    KEY_ESCAPE,
    KEY_HOME,
    KEY_LEFT,
    KEY_SPACE,
    KEY_UP,
)
from .geometry import Point, Rect, Size


comptime POPUP_NONE = 0
comptime POPUP_COMBO = 1
comptime POPUP_MENU = 2
comptime POPUP_CONTEXT_MENU = 3
comptime POPUP_DIALOG = 4

comptime POPUP_PLACE_BELOW = 0
comptime POPUP_PLACE_ABOVE = 1
comptime POPUP_PLACE_RIGHT = 2
comptime POPUP_PLACE_LEFT = 3

comptime POPUP_NO_ACTION = -1


def _contains_action(actions: List[Int], action: Int) -> Bool:
    for index in range(len(actions)):
        if actions[index] == action:
            return True
    return False


def _clamp_popup_position(
    position: Float32,
    viewport_start: Float32,
    viewport_extent: Float32,
    popup_extent: Float32,
) -> Float32:
    if viewport_extent <= 0.0 or popup_extent >= viewport_extent:
        return position
    var minimum = viewport_start
    var maximum = viewport_start + viewport_extent - popup_extent
    var result = position
    if result < minimum:
        result = minimum
    if result > maximum:
        result = maximum
    return result


def place_popup(
    anchor: Rect,
    size: Size,
    viewport: Rect,
    placement: Int = POPUP_PLACE_BELOW,
) -> Rect:
    """Place and viewport-clamp a popup without depending on a backend."""
    var width = size.width if size.width > 0.0 else 0.0
    var height = size.height if size.height > 0.0 else 0.0
    var x = anchor.x
    var y = anchor.y + anchor.height
    if placement == POPUP_PLACE_ABOVE:
        y = anchor.y - height
    elif placement == POPUP_PLACE_RIGHT:
        x = anchor.x + anchor.width
        y = anchor.y
    elif placement == POPUP_PLACE_LEFT:
        x = anchor.x - width
        y = anchor.y
    x = _clamp_popup_position(x, viewport.x, viewport.width, width)
    y = _clamp_popup_position(y, viewport.y, viewport.height, height)
    return Rect(x, y, width, height)


struct PopupEntry:
    """One open popup and its stable action IDs."""

    var id: Int
    var kind: Int
    var owner_id: Int
    var anchor: Rect
    var bounds: Rect
    var placement: Int
    var modal: Bool
    var focus_scope_id: Int
    var restore_focus_id: Int
    var action_ids: List[Int]
    var highlighted_index: Int

    def __init__(
        out self,
        id: Int = -1,
        kind: Int = POPUP_NONE,
        owner_id: Int = -1,
        anchor: Rect = Rect(0.0, 0.0, 0.0, 0.0),
        bounds: Rect = Rect(0.0, 0.0, 0.0, 0.0),
        placement: Int = POPUP_PLACE_BELOW,
        modal: Bool = False,
        focus_scope_id: Int = -1,
        restore_focus_id: Int = -1,
    ):
        self.id = id
        self.kind = kind
        self.owner_id = owner_id
        self.anchor = anchor
        self.bounds = bounds
        self.placement = placement
        self.modal = modal
        self.focus_scope_id = focus_scope_id if focus_scope_id >= 0 else id
        self.restore_focus_id = restore_focus_id
        self.action_ids = List[Int]()
        self.highlighted_index = -1

    def set_actions(mut self, actions: List[Int]):
        self.action_ids = List[Int](capacity=len(actions))
        for index in range(len(actions)):
            var action = actions[index]
            if action >= 0 and not _contains_action(self.action_ids, action):
                self.action_ids.append(action)
        self.highlighted_index = 0 if len(self.action_ids) > 0 else -1

    def action_count(self) -> Int:
        return len(self.action_ids)

    def action_at(self, index: Int) -> Int:
        if index < 0 or index >= len(self.action_ids):
            return POPUP_NO_ACTION
        return self.action_ids[index]

    def highlighted_action(self) -> Int:
        return self.action_at(self.highlighted_index)


struct PopupLayerState:
    """A small nested popup stack with explicit focus restoration."""

    var entries: List[PopupEntry]
    var active_focus_id: Int
    var restored_focus_id: Int
    var generation: Int

    def __init__(out self):
        self.entries = List[PopupEntry]()
        self.active_focus_id = -1
        self.restored_focus_id = -1
        self.generation = 0

    def depth(self) -> Int:
        return len(self.entries)

    def is_open(self) -> Bool:
        return len(self.entries) > 0

    def top_id(self) -> Int:
        if len(self.entries) == 0:
            return -1
        return self.entries[len(self.entries) - 1].id

    def top_kind(self) -> Int:
        if len(self.entries) == 0:
            return POPUP_NONE
        return self.entries[len(self.entries) - 1].kind

    def top_owner_id(self) -> Int:
        if len(self.entries) == 0:
            return -1
        return self.entries[len(self.entries) - 1].owner_id

    def top_anchor(self) -> Rect:
        if len(self.entries) == 0:
            return Rect(0.0, 0.0, 0.0, 0.0)
        return self.entries[len(self.entries) - 1].anchor

    def top_bounds(self) -> Rect:
        if len(self.entries) == 0:
            return Rect(0.0, 0.0, 0.0, 0.0)
        return self.entries[len(self.entries) - 1].bounds

    def top_modal(self) -> Bool:
        return len(self.entries) > 0 and self.entries[len(self.entries) - 1].modal

    def focus_target(self) -> Int:
        return self.active_focus_id

    def restored_focus_target(self) -> Int:
        return self.restored_focus_id

    def modal_scope_id(self) -> Int:
        if len(self.entries) == 0:
            return -1
        return self.entries[len(self.entries) - 1].focus_scope_id

    def traps_focus(self) -> Bool:
        return self.top_modal()

    def allows_focus(self, target_id: Int) -> Bool:
        """Check a target against the active modal focus scope."""
        if not self.top_modal():
            return True
        return target_id == self.modal_scope_id()

    def open(
        mut self,
        id: Int,
        kind: Int,
        owner_id: Int,
        anchor: Rect,
        bounds: Rect,
        placement: Int = POPUP_PLACE_BELOW,
        modal: Bool = False,
        focus_scope_id: Int = -1,
        restore_focus_id: Int = -1,
    ) -> Bool:
        """Open or refresh a popup; a new ID becomes a nested top layer."""
        if id < 0:
            return False
        for index in range(len(self.entries)):
            if self.entries[index].id == id:
                while len(self.entries) > index + 1:
                    _ = self.entries.pop(len(self.entries) - 1)
                self.entries[index].kind = kind
                self.entries[index].owner_id = owner_id
                self.entries[index].anchor = anchor
                self.entries[index].bounds = bounds
                self.entries[index].placement = placement
                self.entries[index].modal = modal
                self.entries[index].focus_scope_id = (
                    focus_scope_id if focus_scope_id >= 0 else id
                )
                self.entries[index].restore_focus_id = restore_focus_id
                self.active_focus_id = self.entries[index].focus_scope_id
                self.restored_focus_id = -1
                self.generation += 1
                return True

        self.entries.append(
            PopupEntry(
                id,
                kind,
                owner_id,
                anchor,
                bounds,
                placement,
                modal,
                focus_scope_id,
                restore_focus_id,
            )
        )
        self.active_focus_id = (
            focus_scope_id if focus_scope_id >= 0 else id
        )
        self.restored_focus_id = -1
        self.generation += 1
        return True

    def open_root(
        mut self,
        id: Int,
        kind: Int,
        owner_id: Int,
        anchor: Rect,
        bounds: Rect,
        placement: Int = POPUP_PLACE_BELOW,
        modal: Bool = False,
        focus_scope_id: Int = -1,
        restore_focus_id: Int = -1,
    ) -> Bool:
        _ = self.dismiss_all()
        return self.open(
            id,
            kind,
            owner_id,
            anchor,
            bounds,
            placement,
            modal,
            focus_scope_id,
            restore_focus_id,
        )

    def set_actions(mut self, popup_id: Int, actions: List[Int]) -> Bool:
        for index in range(len(self.entries)):
            if self.entries[index].id == popup_id:
                self.entries[index].set_actions(actions)
                return True
        return False

    def top_action_count(self) -> Int:
        if len(self.entries) == 0:
            return 0
        return self.entries[len(self.entries) - 1].action_count()

    def highlighted_action(self) -> Int:
        if len(self.entries) == 0:
            return POPUP_NO_ACTION
        return self.entries[len(self.entries) - 1].highlighted_action()

    def set_highlighted_index(mut self, index: Int) -> Bool:
        if len(self.entries) == 0:
            return False
        var entry_index = len(self.entries) - 1
        var count = self.entries[entry_index].action_count()
        if index < 0 or index >= count:
            return False
        if self.entries[entry_index].highlighted_index == index:
            return False
        self.entries[entry_index].highlighted_index = index
        return True

    def move_highlight(mut self, delta: Int) -> Bool:
        if len(self.entries) == 0:
            return False
        var entry_index = len(self.entries) - 1
        var count = self.entries[entry_index].action_count()
        if count == 0:
            return False
        var next = self.entries[entry_index].highlighted_index
        if next < 0:
            next = 0
        next += delta
        if next < 0:
            next = 0
        if next >= count:
            next = count - 1
        return self.set_highlighted_index(next)

    def close_top(mut self) -> Bool:
        if len(self.entries) == 0:
            return False
        var index = len(self.entries) - 1
        var restore = self.entries[index].restore_focus_id
        _ = self.entries.pop(index)
        self.restored_focus_id = restore
        if len(self.entries) == 0:
            self.active_focus_id = -1
        else:
            self.active_focus_id = self.entries[len(self.entries) - 1].focus_scope_id
        self.generation += 1
        return True

    def dismiss(mut self) -> Bool:
        return self.close_top()

    def dismiss_if_outside(mut self, point: Point) -> Bool:
        """Dismiss a non-modal top layer when a click lands outside it."""
        if len(self.entries) == 0 or self.top_modal():
            return False
        var entry_index = len(self.entries) - 1
        if (
            self.entries[entry_index].bounds.contains(point)
            or self.entries[entry_index].anchor.contains(point)
        ):
            return False
        return self.close_top()

    def dismiss_all(mut self) -> Bool:
        if len(self.entries) == 0:
            return False
        var restore = self.entries[0].restore_focus_id
        self.entries = List[PopupEntry]()
        self.active_focus_id = -1
        self.restored_focus_id = restore
        self.generation += 1
        return True

    def activate_top(mut self) -> Int:
        if len(self.entries) == 0:
            return POPUP_NO_ACTION
        var action = self.highlighted_action()
        if action == POPUP_NO_ACTION:
            return POPUP_NO_ACTION
        _ = self.close_top()
        return action

    def handle_key(mut self, key: Int) -> Bool:
        """Handle navigation/dismissal while leaving action dispatch to Moxi."""
        if len(self.entries) == 0:
            return False
        if key == KEY_ESCAPE:
            return self.close_top()
        if key == KEY_LEFT and len(self.entries) > 1:
            return self.close_top()
        if key == KEY_UP:
            _ = self.move_highlight(-1)
            return self.top_action_count() > 0
        if key == KEY_DOWN:
            _ = self.move_highlight(1)
            return self.top_action_count() > 0
        if key == KEY_HOME:
            _ = self.set_highlighted_index(0)
            return self.top_action_count() > 0
        if key == KEY_END:
            _ = self.set_highlighted_index(self.top_action_count() - 1)
            return self.top_action_count() > 0
        if key == KEY_ENTER or key == KEY_SPACE:
            var action = self.activate_top()
            return action != POPUP_NO_ACTION or self.is_open()
        return False
