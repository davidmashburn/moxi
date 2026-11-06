# E04: experimental native Mojo/CPython boundary

This separate `moxi-native-experimental` wheel calls **compiled Mojo in the
Python process**, through a small C extension. It imports as `moxi_native`;
`moxi`, its dispatcher, and its PNG/SVG/PDF/RGBA contracts are unchanged.
Binding code lives here, outside the stable Mojo package roots. No subprocess,
CLI renderer, JIT, runtime compiler, Mojo import path, or retained Mojo handle
is used by `render`.

The local proof targets Mojo **1.1.0 (8189361e)**, macOS arm64 and the CPython
used to build the wheel. The captured wheel is CPython 3.14/macOS 26/arm64,
**not abi3**, universal, cross-platform, or a production distribution.
`--emit object` is explicitly experimental in this compiler's build help.
The first minimal C export needed only libSystem after object linking; the
actual Moxi scene renderer additionally needs the Mojo runtime.

## Boundary and ownership

```python
import numpy as np
from moxi import PlotSpec
from moxi_native import Column, ColumnKind, RenderFormat, capabilities, render

spec = PlotSpec("Native line")
spec.add_line("signal", "sample", "value")
columns = {
    "sample": Column(np.array([0., 1., 2.], dtype=np.float64)),
    "value": Column(np.array([1., np.nan, 3.]),
                    validity=np.array([True, False, True]),
                    kind=ColumnKind.NUMERIC),
}
png = render(spec.to_json(), columns, 320, 240, RenderFormat.PNG)
print(capabilities())
```

The public call accepts serialized PlotSpec JSON and a mapping of named
`Column` values. A column has a NumPy buffer, optional boolean validity mask,
`ColumnKind`, and optional category dictionary. `float32`, `float64`, `int32`,
and `int64` are supported. Buffers must be one-dimensional, C-contiguous,
native-endian arrays with equal lengths. Read-only and unaligned contiguous
arrays work because values are copied. Strided, object, string, boolean,
complex, unsigned, datetime and masked arrays are rejected. Use the explicit
mask for nulls. Category/string/timestamp kinds and any category metadata are
explicitly rejected, including an empty dictionary; no silent numeric coercion
is offered for them. The named enum is parsed at construction.

Every call snapshots validity and converts numeric values to owned Float64
storage. Invalid entries become zero before native dispatch; valid NaN,
infinity, or magnitudes above 1,000,000 are rejected. The C shim checks the
packed byte lengths, duplicate names, mask bytes, dimensions and finite values
again, and copies numbers into aligned C storage. Mojo copies these values
into a local `PlotDataTable`, parses the bounded spec, constructs the real
Moxi plot scene, and renders it. Scene coordinates are Float32: accepted
Float64/Int64 input does **not** promise 64-bit coordinate precision.

The C buffers are borrowed **only for that synchronous call**, with the GIL
held. Mojo writes into C-owned output memory and destroys all its local
strings, tables, scenes and renderers before returning. C copies that output
into Python-owned immutable bytes and frees its buffers on every exit.
PNG/PDF container encoding then runs in Python on those native pixels.
No Mojo-owned object survives the Python call. This is deliberately a
**copied boundary, not zero-copy**. It does not promise an atomic snapshot
against concurrent writers: callers must not mutate inputs while calling it.
Python thread tests exercise sequential calls under the GIL, not parallel
native execution or free-threaded/subinterpreter support.

## Declared rendering slice

- 1–4 ordinary line/scatter layers; named quantitative x/y fields and constant
  color/opacity/size/line width. Printable ASCII titles/labels only. Shared
  scales retain their default. Transforms, non-default scales, facets,
  annotations, interactions and richer encodings are explicitly rejected.
- 1–8 columns, 1–4096 rows, ASCII identifier names up to 64 characters,
  dimensions 64–1024 per side, JSON up to 16 KiB, styles up to 64 pixels,
  SVG output up to 16 MiB. These are experimental resource bounds.
- Null rows are omitted by the existing plot model for the referenced fields.
  A line connects the remaining valid points; it does not introduce a gap mark.
- SVG comes from `SvgSceneRenderer`. RGBA comes from
  `SoftwareSceneRenderer`, the repository's deterministic verification backend.
  It omits text/image resource pixels and has approximate path rendering.
  PNG losslessly wraps that RGBA; PDF embeds an RGB raster on white. Native PDF
  does **not** claim the facade's vector geometry implementation. The byte
  signatures and dimensions agree; pixel/text/layout parity is not claimed.

