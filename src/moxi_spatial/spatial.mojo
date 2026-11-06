"""Typed public facade; the native core owns all spatial state and validates FFI inputs."""
from std.ffi import external_call
from std.collections import List

struct SpatialTool(ImplicitlyCopyable, Equatable):
    var value: Int32
    comptime SELECT = Self(0)
    comptime ORBIT = Self(1)
    comptime PAN = Self(2)
    comptime AXIS_X = Self(3)
    comptime AXIS_Y = Self(4)
    comptime AXIS_Z = Self(5)
    comptime PLANE_XY = Self(6)
    comptime PLANE_XZ = Self(7)
    comptime PLANE_YZ = Self(8)
    comptime ROTATE_Z = Self(9)
    comptime SCALE = Self(10)

    def __init__(out self, value: Int32):
        self.value = value

    def __eq__(self, other: Self) -> Bool:
        return self.value == other.value

    def __ne__(self, other: Self) -> Bool:
        return self.value != other.value

struct SpatialState(ImplicitlyCopyable, Equatable):
    var value: Int32
    comptime READY = Self(0)
    comptime COMPUTING = Self(1)
    comptime DISPOSED = Self(2)
    comptime UNSUPPORTED = Self(3)
    comptime FAILED = Self(4)

    def __init__(out self, value: Int32):
        self.value = value

    def __eq__(self, other: Self) -> Bool:
        return self.value == other.value

    def __ne__(self, other: Self) -> Bool:
        return self.value != other.value

struct SpatialProjection(ImplicitlyCopyable, Equatable):
    var value: Int32
    comptime PERSPECTIVE = Self(0)
    comptime ORTHOGRAPHIC = Self(1)

    def __init__(out self, value: Int32):
        self.value = value

    def __eq__(self, other: Self) -> Bool:
        return self.value == other.value

    def __ne__(self, other: Self) -> Bool:
        return self.value != other.value

struct SpatialCommand(ImplicitlyCopyable, Equatable):
    var value: Int32
    comptime FIT = Self(0)
    comptime NEXT = Self(1)
    comptime UNDO = Self(2)
    comptime REDO = Self(3)
    comptime CANCEL = Self(4)
    comptime DISPOSE = Self(5)
    comptime RECREATE = Self(6)

    def __init__(out self, value: Int32):
        self.value = value

    def __eq__(self, other: Self) -> Bool:
        return self.value == other.value

    def __ne__(self, other: Self) -> Bool:
        return self.value != other.value

struct SpatialMetric(ImplicitlyCopyable, Equatable):
    var value: Int32
    comptime DOCUMENT = Self(0)
    comptime GEOMETRY = Self(1)
    comptime CAMERA = Self(2)
    comptime VIEWPORT = Self(3)
    comptime GENERATION = Self(4)
    comptime PREVIEW = Self(5)
    comptime SELECTED = Self(6)
    comptime HISTORY = Self(7)
    comptime BUILDS = Self(8)
    comptime ACCEPTED = Self(9)
    comptime REJECTED = Self(10)
    comptime REPLACED = Self(11)
    comptime FRAME_BUILDS = Self(12)
    comptime UPLOADS = Self(13)
    comptime SUBMISSIONS = Self(14)

    def __init__(out self, value: Int32):
        self.value = value

    def __eq__(self, other: Self) -> Bool:
        return self.value == other.value

    def __ne__(self, other: Self) -> Bool:
        return self.value != other.value

struct SpatialTiming(ImplicitlyCopyable, Equatable):
    var value: Int32
    comptime CPU = Self(0)
    comptime ENCODE = Self(1)
    comptime WAIT = Self(2)
    comptime GPU = Self(3)
    comptime READBACK = Self(4)
    comptime PUBLICATION = Self(5)
    comptime TOTAL = Self(6)

    def __init__(out self, value: Int32):
        self.value = value

    def __eq__(self, other: Self) -> Bool:
        return self.value == other.value

    def __ne__(self, other: Self) -> Bool:
        return self.value != other.value

struct SpatialComponent(ImplicitlyCopyable, Equatable):
    var value: Int32
    comptime X = Self(0)
    comptime Y = Self(1)
    comptime Z = Self(2)
    comptime ANGLE = Self(3)
    comptime SCALE = Self(4)

    def __init__(out self, value: Int32):
        self.value = value

    def __eq__(self, other: Self) -> Bool:
        return self.value == other.value

    def __ne__(self, other: Self) -> Bool:
        return self.value != other.value

