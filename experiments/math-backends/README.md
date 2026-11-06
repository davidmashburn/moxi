# D01 — symbolic backend comparison

Choose **the persistent SymPy worker for the initial D02 adapter**, provisionally.
The runnable experiment implements both candidates against one exact-expression
corpus. SymPy covers more of that corpus and has lower warm median request cost
through this implementation; SymEngine has substantially lower startup and RSS.
This is an application-boundary decision, not a claim about intrinsic engine
speed. Confidence is **moderate**: a less expensive Mojo conversion layer,
different required operations, deployment constraints, or larger repeated
measurements could change the choice.

The implementation lives entirely in this experiment. It does not change Moxi's
renderer, existing packages, or the planning checkout. Its native demo is an
actual Mojo `App`/`Component` with `MacOSWindow` and `MacOSRenderer`, submitting to
the same workers and corpus as the tests. The Python package is deliberately
experimental; it is not the D02 editor or a general CAS API.

## Run from a fresh task environment

Requirements: the repository's Mojo **1.1.0**, Python **3.14.7** for the recorded
run, CMake, a C/C++ compiler, and a local **GMP 6.3.0** development installation.
The measured host used Apple clang **21.0.0**, CMake **4.4.3**, macOS **27.0.1**,
and arm64. Other versions/platforms are unverified. Python package metadata
permits 3.11+, but only 3.14.7 was exercised.

```sh
python3 -m venv /tmp/moxi-d01/venv
/tmp/moxi-d01/venv/bin/pip install 'sympy==1.14.0' 'mpmath==1.3.0' 'pytest==9.0.2'
export MOJO_PYTHON_LIBRARY="$(python3 -c 'import sysconfig; print(sysconfig.get_config_var("LIBDIR") + "/" + sysconfig.get_config_var("LDLIBRARY"))')"
bash experiments/math-backends/build-native.sh > /tmp/moxi-d01/build-driver.log 2>&1
bash experiments/math-backends/check.sh > /tmp/moxi-d01/check.log 2>&1
bash experiments/math-backends/package-check.sh > /tmp/moxi-d01/package-check.log 2>&1
bash experiments/math-backends/run-demo.sh
```

`MOXI_MOJO_MANIFEST` can point to an existing compatible Pixi manifest to reuse
its toolchain without installing into this checkout. The recorded run used the
main Moxi checkout's locked environment. `MOXI_GMP_PREFIX` defaults to
`/opt/homebrew`; `MOXI_MATH_BUILD_DIR` defaults to `/tmp/moxi-d01`. Build scripts
never install system packages, publish, or modify the planning checkout. The
source tarball is checksum-pinned; compiler, GMP and Python must be provisioned
at the versions above for reproduction. Native artifacts retain development
rpaths and are **not a relocatable application bundle**.

## Implemented boundary

`model.py` owns immutable typed nodes, symbol identity/label/domain, operation
options, source-node diagnostics, selected-subtree replacement, and exact
base-ten decimal conversion. Integers and rationals cross the wire as decimal
strings, including values beyond machine range. Floats, exponent notation,
zero/negative rational denominators, unresolved operators and incomplete input
are refused. Decimal text `0.1` means exactly `1/10`.

The versioned notation text is explicit JSON containing the **whole tree**,
including IDs, holes, malformed text and unresolved rows. It round-trips without
backend normalization. This is a bounded probe notation, not the proposed D02
human math syntax. Structural edits and corresponding JSON edits produce the
same semantic request; all imported results can be re-submitted. Display strings
are previews only and are never parsed as expressions.

SymPy constructs objects from a closed constructor vocabulary in one persistent
Python subprocess. There is no `eval`, `sympify`, arbitrary import, or expression
string parser on the wire. Construction can canonicalize; the source document
stays unchanged until explicit application. The launcher removes embedded
CPython's `PYTHONHOME`, `PYTHONEXECUTABLE`, and `__PYVENV_LAUNCHER__` overrides so
an explicitly selected worker virtualenv remains effective.

SymEngine uses the **0.14.0 C wrapper**, built with GMP, shared linking,
`WITH_SYMENGINE_RCP=ON`, and `WITH_SYMENGINE_THREAD_SAFE=ON`. `native/worker.mojo`
owns each opaque `basic_new_heap` allocation in a move-only `Expression` with a
matching destructor. `bridge.c` only scopes C-API vectors and owned strings;
no C++ layouts, borrowed expression pointers, or backend strings enter the
notation. Result traversal inspects class IDs/arguments and extracts arbitrary
precision integer strings. Expression and string counters must be zero after
each successful operation **and** failed import. The native worker embeds
CPython for framing/tree objects; this real deployment/conversion cost is
included in the comparison. It does not use a Python SymEngine binding or SymPy.

