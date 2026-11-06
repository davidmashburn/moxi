"""Ordinary Component mounting with retained local layouts and projected publications."""
from std.collections import List, Dict
from moxi.component import Component
from moxi.column_view import ColumnView
from moxi.geometry import Point, Rect
from moxi.event import *
from moxi.view_node import ViewNode, CONTAINER_KIND, LABEL_KIND, BUTTON_KIND, TEXT_INPUT_VIEW_KIND, SLIDER_KIND
from moxi.layout import LAYOUT_STACK
from moxi.style import Color, default_panel_style
from moxi.scene import Scene
from moxi.scene_text import SceneTextStyle
from .model import *
from .geometry import *
from .interaction import *
from .commands import CanvasBinding, HostPlatform, canvas_bindings, resolve_modifier

comptime ROOT_ID = 1
comptime VIEWPORT_ID = 2
comptime SURFACE_FOCUS_ID = 3
comptime STATUS_ID = 4
comptime TOOLBAR_BASE = 100
comptime CONTROL_BASE = 10000
comptime ID_STRIDE = 1000
comptime HEADER_HEIGHT = 32


@fieldwise_init
struct PointerPreparation(Equatable, ImplicitlyCopyable):
    var value: Int
    comptime UNCHANGED = Self(0)
    comptime PUBLISH = Self(1)
    comptime CONSUMED = Self(2)


struct MountedComponent[Child: Component & Deinitable](ImplicitlyCopyable):
    var id: Int
    var child: Self.Child
    var nodes: List[ViewNode]
    var width: Float32
    var height: Float32
    var builds: Int
    var measurements: Int

    def __init__(out self, id: Int, child: Self.Child, bounds: Rect):
        self.id = id
        self.child = child
        self.nodes = List[ViewNode]()
        self.width = 0
        self.height = 0
        self.builds = 0
        self.measurements = 0
        self.refresh(bounds)

    def __init__(out self, *, copy: Self):
        self.id = copy.id
        self.child = copy.child
        self.nodes = copy.nodes.copy()
        self.width = copy.width
        self.height = copy.height
        self.builds = copy.builds
        self.measurements = copy.measurements

    def refresh(mut self, bounds: Rect):
        var view = self.child.build(Rect(0, HEADER_HEIGHT, bounds.width, max(Float32(1), bounds.height - HEADER_HEIGHT)))
        self.nodes = view.children.copy()
        self.width = bounds.width
        self.height = bounds.height
        self.builds += 1
        # Layout invocation count, not a claim about underlying shaping calls.
        self.measurements += 1


struct ContentVersion[Child: Component & Deinitable](ImplicitlyCopyable):
    var before: List[MountedComponent[Self.Child]]
    var after: List[MountedComponent[Self.Child]]

    def __init__(out self, before: List[MountedComponent[Self.Child]], after: List[MountedComponent[Self.Child]]):
        self.before = before.copy()
        self.after = after.copy()

    def __init__(out self, *, copy: Self):
        self.before = copy.before.copy()
        self.after = copy.after.copy()


