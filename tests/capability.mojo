"""Capability bus contract test."""

from moxi import test_check
from moxi import (
    CALLER_AGENT,
    CALLER_UI,
    CAPABILITY_BUSY,
    CAPABILITY_EXECUTOR_REQUIRED,
    CAPABILITY_HANDLER_MISMATCH,
    CAPABILITY_HANDLER_NOT_REGISTERED,
    CAPABILITY_OK,
    CAPABILITY_QUEUE_FULL,
    CAPABILITY_REQUIRES_APPROVAL,
    CAPABILITY_SCHEMA_INVALID,
    CAPABILITY_UNAVAILABLE,
    CapabilityBus,
    CapabilityApproval,
    CapabilityDescriptor,
    CapabilityHandler,
    CapabilityInvocation,
    CapabilityResult,
    SIDE_EFFECT_DESTRUCTIVE,
)


struct EchoHandler(CapabilityHandler):
    var executions: Int

    def __init__(out self):
        self.executions = 0

    def capability_descriptor(self) -> CapabilityDescriptor:
        return CapabilityDescriptor("demo.echo", "Echo request arguments")

    def execute_capability(
        mut self,
        invocation: CapabilityInvocation,
    ) -> CapabilityResult:
        self.executions += 1
        return CapabilityResult(
            invocation.request_id,
            CAPABILITY_OK,
            invocation.arguments,
        )


