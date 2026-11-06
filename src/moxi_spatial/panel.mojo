"""S4 experimental affine planar mapping. World IME/AX geometry is unsupported.

One panel per SpatialViewport; the viewport and source owner must outlive this
borrowed adapter. Same owner cannot be source and destination. No event loop.
"""
from std.ffi import external_call
from .spatial import SpatialViewport, SpatialPoint

struct PanelMode(ImplicitlyCopyable, Equatable):
    var value: Int32
    comptime WORLD = Self(0)
    comptime SCREEN = Self(1)
    def __init__(out self, value: Int32):
        self.value = value
    def __eq__(self, other: Self) -> Bool:
        return self.value == other.value
    def __ne__(self, other: Self) -> Bool:
        return self.value != other.value
    @staticmethod
    def parse(value: Int32) raises -> Self:
        if value != Self.WORLD.value and value != Self.SCREEN.value:
            raise Error("Unsupported panel mode")
        return Self(value)

struct PanelPhase(ImplicitlyCopyable, Equatable):
    var value: Int32
    comptime PROBE = Self(0)
    comptime DOWN = Self(1)
    comptime MOVE = Self(2)
    comptime UP = Self(3)
    comptime CANCEL = Self(4)
    def __init__(out self, value: Int32):
        self.value = value
    def __eq__(self, other: Self) -> Bool:
        return self.value == other.value
    def __ne__(self, other: Self) -> Bool:
        return self.value != other.value

struct PanelResult(ImplicitlyCopyable, Equatable):
    var value: Int32
    comptime HIT = Self(0)
    comptime OUTSIDE = Self(1)
    comptime HIDDEN = Self(2)
    comptime INVALID = Self(3)
    comptime STALE = Self(4)
    comptime IDLE = Self(5)
    def __init__(out self, value: Int32):
        self.value = value
    def __eq__(self, other: Self) -> Bool:
        return self.value == other.value
    def __ne__(self, other: Self) -> Bool:
        return self.value != other.value

struct WorldPanel:
    var _view: UInt64
    def __init__(out self, view: SpatialViewport):
        self._view = view._handle
    def configure(self, origin: SpatialPoint, right: SpatialPoint, down: SpatialPoint, width: Float64 = 400, height: Float64 = 240) -> Bool:
        return external_call["ms_panel_configure", Int32](self._view,origin.x,origin.y,origin.z,right.x,right.y,right.z,down.x,down.y,down.z,width,height) != 0
    def route(self, phase: PanelPhase, x: Float64, y: Float64) -> PanelResult:
        return PanelResult(external_call["ms_panel_route", Int32](self._view,phase.value,x,y))
    def local_x(self) -> Float64:
        return external_call["ms_panel_local", Float64](self._view,Int32(0))
    def local_y(self) -> Float64:
        return external_call["ms_panel_local", Float64](self._view,Int32(1))
    def project_x(self, x: Float64, y: Float64) -> Float64:
        return external_call["ms_panel_project", Float64](self._view,x,y,Int32(0))
    def project_y(self, x: Float64, y: Float64) -> Float64:
        return external_call["ms_panel_project", Float64](self._view,x,y,Int32(1))
    def render(self, source_owner: UInt64, slot: Int32) -> Bool:
        return external_call["ms_panel_render", Int32](self._view,source_owner,slot) != 0