struct CanvasView[Child: Component & Deinitable](Component):
    """Public surface. Components own controls; CanvasState owns manipulation.

    Child-local IDs must be in [0, 998). Namespace IDs are stable across camera,
    culling, and sibling edits. One mount per stable object. Component content is
    retained even when its published view is culled. No native overlay is faked.
    """
    var destination: CanvasDocument
    var has_destination: Bool
    var destination_title: String
    var bindings: List[CanvasBinding]
    var pending_command: CanvasCommand
    var publication: CanvasSnapshot
    var geometry_cache: GeometryCache
    var document: CanvasDocument
    var state: CanvasState
    var policy: ConnectionPolicy
    var mounts: List[MountedComponent[Self.Child]]
    var content_history: List[ContentVersion[Self.Child]]
    var editor: Int
    var content_before: List[MountedComponent[Self.Child]]
    var content_document_before: CanvasDocument
    var content_dirty: Bool
    var control_pointer: Int
    var control_owner: Int
    var parent_scroll: Float32
    var parent_builds: Int
    var last_child_nodes: Int
    var search: String
    var searching: Bool
    var search_index: Int

    def __init__(out self, document: CanvasDocument, viewport: Rect = Rect(20, 100, 980, 580)):
        self.destination = CanvasDocument()
        self.has_destination = False
        self.destination_title = ""
        self.bindings = List[CanvasBinding]()
        self.pending_command = CanvasCommand.NONE
        self.geometry_cache = GeometryCache()
        self.publication = CanvasSnapshot(document, Camera(viewport))
        self.document = document
        self.state = CanvasState(Camera(viewport))
        self.policy = ConnectionPolicy()
        self.mounts = List[MountedComponent[Self.Child]]()
        self.content_history = List[ContentVersion[Self.Child]]()
        self.editor = -1
        self.content_before = List[MountedComponent[Self.Child]]()
        self.content_document_before = document
        self.content_dirty = False
        self.control_pointer = -1
        self.control_owner = -1
        self.parent_scroll = 0
        self.parent_builds = 0
        self.last_child_nodes = 0
        self.search = ""
        self.searching = False
        self.search_index = 0

    def __init__(out self, *, copy: Self):
        self.destination = copy.destination
        self.has_destination = copy.has_destination
        self.destination_title = copy.destination_title
        self.bindings = copy.bindings.copy()
        self.pending_command = copy.pending_command
        self.geometry_cache = copy.geometry_cache
        self.publication = copy.publication
        self.document = copy.document
        self.state = copy.state
        self.policy = copy.policy
        self.mounts = copy.mounts.copy()
        self.content_history = copy.content_history.copy()
        self.editor = copy.editor
        self.content_before = copy.content_before.copy()
        self.content_document_before = copy.content_document_before
        self.content_dirty = copy.content_dirty
        self.control_pointer = copy.control_pointer
        self.control_owner = copy.control_owner
        self.parent_scroll = copy.parent_scroll
        self.parent_builds = copy.parent_builds
        self.last_child_nodes = copy.last_child_nodes
        self.search = copy.search
        self.searching = copy.searching
        self.search_index = copy.search_index

    def mount(mut self, id: Int, child: Self.Child) raises:
        if id not in self.document.object_index or id >= 1000000:
            raise Error("Mount requires a bounded stable object ID")
        for prior in self.mounts:
            if prior.id == id:
                raise Error("Object already mounted")
        var mounted = MountedComponent[Self.Child](id, child, self.document.world_bounds(id))
        for node in mounted.nodes:
            if node.id < 0 or node.id >= ID_STRIDE - 2:
                raise Error("Child IDs must be in [0, 998)")
        self.mounts.append(mounted)

    def control_id(self, object: Int, local: Int) -> Int:
        return CONTROL_BASE + object * ID_STRIDE + local

    def mount_index(self, id: Int) -> Int:
        for i in range(len(self.mounts)):
            if self.mounts[i].id == id:
                return i
        return -1

    def snapshot(self) -> CanvasSnapshot:
        return self.publication

    def supports_localized_execution(self) -> Bool:
        return True

    def localized_last_child_nodes(self) -> Int:
        return self.last_child_nodes

    def localized_last_child_commands(self) -> Int:
        return self.last_child_nodes

    def localized_view(mut self, bounds: Rect) -> ColumnView:
        self.parent_builds += 1
        self.state.camera.viewport = Rect(bounds.x + 20, bounds.y + 100 - self.parent_scroll, max(Float32(100), bounds.width - 40), max(Float32(100), bounds.height - 130))
        var preview = self.presentation_document()
        for i in range(len(self.mounts)):
            var rect = preview.world_bounds(self.mounts[i].id)
            if rect.width > 0 and (rect.width != self.mounts[i].width or rect.height != self.mounts[i].height):
                self.mounts[i].refresh(rect)
                self.last_child_nodes += len(self.mounts[i].nodes)
        self.geometry_cache.prune(preview)
        self.publication = CanvasSnapshot(preview, self.state.camera, self.editor, self.geometry_cache)
        return self.build(bounds)

    def build(self, bounds: Rect) -> ColumnView:
        var root = ColumnView(bounds, 0, 0)
        root.published_geometry = True
        root.clip_to_bounds = True
        root.surface_style.fill = Color(0.055, 0.073, 0.11, 1)
        var container = ViewNode(CONTAINER_KIND, ROOT_ID, "Canvas workspace", bounds.height)
        container.bounds = bounds
        container.container_layout_kind = LAYOUT_STACK
        root.add(container)
        var outer = ViewNode(CONTAINER_KIND, 6, "Scrollable parent · wheel in margin", bounds.height - 130)
        outer.bounds = Rect(bounds.x + 20, bounds.y + 100, bounds.width - 40, bounds.height - 130)
        outer.parent_id = ROOT_ID
        outer.container_layout_kind = LAYOUT_STACK
        outer.clip_children = True
        root.add(outer)
        var clip = ViewNode(CONTAINER_KIND, VIEWPORT_ID, "Canvas viewport", self.state.camera.viewport.height)
        clip.bounds = self.state.camera.viewport
        clip.parent_id = 6
        clip.container_layout_kind = LAYOUT_STACK
        clip.clip_children = True
        root.add(clip)
        var surface = ViewNode(BUTTON_KIND, SURFACE_FOCUS_ID, "", self.state.camera.viewport.height)
        surface.bounds = self.state.camera.viewport
        surface.parent_id = VIEWPORT_ID
        surface.style.fill = Color(0.075, 0.10, 0.15, 1)
        surface.style.border_width = 0
        surface.semantics.label = "Canvas. Arrows navigate; M move; R resize; C connect; slash search; Enter edit."
        root.add(surface)
        var preview = self.presentation_document()
        var snapshot = self.snapshot()
        for object in preview.objects:
            if object.id not in snapshot.visible:
                continue
            var object_bounds = self.state.camera.rect(preview.world_bounds(object.id))
            var panel = ViewNode(CONTAINER_KIND, self.control_id(object.id, ID_STRIDE - 1), object.title, object_bounds.height)
            panel.bounds = object_bounds
            panel.parent_id = VIEWPORT_ID
            panel.container_layout_kind = LAYOUT_STACK
            panel.component_surface = True
            panel.clip_children = True
            panel.style = default_panel_style()
            panel.style.fill = Color(0.12, 0.20, 0.26, 1) if object.kind == ObjectKind.GROUP else Color(0.13, 0.17, 0.24, 1)
            panel.style.border = Color(0.35, 0.85, 0.95, 1) if self.state.is_selected(object.id) else Color(0.26, 0.32, 0.43, 1)
            panel.style.border_width = 2
            panel.semantics.label = object.title
            panel.semantics.selected = self.state.is_selected(object.id)
            panel.semantics.bounds = object_bounds.intersection(self.state.camera.viewport)
            root.add(panel)
            var header = ViewNode(LABEL_KIND, self.control_id(object.id, 998), object.title, Float32(HEADER_HEIGHT) * Float32(self.state.camera.zoom))
            header.bounds = Rect(object_bounds.x + 10, object_bounds.y + 3, object_bounds.width - 20, Float32(HEADER_HEIGHT) * Float32(self.state.camera.zoom) - 4)
            header.style.font_size = 15 * Float32(self.state.camera.zoom)
            header.style.text = Color(0.82, 0.94, 1, 1)
            header.parent_id = panel.id
            root.add(header)
            var index = self.mount_index(object.id)
            if index < 0:
                continue
            for child in self.mounts[index].nodes:
                var projected = child
                projected.id = self.control_id(object.id, child.id)
                projected.parent_id = panel.id if child.parent_id < 0 else self.control_id(object.id, child.parent_id)
                var world = preview.world_bounds(object.id)
                var local = child.bounds
                local.x += world.x
                local.y += world.y
                projected.bounds = self.state.camera.rect(local)
                projected.style.font_size *= Float32(self.state.camera.zoom)
                projected.style.corner_radius *= Float32(self.state.camera.zoom)
                projected.style.border_width *= Float32(self.state.camera.zoom)
                projected.semantics.id = projected.id
                projected.semantics.parent_id = projected.parent_id
                projected.semantics.bounds = projected.bounds.intersection(object_bounds).intersection(self.state.camera.viewport)
                # Roving canvas entry; controls become tab stops only on entry.
                projected.focusable = child.focusable and self.editor == object.id
                root.add(projected)
        var toolbar = List[CanvasCommand]([CanvasCommand.UNDO, CanvasCommand.REDO, CanvasCommand.MOVE, CanvasCommand.RESIZE, CanvasCommand.CONNECT, CanvasCommand.RECONNECT, CanvasCommand.DELETE, CanvasCommand.FIT_ALL, CanvasCommand.ZOOM_IN, CanvasCommand.ZOOM_OUT])
        var width = (bounds.width - 40) / Float32(len(toolbar))
        for i in range(len(toolbar)):
            var button = ViewNode(BUTTON_KIND, TOOLBAR_BASE + toolbar[i].value, command_title(toolbar[i]), 30)
            button.bounds = Rect(20 + Float32(i) * width, 16, width - 5, 30)
            button.parent_id = ROOT_ID
            button.style.font_size = 10
            button.enabled = self.state.enabled(toolbar[i], self.document) == ""
            button.semantics.hint = self.state.enabled(toolbar[i], self.document)
            root.add(button)
        var status = ViewNode(LABEL_KIND, STATUS_ID, self.state.status, 30)
        status.bounds = Rect(20, 57, bounds.width - 40, 30)
        status.parent_id = ROOT_ID
        status.style.font_size = 13
        status.style.text = Color(0.75, 0.87, 0.96, 1)
        root.add(status)
        if self.searching:
            var results = self.search_results()
            var text = String("Search: ", self.search, "   ↑↓ choose · Enter run · Esc close\n")
            for i in range(min(len(results), 9)):
                text += String("› " if i == self.search_index else "  ", results[i], "\n")
            var search = ViewNode(LABEL_KIND, 5, text, 240)
            search.bounds = Rect(80, 110, min(Float32(650), bounds.width - 160), 240)
            search.parent_id = ROOT_ID
            search.style.fill = Color(0.1, 0.12, 0.2, 1)
            search.style.text = Color(1, 1, 1, 1)
            search.wrap_text = True
            root.add(search)
        return root^

    def child_view(self, object: Int, view: ColumnView) -> ColumnView:
        var local = ColumnView(self.state.camera.rect(self.document.world_bounds(object)), 0, 0)
        local.published_geometry = True
        var offset = self.control_id(object, 0)
        for child in view.children:
            if child.id >= offset and child.id < offset + 998:
                var node = child
                node.id -= offset
                node.parent_id = -1 if child.parent_id == offset + 999 else child.parent_id - offset
                local.add(node)
        return local^

    def control_at(self, point: Point, view: ColumnView) -> Int:
        # Structural ownership: any enabled ordinary interactive leaf owns input,
        # even before it becomes a tab stop. No nodrag exclusion list.
        for i in range(len(view.children) - 1, -1, -1):
            var child = view.children[i]
            if child.id < CONTROL_BASE or child.id % ID_STRIDE >= 998:
                continue
            var object = (child.id - CONTROL_BASE) // ID_STRIDE
            var index = self.mount_index(object)
            if index < 0:
                continue
            var local = (child.id - CONTROL_BASE) % ID_STRIDE
            for original in self.mounts[index].nodes:
                if original.id == local and original.focusable and original.enabled and child.bounds.contains(point) and view.point_is_visible(child, point):
                    return child.id
        return -1

    def remember_content(mut self, before: List[MountedComponent[Self.Child]], cursor: Int):
        while len(self.content_history) > cursor:
            _ = self.content_history.pop()
        self.content_history.append(ContentVersion[Self.Child](before, self.mounts))
        if len(self.content_history) > self.state.history.limit:
            _ = self.content_history.pop(0)

    @no_inline
    def flush_content(mut self):
        if self.content_dirty:
            var before = self.content_document_before
            var cursor = self.state.history.cursor
            self.document.revision += 1
            self.state.history.record(before, self.document, "Edit component content")
            var content_before = self.content_before.copy()
            self.remember_content(content_before, cursor)
            self.content_dirty = False

    def command(mut self, command: CanvasCommand) -> Bool:
        self.flush_content()
        var before = self.mounts.copy()
        var cursor = self.state.history.cursor
        var revision = self.document.revision
        var changed = False
        if command == CanvasCommand.COMMIT and self.has_destination and self.state.session == SessionKind.MOVE and self.state.base_revision == self.document.revision:
            var prior = self.document
            self.document = self.destination
            self.document.revision = prior.revision + 1
            self.state.history.record(prior, self.document, self.destination_title)
            self.state.cancel()
            changed = True
        else:
            changed = self.state.dispatch(command, self.document, self.policy)
        if self.state.session == SessionKind.IDLE:
            self.has_destination = False
        if command == CanvasCommand.UNDO and changed and cursor - 1 < len(self.content_history):
            self.mounts = self.content_history[cursor - 1].before.copy()
        elif command == CanvasCommand.REDO and changed and cursor < len(self.content_history):
            self.mounts = self.content_history[cursor].after.copy()
        elif self.document.revision != revision and changed:
            self.remember_content(before, cursor)
        return changed

    def localized_dispatch(mut self, event: Event, view: ColumnView) -> Int:
        self.last_child_nodes = 0
        if self.update(event, view):
            return 2
        return 0

    def update(mut self, event: Event, view: ColumnView) -> Bool:
        if event.kind == POINTER_CANCEL_KIND:
            self.state.cancel()
            self.control_pointer = -1
            self.control_owner = -1
            return True
        if event.kind == FRAME_TICK_KIND:
            return self.state.autopan(self.document, Float64(event.delta_seconds))
        if event.kind == SCROLL_KIND and not self.interaction_clip().contains(event.position):
            if self.state.session != SessionKind.IDLE or self.control_pointer >= 0:
                return True
            self.parent_scroll = max(Float32(0), min(Float32(180), self.parent_scroll - event.scroll_delta.y))
            return True
        if event.kind == SCROLL_KIND and self.interaction_clip().contains(event.position):
            if self.state.session != SessionKind.IDLE or self.control_pointer >= 0:
                self.state.status = "Viewport frozen during manipulation"
                return True
            if (event.modifiers & MOD_COMMAND) != 0:
                self.state.camera.zoom_at(self.state.camera.zoom * (1.1 if event.scroll_delta.y > 0 else 0.9), event.position)
            else:
                self.state.camera.pan(event.scroll_delta.x, -event.scroll_delta.y)
            return True
        if event.target >= TOOLBAR_BASE and event.target < TOOLBAR_BASE + 30 and event.kind == CLICK_KIND:
            return self.command(CanvasCommand(event.target - TOOLBAR_BASE))
        var target = event.target
        if event.kind == POINTER_DOWN_KIND or event.kind == CLICK_KIND:
            var control = self.control_at(event.position, view)
            if control >= 0:
                target = control
                var owner = (target - CONTROL_BASE) // ID_STRIDE
                if self.editor != owner:
                    self.flush_content()
                    self.editor = owner
                self.state.focus = owner
                self.control_owner = target
                if event.kind == POINTER_DOWN_KIND:
                    self.control_pointer = event.pointer_id
            elif event.position.y >= self.state.camera.viewport.y:
                self.flush_content()
                self.editor = -1
        if self.control_pointer >= 0 and event.pointer_id == self.control_pointer and (event.kind == POINTER_MOVE_KIND or event.kind == DRAG_UPDATE_KIND or event.kind == POINTER_UP_KIND or event.kind == DROP_KIND):
            target = self.control_owner
        if target >= CONTROL_BASE and (target - CONTROL_BASE) % ID_STRIDE < 998:
            var owner = (target - CONTROL_BASE) // ID_STRIDE
            var index = self.mount_index(owner)
            if index >= 0:
                var routed = event
                routed.target = (target - CONTROL_BASE) % ID_STRIDE
                if not self.content_dirty:
                    self.content_before = self.mounts.copy()
                    self.content_document_before = self.document
                var local = self.child_view(owner, view)
                var changed = self.mounts[index].child.update(routed, local)
                if changed:
                    self.content_dirty = True
                    self.mounts[index].refresh(self.document.world_bounds(owner))
                    # Publish content extent and fractional port anchors atomically.
                    var required: Float32 = 0
                    for node in self.mounts[index].nodes:
                        required = max(required, node.bounds.y + node.bounds.height + 12)
                    var object_index = self.document.object_index.get(owner, -1)
                    if object_index >= 0 and required > self.document.objects[object_index].bounds.height:
                        self.document.objects[object_index].bounds.height = min(Float32(100000), required)
                        self.document.revision += 1
                        self.mounts[index].refresh(self.document.world_bounds(owner))
                    self.last_child_nodes = len(self.mounts[index].nodes)
                if event.kind == POINTER_UP_KIND or event.kind == DROP_KIND or event.kind == CLICK_KIND:
                    self.control_pointer = -1
                    self.control_owner = -1
                    if routed.target != 1:
                        self.flush_content()
                return changed or event.kind == POINTER_DOWN_KIND
        if event.kind == POINTER_DOWN_KIND and self.interaction_clip().contains(event.position):
            var snapshot = self.snapshot()
            var port = snapshot.hit_port(event.position)
            if port >= 0:
                if self.state.session == SessionKind.CONNECT:
                    self.state.target = port
                    _ = self.command(CanvasCommand.COMMIT)
                else:
                    self.state.start_connection(self.document, port, -1, event.pointer_id)
                return True
            var id = snapshot.hit_object(event.position)
            if event.buttons == 4:
                self.state.begin(self.document, SessionKind.PAN, event.position, event.pointer_id)
            elif id >= 0:
                if not self.state.is_selected(id) or (event.modifiers & MOD_SHIFT) != 0:
                    self.state.select(id, (event.modifiers & MOD_SHIFT) != 0)
                var bounds = self.state.camera.rect(self.document.world_bounds(id))
                var resize = event.position.x > bounds.x + bounds.width - 14 and event.position.y > bounds.y + bounds.height - 14
                if resize or event.position.y <= bounds.y + Float32(HEADER_HEIGHT) * Float32(self.state.camera.zoom):
                    self.state.begin(self.document, SessionKind.RESIZE if resize else SessionKind.MOVE, event.position, event.pointer_id)
            else:
                self.state.selected.clear()
                self.state.selected_edge = snapshot.hit_edge(event.position)
                if self.state.selected_edge < 0:
                    self.state.select(-1)
                    self.state.begin(self.document, SessionKind.MARQUEE, event.position, event.pointer_id)
            return True
        if event.kind == POINTER_MOVE_KIND or event.kind == DRAG_UPDATE_KIND:
            if self.state.motion(self.document, event.position, event.pointer_id):
                if self.state.session == SessionKind.CONNECT:
                    var snapshot = self.snapshot()
                    self.state.target = snapshot.hit_port(event.position, self.state.target)
                    self.state.status = self.policy.rejection(self.document, self.state.source, self.state.target, self.state.replacing)
                return True
        if event.kind == POINTER_UP_KIND or event.kind == DROP_KIND:
            if event.pointer_id == self.state.pointer:
                if self.state.session == SessionKind.CONNECT and self.state.target < 0:
                    self.state.pointer = -1
                    return True
                _ = self.command(CanvasCommand.COMMIT)
                return True
        return False

    def search_results(self) -> List[String]:
        var result = List[String]()
        for i in range(1, 34):
            var title = command_title(CanvasCommand(i))
            if self.search == "" or self.search.lower() in title.lower():
                result.append(title)
        for object in self.document.objects:
            if self.search == "" or self.search.lower() in object.title.lower():
                result.append(String("Object: ", object.title))
        return result^

    def interaction_clip(self) -> Rect:
        var viewport = self.state.camera.viewport
        return viewport.intersection(Rect(viewport.x, viewport.y + self.parent_scroll, viewport.width, viewport.height))

    def edge_scene(self) -> Scene:
        var scene = Scene()
        var snapshot = self.snapshot()
        scene.push_clip(1, self.interaction_clip())
        for edge in snapshot.edges:
            var color = Color(0.3, 0.77, 0.9, 1) if edge.id != self.state.selected_edge else Color(1, 0.8, 0.3, 1)
            for i in range(1, len(edge.points)):
                scene.append_line(edge.id, edge.points[i - 1], edge.points[i], color, 2)
            var end = edge.points[len(edge.points) - 1]
            var prev = edge.points[len(edge.points) - 2]
            var length = max(Float32(0.001), distance(prev, end))
            var dx = (end.x - prev.x) / length
            var dy = (end.y - prev.y) / length
            scene.append_line(edge.id, end, Point(end.x - dx * 10 + dy * 5, end.y - dy * 10 - dx * 5), color, 2)
            scene.append_line(edge.id, end, Point(end.x - dx * 10 - dy * 5, end.y - dy * 10 + dx * 5), color, 2)
            if edge.text != "":
                scene.append_text_styled(edge.id, edge.text, edge.label, color, SceneTextStyle("system-ui", 11))
        scene.pop_clip()
        return scene^

    def overlay_scene(self) -> Scene:
        var scene = Scene()
        var snapshot = self.snapshot()
        var camera = self.state.camera
        scene.push_clip(1, self.interaction_clip())
        for id in snapshot.ports.keys():
            var point = snapshot.ports.get(id, Point(0, 0))
            if not self.interaction_clip().contains(point):
                continue
            var color = Color(0.4, 0.9, 0.75, 1)
            if id == self.state.target:
                color = Color(0.9, 0.4, 0.3, 1) if self.policy.rejection(self.document, self.state.source, id, self.state.replacing) != "" else Color(1, 0.9, 0.3, 1)
            scene.append_rounded_rect(id, Rect(point.x - 5, point.y - 5, 10, 10), color, 5)
        if self.state.session == SessionKind.CONNECT and self.state.source in snapshot.ports:
            var end = self.state.last
            if self.state.target in snapshot.ports:
                end = snapshot.ports.get(self.state.target, Point(0, 0))
            scene.append_line(0, snapshot.ports.get(self.state.source, Point(0, 0)), end, Color(1, 0.75, 0.2, 1), 2)
        if self.state.session == SessionKind.MARQUEE:
            scene.append_rect(0, Rect(min(self.state.start.x, self.state.last.x), min(self.state.start.y, self.state.last.y), abs(self.state.last.x - self.state.start.x), abs(self.state.last.y - self.state.start.y)), Color(0.3, 0.7, 1, 0.15))
        for i in range(len(snapshot.ids)):
            if self.state.is_selected(snapshot.ids[i]):
                var bounds = snapshot.bounds[i]
                scene.append_rect(0, Rect(bounds.x + bounds.width - 10, bounds.y + bounds.height - 10, 10, 10), Color(0.5, 0.9, 1, 1))
        scene.pop_clip()
        var map = self.minimap()
        scene.append_rounded_rect(0, map.viewport, Color(0.03, 0.05, 0.09, 0.96), 7)
        scene.push_clip(0, map.viewport)
        var occupied = Dict[Int, Bool]()
        for object in self.document.objects:
            if self.document.visible(object.id):
                var rect = map.rect(self.document.world_bounds(object.id))
                if len(self.document.objects) > 512:
                    var column = max(0, min(31, Int((rect.x - map.viewport.x) / map.viewport.width * 32)))
                    var row = max(0, min(23, Int((rect.y - map.viewport.y) / map.viewport.height * 24)))
                    var key = column + row * 32
                    if key in occupied:
                        continue
                    occupied[key] = True
                    rect = Rect(map.viewport.x + Float32(column) * map.viewport.width / 32, map.viewport.y + Float32(row) * map.viewport.height / 24, map.viewport.width / 32, map.viewport.height / 24)
                scene.append_rect(object.id, rect, Color(0.22, 0.49, 0.64, 1))
        var top = camera.unproject(WindowPoint(camera.viewport.x, camera.viewport.y))
        scene.append_rect(0, map.rect(Rect(Float32(top.x), Float32(top.y), camera.viewport.width / Float32(camera.zoom), camera.viewport.height / Float32(camera.zoom))), Color(0.6, 0.85, 1, 0.16))
        scene.pop_clip()
        return scene^

    def scene(self) -> Scene:
        var scene = self.edge_scene()
        var overlay = self.overlay_scene()
        for i in range(overlay.count()):
            scene.append(overlay.command(i))
        return scene^

    def minimap(self) -> Camera:
        var viewport = self.state.camera.viewport
        var map = Camera(Rect(viewport.x + viewport.width - 180, viewport.y + viewport.height - 125, 170, 115))
        var snapshot = self.snapshot()
        var extent = snapshot.extent
        map.zoom = min(Float64(150) / Float64(max(Float32(1), extent.width)), Float64(95) / Float64(max(Float32(1), extent.height)))
        map.x = Float64(extent.x) - 10 / map.zoom
        map.y = Float64(extent.y) - 10 / map.zoom
        return map

    def group_selection(mut self, ungroup: Bool = False) -> Bool:
        self.flush_content()
        if len(self.state.selected) == 0:
            self.state.status = "Select objects to group"
            return False
        var before = self.document
        var mounts = self.mounts.copy()
        var cursor = self.state.history.cursor
        if ungroup:
            var groups = List[Int]()
            for object in self.document.objects:
                if self.state.is_selected(object.id) and object.kind == ObjectKind.GROUP:
                    groups.append(object.id)
            if len(groups) == 0:
                self.state.status = "Select a group to ungroup"
                return False
            for i in range(len(self.document.objects)):
                if self.state.is_selected(self.document.objects[i].parent):
                    var bounds = self.document.world_bounds(self.document.objects[i].id)
                    self.document.objects[i].parent = -1
                    self.document.objects[i].bounds = bounds
            self.document.remove(groups)
        else:
            var extent = Rect(0, 0, 0, 0)
            var first = True
            var id = 1
            for object in self.document.objects:
                id = max(id, object.id + 1)
                if self.state.is_selected(object.id):
                    if object.kind == ObjectKind.GROUP or object.parent >= 0:
                        self.state.status = "Only ungrouped nodes can form a one-level group"
                        return False
                    var bounds = self.document.world_bounds(object.id)
                    extent = bounds if first else union(extent, bounds)
                    first = False
            extent = Rect(extent.x - 20, extent.y - 45, extent.width + 40, extent.height + 65)
            try:
                # Groups are painted first, behind their children.
                self.document.add(CanvasObject(id, extent, "Group", -1, ObjectKind.GROUP))
                var group = self.document.objects.pop()
                self.document.objects.insert(0, group)
                self.document.reindex()
                for i in range(len(self.document.objects)):
                    if self.state.is_selected(self.document.objects[i].id):
                        self.document.objects[i].parent = id
                        self.document.objects[i].bounds.x -= extent.x
                        self.document.objects[i].bounds.y -= extent.y
                self.state.select(id)
            except e:
                self.document = before
                self.state.status = String(e)
                return False
        self.document.revision += 1
        self.state.history.record(before, self.document, "Ungroup" if ungroup else "Group")
        self.remember_content(mounts, cursor)
        return True

    def clipboard_copy(mut self, target: Int, view: ColumnView) -> String:
        var owner = (target - CONTROL_BASE) // ID_STRIDE
        var index = self.mount_index(owner)
        if index < 0:
            return ""
        var child_view = self.child_view(owner, view)
        return self.mounts[index].child.clipboard_copy((target - CONTROL_BASE) % ID_STRIDE, child_view)

    def clipboard_cut(mut self, target: Int, view: ColumnView) -> String:
        var owner = (target - CONTROL_BASE) // ID_STRIDE
        var index = self.mount_index(owner)
        if index < 0:
            return ""
        if not self.content_dirty:
            self.content_before = self.mounts.copy()
            self.content_document_before = self.document
        var child_view = self.child_view(owner, view)
        var text = self.mounts[index].child.clipboard_cut((target - CONTROL_BASE) % ID_STRIDE, child_view)
        if text != "":
            self.content_dirty = True
            self.mounts[index].refresh(self.document.world_bounds(owner))
        return text

    def clipboard_paste(mut self, target: Int, text: String, view: ColumnView) -> Bool:
        var owner = (target - CONTROL_BASE) // ID_STRIDE
        var index = self.mount_index(owner)
        if index < 0:
            return False
        if not self.content_dirty:
            self.content_before = self.mounts.copy()
            self.content_document_before = self.document
        var child_view = self.child_view(owner, view)
        var changed = self.mounts[index].child.clipboard_paste((target - CONTROL_BASE) % ID_STRIDE, text, child_view)
        if changed:
            self.content_dirty = True
            self.mounts[index].refresh(self.document.world_bounds(owner))
        return changed

    def finish_editing(mut self):
        self.flush_content()
        self.editor = -1

    def prepare_pointer(mut self, event: Event, view: ColumnView) -> PointerPreparation:
        if event.kind != POINTER_DOWN_KIND and event.kind != CLICK_KIND:
            return PointerPreparation.UNCHANGED
        var map = self.minimap()
        if map.viewport.contains(event.position):
            if self.state.session == SessionKind.IDLE:
                var world = map.unproject(WindowPoint(event.position.x, event.position.y))
                var camera = self.state.camera
                camera.x = world.x - Float64(camera.viewport.width) / (2 * camera.zoom)
                camera.y = world.y - Float64(camera.viewport.height) / (2 * camera.zoom)
                self.state.camera = camera
            return PointerPreparation.CONSUMED
        var target = self.control_at(event.position, view)
        if target >= 0:
            var owner = (target - CONTROL_BASE) // ID_STRIDE
            if self.editor != owner:
                self.flush_content()
                self.editor = owner
                return PointerPreparation.PUBLISH
        elif self.interaction_clip().contains(event.position):
            self.flush_content()
            self.editor = -1
            return PointerPreparation.PUBLISH
        return PointerPreparation.UNCHANGED

    def key_command(mut self, event: Event, host: HostPlatform) -> CanvasCommand:
        if self.searching:
            if event.key == KEY_ESCAPE:
                self.searching = False
            elif event.key == KEY_BACKSPACE:
                if self.search.count_codepoints() > 0:
                    var shortened = String(self.search[codepoint=:-1])
                    self.search = shortened^
            elif event.key == KEY_DOWN or event.key == KEY_UP:
                var count = len(self.search_results())
                if count > 0:
                    self.search_index = (self.search_index + (1 if event.key == KEY_DOWN else -1) + count) % count
            elif event.key == KEY_ENTER:
                var results = self.search_results()
                if self.search_index < len(results):
                    var chosen = results[self.search_index]
                    self.searching = False
                    for i in range(1, 34):
                        if chosen == command_title(CanvasCommand(i)):
                            return CanvasCommand(i)
                    for object in self.document.objects:
                        if chosen == String("Object: ", object.title):
                            self.state.select(object.id)
                            self.state.camera.reveal(self.document.world_bounds(object.id))
            return CanvasCommand.NONE
        if self.state.session == SessionKind.IDLE:
            var application = self.application_command(event, host)
            if application != CanvasCommand.NONE:
                return application
        if event.key == KEY_ENTER:
            return CanvasCommand.COMMIT if self.state.session != SessionKind.IDLE else CanvasCommand.ENTER_CONTROLS
        if event.key == KEY_LEFT or event.key == KEY_RIGHT or event.key == KEY_UP or event.key == KEY_DOWN:
            var direction = -1 if event.key == KEY_LEFT or event.key == KEY_UP else 1
            if self.state.session == SessionKind.CONNECT:
                self.state.choose_target(self.document, direction)
                self.state.status = self.policy.rejection(self.document, self.state.source, self.state.target, self.state.replacing)
            elif self.state.session == SessionKind.MOVE or self.state.session == SessionKind.RESIZE:
                var amount: Float32 = 10 if event.modifiers & MOD_SHIFT else 1
                if event.modifiers & MOD_OPTION:
                    amount = 0.1
                self.state.nudge(amount * Float32(direction) if event.key == KEY_LEFT or event.key == KEY_RIGHT else 0,
                                 amount * Float32(direction) if event.key == KEY_UP or event.key == KEY_DOWN else 0)
            else:
                self.state.navigation(self.document, direction, (event.modifiers & MOD_SHIFT) != 0)
            return CanvasCommand.NONE
        for binding in canvas_bindings(host):
            if event.key == binding.key and event.modifiers == resolve_modifier(binding.modifier, host):
                return binding.command
        return CanvasCommand.NONE

    def application_command(self, event: Event, host: HostPlatform) -> CanvasCommand:
        for binding in self.bindings:
            if event.key == binding.key and event.modifiers == resolve_modifier(binding.modifier, host):
                return binding.command
        return CanvasCommand.NONE

    def take_application_command(mut self) -> CanvasCommand:
        var command = self.pending_command
        self.pending_command = CanvasCommand.NONE
        return command

    def presentation_document(self) -> CanvasDocument:
        if self.has_destination and self.state.session == SessionKind.MOVE and self.state.base_revision == self.document.revision:
            return self.destination
        return self.state.preview(self.document)

    def propose_destination(mut self, proposal: CanvasDocument, title: String, expected_revision: Int) -> Bool:
        """Consumer semantic move/reparent hook. Canvas owns preview/cancel/history.

        The consumer owns domain validation and supplies a complete proposed store;
        stable identities and graph policy remain checked here. No view geometry
        synchronization is needed. Publish again after proposing a destination.
        """
        if self.state.session != SessionKind.MOVE or expected_revision != self.document.revision or self.state.base_revision != expected_revision:
            self.has_destination = False
            return False
        self.has_destination = False
        if len(proposal.objects) != len(self.document.objects) or len(proposal.ports) != len(self.document.ports) or len(proposal.edges) != len(self.document.edges):
            return False
        # This hook changes placement/parentage; graph edits use graph commands.
        for i in range(len(proposal.ports)):
            var a = proposal.ports[i]
            var b = self.document.ports[i]
            if a.id != b.id or a.object != b.object or a.direction != b.direction or a.x != b.x or a.y != b.y or a.type_id != b.type_id or a.capacity != b.capacity:
                return False
        for i in range(len(proposal.edges)):
            var a = proposal.edges[i]
            var b = self.document.edges[i]
            if a.id != b.id or a.source != b.source or a.target != b.target or a.label != b.label or a.path != b.path:
                return False
        var changed = False
        for i in range(len(proposal.objects)):
            var object = proposal.objects[i]
            var prior = self.document.objects[i]
            if object.id != prior.id or object.title != prior.title or object.kind != prior.kind or object.hidden != prior.hidden:
                return False
            changed = changed or object.parent != prior.parent or object.bounds.x != prior.bounds.x or object.bounds.y != prior.bounds.y or object.bounds.width != prior.bounds.width or object.bounds.height != prior.bounds.height
            if object.id not in self.document.object_index or not valid_bounds(object.bounds):
                return False
            if object.parent >= 0:
                var index = proposal.object_index.get(object.parent, -1)
                if index < 0 or proposal.objects[index].kind != ObjectKind.GROUP or object.kind == ObjectKind.GROUP:
                    return False
        for edge in proposal.edges:
            if self.policy.rejection(proposal, edge.source, edge.target, edge.id) != "":
                return False
        if not changed:
            return False
        self.destination = proposal
        self.has_destination = True
        self.destination_title = title
        self.state.status = String("Destination: ", title, " · Enter commits · Escape cancels")
        return True
