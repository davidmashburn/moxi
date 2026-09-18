# Workbench hardening evidence

Raw measurements are preserved without binaries or object files. Each completed
lane has a compact `summary.json` and the unchanged complete report in
`full.json.gz`, including every sample. Raw stdout is also gzip-compressed;
process records, `/usr/bin/time` output, and source hashes remain plain text.
`manifest.json` records SHA-256 and byte size for each artifact, including the
uncompressed hash for gzip files. Gzip headers use a zero timestamp.

Extract a full report without changing the archive:

```sh
gzip -dc docs/benchmarks/workbench-hardening-2026-09-18/baseline-native/full.json.gz > /tmp/moxi-baseline-native.json
python3 -m json.tool /tmp/moxi-baseline-native.json > /dev/null
```

Original reports and process records retain their original `dist/` paths as
provenance. Their matching archived artifacts are under the same lane and `raw/`
subdirectory here, with `.gz` added to compressed files. `archive.py` reproduces
the bundle from completed local lanes; it must not run on a lane still writing.

`first-launch/` and `rebuilt-launch/` pair read-only process observations with the parent's native CUA
window, action, and Command-Q evidence. The process record deliberately leaves
desktop acceptance pending; its paired CUA record supplies those observations.
`repository-check/` preserves the full validation log and its recorded exit code.

## Measurement boundaries

The native lane is offscreen AppKit custom-command CPU drawing. It sums a retained
scene paint and a plot paint into separate fresh bitmap contexts. It does not
measure the actual native control renderer, a composed visible window, event
queue delay, display presentation, or input-to-photon latency. The host's explicit
plot-bounds clip is not applied in this lane. These fixed boundaries support a
before/after custom-path cost comparison, not a desktop frame-rate guarantee.

The baseline's first process overlapped compilation and native UI investigation.
Preserve that contention and all outliers when interpreting run variability.
Candidate source hashes include inactive soak support and the conditional phase
timer switch; the instrumented workload and sampling boundary remain the same.

`soak/` is a persistent 100k-row App with offscreen AppKit drawing: 30 seconds
warm-up followed by a requested 600-second cycle. It is not a native-window soak.
The repository check and visible-window observation overlapped parts of this
run. Its RSS samples and peak are observations, not a proof of leak absence.

`native-window-soak/` separately records RSS for the real visible 100k-row app
for 30 seconds warm-up plus 600 seconds measured. Its paired CUA evidence records
11 periodic interaction cycles, including an approximately three-minute gap
between the first two cycles during context compaction. It is not continuous
high-frequency interaction. Final selected-row export and ordinary Command-Q
are recorded separately from the memory sampler. Recreate its input using
[the fixture recipe and hash](native-window-fixture.md).

Key-construction TSVs are focused development measurements. The baseline is one
pre-change run; the final comparison has three repetitions at 1k/10k/100k rows
across monotone, reversed, shuffled, and sparse-shuffled keys, comparing individual
and bulk append. Key generation is excluded; bulk temporary value/valid-list
construction is included. They ran under concurrent development and should not
be treated as calibrated native performance measurements.

See [the hardening report](../../data-workbench-hardening.md) for interpretation,
support limits, and checks outside these benchmark boundaries.
