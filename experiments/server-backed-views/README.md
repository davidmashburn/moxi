# Server-backed reduced-view probe

This is the first bounded experiment from
[the server-backed views plan](https://github.com/davidmashburn/moxi/blob/project-planning/docs/design/server-backed-views.md). It is intentionally example-local and
uses only the Python standard library. Run it from the repository root:

```text
python3 experiments/server-backed-views/probe.py
```

## Scope

`probe.py` generates one million deterministic points using a fixed seed. The
source representation uses two `array('d')` coordinate buffers and one
`array('I')` buffer of stable 1-based source IDs. The IDs are source identity;
they are not density-cell IDs and are not included in a reduced response.

The density query uses a viewport with half-open semantics:

```text
xmin <= x < xmax and ymin <= y < ymax
```

The response is a row-major count grid plus parallel `x_edges` and `y_edges`
arrays. Adjacent edges describe each cell's lower-inclusive, upper-exclusive
bounds. Every query is capped at 128 cells per axis, 4,096 cells total, and a
64 KiB compact JSON response. The response carries the query ID and source
revision but no source coordinate or source-ID arrays.

The in-process adapter keeps camera state synchronous and manually releases
backend callbacks. It permits one active request and one replaceable pending
request. A reply must match session, dataset revision, generation, query ID,
source revision, and grid shape before it can replace the displayed view. The
previous view remains available while a request is outstanding or fails. The
probe also covers backend error/retry, context changes, delayed stale replies,
rapid camera updates, and disposal.

## Checks and measurements

The executable assertions cover:

- exact small-fixture totals, internal boundaries, and viewport upper-bound
  exclusion;
- invalid viewport and grid dimensions, overflowed spans, and unrepresentable
  grid edges;
- a full-range one-million-point query and its payload bound;
- bounded queues during rapid camera changes with delayed completions;
- stale-generation, wrong-session, wrong-revision, and duplicate replies;
- retained prior view after a backend error, retry, and no update after
  disposal;
- the real reducer feeding the adapter, including malformed-response rejection
  with a visible error and successful retry.

The final lines report the actual bytes in the three source array buffers and
the serialized response bytes. Generation and query durations are diagnostics
for this local process only. They do not measure browser responsiveness,
network latency, authenticated transport, server throughput, cancellation,
memory pressure, or notebook compatibility.

Record selection and aggregate selection are deliberately deferred from this
first slice; a future exact-ID/details request must keep that distinction
explicit.

Observed October 27, 2026: the full-range 64-by-64 query preserved a total of
1,000,000 points. Source buffers occupied 20,000,000 bytes; compact response
JSON was 17,554 bytes (64 KiB cap). This compares different representations,
not equivalent fidelity: the response contains density counts, not individual
records. No full-data browser baseline was measured. The reducer scans all
source points; a spatial index and actual backend cancellation remain future work.
The manual transport retains callback history for test replay; it is not a
production transport or bounded long-session memory implementation.