struct SpatialAnchorPolicy(ImplicitlyCopyable, Equatable):
    var value: Int32
    comptime HIDE_OCCLUDED = Self(0)
    comptime ALWAYS_VISIBLE = Self(1)

    def __init__(out self, value: Int32):
        self.value = value

    def __eq__(self, other: Self) -> Bool:
        return self.value == other.value

    def __ne__(self, other: Self) -> Bool:
        return self.value != other.value

struct SpatialAnchorState(ImplicitlyCopyable, Equatable):
    var value: Int32
    comptime VISIBLE = Self(0)
    comptime OCCLUDED = Self(1)
    comptime OFFSCREEN = Self(2)
    comptime BEHIND_CAMERA = Self(3)

    def __init__(out self, value: Int32):
        self.value = value

    def __eq__(self, other: Self) -> Bool:
        return self.value == other.value

    def __ne__(self, other: Self) -> Bool:
        return self.value != other.value

struct SpatialRoute(ImplicitlyCopyable, Equatable):
    var value: Int32
    comptime NONE = Self(0)
    comptime SELECTION = Self(1)
    comptime NAVIGATION = Self(2)
    comptime MANIPULATION = Self(3)
    comptime REJECTED = Self(4)

    def __init__(out self, value: Int32):
        self.value = value

    def __eq__(self, other: Self) -> Bool:
        return self.value == other.value

    def __ne__(self, other: Self) -> Bool:
        return self.value != other.value

@fieldwise_init
struct SpatialPoint(ImplicitlyCopyable):
    var x: Float64
    var y: Float64
    var z: Float64


@fieldwise_init
struct SpatialCamera(ImplicitlyCopyable):
    var projection: SpatialProjection
    var yaw: Float64
    var pitch: Float64
    var distance: Float64
    var target: SpatialPoint


@fieldwise_init
struct SpatialObject(ImplicitlyCopyable):
    var id: UInt64
    var position: SpatialPoint
    var angle: Float64
    var scale: Float64
    var color: SpatialPoint


@fieldwise_init
struct SpatialAnchor(ImplicitlyCopyable):
    var state: SpatialAnchorState
    var x: Float64
    var y: Float64


@fieldwise_init
struct SpatialLine(ImplicitlyCopyable):
    var x1: Float64
    var y1: Float64
    var x2: Float64
    var y2: Float64
    var color: SpatialPoint
    var handle: Bool


