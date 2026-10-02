# Taffy 0.14 comparison spike

This directory is an isolated, reproducible experiment for the layout-engine
comparison described in [`docs/layout-research.md`](../../docs/layout-research.md).
It is not a Moxi production dependency and does not change Moxi's build or
runtime. The spike uses the exact Cargo dependency `taffy = "=0.14.0"` and a
checked-in `Cargo.lock`.

The experiment answers four narrow questions:

1. Can Taffy 0.14 express the shared row, column, min/max, and wrapping
   fixtures?
2. Can its external measurement callback use Moxi's deterministic estimator?
3. Does a retained Taffy tree avoid leaf callbacks on an unchanged rerun and
   remeasure only the invalidated part after one text update?
4. Is a small C ABI and static library technically feasible?

It does not establish a speed ranking against Mojo. No Mojo implementation was
available in this spike, and the benchmark below is a Rust-level Taffy run with
local result publication, not an end-to-end Mojo or production-renderer run.

## Reproduce

Run from this directory:

```sh
cargo fmt --check
cargo test --locked
cargo build --release --locked
./target/release/layout-taffy correctness
./target/release/layout-taffy correctness-json
./target/release/layout-taffy benchmark --iterations 7
```

The executable defaults to seven iterations. `TAFFY_BENCH_ITERS=3` or
`--iterations 3` is useful for a quick smoke run. The release benchmark is
intentionally separate from `cargo test`; the reported numbers below were
collected with `--iterations 7`.

The optional static-library check uses the checked-in C header and example:

```sh
cc -std=c11 -Wall -Wextra -Iinclude \
  examples/ffi_smoke.c target/release/liblayout_taffy_spike.a \
  -o target/release/ffi-smoke
target/release/ffi-smoke
```

Expected smoke output has a positive rectangle, for example:

```text
ffi first: 0.00 0.00 100.00 20.00
```

`Cargo.lock` pins Taffy and its transitive crates. `cargo tree --locked` is a
quick way to inspect the resolved set. The crate declares `rlib` and
`staticlib` outputs; the binary is only a benchmark and fixture runner.

## API boundary

