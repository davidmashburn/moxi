"""Capability-bus value types: envelopes, descriptors, results, and the queue.

These are the value-oriented data types that `CapabilityBus` (in
`capability_bus.mojo`) operates on. They carry no bus-execution logic
themselves.
"""


from moxi.json import json_fragment_is_valid, json_quote, json_skip_whitespace, json_is_whitespace, json_char


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
comptime MAX_CAPABILITIES = 10
comptime MAX_PENDING_CAPABILITIES = 4


def side_effect_name(side_effect: Int) -> String:
    """Return the stable manifest label for a side-effect class."""
    if side_effect == SIDE_EFFECT_LOCAL:
        return "local"
    if side_effect == SIDE_EFFECT_NETWORK:
        return "network"
    if side_effect == SIDE_EFFECT_DESTRUCTIVE:
        return "destructive"
    return "none"


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

