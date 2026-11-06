"""Bounded copied-image composition; no exposed native image/GPU identity."""
from std.ffi import external_call
from std.collections import List


struct CompositionSurface:
    """Move-only resource bound to one live Moxi window and one draw slot.

    Main thread only. RGBA8 premultiplied sRGB, top row first. publish() copies
    its input; compose() freezes a snapshot until the next compose. Close before
    the window. Invalid owners, stale serials, disposed resources and dimensions
    above 2048 pixels fail without changing another window or resource.
    """
    var _owner: UInt64
    var _token: UInt64

    def __init__(out self, owner: UInt64) raises:
        self._owner = owner
        self._token = external_call["moxi_composition_acquire", UInt64](owner)
        if self._token == 0:
            raise Error("Composition owner unavailable or capacity exhausted (32)")

    def __deinit__(deinit self):
        if self._token != 0:
            _ = external_call["moxi_composition_release", Int32](self._owner,self._token)

    def close(mut self):
        if self._token != 0:
            _ = external_call["moxi_composition_release", Int32](self._owner,self._token)
            self._token = 0

    def publish(self, serial: UInt64, rgba: List[UInt8], width: Int32, height: Int32, stride: Int32) -> Bool:
        return external_call["moxi_composition_publish", Int32](self._owner,self._token,serial,rgba.unsafe_ptr(),UInt(len(rgba)),width,height,stride) != 0

    def compose(self, image_slot: Int32, x: Float32, y: Float32, width: Float32, height: Float32) -> Bool:
        return external_call["moxi_composition_compose", Int32](self._owner,self._token,image_slot,x,y,width,height) != 0
