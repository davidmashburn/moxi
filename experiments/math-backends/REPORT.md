# D01 measured decision and delivery evidence

Use the persistent **SymPy worker as the provisional initial D02 adapter**.
Confidence: **moderate**. Both executable probes preserve exact supported scalar
semantics and satisfy the tested ownership, process, queue and stale-result
boundaries. The SymPy adapter additionally handles four relevant corpus cases
and has lower warm median boundary cost in this run. SymEngine starts faster and
uses less resident memory. This decision is specific to the implemented bridge;
it is not a comparison of the engines' intrinsic arithmetic throughput.

The full editing/distribution exit contract is **not yet proven**. D02's actual
2D editor and a relocatable, signed application are absent from this probe.
The smallest next integration is to connect D02's selected subtree and lossless
text representation to `Request`/`Document`, then repeat the same corpus and
lifecycle checks in that editor. Shipping requires a separate runtime/package
verification. Do not mark those gates complete based on this report.

## Recorded run and correctness

Evidence was collected on 2026-11-06, macOS 27.0.1 arm64. The exact build flags,
engine/toolchain versions, source archive checksum, selected binary hashes,
linked dependencies and sizes are in [environment.json](evidence/environment.json).
SymEngine 0.14.0 was built locally, Release/shared/GMP 6.3.0, with thread-safe
reference counting enabled. The Mojo compiler was 1.1.0 (8189361e), Python 3.14.7,
SymPy 1.14.0 and mpmath 1.3.0. Build/reproduction commands are in [README](README.md).

All 16 shared corpus cases had their expected outcome for both adapters: SymPy
returned 13 editable results and three explicit unsupported results; SymEngine
returned nine editable results and seven explicit unsupported results. There
were no unexpected transport failures or incorrect hand-oracle results.

| Cases | SymPy probe | SymEngine probe |
|---|---|---|
| Exact fraction, 90-digit integer payload, exact decimal | Supported | Supported |
| Expansion, selected numerator, polynomial/sine-product derivative, compound substitution | Supported | Supported |
| General complex `sqrt(x²)` | Remains conditional expression | Remains conditional expression |
| Positive symbol `sqrt(p²)` | Returns the positive symbol | Unsupported assumption |
| Real symbol root requiring `Abs` | Unsupported result | Unsupported assumption |
| Small matrix, explicit matrix product, unknown named function | Supported | Unsupported adapter input |
| Unknown-function derivative and infinity | Unsupported result | Unsupported input/result |
| Holes, malformed text, unresolved rows, bound-variable scope | Local rejection before worker launch | Same |

The native adapter's refusals do not establish a limitation of SymEngine's full
API. Only this intentionally small adapter was implemented. The native bridge
uses the selected release's [C wrapper](https://raw.githubusercontent.com/symengine/symengine/v0.14.0/symengine/cwrapper.h),
including owned basic handles, expression arguments, exact numerator/denominator,
expansion, differentiation and substitution. Mojo owns move-only expressions;
small C helpers scope vector/string ownership. No C++ layout crosses the ABI.

Expected results are independently written trees. The comparison oracle only
flattens associative sums/products and disregards their order and node IDs;
it never asks either engine to prove equivalence. Each successful imported tree
passes validation, lossless JSON notation round-trip and re-submission. Original
notation remains intact until explicit application. Matrix multiplication and
scalar multiplication have separate node kinds. Unsupported import does not
invent symbols or silently discard assumptions.

The structural/JSON equivalent-edit check is useful semantic-boundary evidence,
but does not demonstrate a human-readable math syntax or actual 2D caret edits.
Those remain explicit D02 gates. The native demonstration is the real Moxi
`App`/`Component` on `MacOSWindow`/`MacOSRenderer`; no renderer file was changed.

## Timing and retained memory

[Raw measurement summaries](evidence/measurements.json) were recorded at
2026-11-06T10:23:02Z. There are 30 repeated expansions per size and engine in
one persistent process. The expressions repeat identically, so engine caches
remain enabled. This is a warm repeated-request workload, **not a measurement of
30 distinct newly edited expressions**. The first sample for a new size may
include uncached work; no artificial warm-up removes it. With 30 samples,
nearest-rank p99 equals the maximum. This small single-host run does not establish
stable tail latency or a universal performance ranking.

| Worker | Startup handshake ms | Cold first result, IO ms | Cold observed by caller ms | RSS before/after warm run MiB |
|---|---:|---:|---:|---:|
| SymPy | 275.612 | 288.385 | 288.938 | 57.81 / 58.34 |
| SymEngine | 41.300 | 41.913 | 42.142 | 25.27 / 25.66 |

Warm IO-thread request time, milliseconds, median / p95 / p99 / maximum:

