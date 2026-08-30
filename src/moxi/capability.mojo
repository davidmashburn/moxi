"""Explicit capability authorization and execution contracts.

The bus is deliberately in-process and value-oriented. ``authorize()`` is the
adapter boundary for UI-owned mutations; ``invoke_handler()`` is the execution
path for a registered typed handler. ``invoke()`` never reports a mutation as
complete when no executor was supplied.
"""


comptime CALLER_UI = 1
comptime CALLER_AGENT = 2
comptime CALLER_SYSTEM = 3

comptime SIDE_EFFECT_NONE = 0
comptime SIDE_EFFECT_LOCAL = 1
comptime SIDE_EFFECT_NETWORK = 2
comptime SIDE_EFFECT_DESTRUCTIVE = 3

comptime CAPABILITY_OK = 0
comptime CAPABILITY_NOT_FOUND = 1
comptime CAPABILITY_DISABLED = 2
comptime CAPABILITY_REQUIRES_APPROVAL = 3
comptime CAPABILITY_BUSY = 4
comptime CAPABILITY_INVALID = 5
comptime CAPABILITY_EXECUTOR_REQUIRED = 6
comptime CAPABILITY_UNAVAILABLE = 7
comptime CAPABILITY_SCHEMA_INVALID = 8
comptime CAPABILITY_HANDLER_NOT_REGISTERED = 9
comptime CAPABILITY_HANDLER_MISMATCH = 10
comptime CAPABILITY_QUEUE_FULL = 11
comptime CAPABILITY_APPROVAL_INVALID = 12
comptime MAX_CAPABILITIES = 8
comptime MAX_PENDING_CAPABILITIES = 4


def json_quote(value: String) -> String:
    """Quote controlled metadata with the JSON escapes Moxi emits."""
    var result = String("")
    result += chr(34)
    for index in range(value.count_codepoints()):
        var glyph = String(value[codepoint=index:index + 1])
        if glyph == chr(34) or glyph == chr(92):
            result += chr(92)
            result += glyph
        elif glyph == chr(10):
            result += chr(92)
            result += "n"
        elif glyph == chr(13):
            result += chr(92)
            result += "r"
        elif glyph == chr(9):
            result += chr(92)
            result += "t"
        elif glyph == chr(8):
            result += chr(92)
            result += "b"
        elif glyph == chr(12):
            result += chr(92)
            result += "f"
        elif json_is_control(glyph):
            result += chr(92)
            result += "u"
            result += json_control_escape(glyph)
        else:
            result += glyph
    result += chr(34)
    return result


def side_effect_name(side_effect: Int) -> String:
    """Return the stable manifest label for a side-effect class."""
    if side_effect == SIDE_EFFECT_LOCAL:
        return "local"
    if side_effect == SIDE_EFFECT_NETWORK:
        return "network"
    if side_effect == SIDE_EFFECT_DESTRUCTIVE:
        return "destructive"
    return "none"


def json_char(value: String, index: Int) -> String:
    if index < 0 or index >= value.count_codepoints():
        return ""
    return String(value[codepoint=index:index + 1])


def json_is_whitespace(glyph: String) -> Bool:
    return (
        glyph == " "
        or glyph == chr(9)
        or glyph == chr(10)
        or glyph == chr(13)
    )


def json_is_digit(glyph: String) -> Bool:
    return (
        glyph == "0"
        or glyph == "1"
        or glyph == "2"
        or glyph == "3"
        or glyph == "4"
        or glyph == "5"
        or glyph == "6"
        or glyph == "7"
        or glyph == "8"
        or glyph == "9"
    )


def json_is_hex_digit(glyph: String) -> Bool:
    return (
        json_is_digit(glyph)
        or glyph == "a"
        or glyph == "b"
        or glyph == "c"
        or glyph == "d"
        or glyph == "e"
        or glyph == "f"
        or glyph == "A"
        or glyph == "B"
        or glyph == "C"
        or glyph == "D"
        or glyph == "E"
        or glyph == "F"
    )


def json_is_control(glyph: String) -> Bool:
    """Return whether a glyph is forbidden raw JSON string control data."""
    return (
        glyph == chr(0)
        or glyph == chr(1)
        or glyph == chr(2)
        or glyph == chr(3)
        or glyph == chr(4)
        or glyph == chr(5)
        or glyph == chr(6)
        or glyph == chr(7)
        or glyph == chr(8)
        or glyph == chr(9)
        or glyph == chr(10)
        or glyph == chr(11)
        or glyph == chr(12)
        or glyph == chr(13)
        or glyph == chr(14)
        or glyph == chr(15)
        or glyph == chr(16)
        or glyph == chr(17)
        or glyph == chr(18)
        or glyph == chr(19)
        or glyph == chr(20)
        or glyph == chr(21)
        or glyph == chr(22)
        or glyph == chr(23)
        or glyph == chr(24)
        or glyph == chr(25)
        or glyph == chr(26)
        or glyph == chr(27)
        or glyph == chr(28)
        or glyph == chr(29)
        or glyph == chr(30)
        or glyph == chr(31)
    )