def main():
    var bus = CapabilityBus()
    _ = bus.register(
        CapabilityDescriptor(
            "demo.read",
            "Read local demo state",
        )
    )
    _ = bus.register(
        CapabilityDescriptor(
            "demo.delete",
            "Delete demo state",
            SIDE_EFFECT_DESTRUCTIVE,
            True,
            True,
        )
    )

    var read = CapabilityInvocation("r1", "demo.read", CALLER_UI)
    var read_authorization = bus.authorize(read)
    test_check(read_authorization.status == CAPABILITY_OK)
    test_check(not read_authorization.executed)
    test_check(bus.invoke(read).status == CAPABILITY_EXECUTOR_REQUIRED)

    var blocked = CapabilityInvocation("r2", "demo.delete", CALLER_AGENT)
    test_check(bus.authorize(blocked).status == CAPABILITY_REQUIRES_APPROVAL)
    var approval = bus.issue_approval(blocked, "test-confirmation")
    blocked.set_approval_token(approval.token, "wrong-source")
    test_check(bus.authorize(blocked).status == CAPABILITY_REQUIRES_APPROVAL)
    blocked.set_approval(approval)
    var lease = bus.authorize(blocked)
    test_check(lease.status == CAPABILITY_OK)
    test_check(bus.is_busy())
    var concurrent = CapabilityInvocation("r3", "demo.delete", CALLER_AGENT)
    var concurrent_approval = bus.issue_approval(concurrent, "test-confirmation")
    concurrent.set_approval(concurrent_approval)
    test_check(bus.authorize(concurrent).status == CAPABILITY_BUSY)
    test_check(not bus.complete("demo.delete", "wrong-lease"))
    test_check(bus.complete("demo.delete", lease.lease_token))
    test_check(not bus.is_busy())
    test_check(bus.total_invocations == 6)
    test_check(bus.rejected_invocations == 3)

    var unavailable = CapabilityDescriptor(
        "demo.optional",
        "Optional demo state",
    )
    _ = bus.register(unavailable)
    test_check(bus.set_available("demo.optional", False, "Demo data is offline"))
    test_check(
        bus.authorize(
            CapabilityInvocation("optional-1", "demo.optional", CALLER_UI)
        ).status == CAPABILITY_UNAVAILABLE
    )

    var invalid_schema = CapabilityDescriptor(
        "demo.invalid",
        "Rejected schema",
        parameters_schema="{not-json",
    )
    test_check(not invalid_schema.schema_valid)
    test_check(not bus.register(invalid_schema))
    test_check(
        CapabilityDescriptor(
            "demo.whitespace",
            "Whitespace schema",
            parameters_schema=" { \"type\": \"object\" } ",
        ).schema_valid
    )
    test_check(
        CapabilityDescriptor(
            "demo.bad-value",
            "Malformed value",
            parameters_schema="{\"type\":}",
        ).schema_valid == False
    )
    test_check(
        CapabilityDescriptor(
            "demo.bad-array",
            "Malformed array",
            parameters_schema="[1,]",
        ).schema_valid == False
    )
    var permissions_descriptor = CapabilityDescriptor(
        "demo.permissions",
        "Permissions with formatting",
    )
    var permissions_valid = permissions_descriptor.set_permissions(
        " [\"files.read\"] "
    )
    test_check(permissions_valid)
    test_check(permissions_descriptor.permissions_json == " [\"files.read\"] ")
    var raw_control = String("{\"description\":\"")
    raw_control += chr(1)
    raw_control += "\"}"
    test_check(
        CapabilityDescriptor(
            "demo.raw-control",
            "Rejected raw control",
            parameters_schema=raw_control,
        ).schema_valid == False
    )
    var bad_arguments = CapabilityDescriptor(
        "demo.structured",
        "Structured arguments",
        parameters_schema="{\"type\":\"object\"}",
    )
    _ = bus.register(bad_arguments)
    test_check(
        bus.authorize(
            CapabilityInvocation("structured-1", "demo.structured", CALLER_UI, "{bad")
        ).status == CAPABILITY_SCHEMA_INVALID
    )
    test_check(bus.total_invocations == 8)
    test_check(bus.rejected_invocations == 5)
    test_check(bus.descriptor(99).name == "")

    var pending = CapabilityInvocation("queued", "demo.read", CALLER_UI)
    test_check(bus.enqueue(pending))
    test_check(bus.pending_count() == 1)
    test_check(bus.dequeue().request_id == "queued")
    test_check(bus.pending_count() == 0)
    test_check(bus.enqueue(CapabilityInvocation("q1", "demo.read", CALLER_UI)))
    test_check(bus.enqueue(CapabilityInvocation("q2", "demo.read", CALLER_UI)))
    test_check(bus.enqueue(CapabilityInvocation("q3", "demo.read", CALLER_UI)))
    test_check(bus.enqueue(CapabilityInvocation("q4", "demo.read", CALLER_UI)))
    test_check(not bus.enqueue(CapabilityInvocation("q5", "demo.read", CALLER_UI)))
    test_check(bus.queue_status() == CAPABILITY_QUEUE_FULL)
    while bus.pending_count() > 0:
        _ = bus.dequeue()
    var manifest = bus.manifest_json("moxi-test", "0.5.0")
    test_check("demo.read" in manifest)
    test_check("exclusive" in manifest)
    test_check("generated_at" in manifest)
    test_check("{not-json" not in manifest)
    var control_descriptor = CapabilityDescriptor(
        "demo.control-description",
        String("Description", chr(1)),
    )
    test_check(bus.register(control_descriptor))
    var control_manifest = bus.manifest_json("moxi-test", "0.5.0")
    test_check(chr(1) not in control_manifest)
    test_check("0001" in control_manifest)
    var handler_bus = CapabilityBus()
    var handler = EchoHandler()
    var echo = CapabilityInvocation(
        "echo-1",
        "demo.echo",
        CALLER_UI,
        "{\"value\":\"hello\"}",
    )
    test_check(
        handler_bus.invoke_handler(handler, echo).status
        == CAPABILITY_HANDLER_NOT_REGISTERED
    )
    test_check(handler_bus.register_handler(handler))
    var echo_result = handler_bus.invoke_handler(handler, echo)
    test_check(echo_result.output == "{\"value\":\"hello\"}")
    var echo_replay = handler_bus.invoke_handler(handler, echo)
    test_check(echo_replay.is_replay())
    test_check(handler.executions == 1)
    var echo_two = CapabilityInvocation(
        "echo-2",
        "demo.echo",
        CALLER_UI,
        "{\"value\":\"second\"}",
    )
    test_check(handler_bus.invoke_handler(handler, echo_two).completed())
    var old_echo_replay = handler_bus.invoke_handler(handler, echo)
    test_check(old_echo_replay.is_replay())
    test_check(handler.executions == 2)
    var mismatch = CapabilityInvocation("mismatch-1", "demo.read", CALLER_UI)
    test_check(
        handler_bus.invoke_handler(handler, mismatch).status
        == CAPABILITY_HANDLER_MISMATCH
    )

    var bounded = CapabilityBus(1)
    _ = bounded.register(CapabilityDescriptor("bounded.one", "One request"))
    test_check(bounded.queue_capacity() == 1)
    test_check(bounded.enqueue(CapabilityInvocation("b1", "bounded.one", CALLER_UI)))
    test_check(not bounded.enqueue(CapabilityInvocation("b2", "bounded.one", CALLER_UI)))
    test_check(bounded.dropped_queue_count() == 1)
    test_check(bounded.dequeue().request_id == "b1")
    test_check(bounded.set_queue_capacity(2))
    print("Moxi capability test passed")
