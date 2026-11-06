"""Explicit, main-thread AppKit window sessions; eight live instances maximum.

Legacy NativeWindow/renderer calls address the selected session. Use submit()
for an atomic select/render/AX/present operation and close() to dispose it.
Application models deliberately outlive a close/reopen cycle.
"""
from std.ffi import external_call
from .backend import BACKEND_MACOS_APPKIT
from .native_window import NativeWindow
from .native_frame import NativeFrameRenderer
from .window import WindowConfig
from .event import Event
from .frame import FramePacket, submit_frame
from .geometry import Size
from .control_state import MenuState, DialogState
from std.collections import List


struct MacOSWindowInstance:
    var handle: UInt64
    var transport: NativeWindow[BACKEND_MACOS_APPKIT, True]
    var renderer: NativeFrameRenderer[BACKEND_MACOS_APPKIT]

    def __init__(out self):
        self.handle = 0
        self.transport = NativeWindow[BACKEND_MACOS_APPKIT, True]()
        self.renderer = NativeFrameRenderer[BACKEND_MACOS_APPKIT]()

    def __deinit__(deinit self):
        if self.handle != 0:
            _ = external_call["moxi_window_destroy_instance", Int32](self.handle)

    def activate(self) raises:
        if self.handle == 0 or external_call["moxi_window_select_instance", Int32](self.handle) == 0:
            raise Error("Native window instance is closed or retired")

    def open(mut self, config: WindowConfig, x: Float32, y: Float32) raises:
        if self.handle != 0:
            raise Error("Close the native instance before reopening")
        self.handle = external_call["moxi_window_create_instance", UInt64]()
        if self.handle == 0:
            raise Error("AppKit window instance capacity (8) exhausted")
        self.activate()
        self.transport.open(config)
        external_call["moxi_window_set_position", NoneType](x, y)

    def is_open(self) raises -> Bool:
        if self.handle == 0:
            return False
        self.activate()
        return self.transport.is_open()

    def size(self) raises -> Size:
        self.activate()
        return self.transport.size()

    def poll_event(mut self) raises -> Event:
        self.activate()
        return self.transport.poll_event()

    def pump(mut self) raises:
        self.activate()
        self.transport.pump()

    def wait(mut self, seconds: Float32) raises:
        self.activate()
        self.transport.wait_for_work(seconds)

    def submit(mut self, packet: FramePacket) raises:
        self.activate()
        submit_frame(self.transport, self.renderer, packet)

    def menu(mut self, mut model: MenuState, labels: List[String], x: Float32, y: Float32) raises -> Int:
        self.activate()
        _ = model.show()
        external_call["moxi_window_menu_begin", NoneType]()
        for i in range(len(labels)):
            var label = labels[i]
            external_call["moxi_window_menu_add", NoneType](label.as_c_string_span().ptr(), Int32(i))
        var chosen = Int(external_call["moxi_window_menu_show", Int32](x, y))
        if chosen >= 0:
            _ = model.activate(chosen)
        else:
            _ = model.dismiss()
        return chosen

    def dialog(mut self, mut model: DialogState, target: Int, title: String, message: String) raises:
        self.activate()
        if model.open:
            return
        var native_title = title
        var native_message = message
        if external_call["moxi_window_dialog_show", Int32](Int32(target), native_title.as_c_string_span().ptr(), native_message.as_c_string_span().ptr()) == 0:
            raise Error("Native dialog is already open")
        _ = model.show()

    def close(mut self) raises:
        if self.handle != 0:
            _ = external_call["moxi_window_destroy_instance", Int32](self.handle)
            self.handle = 0
            self.renderer.release_resources()