def json_control_escape(glyph: String) -> String:
    """Return the four hex digits for a raw control's JSON escape."""
    if glyph == chr(0):
        return "0000"
    if glyph == chr(1):
        return "0001"
    if glyph == chr(2):
        return "0002"
    if glyph == chr(3):
        return "0003"
    if glyph == chr(4):
        return "0004"
    if glyph == chr(5):
        return "0005"
    if glyph == chr(6):
        return "0006"
    if glyph == chr(7):
        return "0007"
    if glyph == chr(8):
        return "0008"
    if glyph == chr(9):
        return "0009"
    if glyph == chr(10):
        return "000a"
    if glyph == chr(11):
        return "000b"
    if glyph == chr(12):
        return "000c"
    if glyph == chr(13):
        return "000d"
    if glyph == chr(14):
        return "000e"
    if glyph == chr(15):
        return "000f"
    if glyph == chr(16):
        return "0010"
    if glyph == chr(17):
        return "0011"
    if glyph == chr(18):
        return "0012"
    if glyph == chr(19):
        return "0013"
    if glyph == chr(20):
        return "0014"
    if glyph == chr(21):
        return "0015"
    if glyph == chr(22):
        return "0016"
    if glyph == chr(23):
        return "0017"
    if glyph == chr(24):
        return "0018"
    if glyph == chr(25):
        return "0019"
    if glyph == chr(26):
        return "001a"
    if glyph == chr(27):
        return "001b"
    if glyph == chr(28):
        return "001c"
    if glyph == chr(29):
        return "001d"
    if glyph == chr(30):
        return "001e"
    return "001f"


def json_skip_whitespace(value: String, index: Int) -> Int:
    var result = index
    while result < value.count_codepoints() and json_is_whitespace(
        json_char(value, result)
    ):
        result += 1
    return result


def json_parse_string(value: String, mut index: Int) -> Bool:
    if json_char(value, index) != chr(34):
        return False
    index += 1
    while index < value.count_codepoints():
        var glyph = json_char(value, index)
        if glyph == chr(34):
            index += 1
            return True
        if glyph == chr(92):
            index += 1
            if index >= value.count_codepoints():
                return False
            var escaped = json_char(value, index)
            if (
                escaped == chr(34)
                or escaped == chr(92)
                or escaped == "/"
                or escaped == "b"
                or escaped == "f"
                or escaped == "n"
                or escaped == "r"
                or escaped == "t"
            ):
                index += 1
                continue
            if escaped == "u":
                for _ in range(4):
                    index += 1
                    if index >= value.count_codepoints() or not json_is_hex_digit(
                        json_char(value, index)
                    ):
                        return False
                index += 1
                continue
            return False
        if json_is_control(glyph):
            return False
        index += 1
    return False


def json_parse_number(value: String, mut index: Int) -> Bool:
    var start = index
    if json_char(value, index) == "-":
        index += 1
    if not json_is_digit(json_char(value, index)):
        return False
    if json_char(value, index) == "0":
        index += 1
        if json_is_digit(json_char(value, index)):
            return False
    else:
        while json_is_digit(json_char(value, index)):
            index += 1
    if json_char(value, index) == ".":
        index += 1
        if not json_is_digit(json_char(value, index)):
            return False
        while json_is_digit(json_char(value, index)):
            index += 1
    var exponent = json_char(value, index)
    if exponent == "e" or exponent == "E":
        index += 1
        var sign = json_char(value, index)
        if sign == "+" or sign == "-":
            index += 1
        if not json_is_digit(json_char(value, index)):
            return False
        while json_is_digit(json_char(value, index)):
            index += 1
    return index > start


def json_parse_value(value: String, mut index: Int, depth: Int = 0) -> Bool:
    if depth > 32:
        return False
    index = json_skip_whitespace(value, index)
    var glyph = json_char(value, index)
    if glyph == chr(34):
        return json_parse_string(value, index)
    if glyph == "{":
        index += 1
        index = json_skip_whitespace(value, index)
        if json_char(value, index) == "}":
            index += 1
            return True
        while True:
            if not json_parse_string(value, index):
                return False
            index = json_skip_whitespace(value, index)
            if json_char(value, index) != ":":
                return False
            index += 1
            if not json_parse_value(value, index, depth + 1):
                return False
            index = json_skip_whitespace(value, index)
            if json_char(value, index) == "}":
                index += 1
                return True
            if json_char(value, index) != ",":
                return False
            index = json_skip_whitespace(value, index + 1)
    if glyph == "[":
        index += 1
        index = json_skip_whitespace(value, index)
        if json_char(value, index) == "]":
            index += 1
            return True
        while True:
            if not json_parse_value(value, index, depth + 1):
                return False
            index = json_skip_whitespace(value, index)
            if json_char(value, index) == "]":
                index += 1
                return True
            if json_char(value, index) != ",":
                return False
            index = json_skip_whitespace(value, index + 1)
    if glyph == "t" and value[codepoint=index:index + 4] == "true":
        index += 4
        return True
    if glyph == "f" and value[codepoint=index:index + 5] == "false":
        index += 5
        return True
    if glyph == "n" and value[codepoint=index:index + 4] == "null":
        index += 4
        return True
    if glyph == "-" or json_is_digit(glyph):
        return json_parse_number(value, index)
    return False


def json_fragment_is_valid(value: String, object_only: Bool = False) -> Bool:
    """Validate a complete JSON value before emitting or executing it."""
    if value.count_codepoints() == 0:
        return False
    var index = json_skip_whitespace(value, 0)
    if object_only and json_char(value, index) != "{":
        return False
    if not json_parse_value(value, index):
        return False
    index = json_skip_whitespace(value, index)
    return index == value.count_codepoints()


def json_document_is_valid(value: String) -> Bool:
    """Validate the bounded JSON document shapes accepted by invocations."""
    return json_fragment_is_valid(value)