The implementation uses Taffy's high-level
[`TaffyTree`](https://docs.rs/taffy/0.14.0/taffy/struct.TaffyTree.html) with a
`NodeContext` per node. Nodes are created with
`new_leaf_with_context`/`new_with_children`; layout calls
`compute_layout_with_measure`; copied rectangles are read through `layout`.
The external callback receives Taffy's `LayoutInput`, `NodeId`, optional node
context, and style. It delegates leaf sizing to the versioned
[`compute_leaf_layout`](https://docs.rs/taffy/0.14.0/taffy/fn.compute_leaf_layout.html)
helper so padding, min/max, and the callback's available width go through the
same leaf path.

Taffy does not supply font shaping or text metrics. The callback deliberately
uses the estimator already documented by Moxi: each Unicode scalar has advance
`font_size * 0.56`, greedy wrapping uses the offered width, and each line is
`font_size * 1.25` high. At font size 16, that is an 8.96-point advance and a
20-point line height. This is deterministic fixture behavior, not native font
parity.

The C bridge is intentionally smaller than the Rust API:

- `layout_taffy_create(width, height)` creates an opaque retained row tree.
- `layout_taffy_add_text` copies a NUL-terminated string into a measured leaf.
- `layout_taffy_compute` updates the root viewport and computes layout.
- `layout_taffy_get_rect` copies one rectangle by an adapter-owned integer
  index; Taffy's generational `NodeId` never crosses the ABI.
- `layout_taffy_destroy` releases the handle.

The create/add/compute/query operations catch Rust panics and return an error
code; destroy only drops a valid handle. The bridge does not yet expose
structured errors, C-side measurement callbacks, remove or reparent
operations, threading guarantees, or an allocation policy. The smoke program
proves that the current arm64 static library links and executes; it is a
feasibility result, not a production integration.

## Correctness fixtures

The executable prints rectangles in the order root, first child, second child.
The release run used for this document produced:

```text
correctness:
  row-weighted-fill-min-max: rects=(0.00,0.00,300.00,40.00) (0.00,0.00,60.00,40.00) (70.00,0.00,230.00,40.00) callbacks=4 measured=4 measure_ns=42
  column-content-header-fill-body: rects=(0.00,0.00,300.00,200.00) (10.00,10.00,280.00,20.00) (10.00,35.00,280.00,155.00) callbacks=6 measured=6 measure_ns=209
  wrapped-text-at-offered-width: rects=(0.00,0.00,200.00,60.00) (0.00,0.00,95.00,40.00) (105.00,0.00,95.00,60.00) callbacks=4 measured=4 measure_ns=126
```

The callback nanoseconds vary by run; geometry is the acceptance result.
For differential fixture checks, `correctness-json` prints the same geometry and
counter fields as strict JSON on stdout; its rectangle order is root, first
child, second child.

| Fixture | Input contract | Expected geometry |
| --- | --- | --- |
| Weighted row with cap | Row width 300, gap 10; flex weights 1 and 2; both basis 0, min width 0, shrink 0; first max width 60 | First child `x=0, width=60`; second `x=70, width=230`; both height 40 |
| Content header and fill body | Column viewport 300x200, padding 10 on every side, gap 5; fixed header height 20; body `flex_grow=1`, minimum height 40 | Body `x=10, y=35, width=280, height=155` |
| Wrapped text at offered width | Row width 200, gap 10; two fill children receive `(200 - 10) / 2 = 95`; font 16, advance `.56`, line height `20` | 20 scalars wrap to height 40; 30 scalars wrap to height 60; both widths 95, second child x 105 |

The row's `flex_basis=0`, zero minimum, and zero shrink are explicit so the
fixture tests weighted remaining-space allocation rather than a content-based
automatic minimum. The column fixture checks that padding is consumed once and
that the fill body receives the remaining inner height. The wrapping fixture
checks that the measurement callback sees the allocated width before returning
the height.

## Benchmark protocol

Each sample creates a fresh retained tree, then runs these phases in order:

1. **Tree creation:** create all Taffy nodes and parent links. This duration is
   reported separately and is excluded from every layout phase.
2. **Cold:** compute layout with the fixed 800x600 viewport, then read every
   node's `Layout` and fold its four fields into a checksum.
3. **Update mutation:** append one character to the first measured leaf and call
   `set_node_context`; this mutation is timed separately from the following
   layout.
4. **Update:** compute and publish every node after the invalidation.
5. **Unchanged:** repeat the same compute and publication without another
   mutation.

The wide shape is one flex-row root with `N - 1` measured leaves. The deep
shape uses up to four children per container, exact node counts, and a maximum
tree level of eight. The resulting longest-path depths are reported in the
table. Publication is a local loop over `tree.layout(node)` for all nodes; it
stands in for copying a layout snapshot but does not measure C marshaling,
Mojo calls, rendering, or allocation counters.

`callback` counts are invocations of the Taffy external measurement callback,
not unique leaves. Taffy can ask the same leaf under multiple constraints.
`measure` is time spent in the deterministic text/box measurement body inside
that callback. All durations and callback counts are summarized as median/p95
over seven samples; values are nanoseconds and formatted as `median/p95`.
`total` is layout plus publication for that phase. Checksums are included to
make result publication observable; equal checksums after an edit are possible
when the edit does not change geometry.

## Release results

Environment for the captured run on 2026-09-24:

```text
architecture: arm64
OS: macOS 26.6.2 (25G83)
rustc: 1.97.1 (8bab26f4f 2026-07-14)
cargo: 1.97.1 (c980f4866 2026-06-30)
clang: Apple clang 21.0.0 (clang-2100.0.123.102)
dependency: taffy 0.14.0, locked checksum 639627c87f43b9181c811f40a6296409e093a17bc761214cba3c15df74f86b99
profile: cargo release, seven iterations, median/p95
```

The full runner output is preserved here so the individual timing, callback,
measurement, and checksum fields remain auditable:

```text
benchmark columns: shape nodes depth iterations | creation_ns median/p95 | cold_layout_ns median/p95 | cold_publication_ns median/p95 | cold_total_ns median/p95 | cold_callbacks median/p95 | cold_measure_ns median/p95 | update_mutation_ns median/p95 | update_layout_ns median/p95 | update_publication_ns median/p95 | update_total_ns median/p95 | update_callbacks median/p95 | update_measure_ns median/p95 | unchanged_layout_ns median/p95 | unchanged_publication_ns median/p95 | unchanged_total_ns median/p95 | unchanged_callbacks median/p95 | unchanged_measure_ns median/p95
benchmark wide 100 2 7 | 17875/29833 | 29792/45333 | 208/209 | 30000/45541 | 198/198 | 3794/4206 | 166/542 | 15834/21166 | 209/250 | 16043/21416 | 2/2 | 41/84 | 417/500 | 209/209 | 625/709 | 0/0 | 0/0
  checksums cold=284398392763374922 update=284398392763497802 unchanged=284398392763497802
benchmark wide 1000 2 7 | 143750/207375 | 240708/253208 | 2208/2250 | 242916/255458 | 1998/1998 | 37704/38793 | 167/375 | 114875/136042 | 2250/2250 | 117125/138250 | 2/2 | 41/84 | 5250/11500 | 2208/2291 | 7459/13791 | 0/0 | 0/0
  checksums cold=6445915809941380334 update=6445915782560963822 unchanged=6445915782560963822
benchmark wide 10000 2 7 | 1989916/3694583 | 6086458/9347125 | 22958/47041 | 6109416/9394166 | 19998/19998 | 405786/451386 | 2750/8542 | 3961125/5893416 | 23084/24000 | 3983709/5916999 | 2/2 | 333/625 | 59250/68917 | 22416/22583 | 81791/91333 | 0/0 | 0/0
  checksums cold=14356385315197303812 update=12050542305983609858 unchanged=12050542305983609858
benchmark deep 100 5 7 | 15708/22666 | 44583/57750 | 208/250 | 44833/57958 | 192/192 | 3785/4459 | 167/875 | 3917/6125 | 208/250 | 4125/6333 | 3/3 | 83/84 | 459/583 | 209/209 | 668/792 | 0/0 | 0/0
  checksums cold=13759529268550559611 update=13759529268550559611 unchanged=13759529268550559611
benchmark deep 1000 6 7 | 145667/187042 | 467459/560458 | 2250/2292 | 469709/562750 | 1977/1977 | 40545/41959 | 250/792 | 11292/11958 | 2209/2250 | 13501/14208 | 3/3 | 83/124 | 5875/5959 | 2208/2250 | 8124/8126 | 0/0 | 0/0
  checksums cold=18122358006890286385 update=18122358006890286385 unchanged=18122358006890286385
benchmark deep 10000 8 7 | 1766625/2977458 | 6966833/7831542 | 22667/129458 | 6989458/7860292 | 13617/13617 | 283189/297836 | 2333/4792 | 82833/728584 | 22458/39375 | 105375/767959 | 3/3 | 83/250 | 77584/569917 | 22292/36250 | 99876/606167 | 0/0 | 0/0
  checksums cold=14827440550859921760 update=14827440550859921760 unchanged=14827440550859921760
```

The p95 outliers in the larger deep rows are retained as observed rather than
discarded. They are a reason to repeat the protocol on the target machines
before deriving any budget. The stable behavioral signal in this run is that
the unchanged phase made zero measurement callbacks for every shape and size;
one-leaf updates made two callbacks in wide trees and three in deep trees.

## Integration tradeoff and recommendation

Taffy is a credible comparison engine for the flex/content slice: the pinned
API expresses the weighted cap, padding plus fill, and width-dependent
measurement fixtures, and its retained tree cache gives the desired zero
callback unchanged rerun in this experiment. The high-level API also keeps
styles, contexts, generational node IDs, and computed layouts together, which
reduces the amount of layout bookkeeping in an adapter.

The static library boundary is technically feasible, but shipping it would add
a Rust/Cargo artifact and target-specific cross-compilation/linking to the Moxi
package. Moxi would need an identity map from retained view handles to Taffy
`NodeId`s, an explicit ownership and error model, a text measurement callback
that shares metrics with rendering, and a publication path for all geometry.
The current bridge is deliberately too narrow to settle those choices. A
low-level Taffy tree could avoid mirroring some storage, but it would transfer
cache invalidation and tree bookkeeping to Moxi; this spike does not measure
that alternative.

Recommendation from this spike: keep Taffy as the opt-in comparison/prototype
path and use its behavior to inform the Mojo adapter contract. Do not make it a
production dependency or claim a performance win yet. The next decision needs
an equivalent Mojo implementation, target-platform packaging test, and native
text-metric parity check. Taffy's own published benchmark table also excludes
tree creation and uses particular revisions, so it is methodology context, not
evidence for a Moxi engine ranking; see the
[`Taffy benchmark notes`](https://github.com/DioxusLabs/taffy#benchmarks-vs-yoga).

## Primary API sources

- [Taffy 0.14.0 `TaffyTree` API](https://docs.rs/taffy/0.14.0/taffy/struct.TaffyTree.html)
- [Taffy 0.14.0 `compute_leaf_layout`](https://docs.rs/taffy/0.14.0/taffy/fn.compute_leaf_layout.html)
- [Taffy 0.14.0 crate source](https://docs.rs/crate/taffy/0.14.0/source/)
- [Taffy upstream benchmark scope](https://github.com/DioxusLabs/taffy#benchmarks-vs-yoga)
