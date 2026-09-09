"""Basic reusable control descriptors: label, button, and simple inputs."""


from .style import (
    Style,
    default_button_style,
    default_checkbox_style,
    default_label_style,
    default_progress_style,
    default_slider_style,
    default_switch_style,
    default_radio_style,
    default_image_style,
)
from .view import (
    BUTTON_KIND,
    CANVAS_KIND,
    CHECKBOX_KIND,
    IMAGE_KIND,
    LABEL_KIND,
    PROGRESS_KIND,
    RADIO_KIND,
    SEPARATOR_KIND,
    SLIDER_KIND,
    SWITCH_KIND,
    ViewNode,
)


struct LabelControl(ImplicitlyCopyable):
    """A reusable declarative label descriptor."""

    var id: Int
    var text: String
    var preferred_height: Float32
    var style: Style

    def __init__(
        out self,
        id: Int,
        text: String,
        preferred_height: Float32,
    ):
        self.id = id
        self.text = text
        self.preferred_height = preferred_height
        self.style = default_label_style()

    def __init__(
        out self,
        id: Int,
        text: String,
        preferred_height: Float32,
        style: Style,
    ):
        self.id = id
        self.text = text
        self.preferred_height = preferred_height
        self.style = style

    def node(self) -> ViewNode:
        return ViewNode(
            LABEL_KIND,
            self.id,
            self.text,
            self.preferred_height,
            self.style,
        )


struct ButtonControl(ImplicitlyCopyable):
    """A reusable declarative button descriptor."""

    var id: Int
    var text: String
    var preferred_height: Float32
    var style: Style
    var enabled: Bool

    def __init__(
        out self,
        id: Int,
        text: String,
        preferred_height: Float32,
    ):
        self.id = id
        self.text = text
        self.preferred_height = preferred_height
        self.style = default_button_style()
        self.enabled = True

    def __init__(
        out self,
        id: Int,
        text: String,
        preferred_height: Float32,
        style: Style,
        enabled: Bool = True,
    ):
        self.id = id
        self.text = text
        self.preferred_height = preferred_height
        self.style = style
        self.enabled = enabled

    def node(self) -> ViewNode:
        var node = ViewNode(
            BUTTON_KIND,
            self.id,
            self.text,
            self.preferred_height,
            self.style,
        )
        node.enabled = self.enabled
        node.semantics.enabled = self.enabled
        return node


struct CheckboxControl(ImplicitlyCopyable):
    """A reusable, keyboard-focusable checkbox descriptor."""

    var id: Int
    var text: String
    var checked: Bool
    var preferred_height: Float32
    var style: Style
    var enabled: Bool

    def __init__(
        out self,
        id: Int,
        text: String,
        checked: Bool,
        preferred_height: Float32,
    ):
        self.id = id
        self.text = text
        self.checked = checked
        self.preferred_height = preferred_height
        self.style = default_checkbox_style()
        self.enabled = True

    def __init__(
        out self,
        id: Int,
        text: String,
        checked: Bool,
        preferred_height: Float32,
        style: Style,
        enabled: Bool = True,
    ):
        self.id = id
        self.text = text
        self.checked = checked
        self.preferred_height = preferred_height
        self.style = style
        self.enabled = enabled

    def node(self) -> ViewNode:
        var node = ViewNode(
            CHECKBOX_KIND,
            self.id,
            self.text,
            self.preferred_height,
            self.style,
        )
        node.set_checked(self.checked)
        node.enabled = self.enabled
        node.semantics.enabled = self.enabled
        return node


struct ProgressControl(ImplicitlyCopyable):
    """A non-interactive determinate progress indicator descriptor."""

    var id: Int
    var text: String
    var progress: Float32
    var preferred_height: Float32
    var style: Style

    def __init__(
        out self,
        id: Int,
        text: String,
        progress: Float32,
        preferred_height: Float32,
    ):
        self.id = id
        self.text = text
        self.progress = progress
        self.preferred_height = preferred_height
        self.style = default_progress_style()

    def __init__(
        out self,
        id: Int,
        text: String,
        progress: Float32,
        preferred_height: Float32,
        style: Style,
    ):
        self.id = id
        self.text = text
        self.progress = progress
        self.preferred_height = preferred_height
        self.style = style

    def node(self) -> ViewNode:
        var node = ViewNode(
            PROGRESS_KIND,
            self.id,
            self.text,
            self.preferred_height,
            self.style,
        )
        node.set_progress(self.progress)
        return node


