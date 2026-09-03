"""Interactive showcase for the collection and popup foundation."""

from std.collections import List

from .collection_state import (
    COLUMN_SORT_ASCENDING,
    COLUMN_SORT_DESCENDING,
    CollectionColumn,
    CollectionSelection,
    TreeCollectionState,
)
from .component import Component
from .controls import ButtonControl, LabelControl
from .event import (
    ACTION_KIND,
    CLICK_KIND,
    KEY_DOWN,
    KEY_DOWN_KIND,
    KEY_ESCAPE,
    KEY_ENTER,
    KEY_SPACE,
    MOD_COMMAND,
    MOD_CONTROL,
    MOD_SHIFT,
    POINTER_CANCEL_KIND,
    POINTER_DOWN_KIND,
    POINTER_MOVE_KIND,
    POINTER_UP_KIND,
    DRAG_BEGIN_KIND,
    DRAG_UPDATE_KIND,
    DROP_KIND,
    SCROLL_KIND,
    Event,
)
from .geometry import Point, Rect, Size
from .popup import (
    POPUP_CONTEXT_MENU,
    POPUP_DIALOG,
    POPUP_MENU,
    POPUP_PLACE_BELOW,
    POPUP_PLACE_RIGHT,
    PopupLayerState,
    PopupEntry,
    place_popup,
)
from .reorder import ReorderInteraction
from .scene import Scene
from .scrollbar import (
    SCROLLBAR_HIT_THUMB,
    SCROLLBAR_HIT_TRACK,
    SCROLLBAR_STEP_BACKWARD,
    SCROLLBAR_STEP_FORWARD,
    SCROLLBAR_VERTICAL,
    ScrollbarState,
)
from .style import (
    Color,
    Style,
    default_button_style,
    default_panel_style,
    default_surface_style,
)
from .view import ColumnView


comptime INTERACTION_SHOWCASE_CANVAS_ID = 1
comptime INTERACTION_SHOWCASE_SELECT_NEXT_ID = 2
comptime INTERACTION_SHOWCASE_MOVE_ID = 3
comptime INTERACTION_SHOWCASE_SCROLL_BACK_ID = 4
comptime INTERACTION_SHOWCASE_SCROLL_FORWARD_ID = 5
comptime INTERACTION_SHOWCASE_TREE_ID = 6
comptime INTERACTION_SHOWCASE_MENU_ID = 7
comptime INTERACTION_SHOWCASE_DIALOG_ID = 8
comptime INTERACTION_SHOWCASE_SORT_ID = 9
comptime INTERACTION_SHOWCASE_RESET_ID = 10
comptime INTERACTION_SHOWCASE_TITLE_ID = 11
comptime INTERACTION_SHOWCASE_BODY_ID = 12
comptime INTERACTION_SHOWCASE_STATUS_ID = 13
comptime INTERACTION_SHOWCASE_METRICS_ID = 14
comptime INTERACTION_SHOWCASE_INSTRUCTIONS_ID = 15

comptime INTERACTION_SHOWCASE_MENU_POPUP_ID = 100
comptime INTERACTION_SHOWCASE_CONTEXT_POPUP_ID = 101
comptime INTERACTION_SHOWCASE_DIALOG_POPUP_ID = 200
comptime INTERACTION_SHOWCASE_MENU_ACTION_ID = 110
comptime INTERACTION_SHOWCASE_CONTEXT_ACTION_ID = 120
comptime INTERACTION_SHOWCASE_DIALOG_ACCEPT_ID = 210
comptime INTERACTION_SHOWCASE_DIALOG_CANCEL_ID = 211

comptime INTERACTION_SHOWCASE_ROW_HEIGHT: Float32 = 32.0
comptime INTERACTION_SHOWCASE_HEADER_HEIGHT: Float32 = 34.0
comptime INTERACTION_SHOWCASE_VISIBLE_ROWS = 6


def _ink() -> Color:
    return Color(0.93, 0.96, 1.0, 1.0)


def _muted_ink() -> Color:
    return Color(0.68, 0.75, 0.86, 1.0)


def _subtle_ink() -> Color:
    return Color(0.48, 0.57, 0.70, 1.0)


def _accent_ink() -> Color:
    return Color(0.48, 0.79, 1.0, 1.0)


def _accent_fill() -> Color:
    return Color(0.12, 0.38, 0.70, 1.0)


def _quiet_fill() -> Color:
    return Color(0.13, 0.17, 0.26, 1.0)


def _panel_fill() -> Color:
    return Color(0.055, 0.085, 0.15, 1.0)


def _label_style(font_size: Float32, color: Color) -> Style:
    var style = default_button_style()
    style.fill = Color(0.0, 0.0, 0.0, 0.0)
    style.text = color
    style.font_size = font_size
    style.corner_radius = 0.0
    return style


def _button_style(selected: Bool = False) -> Style:
    var style = default_button_style()
    style.fill = _quiet_fill()
    style.text = _muted_ink()
    style.font_size = 12.0
    style.corner_radius = 7.0
    if selected:
        style.fill = _accent_fill()
        style.text = _ink()
    return style


def _is_activation(event: Event) -> Bool:
    return (
        event.kind == CLICK_KIND
        or (
            event.kind == KEY_DOWN_KIND
            and (event.key == KEY_ENTER or event.key == KEY_SPACE)
        )
        or event.kind == ACTION_KIND
    )


def _demo_keys() -> List[Int]:
    var result = List[Int](capacity=10)
    for index in range(10):
        # Sparse identities make index/key confusion visible after reorder.
        result.append(100 + index * 7)
    return result^