| Expression | SymPy | SymEngine |
|---|---|---|
| `(x+y)^2` | 0.149 / 0.179 / 0.249 / 0.249 | 0.243 / 0.313 / 0.314 / 0.314 |
| `(x+y)^8` | 0.401 / 0.487 / 1.662 / 1.662 | 0.832 / 0.876 / 0.910 / 0.910 |
| `(x+y)^24` | 0.964 / 2.646 / 3.624 / 3.624 | 2.535 / 2.615 / 2.672 / 2.672 |

Caller-observed submit-through-poll time, milliseconds, same statistics:

| Expression | SymPy | SymEngine |
|---|---|---|
| `(x+y)^2` | 0.773 / 0.779 / 0.841 / 0.841 | 0.774 / 0.839 / 0.878 / 0.878 |
| `(x+y)^8` | 0.781 / 0.846 / 2.060 / 2.060 | 0.861 / 1.304 / 1.566 / 1.566 |
| `(x+y)^24` | 1.004 / 2.685 / 3.659 / 3.659 | 2.573 / 2.927 / 3.069 / 3.069 |

The caller harness polls at 0.5 ms intervals, creating a measurement floor at
small sizes. `total_ns` begins when the IO thread dequeues work and ends after
validated import; it includes cold startup but excludes submit-time validation,
thread scheduling and UI polling. `app_observed_ns` includes those caller costs
and polling delay. Neither metric includes rendering.

The JSON report separately records export serialization, round-trip, residual
transport, worker construction, explicit computation, worker conversion and
validated parent import. `transport_ns` subtracts the reported worker span from
the round-trip, so includes worker framing/encoding and scheduling rather than
pure kernel pipe time. Constructor canonicalization is in `construct_ns`, not
`compute_ns`. Medians of the parts need not sum to median end-to-end time.

For power 24, median worker conversion was 0.357 ms (SymPy) versus 1.665 ms
(SymEngine); parent import was 0.327/0.330 ms. The Mojo worker embeds CPython for
structured framing/tree objects, and repeated Mojo-to-Python conversion dominates
its warm boundary cost here. It does not use a Python SymEngine binding. Removing
that cost or measuring predominantly novel/large expressions could change the
choice. SymEngine already has better p99/max for powers 8 and 24 in this sample.

The parent integration capture recorded 320 app ticks. During real slow
expansions, excluding capture pauses, SymPy had 49 intervals with median/p95/max
17.133/20.351/20.789 ms; SymEngine had 49 at 17.151/21.027/21.175 ms. The loop
intentionally sleeps 16 ms and continues dispatching events and applying edits.
These are application tick intervals, **not GPU presentation timestamps** or a
human usability assessment. Original intervals are in the gallery's `frames.json`.

## Lifecycle and failure evidence

The worker suite passed **32 tests**; parent review added two selected-binder
regressions and reran all **34 tests** successfully. Selecting the body or a deeper
subtree of an integral is rejected before worker launch, preserving the same
bound-variable scope restriction as whole-expression requests.
The suite exercises independent document revision
and request generation checks, selected-subtree application, local input
rejection, bounded one-active/one-pending replacement, real slow-work edits,
logical cancellation, physical kill, deadlines, restart and document closure.
Malformed, truncated, oversized and wrong-identity worker responses are rejected;
unknown symbols/domains/statuses cannot become editable results. A missing worker
reports failure without damaging the document.

Native live basic/string counters returned to zero after every observed success
and failed import, including 100 alternating requests per engine in the suite
and a separate 200-operation native stress run. C vectors are locally scoped.
The counters do not count every internal SymEngine/GMP/CPython allocation.
Resident growth across the warm run was about 0.53 MiB for SymPy and 0.39 MiB for
SymEngine; retained memory includes caches and is not a leak measurement.

macOS `leaks` exited successfully and reported zero leaks for the 200-request
native process, **with a restricted-process warning**: the process was not
debuggable and only restricted memory contents were available. That result is
limited evidence. ASan, Instruments and an exhaustive native allocator audit
were not run. Killing a process releases its address space; this does not imply
an in-process algorithm is cooperatively interruptible.

## Packaging, size and notices

`package-check.sh` built a wheel and installed it in a fresh temporary virtualenv.
A copied consumer outside this checkout imported only the installed package,
verified base import without SymPy, installed the pinned optional dependencies,
ran `pip check`, and exercised both real workers. This caught and fixed embedded
CPython's environment overrides selecting the wrong interpreter despite an
explicit virtualenv executable. The regression is covered by the focused suite.

The Python wheel contains the protocol/controller/adapters and original MIT
license. It does **not** contain the native executable or a Python/Mojo runtime.
The native consumer still uses the explicit development executable and its
local dependency paths. Thus a clean wheel consumer passes, while clean-machine
application distribution remains unverified.