struct CapabilityApproval(ImplicitlyCopyable):
    """A bus-issued approval bound to one request and capability name."""

    var request_id: String
    var capability_name: String
    var token: String
    var source: String

    def __init__(
        out self,
        request_id: String = "",
        capability_name: String = "",
        token: String = "",
        source: String = "",
    ):
        self.request_id = request_id
        self.capability_name = capability_name
        self.token = token
        self.source = source


struct CapabilityInvocation(ImplicitlyCopyable):
    """The caller-neutral envelope for one capability request."""

    var request_id: String
    var capability_name: String
    var caller: Int
    var arguments: String
    var timestamp: Int
    var side_effect: Int
    var caller_component: String
    var view_route: String
    var idempotency_key: String
    var reasoning_context: String
    var approval_token: String
    var approval_source: String

    def __init__(
        out self,
        request_id: String,
        capability_name: String,
        caller: Int,
        arguments: String = "",
        timestamp: Int = 0,
    ):
        self.request_id = request_id
        self.capability_name = capability_name
        self.caller = caller
        self.arguments = arguments
        self.timestamp = timestamp
        self.side_effect = SIDE_EFFECT_NONE
        self.caller_component = ""
        self.view_route = ""
        self.idempotency_key = request_id
        self.reasoning_context = ""
        self.approval_token = ""
        self.approval_source = ""

    def set_ui_context(mut self, component_id: String, route: String):
        """Attach the originating UI component and route for audit logs."""
        self.caller_component = component_id
        self.view_route = route

    def set_agent_context(
        mut self,
        idempotency_key: String,
        reasoning_context: String,
    ):
        """Attach agent idempotency and reasoning metadata."""
        self.idempotency_key = idempotency_key
        self.reasoning_context = reasoning_context

    def set_approval(mut self, approval: CapabilityApproval):
        """Attach a bus-issued approval token to this exact request."""
        self.approval_token = approval.token
        self.approval_source = approval.source

    def set_approval_token(mut self, token: String, source: String = "ui"):
        """Attach an approval token received from an approval adapter."""
        self.approval_token = token
        self.approval_source = source


struct CapabilityDescriptor(ImplicitlyCopyable):
    """Manifest metadata, availability, and policy for one capability."""

    var name: String
    var description: String
    var side_effect: Int
    var requires_approval: Bool
    var exclusive: Bool
    var enabled: Bool
    var available: Bool
    var unavailable_reason: String
    var parameters_schema: String
    var permissions_json: String
    var schema_valid: Bool

    def __init__(
        out self,
        name: String,
        description: String,
        side_effect: Int = SIDE_EFFECT_NONE,
        requires_approval: Bool = False,
        exclusive: Bool = False,
        parameters_schema: String = "{}",
    ):
        self.name = name
        self.description = description
        self.side_effect = side_effect
        self.requires_approval = requires_approval
        self.exclusive = exclusive
        self.enabled = True
        self.available = True
        self.unavailable_reason = ""
        self.schema_valid = json_fragment_is_valid(parameters_schema, True)
        if self.schema_valid:
            self.parameters_schema = parameters_schema
        else:
            self.parameters_schema = "{}"
        self.permissions_json = "[]"

    def manifest_json(self) -> String:
        """Emit one valid, tool-shaped manifest entry."""
        var result = String("{")
        result += "\"name\":"
        result += json_quote(self.name)
        result += ",\"description\":"
        result += json_quote(self.description)
        result += ",\"input_schema\":"
        if self.schema_valid:
            result += self.parameters_schema
        else:
            result += "{}"
        result += ",\"side_effect\":"
        result += json_quote(side_effect_name(self.side_effect))
        result += ",\"permissions\":"
        if json_fragment_is_valid(self.permissions_json):
            result += self.permissions_json
        else:
            result += "[]"
        result += ",\"concurrency\":"
        if self.exclusive:
            result += json_quote("exclusive")
        else:
            result += json_quote("concurrent")
        result += ",\"available\":"
        if self.enabled and self.available:
            result += "true"
        else:
            result += "false"
        result += ",\"unavailable_reason\":"
        if self.enabled and self.available:
            result += "null"
        else:
            result += json_quote(self.unavailable_reason)
        result += ",\"schema_valid\":"
        if self.schema_valid:
            result += "true"
        else:
            result += "false"
        result += "}"
        return result

    def set_parameters_schema(mut self, schema: String) -> Bool:
        """Replace the schema only when its structural JSON is valid."""
        if not json_fragment_is_valid(schema, True):
            self.schema_valid = False
            self.parameters_schema = "{}"
            return False
        self.parameters_schema = schema
        self.schema_valid = True
        return True

    def set_permissions(mut self, permissions_json: String) -> Bool:
        """Attach a JSON array of permission labels for the manifest."""
        if permissions_json.count_codepoints() < 2:
            return False
        var first_index = json_skip_whitespace(permissions_json, 0)
        var last_index = permissions_json.count_codepoints() - 1
        while last_index >= 0 and json_is_whitespace(
            json_char(permissions_json, last_index)
        ):
            last_index -= 1
        if first_index > last_index:
            return False
        var first = json_char(permissions_json, first_index)
        var last = json_char(permissions_json, last_index)
        if first != "[" or last != "]" or not json_fragment_is_valid(permissions_json):
            return False
        self.permissions_json = permissions_json
        return True

    def set_available(mut self, available: Bool, reason: String = ""):
        """Update dynamic availability and its explanatory manifest reason."""
        self.available = available
        self.unavailable_reason = reason if not available else ""