def _copy_collection(source: CollectionSelection) -> CollectionSelection:
    var result = CollectionSelection(0, source.multiple)
    result.keys = source.keys.copy()
    result.selected = source.selected.clone()
    result.focus_key = source.focus_key
    result.anchor_key = source.anchor_key
    return result^


def _copy_tree(source: TreeCollectionState) -> TreeCollectionState:
    var result = TreeCollectionState(source.selection.multiple)
    result.nodes = source.nodes.copy()
    result.selection = _copy_collection(source.selection)
    return result^


def _copy_popups(source: PopupLayerState) -> PopupLayerState:
    var result = PopupLayerState()
    result.active_focus_id = source.active_focus_id
    result.restored_focus_id = source.restored_focus_id
    result.generation = source.generation
    for index in range(len(source.entries)):
        var source_entry = source.entries[index]
        var entry = PopupEntry(
            source_entry.id,
            source_entry.kind,
            source_entry.owner_id,
            source_entry.anchor,
            source_entry.bounds,
            source_entry.placement,
            source_entry.modal,
            source_entry.focus_scope_id,
            source_entry.restore_focus_id,
        )
        entry.action_ids = source_entry.action_ids.copy()
        entry.highlighted_index = source_entry.highlighted_index
        result.entries.append(entry)
    return result^


