# Taffy comparison bridge

This is the former retained-layout backend, preserved as an experimental
reference. The production candidate now executes in
[`src/moxi/retained_engine.mojo`](../../src/moxi/retained_engine.mojo).
No workbench, consumer, benchmark or candidate check links this Rust library.
Its declared Rust minimum applies only to this reference crate.

To run its historical contracts independently:

```sh
cargo test --locked --manifest-path native/retained_layout/Cargo.toml
```

The smaller shared-profile comparison in `experiments/layout-taffy` remains
available separately. Neither reference is a requirement for Mojo consumers.
