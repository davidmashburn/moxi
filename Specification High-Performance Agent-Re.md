# Moxi capability-bus design note

Status: design note aligned with the 0.5 implementation. This document describes
the boundary that is shipped today and the seams reserved for a future agent
bridge. It is not a promise that Moxi includes a network client, an LLM runtime,
or a general-purpose JSON Schema implementation.

The source of truth for the UI lifecycle is [ARCHITECTURE.md](ARCHITECTURE.md).
The executable contract examples are in [tests/capability.mojo](tests/capability.mojo)
and [tests/conversation.mojo](tests/conversation.mojo).

Attribution: the capability-bus concept is credited to David Ash and was seeded
from [The Mythophor capability-bus article](https://www.mythophor.com/agent-ready-architecture-the-capability-bus-pattern/).
Moxi adapts that seed into the in-process UI policy boundary described here.

## Purpose and topology

An agent adapter may propose a tool call, but it never receives a direct mutable
reference to application state. UI code and an eventual agent bridge construct the
same `CapabilityInvocation` and pass it through `CapabilityBus`.

```text
agent or UI adapter
        │ CapabilityInvocation
        ▼
CapabilityBus ── policy, schema shape, availability, lease, replay
        │
        ├── authorize()       adapter owns the mutation
        └── invoke_handler()  registered typed handler owns execution
```

The core is synchronous and in-process. Transport, authentication, model
selection, cancellation, persistence, and worker scheduling remain adapter
responsibilities.

## Caller-neutral envelope

`CapabilityInvocation` contains:

- `request_id` and `idempotency_key` for request correlation and replay;
- `capability_name` and a JSON argument document;
- `caller` (`CALLER_UI`, `CALLER_AGENT`, or `CALLER_SYSTEM`);
- optional `caller_component`, `view_route`, and `reasoning_context` fields;
- an approval token and source when a trusted approval has been granted.

The envelope constructor keeps the compact public form:

```mojo
var request = CapabilityInvocation(
    "request-1",
    "wx.submit",
    CALLER_UI,
    "{\"name\":\"Ada\"}",
)
request.set_ui_context("name-field", "demo/form")
```

## Descriptor and manifest contract

`CapabilityDescriptor` declares a stable name, human description, side-effect
class, approval policy, concurrency policy, input-schema fragment, permissions,
and dynamic availability. Schema fragments must be complete JSON objects. The
bus performs bounded JSON grammar validation on non-empty argument documents; it
does not claim full JSON Schema keyword evaluation in 0.5.

`manifest_json(application, version)` emits a valid object with:

- `schema_version`, application identity, and `generated_at`;
- each registered capability's description and input schema;
- side-effect and concurrency labels;
- `available`, `unavailable_reason`, `permissions`, and `schema_valid`.

Adapters can set availability without removing a capability:

```mojo
_ = bus.set_available("cloud.search", False, "Offline")
```

## Authorization and execution

`authorize()` (also exposed as `begin()`) returns a `CapabilityResult` with
`executed == False`. A successful exclusive request includes a lease token;
the adapter must release it with the matching token:

```mojo
var authorization = bus.authorize(request)
if authorization.ok():
    # Apply the application-owned mutation here.
    _ = bus.complete(request.capability_name, authorization.lease_token)
```

`invoke()` is intentionally not an executor. It returns
`CAPABILITY_EXECUTOR_REQUIRED` after policy approval so an accidental call cannot
be reported as completed work. Typed handlers use the explicit execution path:

```mojo
var result = bus.invoke_handler(handler, request)
if result.completed():
    # The handler ran once; an identical request can be replayed safely.
    pass
```

Handlers must be registered with `register_handler()` and their descriptor name
must match the invocation. A mismatched or unregistered handler is rejected.
Successful results are retained in a bounded four-entry recent-history for
idempotent replay.

## Approval policy

Network and destructive agent calls require a bus-issued, one-shot approval bound
to the exact request id, capability name, token, and source. A Boolean supplied by
the caller is not an approval mechanism.

```mojo
var blocked = bus.authorize(agent_request)
var approval = bus.issue_approval(agent_request, "human-confirmation")
agent_request.set_approval(approval)
var permitted = bus.authorize(agent_request)
```

The wx-style showcase exposes this flow as `Agent reset` followed by
`Approve reset`; the approve control is disabled until a request is pending.

## Queue and concurrency

The current queue is a bounded FIFO with four pending entries. `enqueue()` returns
`False` on overflow and `queue_status()` reports `CAPABILITY_QUEUE_FULL`. Exclusive
leases are tracked per capability, so an active `wx.reset` does not block an
unrelated capability. The bus is not a thread-safe scheduler; a future worker
adapter must serialize access to one bus or add its own synchronization boundary.

## Conversation boundary

`ConversationContext` stores role/content history separately from current
application state. `turn_payload(active_state)` injects a fresh escaped system
message at the front of each turn. `append_capability_result()` preserves status,
execution, replay, error code, output, and recovery hint as a structured tool
message so an adapter can let a model recover from validation or approval errors.

```mojo
context.append_capability_result(result)
var payload = context.turn_payload("remember_name:true")
```

The context object does not perform token counting, network I/O, or transcript
retention policy.

## Human-in-the-loop UI seam

The shipped UI seam is deliberately small: an application can render a pending
approval state, call `issue_approval()` only from a trusted UI/policy adapter, and
retry the exact invocation with that approval. A future agent bridge may add a
modal explanation, argument redaction, timeout, cancellation, and audit log. Those
features are not silently implied by the current core.

## Validation matrix

The capability contract is covered by `tests/capability.mojo` for malformed
envelopes, policy rejection, approval binding, availability, leases, queue
overflow, structured arguments, manifests, handler registration, mismatch, and
replay. `tests/conversation.mojo` covers escaped turn payloads and structured
error recovery. `tests/wx_style.mojo` exercises the same policy boundary through
the visible showcase controls.

Run the release checks with:

```sh
pixi run test
pixi run build
pixi run native-object
pixi run package-consumer
pixi run check
pixi run release-check
```

## Future adapter work

The next agent-facing slices are intentionally outside the 0.5 core:

1. a transport-neutral adapter trait with cancellation and deadlines;
2. a complete JSON Schema evaluator or a clearly selected external validator;
3. multi-request approval records and persistent audit events;
4. a worker queue with explicit UI-thread handoff and synchronization;
5. model-specific manifest adapters for local and remote tool protocols.

Each slice should add a shared scenario and a fail-fast contract test before it is
described as shipped.
