# Server-backed data with local Moxi interaction

Status: initial in-process contract probe passed; browser/transport integration proposed. October 27, 2026.
Implementation baseline: main `875f714`; no server data path is shipped.

## Direction and ownership

Develop this alongside the [complete web target](browser-execution.md).
Execution target and data placement are independent decisions: browser-hosted
Moxi can own immediate interaction/rendering while a server owns a large dataset
and supplies bounded reductions. Neither track blocks the other's experiments.

Bokeh is a useful reference for [server-side downsampling and client level of
detail](https://docs.bokeh.org/en/latest/docs/user_guide/interaction/tools.html#controlling-level-of-detail)
and [browser/server callbacks](https://docs.bokeh.org/en/latest/docs/user_guide/server/app.html).
It demonstrates deliberate placement, not a rule that all data stays on the server.
This is an architectural reference, not a measured performance comparison.

- Application: data semantics, stable record IDs, reduction/query algorithms,
  authoritative selection and edits. Keep the first implementation example-local.
- Browser view: camera, pointer capture, hover over available records, immediate
  gesture feedback, current reduced view, and a visible pending/error state.
- Data adapter: session/dataset revision/query generation, bounded requests and
  responses, cancellation/coalescing, and disposal. Notebook transport is a later
  adapter over the same requirements, not part of Moxi core.

## First bounded experiment

Implement under `experiments/server-backed-views/` using generated spatial data
with stable IDs. A point-density grid is a suitable first view; do not approximate
the FDG simulation by dropping nodes or edges, which changes its semantics.

1. Generate a million points on the backend and query a viewport into a capped
   grid. Return counts, cell bounds, source revision, and query identity. Keep
   source coordinates out of the response. Verify totals and boundary behavior
   against an exact small fixture and test a full-range large query.
2. Keep local camera updates synchronous. Allow at most one active query and
   one replaceable pending request. Only matching session, dataset revision,
   and current generation may replace the displayed result. Test out-of-order
   replies, rapid camera changes, failure/retry, and disposal. Retain the previous
   view while refreshing; never blank it merely because a query is outstanding.
3. Distinguish aggregate selection from record selection. Query exact IDs/details
   on demand with a separate cap; never treat aggregate cell IDs as source IDs.
   Preserve stable selections across reductions and dataset revisions explicitly.
4. Compare the local-full-data and reduced-view routes with identical source
   data and gestures. Record source/result bytes, reduction time, browser memory,
   input-to-local-feedback and time-to-fresh-data separately. Sweep artificial
   delays before testing an actual authenticated transport and remote kernel.

Command: `python3 experiments/server-backed-views/probe.py`.
Acceptance for the first slice: exact counts, bounded payload and queue, stale
responses rejected, camera changes independent of backend completion, and
explicit failure/disposal behavior. An in-process simulation establishes these
contract properties only; it cannot establish browser responsiveness, network
latency, production throughput, or notebook compatibility.

## First-slice evidence

An uncommitted standard-library Python experiment now exists at the path above
on main's `875f714` baseline. It generates one million deterministic points with
stable IDs in compact arrays and produces a 64-by-64 density view. Exact small
fixtures test half-open viewport/cell boundaries; the full query preserves the
million-point total. Invalid dimensions, nonfinite/overflowed viewport spans,
and unrepresentable grid edges are rejected.

Observed source buffers: 20,000,000 bytes; compact JSON response: 17,554 bytes,
below the 65,536-byte cap. This is a reduction in information as well as bytes:
the response carries counts and cell edges, not individual records. It is not
an equivalent-fidelity full-data comparison or a browser performance claim.
The current reducer scans all source points; no index was introduced.

The manually completed callback harness passes 40 rapid camera changes with
one active request and one replaceable pending request. Local camera state
changes before any backend completion. The previous result remains available
and is marked non-current until the latest valid reply arrives. Stale generation,
wrong session/revision, duplicate replies, backend failure/retry, and disposal
checks pass. A fresh integration check feeds the actual reducer into the adapter,
rejects a mismatched response with an error, and successfully retries. Review
also caught and fixed an extreme-coordinate intermediate-overflow case.

These are in-process contract tests, not a browser renderer or real transport.
The test transport retains callback history for replay; it does not establish
bounded long-session memory. Backend cancellation, real delays/disconnection,
exact-record selection, full-data comparison, browser memory and interaction
latency, and Jupyter are still unverified. The README and ignored result log live
beside the experiment; no dependencies or product APIs were changed.

## Integration and remaining gates

Connect the reduced-view adapter to the browser target once a minimal Moxi
event-to-scene path works. Pan/zoom transforms the previous view immediately;
fresh data refines it asynchronously. Report incomplete coverage during panning
and errors without silently presenting stale data as current. Selection/edit
commands need their own authoritative acknowledgement semantics.

Then exercise bounded queues under real slow/disconnected transport, cancellation
of expensive work, disposal/restart, two isolated views, and the
[Jupyter lifecycle](jupyter-integration.md). Choose a binary or text representation
from measured costs. Do not add a public server, authentication system, generalized
query framework, full-data cache, or notebook dependency for this first probe.

Confidence: high that the two tracks can coexist architecturally; unmeasured
whether this placement wins for a specific Moxi workload. Reduction quality,
backend query cost, browser memory, and end-to-end measurements can change which
datasets should use it. A full browser target remains useful even when this
data strategy is not beneficial.