| Installed development component | Bytes |
|---|---:|
| SymEngine worker | 204,016 |
| SymEngine shared library | 4,831,640 |
| GMP shared library | 452,352 |
| Selected Mojo compiler runtime library | 1,173,120 |
| CPython shared library | 5,452,528 |
| SymPy package tree, including installed tests/cache | 72,504,792 |
| mpmath package tree, including installed tests/cache | 4,705,614 |

These are component observations, not an additive final bundle size. The dynamic
inventory includes additional Mojo/system dependencies; the full runtime closure,
Python standard library, duplication and signed bundle were not assembled.

Original probe code uses the repository's MIT license. Pinned upstream notices
are preserved under `notices/`: SymEngine's complete distributed LICENSE plus
cereal, SymPy's LICENSE and bundled latex notice, mpmath, and GMP's GPL/LGPL texts.
SymEngine's top-level MIT license includes third-party notices; it is not a
substitute for dependency review. SymPy's BSD distribution includes additional
notices as well. See the pinned [SymPy license](https://raw.githubusercontent.com/sympy/sympy/sympy-1.14.0/LICENSE).

The chosen GMP configuration is **not an entirely permissive dependency stack**.
[GMP's copying terms](https://gmplib.org/manual/Copying) offer LGPLv3-or-later as
one option. Before distributing a bundled application, verify notices,
corresponding source availability and required replacement/relinking ability,
including the effects of signing. This unbundled development test does not prove
those obligations are met. CPython and Mojo runtime redistribution terms/notices
also require verification for the actual assembled artifact. No signed installer
or runtime source-delivery package was produced.

No entirely-permissive dependency requirement was established, so the conditional
Boost multiprecision build was skipped. It must be measured separately if that
policy becomes a requirement; GMP was not rejected on an inferred policy.

## Artifacts and integration handoff

The [portable slideshow](../../artifacts/demo-slideshows/d01-math-backends/index.html)
contains 27 actual running-window captures, previous/next controls, arrow-key
navigation and a contact sheet. Adjacent PNGs, `captures.json`, the shared-gallery `manifest.json` and `frames.json`
record the fixtures, actions, actual source/result/status, revisions/generations,
base Git revision, source SHA-256, host and dimensions. The base is
`df1eff863f8da5cf2e121ce44bc70e99838fde1c` plus the capture/gallery integration diff.
The capture fingerprint covers executable probe sources/scripts and package
metadata, not documentation/evidence files. A fresh source run produces its own
fingerprint. See README for exact reproduction.

Final artifact verification matched all 27 captures to source fingerprint
`22ce2c782b42f36c53c776aa60ce8628226ae7193c88d8599ab915e9a0188b35`.
Each original is 2200×1520 pixels for a 1100×760-point window. Browser checks
loaded all 27 slides and thumbnails, exercised next/arrow-back/contact-sheet
controls, and found no external image dependencies or failed image loads.
The parent visually inspected exact-result, unsupported-result, restart and
measured-decision screenshots. Shared gallery validation passed for all three
integrated demos. The engine timing tables above retain the original benchmark
run; this fresh capture only replaces native screenshot/frame evidence.

The OS screen-capture command failed (`could not create image from window`).
The fallback snapshots the live Moxi window's AppKit content view, after rendering,
using `cacheDisplayInRect`. It does not construct an offscreen scene, but also does
not verify the OS compositor, window chrome or physical display. Both the
manifest and gallery disclose this limitation. Scripted UI actions call the same
state/controller methods as the buttons; physical pointer/keyboard/IME behavior
was not exercised.

Changes are confined to `experiments/math-backends/` and its D01 gallery. The
application glue is 1,563 lines of Python/Mojo/C/Objective-C plus 236 lines of
focused tests/consumer checks and small shell scripts. This includes
the semantic model, shared protocol, two adapters, native demo, measurement and
gallery tools; it is not merely the size of a C ABI wrapper. Parent review covered boundary validators, document eligibility and process
teardown, fixed the selected-binder escape described above, and reran the clean
installed-consumer checks successfully. The documented embedded-Python path
command was corrected for macOS framework installations after a failed launch;
the corrected command produced the fresh captures.

Local logs remain under `/tmp/moxi-d01/`: `configure.log`, `build.log`,
`install.log`, `worker-build.log`, `final-check.log`, `final-package.log`,
`leaks.log`, `leaks-summary.log`, `verified-demo.log`, and `demo-build.log`.
Clean-consumer details are in `/tmp/moxi-d01-consumer.RD1ZMZ/`.
No existing renderer/core file, planning file, commit, PR or shared-system record
was changed. The parent owns review/commits, planning-row linkage, master-gallery
integration and acceptance of the remaining D02/distribution gates.

Not run: full Moxi regression suite, upstream SymEngine tests, remote CI,
Linux/Windows/other architecture runs, signed/relocatable bundle checks, actual
2D editor interactions, GPU frame presentation, accessibility and human usability.