struct SpatialViewport:
    """Move-only session with a bounded worker and owner-bound composition.

    A session mounts to exactly one owner for its lifetime. Close before closing
    the owner. Recreate preserves document/history and camera; mount failures
    report UNSUPPORTED, rendering failures FAILED. Idle render composes the
    cached frame without a GPU submission. poll() only accepts current work.
    """
    var _handle: UInt64

    def __init__(out self) raises:
        self._handle = external_call["ms_create", UInt64]()
        if self._handle == 0:
            raise Error("Spatial session unavailable or capacity exhausted (16)")

    def __deinit__(deinit self):
        if self._handle != 0:
            _ = external_call["ms_destroy", Int32](self._handle)

    def close(mut self):
        if self._handle != 0:
            _ = external_call["ms_destroy", Int32](self._handle)
            self._handle = 0

    def state(self) -> SpatialState:
        return SpatialState(external_call["ms_state", Int32](self._handle))

    def mount(self, owner: UInt64) -> Bool:
        return external_call["ms_mount", Int32](self._handle, owner) != 0

    def viewport(self, x: Float64, y: Float64, width: Float64, height: Float64, scale: Float64 = 1) -> Bool:
        return external_call["ms_viewport", Int32](self._handle, x, y, width, height, scale) != 0

    def camera(self) -> SpatialCamera:
        return SpatialCamera(SpatialProjection(Int32(external_call["ms_camera_value", Float64](self._handle, Int32(0)))), external_call["ms_camera_value", Float64](self._handle, Int32(1)), external_call["ms_camera_value", Float64](self._handle, Int32(2)), external_call["ms_camera_value", Float64](self._handle, Int32(3)), SpatialPoint(external_call["ms_camera_value", Float64](self._handle, Int32(4)), external_call["ms_camera_value", Float64](self._handle, Int32(5)), external_call["ms_camera_value", Float64](self._handle, Int32(6))))

    def set_camera(self, camera: SpatialCamera) -> Bool:
        return external_call["ms_camera", Int32](self._handle, camera.projection.value, camera.yaw, camera.pitch, camera.distance, camera.target.x, camera.target.y, camera.target.z) != 0

    def navigate(self, yaw: Float64 = 0, pitch: Float64 = 0, pan_x: Float64 = 0, pan_y: Float64 = 0, dolly: Float64 = 0) -> Bool:
        return external_call["ms_navigate", Int32](self._handle, yaw, pitch, pan_x, pan_y, dolly) != 0

    def parameter(self, value: Float64, delay_ms: Int32 = 0) -> Bool:
        return external_call["ms_parameter", Int32](self._handle, value, delay_ms) != 0

    def requested_parameter(self) -> Float64:
        return external_call["ms_parameter_value", Float64](self._handle)

    def displayed_parameter(self) -> Float64:
        return external_call["ms_displayed_parameter", Float64](self._handle)

    def poll(self) -> Bool:
        return external_call["ms_poll", Int32](self._handle) != 0

    def select(self, object: UInt64) -> Bool:
        return external_call["ms_select", Int32](self._handle, object) != 0

    def replace_objects(self, objects: List[SpatialObject]) -> Bool:
        """Atomically replace bounded neutral instances; IDs must be unique/nonzero."""
        if len(objects) > 16:
            return False
        if external_call["ms_objects_begin", Int32](self._handle) == 0:
            return False
        for object in objects:
            if external_call["ms_objects_add", Int32](self._handle, object.id, object.position.x, object.position.y, object.position.z, object.angle, object.scale, object.color.x, object.color.y, object.color.z) == 0:
                return False
        return external_call["ms_objects_commit", Int32](self._handle) != 0

    def command(self, command: SpatialCommand) -> Bool:
        return external_call["ms_command", Int32](self._handle, command.value) != 0

    def operation(self, tool: SpatialTool, a: Float64, b: Float64 = 0, snap: Bool = False) -> Bool:
        """Numeric and keyboard routes: same preview/validate/commit as pointer."""
        return external_call["ms_operation", Int32](self._handle, tool.value, a, b, Int32(snap)) != 0

    def pointer_down(self, tool: SpatialTool, x: Float64, y: Float64) -> SpatialRoute:
        return SpatialRoute(external_call["ms_pointer_down", Int32](self._handle, tool.value, x, y))

    def pointer_move(self, x: Float64, y: Float64, snap: Bool = False) -> Bool:
        return external_call["ms_pointer_move", Int32](self._handle, x, y, Int32(snap)) != 0

    def pointer_up(self) -> Bool:
        return external_call["ms_pointer_up", Int32](self._handle) != 0

    def metric(self, metric: SpatialMetric) -> UInt64:
        return external_call["ms_metric", UInt64](self._handle, metric.value)

    def transform(self, object: UInt64, component: SpatialComponent, preview: Bool = True) -> Float64:
        return external_call["ms_transform_value", Float64](self._handle, object, component.value, Int32(preview))

    def anchor(self, point: SpatialPoint, policy: SpatialAnchorPolicy = SpatialAnchorPolicy.HIDE_OCCLUDED) -> SpatialAnchor:
        var state = SpatialAnchorState(external_call["ms_anchor", Int32](self._handle, point.x, point.y, point.z, policy.value))
        return SpatialAnchor(state, external_call["ms_anchor_x", Float64](self._handle), external_call["ms_anchor_y", Float64](self._handle))

    def render(self, image_slot: Int32 = 0) -> Bool:
        return external_call["ms_render", Int32](self._handle, image_slot) != 0

    def timing(self, metric: SpatialTiming) -> Float64:
        """Last actual render; wall ms except CPU is process CPU; GPU may be NaN."""
        return external_call["ms_timing", Float64](self._handle, metric.value)

    def overlays(self, tool: SpatialTool) -> List[SpatialLine]:
        var result = List[SpatialLine]()
        var count = external_call["ms_overlay_prepare", Int32](self._handle, tool.value)
        for i in range(Int(count)):
            result.append(SpatialLine(external_call["ms_overlay_value", Float64](self._handle, Int32(i), Int32(0)), external_call["ms_overlay_value", Float64](self._handle, Int32(i), Int32(1)), external_call["ms_overlay_value", Float64](self._handle, Int32(i), Int32(2)), external_call["ms_overlay_value", Float64](self._handle, Int32(i), Int32(3)), SpatialPoint(external_call["ms_overlay_value", Float64](self._handle, Int32(i), Int32(4)), external_call["ms_overlay_value", Float64](self._handle, Int32(i), Int32(5)), external_call["ms_overlay_value", Float64](self._handle, Int32(i), Int32(6))), external_call["ms_overlay_value", Float64](self._handle, Int32(i), Int32(7)) != 0))
        return result^
