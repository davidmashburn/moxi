"""The capability-bus execution boundary: `CapabilityHandler` and `CapabilityBus`.

The bus is deliberately in-process and value-oriented. ``authorize()`` is the
adapter boundary for UI-owned mutations; ``invoke_handler()`` is the execution
path for a registered typed handler. ``invoke()`` never reports a mutation as
complete when no executor was supplied.
"""


from moxi.json import json_fragment_is_valid, json_quote
from moxi.capability_types import (
    CALLER_AGENT,
    CALLER_SYSTEM,
    CAPABILITY_BUSY,
    CAPABILITY_DISABLED,
    CAPABILITY_EXECUTOR_REQUIRED,
    CAPABILITY_HANDLER_MISMATCH,
    CAPABILITY_HANDLER_NOT_REGISTERED,
    CAPABILITY_INVALID,
    CAPABILITY_NOT_FOUND,
    CAPABILITY_OK,
    CAPABILITY_QUEUE_FULL,
    CAPABILITY_REQUIRES_APPROVAL,
    CAPABILITY_SCHEMA_INVALID,
    CAPABILITY_UNAVAILABLE,
    CapabilityApproval,
    CapabilityDescriptor,
    CapabilityInvocation,
    CapabilityQueue,
    CapabilityResult,
    MAX_CAPABILITIES,
    MAX_PENDING_CAPABILITIES,
    SIDE_EFFECT_NETWORK,
)


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
    var descriptor_8: CapabilityDescriptor
    var descriptor_9: CapabilityDescriptor
    var descriptor_count_value: Int
    var handler_name_0: String
    var handler_name_1: String
    var handler_name_2: String
    var handler_name_3: String
    var handler_name_4: String
    var handler_name_5: String
    var handler_name_6: String
    var handler_name_7: String
    var handler_name_8: String
    var handler_name_9: String
    var active_token_0: String
    var active_token_1: String
    var active_token_2: String
    var active_token_3: String
    var active_token_4: String
    var active_token_5: String
    var active_token_6: String
    var active_token_7: String
    var active_token_8: String
    var active_token_9: String
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
        self.descriptor_8 = CapabilityDescriptor("", "")
        self.descriptor_9 = CapabilityDescriptor("", "")
        self.descriptor_count_value = 0
        self.handler_name_0 = ""
        self.handler_name_1 = ""
        self.handler_name_2 = ""
        self.handler_name_3 = ""
        self.handler_name_4 = ""
        self.handler_name_5 = ""
        self.handler_name_6 = ""
        self.handler_name_7 = ""
        self.handler_name_8 = ""
        self.handler_name_9 = ""
        self.active_token_0 = ""
        self.active_token_1 = ""
        self.active_token_2 = ""
        self.active_token_3 = ""
        self.active_token_4 = ""
        self.active_token_5 = ""
        self.active_token_6 = ""
        self.active_token_7 = ""
        self.active_token_8 = ""
        self.active_token_9 = ""
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
        if self.descriptor_count_value > 8 and self.descriptor_8.name == name:
            return 8
        if self.descriptor_count_value > 9 and self.descriptor_9.name == name:
            return 9
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
        if index == 8:
            return self.descriptor_8
        if index == 9:
            return self.descriptor_9
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
        elif index == 8:
            self.descriptor_8 = descriptor
        elif index == 9:
            self.descriptor_9 = descriptor

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
        elif index == 8:
            self.handler_name_8 = name
        elif index == 9:
            self.handler_name_9 = name

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
            or self.handler_name_8 == name
            or self.handler_name_9 == name
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
        if index == 8:
            return self.active_token_8
        if index == 9:
            return self.active_token_9
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
        elif index == 8:
            self.active_token_8 = token
        elif index == 9:
            self.active_token_9 = token

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
        if self.active_token_8.count_codepoints() > 0:
            count += 1
        if self.active_token_9.count_codepoints() > 0:
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