struct CapabilityResult(ImplicitlyCopyable):
    """Structured authorization or execution result for one request."""

    var request_id: String
    var status: Int
    var output: String
    var recovery_hint: String
    var replayed: Bool
    var executed: Bool
    var error_code: String
    var timestamp: Int
    var lease_token: String

    def __init__(
        out self,
        request_id: String,
        status: Int,
        output: String,
        recovery_hint: String = "",
        replayed: Bool = False,
        executed: Bool = False,
        error_code: String = "",
        timestamp: Int = 0,
        lease_token: String = "",
    ):
        self.request_id = request_id
        self.status = status
        self.output = output
        self.recovery_hint = recovery_hint
        self.replayed = replayed
        self.executed = executed
        self.error_code = error_code
        self.timestamp = timestamp
        self.lease_token = lease_token

    def ok(self) -> Bool:
        """Return whether the policy boundary accepted the request."""
        return self.status == CAPABILITY_OK

    def completed(self) -> Bool:
        """Return whether a handler actually executed successfully."""
        return self.ok() and self.executed

    def is_replay(self) -> Bool:
        """Return whether this result came from the idempotency record."""
        return self.replayed


struct CapabilityQueue(ImplicitlyCopyable):
    """A bounded FIFO with observable overflow behavior."""

    var first: CapabilityInvocation
    var second: CapabilityInvocation
    var third: CapabilityInvocation
    var fourth: CapabilityInvocation
    var count_value: Int
    var capacity_value: Int
    var dropped_value: Int

    def __init__(out self, capacity: Int = MAX_PENDING_CAPABILITIES):
        self.first = CapabilityInvocation("", "", CALLER_SYSTEM)
        self.second = CapabilityInvocation("", "", CALLER_SYSTEM)
        self.third = CapabilityInvocation("", "", CALLER_SYSTEM)
        self.fourth = CapabilityInvocation("", "", CALLER_SYSTEM)
        self.count_value = 0
        self.capacity_value = capacity
        if self.capacity_value < 1:
            self.capacity_value = 1
        if self.capacity_value > MAX_PENDING_CAPABILITIES:
            self.capacity_value = MAX_PENDING_CAPABILITIES
        self.dropped_value = 0

    def enqueue(mut self, invocation: CapabilityInvocation) -> Bool:
        """Append a request, returning false when the fixed queue is full."""
        if self.count_value >= self.capacity_value:
            self.dropped_value += 1
            return False
        if self.count_value == 0:
            self.first = invocation
        elif self.count_value == 1:
            self.second = invocation
        elif self.count_value == 2:
            self.third = invocation
        else:
            self.fourth = invocation
        self.count_value += 1
        return True

    def dequeue(mut self) -> CapabilityInvocation:
        """Pop the oldest request, or return an empty sentinel."""
        if self.count_value == 0:
            return CapabilityInvocation("", "", CALLER_SYSTEM)
        var result = self.first
        self.first = self.second
        self.second = self.third
        self.third = self.fourth
        self.fourth = CapabilityInvocation("", "", CALLER_SYSTEM)
        self.count_value -= 1
        return result

    def pending_count(self) -> Int:
        """Return the number of queued requests."""
        return self.count_value

    def capacity(self) -> Int:
        return self.capacity_value

    def dropped_count(self) -> Int:
        return self.dropped_value

    def set_capacity(mut self, capacity: Int) -> Bool:
        """Change the queue limit without discarding pending requests."""
        if capacity < 1 or capacity > MAX_PENDING_CAPABILITIES:
            return False
        if capacity < self.count_value:
            return False
        self.capacity_value = capacity
        return True


trait CapabilityHandler(ImplicitlyCopyable):
    """Static handler contract for bus-owned typed execution."""

    def capability_descriptor(self) -> CapabilityDescriptor:
        ...

    def execute_capability(
        mut self,
        invocation: CapabilityInvocation,
    ) -> CapabilityResult:
        ...


