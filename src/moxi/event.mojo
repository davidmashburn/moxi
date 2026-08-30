"""Backend-neutral pointer, keyboard, text, and resize events."""

from .geometry import Point, Size


comptime NONE_KIND = 0
comptime POINTER_DOWN_KIND = 1
comptime KEY_DOWN_KIND = 2
comptime TEXT_INPUT_KIND = 3
comptime WINDOW_RESIZED_KIND = 4
comptime POINTER_UP_KIND = 5
comptime POINTER_MOVE_KIND = 6
comptime CLICK_KIND = 7
comptime COMPOSITION_UPDATE_KIND = 8
comptime COMPOSITION_END_KIND = 9
comptime FRAME_TICK_KIND = 10
comptime SCROLL_KIND = 11
comptime DRAG_BEGIN_KIND = 12
comptime DRAG_UPDATE_KIND = 13
comptime DROP_KIND = 14
comptime TASK_RESULT_KIND = 15
comptime TOUCH_BEGIN_KIND = 16
comptime TOUCH_UPDATE_KIND = 17
comptime TOUCH_END_KIND = 18
comptime POINTER_CANCEL_KIND = 19
comptime ACTION_KIND = 20
comptime NO_ACTION = -1

comptime MOD_SHIFT = 1
comptime MOD_COMMAND = 2
comptime MOD_CONTROL = 4
comptime MOD_OPTION = 8

comptime KEY_TAB = 9
comptime KEY_ENTER = 13
comptime KEY_ESCAPE = 27
comptime KEY_SPACE = 32
comptime KEY_BACKSPACE = 8
comptime KEY_DELETE = 127
comptime KEY_LEFT = 1000
comptime KEY_RIGHT = 1001
comptime KEY_UP = 1002
comptime KEY_DOWN = 1003
comptime KEY_HOME = 1004
comptime KEY_END = 1005
comptime KEY_A = 97
comptime KEY_C = 99
comptime KEY_V = 118
comptime KEY_X = 120


struct ClickEvent(ImplicitlyCopyable):
    """A primary-pointer click in window content coordinates."""

    var position: Point

    def __init__(out self, position: Point):
        self.position = position


struct PointerEvent(ImplicitlyCopyable):
    """A pointer lifecycle event in window content coordinates."""

    var kind: Int
    var position: Point
    var pointer_id: Int
    var buttons: Int

    def __init__(out self, kind: Int, position: Point):
        self.kind = kind
        self.position = position
        self.pointer_id = 0
        self.buttons = 0

    def __init__(
        out self,
        kind: Int,
        position: Point,
        pointer_id: Int,
        buttons: Int,
    ):
        self.kind = kind
        self.position = position
        self.pointer_id = pointer_id
        self.buttons = buttons


struct KeyEvent(ImplicitlyCopyable):
    """A logical key press, independent of native key codes."""

    var key: Int
    var modifiers: Int

    def __init__(out self, key: Int, modifiers: Int = 0):
        self.key = key
        self.modifiers = modifiers


struct TextInputEvent(ImplicitlyCopyable):
    """Committed text input plus an optional native replacement range."""

    var text: String
    var replacement_start: Int
    var replacement_end: Int

    def __init__(
        out self,
        text: String,
        replacement_start: Int = -1,
        replacement_end: Int = -1,
    ):
        self.text = text
        self.replacement_start = replacement_start
        self.replacement_end = replacement_end


struct CompositionEvent(ImplicitlyCopyable):
    """Transient marked text from an input method, or an end marker."""

    var text: String
    var selection_start: Int
    var selection_end: Int
    var ended: Bool

    def __init__(out self):
        self.text = ""
        self.selection_start = 0
        self.selection_end = 0
        self.ended = True

    def __init__(
        out self,
        text: String,
        selection_start: Int = 0,
        selection_end: Int = 0,
    ):
        self.text = text
        self.selection_start = selection_start
        self.selection_end = selection_end
        self.ended = False


struct ResizeEvent(ImplicitlyCopyable):
    """A window content-size change."""

    var size: Size

    def __init__(out self, size: Size):
        self.size = size


struct FrameEvent(ImplicitlyCopyable):
    """A deterministic application frame tick in seconds."""

    var delta_seconds: Float32

    def __init__(out self, delta_seconds: Float32):
        self.delta_seconds = delta_seconds if delta_seconds > 0.0 else 0.0


struct ScrollEvent(ImplicitlyCopyable):
    """A pointer-wheel or trackpad scroll delta in content coordinates."""

    var position: Point
    var delta: Point

    def __init__(out self, delta: Point):
        self.position = Point(0.0, 0.0)
        self.delta = delta

    def __init__(out self, position: Point, delta: Point):
        self.position = position
        self.delta = delta


