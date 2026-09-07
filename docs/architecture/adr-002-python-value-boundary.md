# ADR-002: Start Python at a value boundary

Status: accepted for the first Python milestone.

## Decision

The first Python call accepts serialized `PlotSpec` data and typed contiguous
column buffers and returns an owned file/buffer result. Mojo objects, borrowed
views, native renderer lifetimes, callbacks, and event loops do not cross the
boundary.

## Consequences

- a clean wheel can validate inputs without exposing compiler internals;
- copy versus zero-copy behavior can be measured and documented per dtype;
- NumPy is the first numeric adapter, with pandas and richer nullable/string/
  timestamp adapters following the core contract;
- Python and Mojo share scenario descriptors and checksums; and
- a compiler-dependent developer build is labeled experimental rather than
  advertised as a production wheel.

