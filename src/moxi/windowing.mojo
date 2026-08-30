"""Portable ownership and configuration for multiple application windows."""

from std.collections import List

from .geometry import Size
from .window import WindowConfig


struct WindowId(ImplicitlyCopyable):
    """Stable application window identity."""

    var value: Int

    def __init__(out self, value: Int = -1):
        self.value = value

    def is_valid(self) -> Bool:
        return self.value >= 0


struct WindowState(ImplicitlyCopyable):
    """Backend-neutral state owned by one application window."""

    var id: WindowId
    var title: String
    var size: Size
    var open: Bool
    var focused: Bool

    def __init__(out self, id: WindowId, config: WindowConfig):
        self.id = id
        self.title = config.title
        self.size = Size(config.width, config.height)
        self.open = True
        self.focused = False


struct WindowManager:
    """Bounded window ownership registry independent of a native toolkit."""

    var windows: List[WindowState]
    var next_id: Int
    var capacity_value: Int

    def __init__(out self, capacity: Int = 8):
        self.windows = List[WindowState]()
        self.next_id = 1
        self.capacity_value = capacity if capacity > 0 else 1

    def open(mut self, config: WindowConfig) -> WindowId:
        var open_count = 0
        for index in range(len(self.windows)):
            if self.windows[index].open:
                open_count += 1
        if open_count >= self.capacity_value:
            return WindowId()
        var id = WindowId(self.next_id)
        self.next_id += 1
        self.windows.append(WindowState(id, config))
        if open_count == 0:
            _ = self.focus(id)
        return id

    def close(mut self, id: WindowId) -> Bool:
        for index in range(len(self.windows)):
            if self.windows[index].id.value == id.value and self.windows[index].open:
                self.windows[index].open = False
                if self.windows[index].focused:
                    self.windows[index].focused = False
                    self.focus_next_open()
                return True
        return False

    def focus(mut self, id: WindowId) -> Bool:
        var found = False
        for index in range(len(self.windows)):
            if self.windows[index].open and self.windows[index].id.value == id.value:
                found = True
                break
        if not found:
            return False
        for index in range(len(self.windows)):
            self.windows[index].focused = (
                self.windows[index].open
                and self.windows[index].id.value == id.value
            )
        return found

    def focus_next_open(mut self):
        for index in range(len(self.windows)):
            if self.windows[index].open:
                self.windows[index].focused = True
                return

    def resize(mut self, id: WindowId, size: Size) -> Bool:
        for index in range(len(self.windows)):
            if self.windows[index].id.value == id.value and self.windows[index].open:
                self.windows[index].size = Size(
                    size.width if size.width > 0.0 else 0.0,
                    size.height if size.height > 0.0 else 0.0,
                )
                return True
        return False

    def count(self) -> Int:
        var result = 0
        for index in range(len(self.windows)):
            if self.windows[index].open:
                result += 1
        return result

    def window(self, index: Int) -> WindowState:
        if index < 0 or index >= len(self.windows):
            return WindowState(WindowId(), WindowConfig("", 0.0, 0.0))
        return self.windows[index]
