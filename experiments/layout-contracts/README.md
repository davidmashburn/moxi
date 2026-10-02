# Layout contract probes

Small Python standard-library reference models for the
[Moxi layout API review](../../docs/design/layout-api-review.md). They explore
contracts before committing to production Mojo types. They are not a new runtime,
performance benchmark, native renderer, or proof of the entire architecture.

Run from the repository root:

```sh
python3 -m unittest discover -s experiments/layout-contracts -p 'test_*.py' -v
```

| Model | Questions exercised |
| --- | --- |
| `measurement.py` | Exact width proposals, wrapping thresholds, baseline union, memoization, content/environment/mount invalidation, and one final placement per child |
| `adaptive.py` | Stable content slots across policy switches, separate divider lifetime and resize state, key/type/owner changes, focus/capture, stale work |
| `viewport.py` | Mixed section origins, measured extent correction, key-based anchors, source revisions and realization windows |

The measurement fixture uses five-point characters and toy line boxes. It tracks
explicit revision stamps; it has no shaping, font fallback, painting or native
paragraph payload. Its cache is deliberately unbounded and its proposals cover
only the inline axis. Tests of stamp validity are not tests of a renderer.

The adaptive fixture simulates editor identity and interaction state. It does not
invoke IME, mount native controls, expose accessibility nodes or allocate real pane
rectangles. Its policy constructors and visible generation integers are probe
instrumentation, not the proposed public API. Production callers get opaque handles.

The viewport fixture uses one row section between fixed header/footer boxes and a
finite in-memory extent model. Bounded visible item selection does not establish
a production index's asymptotic cost or memory use. It does not implement arbitrary
section providers, section reordering or cross-section anchor fallback. It does not
validate row-content/font/width invalidation, a two-dimensional table, frozen
columns, native scrolling, sticky semantics, asynchronous lifecycle effects or
the whole transaction pipeline.

These tests make specific counterexamples reproducible. They cannot independently
prove an API implemented by their own reference model; the review also considers
external protocols, adversarial ownership cases and explicit production gates.
