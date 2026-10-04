"""Native macOS specializations and AppKit development services."""

from std.ffi import external_call
from .backend import BACKEND_MACOS_APPKIT
from .clipboard import ClipboardBackend
from .geometry import Rect
from .native_window import (
    NativeCanvasPainter,
    NativeCanvasSceneRenderer,
    NativeRenderer,
    NativeWindow,
)


comptime MacOSRenderer = NativeRenderer[BACKEND_MACOS_APPKIT]
comptime MacOSCanvasSceneRenderer = NativeCanvasSceneRenderer[BACKEND_MACOS_APPKIT]
comptime MacOSCanvasPainter = NativeCanvasPainter[BACKEND_MACOS_APPKIT]
comptime MacOSWindow = NativeWindow[BACKEND_MACOS_APPKIT, True]


struct MacOSFileWatcher:
    """Small mtime watcher for source-driven development hosts."""

    var path: String
    var last_mtime: Int64

    def __init__(out self):
        self.path = ""
        self.last_mtime = -1

    def watch(mut self, path: String) -> Bool:
        self.path = path
        var source = self.path
        var c_source = source.as_c_string_slice()
        self.last_mtime = external_call[
            "moxi_dev_source_mtime_ns",
            Int64,
        ](c_source.ptr())
        return self.last_mtime >= 0

    def changed(mut self) -> Bool:
        if self.path.count_codepoints() == 0:
            return False
        var source = self.path
        var c_source = source.as_c_string_slice()
        var current = external_call[
            "moxi_dev_source_mtime_ns",
            Int64,
        ](c_source.ptr())
        if current < 0 or current == self.last_mtime:
            return False
        self.last_mtime = current
        return True

    def clear(mut self):
        self.path = ""
        self.last_mtime = -1


struct MacOSLiveScript:
    """Build, load, and invoke Moxi's small development C ABI."""

    var loaded: Bool
    var build_revision: Int

    def __init__(out self):
        self.loaded = False
        self.build_revision = 0

    def reload(mut self, source: String, mtime: Int64) -> Bool:
        """Compile a source module and atomically swap its exported frame."""
        self.build_revision += 1
        var output = String(
            "/tmp/moxi-live-",
            self.build_revision,
            "-",
            mtime,
            ".dylib",
        )
        var source_copy = source
        var output_copy = output
        var c_source = source_copy.as_c_string_slice()
        var c_output = output_copy.as_c_string_slice()
        var built = external_call["moxi_dev_build_live_script", Int32](
            c_source.ptr(),
            c_output.ptr(),
        )
        if built == 0:
            return False
        var loaded = external_call["moxi_dev_load_live_script", Int32](
            c_output.ptr()
        )
        if loaded == 0:
            return False
        self.loaded = True
        return True

    def render(mut self, bounds: Rect) -> Bool:
        """Render the currently loaded module into its component canvas."""
        if not self.loaded:
            return False
        return external_call["moxi_dev_render_live_script", Int32](
            bounds.x,
            bounds.y,
            bounds.width,
            bounds.height,
        ) > 0

    def clear(mut self):
        external_call["moxi_dev_clear_live_script", NoneType]()
        self.loaded = False


struct MacOSClipboard(ClipboardBackend):
    """Bridge portable clipboard commands to the active macOS pasteboard."""

    def __init__(out self):
        pass

    def copy(mut self, text: String) raises:
        var text_copy = text
        var c_text = text_copy.as_c_string_slice()
        external_call["moxi_clipboard_set", NoneType](c_text.ptr())

    def paste(mut self) raises -> String:
        var text = String("")
        var index = 0
        while True:
            var codepoint = Int(
                external_call["moxi_clipboard_codepoint_at", Int32](Int32(index))
            )
            if codepoint < 0:
                break
            text += chr(codepoint)
            index += 1
        return text


struct MacOSDemoRunner:
    """Launch one validated Pixi task as a sibling demo process."""

    def __init__(out self):
        pass

    def launch(mut self, task: String) raises -> Bool:
        """Launch a task name, rejecting shell syntax at the native boundary."""
        var task_copy = task
        var c_task = task_copy.as_c_string_slice()
        return external_call["moxi_demo_launch", Int32](c_task.ptr()) != 0

    def is_running(self) raises -> Bool:
        """Return whether the most recently launched task is still running."""
        return external_call["moxi_demo_is_running", Int32]() != 0

    def exit_status(self) raises -> Int:
        """Return the last task's exit status, or -1 before it has exited."""
        return Int(external_call["moxi_demo_exit_status", Int32]())