struct TaskEvent(ImplicitlyCopyable):
    """A task result delivered to a component by the app scheduler."""

    var task_id: Int
    var status: Int
    var payload: String

    def __init__(out self, task_id: Int, status: Int, payload: String = ""):
        self.task_id = task_id
        self.status = status
        self.payload = payload


struct DragEvent(ImplicitlyCopyable):
    """A capture-aware drag or drop payload in content coordinates."""

    var kind: Int
    var position: Point
    var delta: Point
    var payload: String

    def __init__(
        out self,
        kind: Int,
        position: Point,
        delta: Point = Point(0.0, 0.0),
        payload: String = "",
    ):
        self.kind = kind
        self.position = position
        self.delta = delta
        self.payload = payload


struct ActionEvent(ImplicitlyCopyable):
    """An explicit application action with a stable id and payload."""

    var id: Int
    var payload: String

    def __init__(out self, id: Int, payload: String = ""):
        self.id = id
        self.payload = payload


struct SemanticActionEvent(ImplicitlyCopyable):
    """An accessibility action addressed to a concrete view id."""

    var target: Int
    var action: Int
    var payload: String

    def __init__(
        out self,
        target: Int,
        action: Int,
        payload: String = "",
    ):
        self.target = target
        self.action = action
        self.payload = payload


struct Event(ImplicitlyCopyable):
    """A routed event delivered to a component by `App`."""

    var kind: Int
    var target: Int
    var action_id: Int
    var position: Point
    var key: Int
    var modifiers: Int
    var text: String
    var selection_start: Int
    var selection_end: Int
    var replacement_start: Int
    var replacement_end: Int
    var size: Size
    var delta_seconds: Float32
    var scroll_delta: Point
    var task_id: Int
    var task_status: Int
    var pointer_id: Int
    var buttons: Int
    var drag_delta: Point

    def __init__(out self):
        self.kind = NONE_KIND
        self.target = -1
        self.action_id = NO_ACTION
        self.position = Point(0.0, 0.0)
        self.key = 0
        self.modifiers = 0
        self.text = ""
        self.selection_start = 0
        self.selection_end = 0
        self.replacement_start = -1
        self.replacement_end = -1
        self.size = Size(0.0, 0.0)
        self.delta_seconds = 0.0
        self.scroll_delta = Point(0.0, 0.0)
        self.task_id = -1
        self.task_status = -1
        self.pointer_id = 0
        self.buttons = 0
        self.drag_delta = Point(0.0, 0.0)

    def __init__(out self, event: ClickEvent):
        self = Event()
        self.kind = CLICK_KIND
        self.position = event.position

    def __init__(out self, event: PointerEvent):
        self = Event()
        self.kind = event.kind
        self.position = event.position
        self.pointer_id = event.pointer_id
        self.buttons = event.buttons

    def __init__(out self, event: KeyEvent):
        self = Event()
        self.kind = KEY_DOWN_KIND
        self.key = event.key
        self.modifiers = event.modifiers

    def __init__(out self, event: TextInputEvent):
        self = Event()
        self.kind = TEXT_INPUT_KIND
        self.text = event.text
        self.replacement_start = event.replacement_start
        self.replacement_end = event.replacement_end

    def __init__(out self, event: CompositionEvent):
        self = Event()
        if event.ended:
            self.kind = COMPOSITION_END_KIND
        else:
            self.kind = COMPOSITION_UPDATE_KIND
        self.text = event.text
        self.selection_start = event.selection_start
        self.selection_end = event.selection_end

    def __init__(out self, event: ResizeEvent):
        self = Event()
        self.kind = WINDOW_RESIZED_KIND
        self.size = event.size

    def __init__(out self, event: FrameEvent):
        self = Event()
        self.kind = FRAME_TICK_KIND
        self.delta_seconds = event.delta_seconds

    def __init__(out self, event: ScrollEvent):
        self = Event()
        self.kind = SCROLL_KIND
        self.position = event.position
        self.scroll_delta = event.delta

    def __init__(out self, event: TaskEvent):
        self = Event()
        self.kind = TASK_RESULT_KIND
        self.task_id = event.task_id
        self.task_status = event.status
        self.text = event.payload

    def __init__(out self, event: DragEvent):
        self = Event()
        self.kind = event.kind
        self.position = event.position
        self.drag_delta = event.delta
        self.text = event.payload

    def __init__(out self, event: ActionEvent):
        self = Event()
        self.kind = ACTION_KIND
        self.action_id = event.id
        self.text = event.payload

    def __init__(out self, event: SemanticActionEvent):
        self = Event()
        self.kind = ACTION_KIND
        self.target = event.target
        self.action_id = event.action
        self.text = event.payload

    def set_target(mut self, target: Int):
        self.target = target

    def set_action(mut self, action_id: Int):
        """Attach a stable semantic action to a routed target."""
        self.action_id = action_id
