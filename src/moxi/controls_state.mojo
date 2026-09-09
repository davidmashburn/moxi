"""Standalone interaction state shared by slider, toggle, and radio controls."""


from .event import KEY_DOWN, KEY_END, KEY_HOME, KEY_LEFT, KEY_RIGHT, KEY_UP
from .geometry import Point, Rect


struct SliderState(ImplicitlyCopyable):
    """State and keyboard/pointer behavior for a scalar slider."""

    var value: Float32
    var minimum: Float32
    var maximum: Float32
    var step: Float32

    def __init__(
        out self,
        value: Float32 = 0.0,
        minimum: Float32 = 0.0,
        maximum: Float32 = 1.0,
        step: Float32 = 0.1,
    ):
        self.minimum = minimum
        self.maximum = maximum if maximum >= minimum else minimum
        self.step = step if step > 0.0 else 0.1
        self.value = value
        _ = self.set_value(value)

    def set_value(mut self, value: Float32) -> Bool:
        var next = value
        if next < self.minimum:
            next = self.minimum
        if next > self.maximum:
            next = self.maximum
        if next == self.value:
            return False
        self.value = next
        return True

    def normalized(self) -> Float32:
        if self.maximum <= self.minimum:
            return 0.0
        return (self.value - self.minimum) / (self.maximum - self.minimum)

    def nudge(mut self, direction: Int) -> Bool:
        return self.set_value(self.value + self.step * Float32(direction))

    def set_from_position(mut self, position: Point, bounds: Rect) -> Bool:
        if bounds.width <= 0.0:
            return False
        var fraction = (position.x - bounds.x) / bounds.width
        if fraction < 0.0:
            fraction = 0.0
        if fraction > 1.0:
            fraction = 1.0
        var raw = self.minimum + fraction * (self.maximum - self.minimum)
        var steps = Int((raw - self.minimum) / self.step + 0.5)
        return self.set_value(self.minimum + Float32(steps) * self.step)

    def handle_key(mut self, key: Int) -> Bool:
        if key == KEY_LEFT or key == KEY_DOWN:
            return self.nudge(-1)
        if key == KEY_RIGHT or key == KEY_UP:
            return self.nudge(1)
        if key == KEY_HOME:
            return self.set_value(self.minimum)
        if key == KEY_END:
            return self.set_value(self.maximum)
        return False

struct ToggleState(ImplicitlyCopyable):
    """Shared state behavior for switches and checkboxes."""

    var checked: Bool

    def __init__(out self, checked: Bool = False):
        self.checked = checked

    def toggle(mut self) -> Bool:
        self.checked = not self.checked
        return True

    def set_checked(mut self, checked: Bool) -> Bool:
        if self.checked == checked:
            return False
        self.checked = checked
        return True

struct RadioGroupState(ImplicitlyCopyable):
    """Single-selection state shared by a group of radio descriptors."""

    var selected_id: Int
    var group_id: Int

    def __init__(out self, group_id: Int, selected_id: Int = -1):
        self.group_id = group_id
        self.selected_id = selected_id

    def select(mut self, id: Int) -> Bool:
        if self.selected_id == id:
            return False
        self.selected_id = id
        return True

    def is_selected(self, id: Int) -> Bool:
        return self.selected_id == id