struct InteractionShowcaseState(Component):
    """A real component exercising every post-0.5 interaction primitive."""

    var collection: CollectionSelection
    var columns: List[CollectionColumn]
    var tree: TreeCollectionState
    var scrollbar: ScrollbarState
    var popups: PopupLayerState
    var reorder: ReorderInteraction
    var scrollbar_pointer_id: Int
    var scrollbar_grab_offset: Float32
    var dismissed_popup_pointer_id: Int
    var status: String

    def __init__(out self):
        self.collection = CollectionSelection(0, True)
        self.columns = List[CollectionColumn]()
        self.tree = TreeCollectionState(True)
        self.scrollbar = ScrollbarState(SCROLLBAR_VERTICAL, 24.0)
        self.popups = PopupLayerState()
        self.reorder = ReorderInteraction(8.0)
        self.scrollbar_pointer_id = -1
        self.scrollbar_grab_offset = 0.0
        self.dismissed_popup_pointer_id = -1
        self.status = ""
        self._reset_state()

    def __init__(out self, *, copy: Self):
        self.collection = _copy_collection(copy.collection)
        self.columns = copy.columns.copy()
        self.tree = _copy_tree(copy.tree)
        self.scrollbar = copy.scrollbar
        self.popups = _copy_popups(copy.popups)
        self.reorder = copy.reorder
        self.scrollbar_pointer_id = copy.scrollbar_pointer_id
        self.scrollbar_grab_offset = copy.scrollbar_grab_offset
        self.dismissed_popup_pointer_id = copy.dismissed_popup_pointer_id
        self.status = copy.status

    def _reset_state(mut self):
        self.collection = CollectionSelection(0, True)
        var keys = _demo_keys()
        _ = self.collection.set_keys(keys)
        _ = self.collection.select_index(1)

        self.columns = List[CollectionColumn]()
        self.columns.append(CollectionColumn(1, "Name", 178.0, 100.0, 240.0))
        self.columns.append(CollectionColumn(2, "State", 96.0, 72.0, 160.0))
        self.columns.append(CollectionColumn(3, "Stable key", 104.0, 80.0, 160.0))
        _ = self.columns[0].set_sort(COLUMN_SORT_ASCENDING)

        self.tree = TreeCollectionState(True)
        _ = self.tree.add_node(10, -1, True)
        _ = self.tree.add_node(20, 10, False)
        _ = self.tree.add_node(30, 20, False)
        _ = self.tree.add_node(40, -1, False)
        _ = self.tree.select_key(10)

        self.scrollbar = ScrollbarState(SCROLLBAR_VERTICAL, 24.0)
        self.scrollbar.set_metrics(
            Float32(self.collection.item_count()) * INTERACTION_SHOWCASE_ROW_HEIGHT,
            Float32(INTERACTION_SHOWCASE_VISIBLE_ROWS) * INTERACTION_SHOWCASE_ROW_HEIGHT,
        )
        self.scrollbar.set_step(INTERACTION_SHOWCASE_ROW_HEIGHT)

        self.popups = PopupLayerState()
        self.reorder = ReorderInteraction(8.0, self.collection.item_count())
        self.scrollbar_pointer_id = -1
        self.scrollbar_grab_offset = 0.0
        self.dismissed_popup_pointer_id = -1
        self.status = "Ready · select rows, drag to reorder, or open a layer."

    def reset(mut self):
        """Restore all five interaction primitives to their initial state."""
        self._reset_state()

    def intercepts_pointer(self, event: Event) -> Bool:
        """Keep scene popup streams out of the underlying view tree."""
        return self.popups.is_open() or self.dismissed_popup_pointer_id >= 0

    def _selected_index(self) -> Int:
        var index = self.collection.focus_index()
        return 0 if index < 0 else index

    def _sort_collection(mut self, descending: Bool):
        """Apply the visible Name-column order without losing stable focus."""
        var keys = self.collection.keys.copy()
        for left in range(len(keys)):
            for right in range(left + 1, len(keys)):
                var should_swap = (
                    keys[right] > keys[left]
                    if descending
                    else keys[right] < keys[left]
                )
                if should_swap:
                    var swapped = keys[left]
                    keys[left] = keys[right]
                    keys[right] = swapped
        _ = self.collection.set_keys(keys)

    def _canvas_bounds(self, view: ColumnView) -> Rect:
        return view.bounds_for(INTERACTION_SHOWCASE_CANVAS_ID)

    def _table_width(self, canvas: Rect) -> Float32:
        var tree_width: Float32 = 190.0
        var table_width = canvas.width - tree_width - 42.0
        if table_width < 280.0:
            tree_width = 150.0
            table_width = canvas.width - tree_width - 42.0
        if table_width < 200.0:
            table_width = canvas.width - 32.0
        return table_width

    def _scrollbar_track(self, canvas: Rect) -> Rect:
        var table_width = self._table_width(canvas)
        return Rect(
            canvas.x + table_width,
            canvas.y + 16.0 + INTERACTION_SHOWCASE_HEADER_HEIGHT,
            10.0,
            INTERACTION_SHOWCASE_ROW_HEIGHT
                * Float32(INTERACTION_SHOWCASE_VISIBLE_ROWS),
        )

    def _tree_key_at(self, point: Point, canvas: Rect) -> Int:
        var tree_width: Float32 = 190.0
        var table_width = self._table_width(canvas)
        if canvas.width - tree_width - 42.0 < 280.0:
            tree_width = 150.0
        if canvas.width - tree_width - 42.0 < 200.0:
            return -1
        var local_x = point.x - canvas.x
        var local_y = point.y - canvas.y
        var tree_left = table_width + 32.0
        if local_x < tree_left or local_x >= tree_left + tree_width:
            return -1
        var index = Int((local_y - 58.0) / 28.0)
        if index < 0:
            return -1
        var visible = self.tree.visible_keys()
        if index >= len(visible):
            return -1
        return visible[index]

    def _row_index_at(self, point: Point, canvas: Rect) -> Int:
        var local_x = point.x - canvas.x
        var local_y = point.y - canvas.y
        var table_width = self._table_width(canvas)
        if local_x < 22.0 or local_x >= table_width:
            return -1
        var rows_top = 16.0 + INTERACTION_SHOWCASE_HEADER_HEIGHT
        if local_y < rows_top:
            return -1
        var row = Int((local_y - rows_top) / INTERACTION_SHOWCASE_ROW_HEIGHT)
        if row < 0 or row >= INTERACTION_SHOWCASE_VISIBLE_ROWS:
            return -1
        row += Int(self.scrollbar.offset / INTERACTION_SHOWCASE_ROW_HEIGHT)
        if row < 0 or row >= self.collection.item_count():
            return -1
        return row

    def _tree_parent(self, key: Int) -> Int:
        for index in range(len(self.tree.nodes)):
            if self.tree.nodes[index].key == key:
                return self.tree.nodes[index].parent_key
        return -1

    def _tree_depth(self, key: Int) -> Int:
        var depth = 0
        var parent = self._tree_parent(key)
        while parent >= 0 and depth < 8:
            depth += 1
            parent = self._tree_parent(parent)
        return depth

    def _tree_has_children(self, key: Int) -> Bool:
        for index in range(len(self.tree.nodes)):
            if self.tree.nodes[index].parent_key == key:
                return True
        return False

    def _popup_rect(self, bounds: Rect, index: Int) -> Rect:
        var entry = self.popups.entries[index]
        return Rect(
            bounds.x + entry.bounds.x,
            bounds.y + entry.bounds.y,
            entry.bounds.width,
            entry.bounds.height,
        )

    def _open_menu(mut self):
        var anchor = Rect(420.0, 40.0, 130.0, 28.0)
        var popup = place_popup(
            anchor,
            Size(190.0, 118.0),
            Rect(0.0, 0.0, 700.0, 270.0),
            POPUP_PLACE_BELOW,
        )
        _ = self.popups.open_root(
            INTERACTION_SHOWCASE_MENU_POPUP_ID,
            POPUP_MENU,
            INTERACTION_SHOWCASE_MENU_ID,
            anchor,
            popup,
            POPUP_PLACE_BELOW,
            False,
            700,
            -1,
        )
        var actions = List[Int]()
        actions.append(INTERACTION_SHOWCASE_MENU_ACTION_ID)
        actions.append(INTERACTION_SHOWCASE_CONTEXT_ACTION_ID)
        actions.append(INTERACTION_SHOWCASE_DIALOG_ACCEPT_ID)
        _ = self.popups.set_actions(
            INTERACTION_SHOWCASE_MENU_POPUP_ID,
            actions,
        )

        var nested_anchor = Rect(popup.x + 12.0, popup.y + 38.0, 130.0, 24.0)
        var nested = place_popup(
            nested_anchor,
            Size(164.0, 82.0),
            Rect(0.0, 0.0, 700.0, 270.0),
            POPUP_PLACE_RIGHT,
        )
        _ = self.popups.open(
            INTERACTION_SHOWCASE_CONTEXT_POPUP_ID,
            POPUP_CONTEXT_MENU,
            INTERACTION_SHOWCASE_MENU_POPUP_ID,
            nested_anchor,
            nested,
            POPUP_PLACE_RIGHT,
            False,
            701,
            700,
        )
        var nested_actions = List[Int]()
        nested_actions.append(INTERACTION_SHOWCASE_CONTEXT_ACTION_ID)
        nested_actions.append(INTERACTION_SHOWCASE_MENU_ACTION_ID)
        _ = self.popups.set_actions(
            INTERACTION_SHOWCASE_CONTEXT_POPUP_ID,
            nested_actions,
        )
        self.status = "Nested menu open · arrows navigate · Esc restores focus."

    def _open_dialog(mut self):
        var anchor = Rect(250.0, 40.0, 120.0, 28.0)
        var popup = place_popup(
            anchor,
            Size(300.0, 154.0),
            Rect(0.0, 0.0, 700.0, 270.0),
            POPUP_PLACE_BELOW,
        )
        _ = self.popups.open_root(
            INTERACTION_SHOWCASE_DIALOG_POPUP_ID,
            POPUP_DIALOG,
            INTERACTION_SHOWCASE_DIALOG_ID,
            anchor,
            popup,
            POPUP_PLACE_BELOW,
            True,
            702,
            -1,
        )
        var actions = List[Int]()
        actions.append(INTERACTION_SHOWCASE_DIALOG_ACCEPT_ID)
        actions.append(INTERACTION_SHOWCASE_DIALOG_CANCEL_ID)
        _ = self.popups.set_actions(
            INTERACTION_SHOWCASE_DIALOG_POPUP_ID,
            actions,
        )
        self.status = "Modal dialog open · focus is trapped until Esc or Enter."

    def _move_selected(mut self) -> Bool:
        var source = self._selected_index()
        var count = self.collection.item_count()
        if count < 2:
            return False
        var destination = source + 2
        if destination >= count:
            destination = 0
        var key = self.collection.key_at(source)
        self.reorder.reset()
        if not self.reorder.begin(key, source, Point(0.0, 0.0), 1):
            return False
        _ = self.reorder.update(1, Point(12.0, 0.0))
        _ = self.reorder.set_destination(1, destination)
        var command = self.reorder.drop(1, destination)
        if not command.changed:
            return False
        var applied = self.collection.reorder(
            command.from_index,
            command.to_index,
        )
        if not applied.changed:
            return False
        self.status = String(
            "Reordered stable key ",
            command.key,
            " from ",
            command.from_index,
            " to ",
            command.to_index,
            ".",
        )
        return True

    def _handle_pointer(mut self, event: Event, view: ColumnView) -> Bool:
        var canvas = self._canvas_bounds(view)
        var active = self.reorder.is_armed() or self.reorder.is_dragging()
        if self.popups.is_open():
            return False

        if event.kind == POINTER_DOWN_KIND and event.target == INTERACTION_SHOWCASE_CANVAS_ID:
            var track = self._scrollbar_track(canvas)
            var scrollbar_hit = self.scrollbar.hit_test(track, event.position)
            if scrollbar_hit == SCROLLBAR_HIT_THUMB:
                var geometry = self.scrollbar.geometry(track)
                self.scrollbar_pointer_id = event.pointer_id
                self.scrollbar_grab_offset = event.position.y - geometry.thumb.y
                self.status = "Dragging scrollbar thumb."
                return True
            if scrollbar_hit == SCROLLBAR_HIT_TRACK:
                if self.scrollbar.handle_track_click(track, event.position):
                    self.status = String(
                        "Paged to scrollbar offset ",
                        self.scrollbar.offset,
                        ".",
                    )
                    return True

            var row = self._row_index_at(event.position, canvas)
            if row < 0:
                return False
            var extend = (event.modifiers & MOD_SHIFT) != 0
            var toggle = (event.modifiers & (MOD_COMMAND | MOD_CONTROL)) != 0
            _ = self.collection.select_index(row, extend, toggle)
            var key = self.collection.key_at(row)
            self.reorder.reset()
            if self.reorder.begin(key, row, event.position, event.pointer_id):
                self.status = String("Armed stable key ", key, " · move to drag.")
                return True
            return False

        if (
            (event.kind == POINTER_MOVE_KIND or event.kind == DRAG_UPDATE_KIND)
            and self.scrollbar_pointer_id >= 0
        ):
            if event.pointer_id != self.scrollbar_pointer_id:
                return False
            var track = self._scrollbar_track(canvas)
            var next = self.scrollbar.offset_for_thumb_position(
                track,
                event.position,
                self.scrollbar_grab_offset,
            )
            if self.scrollbar.set_offset(next):
                self.status = String(
                    "Dragging scrollbar · offset ",
                    self.scrollbar.offset,
                    ".",
                )
                return True
            return False

        if (
            (
                event.kind == POINTER_UP_KIND
                or event.kind == DROP_KIND
                or event.kind == CLICK_KIND
            )
            and self.scrollbar_pointer_id >= 0
        ):
            if event.pointer_id != self.scrollbar_pointer_id:
                return False
            self.scrollbar_pointer_id = -1
            self.scrollbar_grab_offset = 0.0
            self.status = String(
                "Scrollbar released at offset ",
                self.scrollbar.offset,
                ".",
            )
            return True

        if event.kind == POINTER_CANCEL_KIND and self.scrollbar_pointer_id >= 0:
            if event.pointer_id != self.scrollbar_pointer_id:
                return False
            self.scrollbar_pointer_id = -1
            self.scrollbar_grab_offset = 0.0
            self.status = "Scrollbar drag cancelled."
            return True

        if (
            event.kind == DRAG_BEGIN_KIND
            and (active or self.scrollbar_pointer_id >= 0)
        ):
            return True

        if (
            (event.kind == POINTER_MOVE_KIND or event.kind == DRAG_UPDATE_KIND)
            and active
        ):
            var moved = self.reorder.update(event.pointer_id, event.position)
            if not moved:
                return False
            if self.reorder.is_dragging():
                var destination = self._row_index_at(event.position, canvas)
                if destination >= 0:
                    _ = self.reorder.set_destination(
                        event.pointer_id,
                        destination,
                    )
                self.status = String(
                    "Dragging stable key ",
                    self.reorder.key,
                    " · destination ",
                    self.reorder.to_index,
                    ".",
                )
            return True

        if (
            (
                event.kind == POINTER_UP_KIND
                or event.kind == DROP_KIND
                or event.kind == CLICK_KIND
            )
            and active
        ):
            var destination = self._row_index_at(event.position, canvas)
            var command = self.reorder.drop(event.pointer_id, destination)
            if command.changed:
                var applied = self.collection.reorder(
                    command.from_index,
                    command.to_index,
                )
                self.status = String(
                    "Dropped stable key ",
                    command.key,
                    " at ",
                    applied.to_index,
                    ".",
                )
            elif self.reorder.is_cancelled():
                self.status = "Reorder cancelled · collection unchanged."
            else:
                self.status = "Click retained selection · no reorder emitted."
            return True

        if event.kind == CLICK_KIND:
            var tree_key = self._tree_key_at(event.position, canvas)
            if tree_key >= 0:
                var selected = self.tree.select_key(tree_key)
                var toggled = False
                if self._tree_has_children(tree_key):
                    toggled = self.tree.toggle_expanded(tree_key)
                if selected or toggled:
                    self.status = String(
                        "Tree node ",
                        tree_key,
                        " selected · ",
                        "expanded" if self.tree.is_expanded(tree_key) else "collapsed",
                        ".",
                    )
                    return True
                return False

        if event.kind == POINTER_CANCEL_KIND and active:
            if self.reorder.cancel_pointer(event.pointer_id):
                self.status = "Pointer cancelled · collection unchanged."
                return True
        return False

    def _handle_popup_input(mut self, event: Event, view: ColumnView) -> Bool:
        # A non-modal popup closes on pointer-down outside its bounds. Keep
        # consuming that pointer's terminal events after the layer disappears;
        # otherwise App's captured release can synthesize a click for the
        # underlying table or tree.
        if self.dismissed_popup_pointer_id >= 0:
            if event.kind == POINTER_DOWN_KIND:
                # A fresh press starts a new stream. This matters for hosts
                # that reuse pointer id 0 and deliver a second down before a
                # synthetic terminal event for the previous stream.
                self.dismissed_popup_pointer_id = -1
            elif event.pointer_id != self.dismissed_popup_pointer_id:
                return False
            if event.kind != POINTER_DOWN_KIND and (
                event.kind == POINTER_MOVE_KIND
                or event.kind == DRAG_BEGIN_KIND
                or event.kind == DRAG_UPDATE_KIND
                or event.kind == POINTER_UP_KIND
                or event.kind == POINTER_CANCEL_KIND
                or event.kind == DROP_KIND
                or event.kind == CLICK_KIND
            ):
                self.dismissed_popup_pointer_id = -1
                return True
            if event.kind != POINTER_DOWN_KIND:
                return False
        if not self.popups.is_open():
            return False
        var canvas = self._canvas_bounds(view)
        if event.kind == KEY_DOWN_KIND:
            var action = self.popups.highlighted_action()
            var depth = self.popups.depth()
            if self.popups.handle_key(event.key):
                if event.key == KEY_ESCAPE:
                    self.status = String(
                        "Closed popup · focus restored to ",
                        self.popups.restored_focus_target(),
                        ".",
                    )
                elif (
                    (event.key == KEY_ENTER or event.key == KEY_SPACE)
                    and action >= 0
                ):
                    self.status = String("Activated popup action ", action, ".")
                elif self.popups.depth() != depth:
                    self.status = "Closed nested popup · parent layer remains."
                else:
                    self.status = String(
                        "Popup highlight ",
                        self.popups.highlighted_action(),
                        ".",
                    )
                return True
        if event.kind == POINTER_DOWN_KIND:
            self.dismissed_popup_pointer_id = -1
            var local = Point(
                event.position.x - canvas.x,
                event.position.y - canvas.y,
            )
            var top_index = self.popups.depth() - 1
            var entry = self.popups.entries[top_index]
            if entry.bounds.contains(local) or entry.anchor.contains(local):
                # Keep the pointer stream in the scene-owned popup layer. The
                # eventual click event performs activation after release.
                return True
            if self.popups.dismiss_if_outside(local):
                self.dismissed_popup_pointer_id = event.pointer_id
                self.status = "Dismissed popup outside its bounds."
                return True
            # Modal layers consume outside presses even though they cannot be
            # dismissed by them.
            return True
        if (
            event.kind == POINTER_MOVE_KIND
            or event.kind == POINTER_UP_KIND
            or event.kind == POINTER_CANCEL_KIND
            or event.kind == DRAG_BEGIN_KIND
            or event.kind == DRAG_UPDATE_KIND
            or event.kind == DROP_KIND
        ):
            # Popup geometry is scene-owned. Consume the rest of a pointer
            # stream even when the pointer is over the underlying canvas.
            return True
        if event.kind == CLICK_KIND:
            var local = Point(
                event.position.x - canvas.x,
                event.position.y - canvas.y,
            )
            var top_index = self.popups.depth() - 1
            var entry = self.popups.entries[top_index]
            if entry.bounds.contains(local):
                var action_offset = local.y - entry.bounds.y - 36.0
                if action_offset >= 0.0:
                    var action_index = Int(action_offset / 28.0)
                    if action_index < entry.action_count():
                        _ = self.popups.set_highlighted_index(action_index)
                        var action = self.popups.activate_top()
                        self.status = String(
                            "Activated popup action ",
                            action,
                            " by pointer.",
                        )
                return True
            if self.popups.dismiss_if_outside(local):
                self.status = "Dismissed popup outside its bounds."
                return True
            return True
        return False

    def build(self, bounds: Rect) -> ColumnView:
        var root = ColumnView(bounds, 18.0, 10.0)
        root.set_surface_style(default_surface_style())
        var panel_width = bounds.width - 32.0
        var panel_height = bounds.height - 32.0
        if panel_width < 0.0:
            panel_width = 0.0
        if panel_height < 0.0:
            panel_height = 0.0
        root.set_panel(
            0,
            Rect(bounds.x + 16.0, bounds.y + 16.0, panel_width, panel_height),
            default_panel_style(),
        )

        root.add(
            LabelControl(
                INTERACTION_SHOWCASE_TITLE_ID,
                "Collection & interaction lab",
                34.0,
                _label_style(26.0, _ink()),
            ).node()
        )
        var body = LabelControl(
            INTERACTION_SHOWCASE_BODY_ID,
            "A live table, tree, scrollbar, popup stack, and reorder gesture share one state-first component. Sparse stable keys make identity preservation visible.",
            0.0,
            _label_style(14.0, _muted_ink()),
        )
        var body_node = body.node()
        body_node.set_wrap_text()
        root.add(body_node)
        root.set_preferred_width(INTERACTION_SHOWCASE_BODY_ID, bounds.width - 64.0)
        root.set_intrinsic_height(INTERACTION_SHOWCASE_BODY_ID)

        var controls = root.add_row(
            20,
            0.0,
            38.0,
            0.0,
            6.0,
        )
        var select_button = ButtonControl(
            INTERACTION_SHOWCASE_SELECT_NEXT_ID,
            "Select next",
            34.0,
            _button_style(),
        )
        root.add_to(controls, select_button.node())
        root.set_fixed_width(INTERACTION_SHOWCASE_SELECT_NEXT_ID, 96.0)
        var move_button = ButtonControl(
            INTERACTION_SHOWCASE_MOVE_ID,
            "Move selected",
            34.0,
            _button_style(),
        )
        root.add_to(controls, move_button.node())
        root.set_fixed_width(INTERACTION_SHOWCASE_MOVE_ID, 112.0)
        var sort_button = ButtonControl(
            INTERACTION_SHOWCASE_SORT_ID,
            "Sort Name",
            34.0,
            _button_style(
                self.columns[0].sort_order == COLUMN_SORT_ASCENDING
            ),
        )
        root.add_to(controls, sort_button.node())
        root.set_fixed_width(INTERACTION_SHOWCASE_SORT_ID, 94.0)
        var back_button = ButtonControl(
            INTERACTION_SHOWCASE_SCROLL_BACK_ID,
            "Scroll -",
            34.0,
            _button_style(),
        )
        root.add_to(controls, back_button.node())
        root.set_fixed_width(INTERACTION_SHOWCASE_SCROLL_BACK_ID, 82.0)
        var forward_button = ButtonControl(
            INTERACTION_SHOWCASE_SCROLL_FORWARD_ID,
            "Scroll +",
            34.0,
            _button_style(),
        )
        root.add_to(controls, forward_button.node())
        root.set_fixed_width(INTERACTION_SHOWCASE_SCROLL_FORWARD_ID, 82.0)

        var layers = root.add_row(
            21,
            0.0,
            38.0,
            0.0,
            6.0,
        )
        var tree_button = ButtonControl(
            INTERACTION_SHOWCASE_TREE_ID,
            "Toggle tree",
            34.0,
            _button_style(self.tree.is_expanded(10)),
        )
        root.add_to(layers, tree_button.node())
        root.set_fixed_width(INTERACTION_SHOWCASE_TREE_ID, 104.0)
        var menu_button = ButtonControl(
            INTERACTION_SHOWCASE_MENU_ID,
            "Nested menu",
            34.0,
            _button_style(self.popups.top_kind() == POPUP_CONTEXT_MENU),
        )
        root.add_to(layers, menu_button.node())
        root.set_fixed_width(INTERACTION_SHOWCASE_MENU_ID, 108.0)
        var dialog_button = ButtonControl(
            INTERACTION_SHOWCASE_DIALOG_ID,
            "Modal dialog",
            34.0,
            _button_style(self.popups.top_kind() == POPUP_DIALOG),
        )
        root.add_to(layers, dialog_button.node())
        root.set_fixed_width(INTERACTION_SHOWCASE_DIALOG_ID, 106.0)
        var reset_button = ButtonControl(
            INTERACTION_SHOWCASE_RESET_ID,
            "Reset lab",
            34.0,
            _button_style(),
        )
        root.add_to(layers, reset_button.node())
        root.set_fixed_width(INTERACTION_SHOWCASE_RESET_ID, 92.0)

        var canvas_height = bounds.height - 278.0
        if canvas_height < 250.0:
            canvas_height = 250.0
        root.add_canvas(
            INTERACTION_SHOWCASE_CANVAS_ID,
            "Collection, tree, scrollbar, and popup interaction canvas",
            canvas_height,
        )
        root.set_accessibility_label(
            INTERACTION_SHOWCASE_CANVAS_ID,
            "Collection interaction canvas",
        )
        root.set_accessibility_hint(
            INTERACTION_SHOWCASE_CANVAS_ID,
            "Click a row to select, drag it to reorder, or use the mouse wheel to scroll",
        )

        root.add(
            LabelControl(
                INTERACTION_SHOWCASE_METRICS_ID,
                String(
                    "Rows ",
                    self.collection.item_count(),
                    " · selected ",
                    self.collection.selected_count(),
                    " · offset ",
                    self.scrollbar.offset,
                    " · tree visible ",
                    self.tree.selection.item_count(),
                    " · popup depth ",
                    self.popups.depth(),
                ),
                24.0,
                _label_style(12.0, _subtle_ink()),
            ).node()
        )
        root.add(
            LabelControl(
                INTERACTION_SHOWCASE_STATUS_ID,
                self.status,
                28.0,
                _label_style(13.0, _accent_ink()),
            ).node()
        )
        root.add(
            LabelControl(
                INTERACTION_SHOWCASE_INSTRUCTIONS_ID,
                "Keyboard: Up/Down selects · Shift extends · Cmd/Ctrl toggles · Esc cancels a drag or closes a popup.",
                24.0,
                _label_style(12.0, _muted_ink()),
            ).node()
        )
        root.layout()
        return root^

    def update(mut self, event: Event, view: ColumnView) -> Bool:
        if self._handle_popup_input(event, view):
            return True

        if self._handle_pointer(event, view):
            return True

        if event.kind == SCROLL_KIND:
            if self.popups.is_open():
                return True
            var canvas = self._canvas_bounds(view)
            if canvas.contains(event.position):
                if self.scrollbar.scroll_by(event.scroll_delta.y):
                    self.status = String(
                        "Scrolled to offset ",
                        self.scrollbar.offset,
                        ".",
                    )
                    return True

        if event.kind == KEY_DOWN_KIND and not self.popups.is_open():
            if event.target == INTERACTION_SHOWCASE_CANVAS_ID:
                if self.collection.handle_key(event.key, event.modifiers):
                    self.status = String(
                        "Focused stable key ",
                        self.collection.focus_key,
                        " at index ",
                        self.collection.focus_index(),
                        ".",
                    )
                    return True
            if event.key == KEY_ESCAPE and (
                self.reorder.is_armed() or self.reorder.is_dragging()
            ):
                if self.reorder.cancel():
                    self.status = "Reorder cancelled · collection unchanged."
                    return True

        if not _is_activation(event):
            return False
        if event.target == INTERACTION_SHOWCASE_SELECT_NEXT_ID:
            if self.collection.handle_key(KEY_DOWN):
                self.status = String(
                    "Focused stable key ",
                    self.collection.focus_key,
                    " at index ",
                    self.collection.focus_index(),
                    ".",
                )
                return True
            return False
        if event.target == INTERACTION_SHOWCASE_MOVE_ID:
            return self._move_selected()
        if event.target == INTERACTION_SHOWCASE_SORT_ID:
            var next = COLUMN_SORT_DESCENDING
            if self.columns[0].sort_order != COLUMN_SORT_ASCENDING:
                next = COLUMN_SORT_ASCENDING
            if self.columns[0].set_sort(next):
                self._sort_collection(next == COLUMN_SORT_DESCENDING)
                self.status = String(
                    "Name sort ",
                    "ascending" if next == COLUMN_SORT_ASCENDING else "descending",
                    ".",
                )
                return True
            return False
        if event.target == INTERACTION_SHOWCASE_SCROLL_BACK_ID:
            if self.scrollbar.apply_command(SCROLLBAR_STEP_BACKWARD):
                self.status = String("Scrolled to offset ", self.scrollbar.offset, ".")
                return True
            return False
        if event.target == INTERACTION_SHOWCASE_SCROLL_FORWARD_ID:
            if self.scrollbar.apply_command(SCROLLBAR_STEP_FORWARD):
                self.status = String("Scrolled to offset ", self.scrollbar.offset, ".")
                return True
            return False
        if event.target == INTERACTION_SHOWCASE_TREE_ID:
            if self.tree.toggle_expanded(10):
                self.status = String(
                    "Tree root ",
                    "expanded" if self.tree.is_expanded(10) else "collapsed",
                    " · visible nodes ",
                    self.tree.selection.item_count(),
                    ".",
                )
                return True
            return False
        if event.target == INTERACTION_SHOWCASE_MENU_ID:
            self._open_menu()
            return True
        if event.target == INTERACTION_SHOWCASE_DIALOG_ID:
            self._open_dialog()
            return True
        if event.target == INTERACTION_SHOWCASE_RESET_ID:
            self.reset()
            return True
        return False

    def has_scene(self) -> Bool:
        return True

    def scene(self, bounds: Rect) -> Scene:
        """Paint the state snapshot; all mutation remains in ``update``."""
        var scene = Scene()
        scene.append_rounded_rect(1, bounds, _panel_fill(), 14.0)

        var tree_width: Float32 = 190.0
        var table_width = bounds.width - tree_width - 42.0
        if table_width < 280.0:
            tree_width = 150.0
            table_width = bounds.width - tree_width - 42.0
        if table_width < 200.0:
            tree_width = 0.0
            table_width = bounds.width - 32.0

        var table_x = bounds.x + 16.0
        var table_y = bounds.y + 16.0
        var table_height = bounds.height - 32.0
        var table = Rect(table_x, table_y, table_width, table_height)
        scene.append_rounded_rect(2, table, Color(0.075, 0.11, 0.19, 1.0), 10.0)
        var header = Rect(
            table.x,
            table.y,
            table.width,
            INTERACTION_SHOWCASE_HEADER_HEIGHT,
        )
        scene.append_rounded_rect(3, header, Color(0.11, 0.17, 0.28, 1.0), 8.0)
        scene.append_text(
            4,
            self.columns[0].title,
            Rect(header.x + 12.0, header.y + 8.0, self.columns[0].width, 18.0),
            _accent_ink(),
        )
        scene.append_text(
            5,
            self.columns[1].title,
            Rect(
                header.x + self.columns[0].width + 18.0,
                header.y + 8.0,
                self.columns[1].width,
                18.0,
            ),
            _accent_ink(),
        )
        scene.append_text(
            6,
            self.columns[2].title,
            Rect(
                header.x + self.columns[0].width + self.columns[1].width + 24.0,
                header.y + 8.0,
                self.columns[2].width,
                18.0,
            ),
            _accent_ink(),
        )

        var first = Int(self.scrollbar.offset / INTERACTION_SHOWCASE_ROW_HEIGHT)
        for visible_index in range(INTERACTION_SHOWCASE_VISIBLE_ROWS):
            var data_index = first + visible_index
            if data_index >= self.collection.item_count():
                break
            var key = self.collection.key_at(data_index)
            var row = Rect(
                table.x + 6.0,
                table.y
                    + INTERACTION_SHOWCASE_HEADER_HEIGHT
                    + Float32(visible_index) * INTERACTION_SHOWCASE_ROW_HEIGHT,
                table.width - 26.0,
                INTERACTION_SHOWCASE_ROW_HEIGHT - 4.0,
            )
            var fill = Color(0.09, 0.13, 0.22, 1.0)
            if visible_index % 2 == 1:
                fill = Color(0.082, 0.12, 0.20, 1.0)
            if self.collection.is_selected(key):
                fill = _accent_fill()
            if self.reorder.is_dragging() and self.reorder.key == key:
                fill = Color(0.20, 0.56, 0.72, 1.0)
            scene.append_rounded_rect(20 + visible_index, row, fill, 5.0)
            scene.append_text(
                40 + visible_index,
                String("row-", key),
                Rect(row.x + 10.0, row.y + 7.0, self.columns[0].width, 18.0),
                _ink(),
            )
            var state_text = "ready"
            if self.collection.is_selected(key):
                state_text = "selected"
            if self.reorder.is_dragging() and self.reorder.key == key:
                state_text = "dragging"
            scene.append_text(
                60 + visible_index,
                state_text,
                Rect(
                    row.x + self.columns[0].width + 16.0,
                    row.y + 7.0,
                    self.columns[1].width,
                    18.0,
                ),
                _muted_ink(),
            )
            scene.append_text(
                80 + visible_index,
                String("#", key),
                Rect(
                    row.x + self.columns[0].width + self.columns[1].width + 22.0,
                    row.y + 7.0,
                    self.columns[2].width,
                    18.0,
                ),
                _subtle_ink(),
            )

        var track = Rect(
            table.x + table.width - 16.0,
            table.y + INTERACTION_SHOWCASE_HEADER_HEIGHT,
            10.0,
            INTERACTION_SHOWCASE_ROW_HEIGHT
                * Float32(INTERACTION_SHOWCASE_VISIBLE_ROWS),
        )
        var scrollbar_geometry = self.scrollbar.geometry(track)
        scene.append_rounded_rect(
            90,
            scrollbar_geometry.track,
            Color(0.025, 0.045, 0.08, 1.0),
            5.0,
        )
        if scrollbar_geometry.visible:
            scene.append_rounded_rect(
                91,
                scrollbar_geometry.thumb,
                _accent_ink(),
                5.0,
            )

        if tree_width > 0.0:
            var tree_x = table.x + table.width + 16.0
            var tree = Rect(tree_x, table.y, tree_width, table_height)
            scene.append_rounded_rect(100, tree, Color(0.075, 0.11, 0.19, 1.0), 10.0)
            scene.append_text(
                101,
                "TREE / DISCLOSURE",
                Rect(tree.x + 12.0, tree.y + 12.0, tree.width - 24.0, 18.0),
                _accent_ink(),
            )
            var visible = self.tree.visible_keys()
            for index in range(len(visible)):
                var key = visible[index]
                var marker = ">"
                if self.tree.is_expanded(key):
                    marker = "v"
                var depth = self._tree_depth(key)
                var tree_row = Rect(
                    tree.x + 8.0 + Float32(depth) * 14.0,
                    tree.y + 42.0 + Float32(index) * 28.0,
                    tree.width - 20.0 - Float32(depth) * 14.0,
                    24.0,
                )
                if self.tree.selection.is_selected(key):
                    scene.append_rounded_rect(110 + index, tree_row, _accent_fill(), 5.0)
                scene.append_text(
                    130 + index,
                    String(marker, " node-", key),
                    Rect(tree_row.x + 8.0, tree_row.y + 4.0, tree_row.width - 16.0, 18.0),
                    _ink(),
                )

        if self.popups.is_open() and self.popups.top_modal():
            scene.append_rect(
                150,
                bounds,
                Color(0.0, 0.0, 0.0, 0.36),
            )
        for popup_index in range(self.popups.depth()):
            var entry = self.popups.entries[popup_index]
            var popup = self._popup_rect(bounds, popup_index)
            var popup_fill = Color(0.08, 0.13, 0.22, 0.98)
            if entry.kind == POPUP_DIALOG:
                popup_fill = Color(0.10, 0.16, 0.27, 0.99)
            scene.append_rounded_rect(160 + popup_index, popup, popup_fill, 9.0)
            var popup_title = "MENU"
            if entry.kind == POPUP_CONTEXT_MENU:
                popup_title = "NESTED MENU"
            elif entry.kind == POPUP_DIALOG:
                popup_title = "MODAL DIALOG"
            scene.append_text(
                170 + popup_index,
                popup_title,
                Rect(popup.x + 12.0, popup.y + 10.0, popup.width - 24.0, 18.0),
                _accent_ink(),
            )
            for action_index in range(entry.action_count()):
                var action_row = Rect(
                    popup.x + 8.0,
                    popup.y + 36.0 + Float32(action_index) * 28.0,
                    popup.width - 16.0,
                    24.0,
                )
                if action_index == entry.highlighted_index:
                    scene.append_rounded_rect(
                        180 + popup_index * 10 + action_index,
                        action_row,
                        _accent_fill(),
                        5.0,
                    )
                scene.append_text(
                    190 + popup_index * 10 + action_index,
                    String("action ", entry.action_at(action_index)),
                    Rect(action_row.x + 8.0, action_row.y + 4.0, action_row.width - 16.0, 18.0),
                    _ink(),
                )
        return scene^
