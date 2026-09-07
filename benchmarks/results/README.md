# Reviewed benchmark baselines

This directory contains deliberately reviewed release references, not every
local or CI sample. A baseline is valid only for the environment recorded in
its JSON `environment` object (`git_revision`, dirty state, Mojo version, OS,
and architecture).

To refresh the macOS arm64 full-profile reference:

```sh
MOXI_BENCHMARK_PROFILE=full \
MOXI_BENCHMARK_RUNS=3 \
MOXI_BENCHMARK_OUTPUT=benchmarks/results/macos-arm64-full.json \
bash scripts/benchmark.sh
```

Run this from a clean tree after reviewing deterministic counter/checksum
changes. The report is generated before the baseline file is written, so its
`git_dirty` field describes the source revision being measured. Review the
diff, keep deterministic metrics and checksums stable, and commit the baseline
only when the workload change is intentional. Wall-clock samples are useful
for same-environment diagnostics; they are not portable promises.