`controller.py` owns one active request and one pending slot, replacing the
pending slot rather than growing a queue. A daemon IO thread handles framed
messages; the UI only submits, polls, edits and explicitly applies. Each frame
has a protocol version and a four-byte network-order size capped at 1 MiB.
Trees are capped at 4096 nodes/64 levels; integer payloads at 1024 digits.
Nonblocking writes and bounded reads have deadlines. No general routing system
or thread pool is introduced.

Cancellation can discard logically while work continues, or kill the process.
Replacement normally kills the active process; deadlines kill and reap it too.
The next operation starts a fresh worker. Document closure joins the IO thread
and reaps the child. These are process-termination semantics, not a claim that
SymEngine algorithms are cooperatively interruptible. Completed results must
match **both** request generation and document revision; `Document` also retains
the submitted selection. Applying a result advances the revision. Cancelling
through `Document.cancel` invalidates a previously cached completion as well.

## Corpus and verification

Both workers pass hand-checked structural expectations for exact half,
90-digit rational payloads, exact decimals, expansion, a selected numerator,
polynomial/sine-product differentiation, compound substitution, and
`sqrt(x²)` with an unconstrained complex symbol. The last result stays a radical,
never an unconditional `x`. Tests normalize only associative ordering and node
IDs; agreement between engines is not the correctness oracle.

SymPy additionally imports a small matrix, explicit matrix multiplication,
unknown named functions, and the positive-symbol square-root case. SymEngine's
**probe adapter** refuses those constructs/assumptions; this is not a statement
that the underlying C API lacks matrices/functions. Both refuse a derivative of
an unknown function, infinity, and a real-symbol root requiring an unsupported
`Abs` result. Refusal preserves the source and exposes a usable message. No
unknown result is relabeled as a symbol. Bound-variable operations are rejected
locally with the affected source ID, preventing silent variable capture.

The focused suite includes malformed/oversized/truncated frames after handshake,
wrong versions/generations, invented symbols/assumptions, missing workers,
local input rejection, queue bounds, live edits, cancellation, timeout/restart,
closure, and 100 alternating successful/failed imports per engine. The clean
wheel consumer runs outside the checkout and exercises both real workers, with
only the installed package on `PYTHONPATH`. A base wheel import needs no engine;
SymPy is an optional pinned dependency.

See [the measurement and packaging report](REPORT.md),
[raw measurements](evidence/measurements.json), and
[environment/dependency inventory](evidence/environment.json).

## Actual demo screenshots

```sh
# Uses the actual Moxi AppKit window; requires a GUI session on macOS.
bash experiments/math-backends/run-demo.sh --capture /tmp/moxi-d01/captures \
  > /tmp/moxi-d01/demo.log 2>&1
PYTHONPATH=experiments/math-backends /tmp/moxi-d01/venv/bin/python \
  -m moxi_math_probe.gallery /tmp/moxi-d01/captures
open /tmp/moxi-d01/captures/index.html
```

The scripted actions use the same public state/controller methods as the
buttons: exact arithmetic, apply/text-edit, expand, differentiate, substitute,
assumptions, unsupported result, real slow `(x+y+z)^1200` expansion, edit while
pending, supersede, kill/restart, and measured decision. There are no injected
results or sleeps masquerading as engine work. The default decision screen uses
`evidence/measurements.json`; set `MOXI_MATH_MEASUREMENTS` to a fresh report.

The delivered [slideshow](../../artifacts/demo-slideshows/d01-math-backends/index.html)
has previous/next buttons, arrow-key navigation, a contact sheet, and embedded
PNG data so it can be moved alone. Original PNGs and a manifest accompany it.
Each capture records fixture, actual status/tree, document revision, generation,
base Git revision plus local-change marker, source SHA-256, host, dimensions,
scale and reproduction command. **OS `screencapture` failed** with `could not
create image from window`. The images instead snapshot the running window's
live AppKit content view via `cacheDisplayInRect`; they are not offscreen Moxi
scene renders, and do not establish OS compositor/physical-display behavior.
The native helper is experiment-only and does not modify a renderer.

## Remaining integration gates

- D02 must map its actual 2D notation and text syntax to this semantic vocabulary,
  preserving node/selection identity and conditions. Actual 2D caret/edit
  round-trips are unverified here; the tested structural/JSON bridge is not a
  substitute for that gate. Holes/malformed rows are model-tested, not a shipped
  math editor UI.
- The parent should link the decision/evidence from the planning D01 row and add
  this gallery to the integration branch's master gallery. This worker is not
  authorized to change that checkout, commit, or create PRs.
- Signed/relocatable macOS application packaging, clean-machine runtime discovery,
  dependency replacement, runtime redistribution notices and source delivery are
  still open. The clean Python-wheel consumer is narrower evidence.
- Linux, Windows, other architectures, physical keyboard/IME/accessibility,
  human usability, GPU presentation timing, full Moxi regression suite and
  remote CI were not tested. No renderer/core change warrants claiming them.
- No entirely-permissive dependency policy was approved, so a Boost multiprecision
  build was not added. It remains a conditional follow-up, not a failed GMP gate.