struct CapabilityBus(ImplicitlyCopyable):
    """A bounded, caller-neutral policy boundary for capability adapters."""

    var descriptor_0: CapabilityDescriptor
    var descriptor_1: CapabilityDescriptor
    var descriptor_2: CapabilityDescriptor
    var descriptor_3: CapabilityDescriptor
    var descriptor_4: CapabilityDescriptor
    var descriptor_5: CapabilityDescriptor
    var descriptor_6: CapabilityDescriptor
    var descriptor_7: CapabilityDescriptor
    var descriptor_count_value: Int
    var handler_name_0: String
    var handler_name_1: String
    var handler_name_2: String
    var handler_name_3: String
    var handler_name_4: String
    var handler_name_5: String
    var handler_name_6: String
    var handler_name_7: String
    var active_token_0: String
    var active_token_1: String
    var active_token_2: String
    var active_token_3: String
    var active_token_4: String
    var active_token_5: String
    var active_token_6: String
    var active_token_7: String
    var queue: CapabilityQueue
    var last_invocation: CapabilityInvocation
    var last_result: CapabilityResult
    var completed_capability_name: String
    var completed_request_id: String
    var completed_idempotency_key: String
    var completed_result: CapabilityResult
    var completed_capability_name_1: String
    var completed_request_id_1: String
    var completed_idempotency_key_1: String
    var completed_result_1: CapabilityResult
    var completed_capability_name_2: String
    var completed_request_id_2: String
    var completed_idempotency_key_2: String
    var completed_result_2: CapabilityResult
    var completed_capability_name_3: String
    var completed_request_id_3: String
    var completed_idempotency_key_3: String
    var completed_result_3: CapabilityResult
    var approval_counter: Int
    var pending_approval_request_id: String
    var pending_approval_capability_name: String
    var pending_approval_token: String
    var pending_approval_source: String
    var manifest_generated_at: String
    var last_queue_status: Int
    var total_invocations: Int
    var approved_invocations: Int
    var rejected_invocations: Int

    def __init__(out self, queue_capacity: Int = MAX_PENDING_CAPABILITIES):
        self.descriptor_0 = CapabilityDescriptor("", "")
        self.descriptor_1 = CapabilityDescriptor("", "")
        self.descriptor_2 = CapabilityDescriptor("", "")
        self.descriptor_3 = CapabilityDescriptor("", "")
        self.descriptor_4 = CapabilityDescriptor("", "")
        self.descriptor_5 = CapabilityDescriptor("", "")
        self.descriptor_6 = CapabilityDescriptor("", "")
        self.descriptor_7 = CapabilityDescriptor("", "")
        self.descriptor_count_value = 0
        self.handler_name_0 = ""
        self.handler_name_1 = ""
        self.handler_name_2 = ""
        self.handler_name_3 = ""
        self.handler_name_4 = ""
        self.handler_name_5 = ""
        self.handler_name_6 = ""
        self.handler_name_7 = ""
        self.active_token_0 = ""
        self.active_token_1 = ""
        self.active_token_2 = ""
        self.active_token_3 = ""
        self.active_token_4 = ""
        self.active_token_5 = ""
        self.active_token_6 = ""
        self.active_token_7 = ""
        self.queue = CapabilityQueue(queue_capacity)
        self.last_invocation = CapabilityInvocation("", "", CALLER_SYSTEM)
        self.last_result = CapabilityResult("", CAPABILITY_INVALID, "", "")
        self.completed_capability_name = ""
        self.completed_request_id = ""
        self.completed_idempotency_key = ""
        self.completed_result = CapabilityResult("", CAPABILITY_INVALID, "", "")
        self.completed_capability_name_1 = ""
        self.completed_request_id_1 = ""
        self.completed_idempotency_key_1 = ""
        self.completed_result_1 = CapabilityResult("", CAPABILITY_INVALID, "", "")
        self.completed_capability_name_2 = ""
        self.completed_request_id_2 = ""
        self.completed_idempotency_key_2 = ""
        self.completed_result_2 = CapabilityResult("", CAPABILITY_INVALID, "", "")
        self.completed_capability_name_3 = ""
        self.completed_request_id_3 = ""
        self.completed_idempotency_key_3 = ""
        self.completed_result_3 = CapabilityResult("", CAPABILITY_INVALID, "", "")
        self.approval_counter = 0
        self.pending_approval_request_id = ""
        self.pending_approval_capability_name = ""
        self.pending_approval_token = ""
        self.pending_approval_source = ""
        self.manifest_generated_at = "0"
        self.last_queue_status = CAPABILITY_OK
        self.total_invocations = 0
        self.approved_invocations = 0
        self.rejected_invocations = 0

    def descriptor_index(self, name: String) -> Int:
        """Return a registered descriptor index, or `-1`."""
        if self.descriptor_count_value > 0 and self.descriptor_0.name == name:
            return 0
        if self.descriptor_count_value > 1 and self.descriptor_1.name == name:
            return 1
        if self.descriptor_count_value > 2 and self.descriptor_2.name == name:
            return 2
        if self.descriptor_count_value > 3 and self.descriptor_3.name == name:
            return 3
        if self.descriptor_count_value > 4 and self.descriptor_4.name == name:
            return 4
        if self.descriptor_count_value > 5 and self.descriptor_5.name == name:
            return 5
        if self.descriptor_count_value > 6 and self.descriptor_6.name == name:
            return 6
        if self.descriptor_count_value > 7 and self.descriptor_7.name == name:
            return 7
        return -1

    def descriptor_for_index(self, index: Int) -> CapabilityDescriptor:
        """Read one fixed registry slot, returning an empty invalid descriptor."""
        if index == 0:
            return self.descriptor_0
        if index == 1:
            return self.descriptor_1
        if index == 2:
            return self.descriptor_2
        if index == 3:
            return self.descriptor_3
        if index == 4:
            return self.descriptor_4
        if index == 5:
            return self.descriptor_5
        if index == 6:
            return self.descriptor_6
        if index == 7:
            return self.descriptor_7
        return CapabilityDescriptor("", "", parameters_schema="{}")

    def set_descriptor(mut self, index: Int, descriptor: CapabilityDescriptor):
        """Replace one fixed registry slot."""
        if index == 0:
            self.descriptor_0 = descriptor
        elif index == 1:
            self.descriptor_1 = descriptor
        elif index == 2:
            self.descriptor_2 = descriptor
        elif index == 3:
            self.descriptor_3 = descriptor
        elif index == 4:
            self.descriptor_4 = descriptor
        elif index == 5:
            self.descriptor_5 = descriptor
        elif index == 6:
            self.descriptor_6 = descriptor
        elif index == 7:
            self.descriptor_7 = descriptor

    def set_handler_name(mut self, index: Int, name: String):
        if index == 0:
            self.handler_name_0 = name
        elif index == 1:
            self.handler_name_1 = name
        elif index == 2:
            self.handler_name_2 = name
        elif index == 3:
            self.handler_name_3 = name
        elif index == 4:
            self.handler_name_4 = name
        elif index == 5:
            self.handler_name_5 = name
        elif index == 6:
            self.handler_name_6 = name
        elif index == 7:
            self.handler_name_7 = name

    def handler_registered(self, name: String) -> Bool:
        return (
            self.handler_name_0 == name
            or self.handler_name_1 == name
            or self.handler_name_2 == name
            or self.handler_name_3 == name
            or self.handler_name_4 == name
            or self.handler_name_5 == name
            or self.handler_name_6 == name
            or self.handler_name_7 == name
        )

    def active_token(self, index: Int) -> String:
        if index == 0:
            return self.active_token_0
        if index == 1:
            return self.active_token_1
        if index == 2:
            return self.active_token_2
        if index == 3:
            return self.active_token_3
        if index == 4:
            return self.active_token_4
        if index == 5:
            return self.active_token_5
        if index == 6:
            return self.active_token_6
        if index == 7:
            return self.active_token_7
        return ""

    def set_active_token(mut self, index: Int, token: String):
        if index == 0:
            self.active_token_0 = token
        elif index == 1:
            self.active_token_1 = token
        elif index == 2:
            self.active_token_2 = token
        elif index == 3:
            self.active_token_3 = token
        elif index == 4:
            self.active_token_4 = token
        elif index == 5:
            self.active_token_5 = token
        elif index == 6:
            self.active_token_6 = token
        elif index == 7:
            self.active_token_7 = token

    def register(mut self, descriptor: CapabilityDescriptor) -> Bool:
        """Insert or replace a valid manifest entry by stable name."""
        if descriptor.name.count_codepoints() == 0:
            return False
        if not descriptor.schema_valid:
            return False
        var index = self.descriptor_index(descriptor.name)
        if index != -1:
            self.set_descriptor(index, descriptor)
            return True
        if self.descriptor_count_value >= MAX_CAPABILITIES:
            return False
        self.set_descriptor(self.descriptor_count_value, descriptor)
        self.descriptor_count_value += 1
        return True

    def register_handler[Handler: CapabilityHandler](mut self, handler: Handler) -> Bool:
        """Register handler metadata and bind future execution by its name."""
        var descriptor = handler.capability_descriptor()
        if not self.register(descriptor):
            return False
        var index = self.descriptor_index(descriptor.name)
        self.set_handler_name(index, descriptor.name)
        return True

    def set_enabled(mut self, name: String, enabled: Bool) -> Bool:
        """Enable or disable a capability without removing its manifest entry."""
        var index = self.descriptor_index(name)
        if index == -1:
            return False
        var descriptor = self.descriptor_for_index(index)
        descriptor.enabled = enabled
        self.set_descriptor(index, descriptor)
        return True

    def set_available(mut self, name: String, available: Bool, reason: String = "") -> Bool:
        """Update dynamic availability and expose its reason in the manifest."""
        var index = self.descriptor_index(name)
        if index == -1:
            return False
        var descriptor = self.descriptor_for_index(index)
        descriptor.set_available(available, reason)
        self.set_descriptor(index, descriptor)
        return True

    def descriptor_count(self) -> Int:
        return self.descriptor_count_value

    def descriptor(self, index: Int) -> CapabilityDescriptor:
        return self.descriptor_for_index(index)

    def active_count(self) -> Int:
        var count = 0
        if self.active_token_0.count_codepoints() > 0:
            count += 1
        if self.active_token_1.count_codepoints() > 0:
            count += 1
        if self.active_token_2.count_codepoints() > 0:
            count += 1
        if self.active_token_3.count_codepoints() > 0:
            count += 1
        if self.active_token_4.count_codepoints() > 0:
            count += 1
        if self.active_token_5.count_codepoints() > 0:
            count += 1
        if self.active_token_6.count_codepoints() > 0:
            count += 1
        if self.active_token_7.count_codepoints() > 0:
            count += 1
        return count

    def is_busy(self) -> Bool:
        return self.active_count() > 0

    def issue_approval(
        mut self,
        invocation: CapabilityInvocation,
        source: String = "user",
    ) -> CapabilityApproval:
        """Issue a one-shot approval bound to the request envelope."""
        self.approval_counter += 1
        var token = String("moxi-approval-", self.approval_counter)
        self.pending_approval_request_id = invocation.request_id
        self.pending_approval_capability_name = invocation.capability_name
        self.pending_approval_token = token
        self.pending_approval_source = source
        return CapabilityApproval(
            invocation.request_id,
            invocation.capability_name,
            token,
            source,
        )

    def set_manifest_generated_at(mut self, generated_at: String):
        """Set the adapter-provided manifest generation marker."""
        self.manifest_generated_at = generated_at

    def enqueue(mut self, invocation: CapabilityInvocation) -> Bool:
        """Queue a request and preserve bounded backpressure semantics."""
        if self.queue.enqueue(invocation):
            self.last_queue_status = CAPABILITY_OK
            return True
        self.last_queue_status = CAPABILITY_QUEUE_FULL
        return False

    def queue_status(self) -> Int:
        """Return the status of the most recent enqueue attempt."""
        return self.last_queue_status

    def dequeue(mut self) -> CapabilityInvocation:
        """Pop the oldest queued request."""
        return self.queue.dequeue()

    def pending_count(self) -> Int:
        return self.queue.pending_count()

    def queue_capacity(self) -> Int:
        return self.queue.capacity()

    def dropped_queue_count(self) -> Int:
        """Return requests rejected by the bounded capability FIFO."""
        return self.queue.dropped_count()

    def set_queue_capacity(mut self, capacity: Int) -> Bool:
        """Change the bounded FIFO limit without dropping pending requests."""
        return self.queue.set_capacity(capacity)

    def approval_matches(self, invocation: CapabilityInvocation) -> Bool:
        return (
            invocation.approval_token.count_codepoints() > 0
            and invocation.request_id == self.pending_approval_request_id
            and invocation.capability_name == self.pending_approval_capability_name
            and invocation.approval_token == self.pending_approval_token
            and invocation.approval_source == self.pending_approval_source
        )

    def clear_approval(mut self):
        self.pending_approval_request_id = ""
        self.pending_approval_capability_name = ""
        self.pending_approval_token = ""
        self.pending_approval_source = ""

    def completed_index(self, invocation: CapabilityInvocation) -> Int:
        """Find a recent completed request by idempotency identity."""
        if (
            invocation.request_id == self.completed_request_id
            and invocation.capability_name == self.completed_capability_name
            and invocation.idempotency_key == self.completed_idempotency_key
        ):
            return 0
        if (
            invocation.request_id == self.completed_request_id_1
            and invocation.capability_name == self.completed_capability_name_1
            and invocation.idempotency_key == self.completed_idempotency_key_1
        ):
            return 1
        if (
            invocation.request_id == self.completed_request_id_2
            and invocation.capability_name == self.completed_capability_name_2
            and invocation.idempotency_key == self.completed_idempotency_key_2
        ):
            return 2
        if (
            invocation.request_id == self.completed_request_id_3
            and invocation.capability_name == self.completed_capability_name_3
            and invocation.idempotency_key == self.completed_idempotency_key_3
        ):
            return 3
        return -1

    def completed_result_for_index(self, index: Int) -> CapabilityResult:
        """Return a stored result marked as a replay, or an invalid sentinel."""
        var result = CapabilityResult("", CAPABILITY_INVALID, "", "")
        if index == 0:
            result = self.completed_result
        elif index == 1:
            result = self.completed_result_1
        elif index == 2:
            result = self.completed_result_2
        elif index == 3:
            result = self.completed_result_3
        result.replayed = True
        result.lease_token = ""
        return result

    def begin(mut self, invocation: CapabilityInvocation) -> CapabilityResult:
        """Authorize a request and issue a per-capability exclusive lease."""
        self.last_invocation = invocation
        self.total_invocations += 1
        if (
            invocation.request_id.count_codepoints() == 0
            or invocation.capability_name.count_codepoints() == 0
        ):
            self.rejected_invocations += 1
            var result = CapabilityResult(
                invocation.request_id,
                CAPABILITY_INVALID,
                "",
                "Provide both a request id and capability name.",
                error_code="INVALID_ENVELOPE",
                timestamp=invocation.timestamp,
            )
            self.last_result = result
            return result^

        var completed = self.completed_index(invocation)
        if completed != -1:
            var result = self.completed_result_for_index(completed)
            self.last_result = result
            return result^

        var index = self.descriptor_index(invocation.capability_name)
        if index == -1:
            self.rejected_invocations += 1
            var result = CapabilityResult(
                invocation.request_id,
                CAPABILITY_NOT_FOUND,
                "",
                "Register the capability before invoking it.",
                error_code="NOT_FOUND",
                timestamp=invocation.timestamp,
            )
            self.last_result = result
            return result^

        var descriptor = self.descriptor_for_index(index)
        if not descriptor.schema_valid:
            self.rejected_invocations += 1
            var result = CapabilityResult(
                invocation.request_id,
                CAPABILITY_SCHEMA_INVALID,
                "",
                "Replace the capability schema with a valid JSON object.",
                error_code="SCHEMA_INVALID",
                timestamp=invocation.timestamp,
            )
            self.last_result = result
            return result^

        if descriptor.parameters_schema != "{}" and not json_fragment_is_valid(
            invocation.arguments,
            True,
        ):
            self.rejected_invocations += 1
            var result = CapabilityResult(
                invocation.request_id,
                CAPABILITY_SCHEMA_INVALID,
                "",
                "Provide arguments as a valid JSON document.",
                error_code="VALIDATION",
                timestamp=invocation.timestamp,
            )
            self.last_result = result
            return result

        if not descriptor.enabled:
            self.rejected_invocations += 1
            var result = CapabilityResult(
                invocation.request_id,
                CAPABILITY_DISABLED,
                "",
                "Enable the capability in the current policy before retrying.",
                error_code="DISABLED",
                timestamp=invocation.timestamp,
            )
            self.last_result = result
            return result

        if not descriptor.available:
            self.rejected_invocations += 1
            var result = CapabilityResult(
                invocation.request_id,
                CAPABILITY_UNAVAILABLE,
                "",
                descriptor.unavailable_reason,
                error_code="PRECONDITION_FAILED",
                timestamp=invocation.timestamp,
            )
            self.last_result = result
            return result

        var requires_approval = descriptor.requires_approval
        if (
            invocation.caller == CALLER_AGENT
            and descriptor.side_effect >= SIDE_EFFECT_NETWORK
        ):
            requires_approval = True
        if requires_approval and not self.approval_matches(invocation):
            self.rejected_invocations += 1
            var result = CapabilityResult(
                invocation.request_id,
                CAPABILITY_REQUIRES_APPROVAL,
                "",
                "Obtain approval from a trusted UI or policy adapter and retry.",
                error_code="APPROVAL_REQUIRED",
                timestamp=invocation.timestamp,
            )
            self.last_result = result
            return result^

        if self.active_token(index).count_codepoints() > 0:
            self.rejected_invocations += 1
            var result = CapabilityResult(
                invocation.request_id,
                CAPABILITY_BUSY,
                "",
                "Wait for this capability's active lease to complete.",
                error_code="BUSY",
                timestamp=invocation.timestamp,
            )
            self.last_result = result
            return result^

        var lease_token = String("")
        if descriptor.exclusive:
            lease_token = String("moxi-lease-", invocation.request_id)
            self.set_active_token(index, lease_token)
        self.approved_invocations += 1
        self.clear_approval()
        var output = String("Authorized: ")
        output += descriptor.name
        var result = CapabilityResult(
            invocation.request_id,
            CAPABILITY_OK,
            output,
            "",
            timestamp=invocation.timestamp,
            lease_token=lease_token,
        )
        self.last_result = result
        return result^

    def authorize(mut self, invocation: CapabilityInvocation) -> CapabilityResult:
        """Authorize an adapter-owned mutation while retaining any lease."""
        return self.begin(invocation)

    def complete(mut self, name: String, lease_token: String = "") -> Bool:
        """Release only the matching per-capability lease token."""
        var index = self.descriptor_index(name)
        if index == -1:
            return False
        var active = self.active_token(index)
        if active.count_codepoints() == 0:
            return True
        if lease_token.count_codepoints() == 0 or active != lease_token:
            return False
        self.set_active_token(index, "")
        return True

    def record_completion(
        mut self,
        invocation: CapabilityInvocation,
        result: CapabilityResult,
    ):
        """Record only a real execution result for idempotent replay."""
        if result.completed() and not result.replayed:
            self.completed_capability_name_3 = self.completed_capability_name_2
            self.completed_request_id_3 = self.completed_request_id_2
            self.completed_idempotency_key_3 = self.completed_idempotency_key_2
            self.completed_result_3 = self.completed_result_2
            self.completed_capability_name_2 = self.completed_capability_name_1
            self.completed_request_id_2 = self.completed_request_id_1
            self.completed_idempotency_key_2 = self.completed_idempotency_key_1
            self.completed_result_2 = self.completed_result_1
            self.completed_capability_name_1 = self.completed_capability_name
            self.completed_request_id_1 = self.completed_request_id
            self.completed_idempotency_key_1 = self.completed_idempotency_key
            self.completed_result_1 = self.completed_result
            self.completed_capability_name = invocation.capability_name
            self.completed_request_id = invocation.request_id
            self.completed_idempotency_key = invocation.idempotency_key
            self.completed_result = result
        _ = self.complete(invocation.capability_name, result.lease_token)

    def invoke(mut self, invocation: CapabilityInvocation) -> CapabilityResult:
        """Reject executor-less invocation instead of faking successful work."""
        var authorization = self.begin(invocation)
        if not authorization.ok():
            return authorization
        _ = self.complete(invocation.capability_name, authorization.lease_token)
        var result = CapabilityResult(
            invocation.request_id,
            CAPABILITY_EXECUTOR_REQUIRED,
            "",
            "Call invoke_handler() or authorize() with an application adapter.",
            error_code="EXECUTOR_REQUIRED",
            timestamp=invocation.timestamp,
        )
        self.last_result = result
        return result^

    def invoke_handler[Handler: CapabilityHandler](
        mut self,
        mut handler: Handler,
        invocation: CapabilityInvocation,
    ) -> CapabilityResult:
        """Authorize and execute the registered matching typed handler."""
        var handler_descriptor = handler.capability_descriptor()
        if handler_descriptor.name != invocation.capability_name:
            self.rejected_invocations += 1
            return CapabilityResult(
                invocation.request_id,
                CAPABILITY_HANDLER_MISMATCH,
                "",
                "The handler name must match the invocation capability name.",
                error_code="HANDLER_MISMATCH",
                timestamp=invocation.timestamp,
            )
        if not self.handler_registered(handler_descriptor.name):
            self.rejected_invocations += 1
            return CapabilityResult(
                invocation.request_id,
                CAPABILITY_HANDLER_NOT_REGISTERED,
                "",
                "Register the handler before invoking it.",
                error_code="HANDLER_NOT_REGISTERED",
                timestamp=invocation.timestamp,
            )
        var authorization = self.begin(invocation)
        if not authorization.ok():
            return authorization
        if authorization.replayed:
            return authorization
        var result = handler.execute_capability(invocation)
        result.request_id = invocation.request_id
        result.timestamp = invocation.timestamp
        result.lease_token = authorization.lease_token
        if result.status == CAPABILITY_OK:
            result.executed = True
        self.record_completion(invocation, result)
        self.last_result = result
        return result^

    def manifest_json(self, application: String, version: String) -> String:
        """Emit a valid dynamically prunable tool manifest."""
        var result = String("{\"schema_version\":\"0.5.0\",\"application\":{")
        result += "\"name\":"
        result += json_quote(application)
        result += ",\"version\":"
        result += json_quote(version)
        result += "},\"generated_at\":"
        result += json_quote(self.manifest_generated_at)
        result += ",\"capabilities\":["
        for index in range(self.descriptor_count_value):
            if index > 0:
                result += ","
            result += self.descriptor_for_index(index).manifest_json()
        result += "]}"
        return result