`InputError` covers malformed inputs; `UnsupportedError` is its explicit
unsupported-feature subclass. Native statuses map to `NativeRenderError`
with a named `NativeStatus` (`INVALID_SPEC`, `INVALID_COLUMNS`, `OUTPUT_LIMIT`,
`RENDER_FAILED`). `MemoryError` may propagate for host allocation failure.
C validates memory extents even when its private method is called directly.
The private C ABI and status literals are independently tested; they are not
an external stable ABI promise.

## Reproduce locally

From the repository root, with an installed Mojo 1.1.0 Pixi environment and
Xcode command-line tools:

```sh
# Defaults to this checkout's pixi.toml; optionally reuse another installed env.
MOXI_E04_MANIFEST=/path/to/moxi/pixi.toml \
  bash experiments/python-native/build.sh > /tmp/moxi-e04-build.log 2>&1
bash experiments/python-native/check.sh > /tmp/moxi-e04-clean-check.log 2>&1
```

Build-time dependencies are Mojo 1.1.0, clang/Apple SDK, `install_name_tool`,
`codesign`, Python, setuptools and wheel. The recipe copies three libraries
from that compiler installation into the local experimental wheel, rewrites
non-system dependencies to the bundled siblings, removes compiler paths, and
ad-hoc signs the copies. It never modifies the installed compiler libraries.
The requested minimum deployment target is 15, but the actual wheel tag and
Mach-O minimums are inspected; the tested Homebrew CPython host gives a macOS
26 wheel. This is not evidence of macOS 15 deployment.

`check.sh` creates a new venv outside the repo, installs both built wheels plus
NumPy and independent test decoders (Pillow/pypdf), and runs the tests with
`env -i`, `python -I`, no compiler PATH and no user site/import paths. It copies
tests to the consumer directory. The proof installs an audit hook before Moxi
imports that rejects process creation. Loaded-image inspection additionally
checks that all three Mojo runtimes came from the installed wheel, with no
Pixi image loaded. `inspect_wheel.py` independently inspects wheel members,
Mach-O dependency edges, RPATHs, signatures and minimum build versions without
importing the extension. Consumer directories are retained for inspection.

The native suite decodes PNG/PDF with independent libraries, validates SVG,
compares all four facade contracts, tests accepted/rejected dtypes and masks,
checks private C extents and malformed Mojo JSON, and runs 500 successful
renders alternating public and native failures, retaining outputs across GC
and input destruction/mutation. It also checks 40 calls from four Python
threads. This is bounded lifetime evidence, not a leak-proof or sanitizer claim.
The entire existing Python facade regression suite runs against its clean
installed wheel afterward.

Each format has 30 timed calls after three warmups at 320×240, six rows and two
layers. Results retain all samples, mean, sample standard deviation, median,
p95, minimum and maximum. They include validation, copies, parsing, native
render and container encoding; exclude build/install/import, initial warmup,
file IO and screenshots. No comparison ratio or broad speed claim is made.
The shared host was not load-controlled; the recorded dispersion is substantial.

## Deployment decision

**Retain a working local experimental artifact; leave the production E4 gate
open.** The installed artifact works without a compiler or Mojo import paths,
but the runtime dependency has not disappeared: it is bundled. Installed
compiler metadata says `LicenseRef-Modular-Proprietary`. Redistribution terms
were not reviewed and no publication is authorized. A production decision also
needs a supported ABI/runtime distribution policy, other supported hosts and
Python versions, and a deliberate render-coverage policy. Host success alone
does not establish any of these.

The build records the source revision **plus dirty state and source hashes**,
compiler hash, object hash, original/bundled runtime hashes. The wheel
inspection adds hashes of the wheel and installed binary members. The evidence
manifest adds fixture, report, output and screenshot hashes. Binaries,
renders, reports and generated HTML are ignored local outputs; small source,
fixtures, documentation and the capture manifest remain reviewable.

No E02/E03 specialized plot dispatcher or implementation is edited. The
compiled object imports their shared `moxi_plot` base, so integration must
rebuild and rerun this proof after those branches land; an existing wheel's
source hashes cannot establish behavior of a newer integrated revision.