struct SliderControl(ImplicitlyCopyable):
    """A keyboard-focusable scalar slider with an explicit numeric range."""

    var id: Int
    var text: String
    var value: Float32
    var minimum: Float32
    var maximum: Float32
    var step: Float32
    var preferred_height: Float32
    var style: Style
    var enabled: Bool

    def __init__(
        out self,
        id: Int,
        text: String,
        value: Float32,
        minimum: Float32,
        maximum: Float32,
        step: Float32,
        preferred_height: Float32,
    ):
        self.id = id
        self.text = text
        self.value = value
        self.minimum = minimum
        self.maximum = maximum
        self.step = step if step > 0.0 else 1.0
        self.preferred_height = preferred_height
        self.style = default_slider_style()
        self.enabled = True

    def normalized(self) -> Float32:
        if self.maximum <= self.minimum:
            return 0.0
        var result = (self.value - self.minimum) / (self.maximum - self.minimum)
        if result < 0.0:
            result = 0.0
        if result > 1.0:
            result = 1.0
        return result

    def node(self) -> ViewNode:
        var node = ViewNode(
            SLIDER_KIND,
            self.id,
            self.text,
            self.preferred_height,
            self.style,
        )
        node.set_progress(self.normalized())
        node.set_accessibility_value(String("value ", self.value))
        node.set_accessibility_value_range(self.minimum, self.maximum, self.value)
        node.enabled = self.enabled
        node.semantics.enabled = self.enabled
        return node


struct SwitchControl(ImplicitlyCopyable):
    """A keyboard-focusable on/off switch descriptor."""

    var id: Int
    var text: String
    var checked: Bool
    var preferred_height: Float32
    var style: Style
    var enabled: Bool

    def __init__(
        out self,
        id: Int,
        text: String,
        checked: Bool,
        preferred_height: Float32,
    ):
        self.id = id
        self.text = text
        self.checked = checked
        self.preferred_height = preferred_height
        self.style = default_switch_style()
        self.enabled = True

    def node(self) -> ViewNode:
        var node = ViewNode(
            SWITCH_KIND,
            self.id,
            self.text,
            self.preferred_height,
            self.style,
        )
        node.set_checked(self.checked)
        node.enabled = self.enabled
        node.semantics.enabled = self.enabled
        return node


struct RadioControl(ImplicitlyCopyable):
    """A keyboard-focusable radio option descriptor."""

    var id: Int
    var group_id: Int
    var text: String
    var selected: Bool
    var preferred_height: Float32
    var style: Style
    var enabled: Bool

    def __init__(
        out self,
        id: Int,
        group_id: Int,
        text: String,
        selected: Bool,
        preferred_height: Float32,
    ):
        self.id = id
        self.group_id = group_id
        self.text = text
        self.selected = selected
        self.preferred_height = preferred_height
        self.style = default_radio_style()
        self.enabled = True

    def node(self) -> ViewNode:
        var node = ViewNode(
            RADIO_KIND,
            self.id,
            self.text,
            self.preferred_height,
            self.style,
        )
        node.set_selected(self.selected)
        node.enabled = self.enabled
        node.semantics.enabled = self.enabled
        node.set_accessibility_value(String("group ", self.group_id))
        return node


struct ImageControl(ImplicitlyCopyable):
    """An image descriptor backed by an application-owned resource id."""

    var id: Int
    var alt_text: String
    var resource_id: Int
    var preferred_height: Float32
    var style: Style

    def __init__(
        out self,
        id: Int,
        alt_text: String,
        resource_id: Int,
        preferred_height: Float32,
    ):
        self.id = id
        self.alt_text = alt_text
        self.resource_id = resource_id
        self.preferred_height = preferred_height
        self.style = default_image_style()

    def node(self) -> ViewNode:
        var node = ViewNode(
            IMAGE_KIND,
            self.id,
            self.alt_text,
            self.preferred_height,
            self.style,
        )
        node.set_resource_id(self.resource_id)
        return node


struct SeparatorControl(ImplicitlyCopyable):
    """A non-focusable visual separator."""

    var id: Int
    var preferred_height: Float32

    def __init__(out self, id: Int, preferred_height: Float32 = 1.0):
        self.id = id
        self.preferred_height = preferred_height

    def node(self) -> ViewNode:
        return ViewNode(SEPARATOR_KIND, self.id, "", self.preferred_height)


struct CanvasControl(ImplicitlyCopyable):
    """A custom drawing surface descriptor for app-owned scene content."""

    var id: Int
    var text: String
    var preferred_height: Float32

    def __init__(out self, id: Int, text: String, preferred_height: Float32):
        self.id = id
        self.text = text
        self.preferred_height = preferred_height

    def node(self) -> ViewNode:
        return ViewNode(CANVAS_KIND, self.id, self.text, self.preferred_height)


