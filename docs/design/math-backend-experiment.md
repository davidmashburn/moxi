# Symbolic backend integration experiment

Status: planned experiment for [native math editing](math-editing.md).
SymEngine and SymPy remain candidates; neither is selected by this document.
The outcome is one initial adapter choice and a record of supported operations,
integration costs, and limitations. Shipping both adapters is optional.

The editor independently requires a one-to-one, human-readable/editable text
representation of every 2D document state. Neither backend defines this syntax.
Successful results must import into notation that round-trips through that text
form; backend strings alone do not satisfy the editor contract.

## Questions to answer

Can a Mojo application submit a structured expression, keep editing while it
computes, and import the result as editable math? What does the smallest reliable
integration cost in deployment, ownership complexity, and application code?
Does the chosen license/dependency configuration fit how we intend to distribute
the package? These questions take precedence over an isolated arithmetic speed
comparison.

## Candidate implementations

For SymEngine, prototype its C wrapper behind a narrow Mojo ownership layer.
Use opaque handles internally, translate errors, and pair every allocation with
release. No C++ object layouts or borrowed native pointers become document data.
The [C API](https://github.com/symengine/symengine/blob/master/symengine/cwrapper.h)
exposes expression arguments, arithmetic, substitution, expansion, and
differentiation. Verify the actual selected release and coverage during the probe.

Start the native probe with the default GMP integer backend. Run computation on
a worker, with explicit ownership and the appropriate thread-safe configuration;
do not assume a thread-safe build makes every operation interruptible. If safe
termination or bounded queue handling requires a process boundary, record and
test that additional cost. Suppressing a completion alone does not stop native
work.

For SymPy, prototype one persistent Python worker process with framed,
versioned structured messages. Keep startup out of repeated-operation timings
and report it separately. Construct expressions through an explicit vocabulary
of supported constructors. Do not use `eval`, arbitrary source execution, or
an unrestricted expression-string parser as the wire protocol. Importing user
code or providing a Python console is outside this experiment.

SymPy objects may canonicalize expressions during construction. Its
[guidance on automatic evaluation](https://docs.sympy.org/latest/explanation/best-practices.html#avoid-too-much-automatic-evaluation)
also cautions that suppressing evaluation is fragile. Test semantic conversion
independently of preserving editor notation: the original notation stays in
the document regardless of backend behavior.

Use a bounded queue and one active computation initially. Exercise replacement,
logical cancellation, worker termination/restart where supported, and cleanup
after document closure. Avoid adding a general multi-engine routing framework.

## Shared expression and operation corpus

The fixtures are typed trees with exact integer/rational payloads, explicit
function arguments, symbol identities, and operation-specific options. Human
readable expressions below describe fixtures; they are not a proposed user
input syntax or transport format.

- Exact arithmetic: one third plus one sixth returns one half without a float
  conversion. A numerator or denominator beyond machine-integer range survives
  both directions. Define exact-decimal conversion explicitly.
- Expansion: the square of a sum of two scalar symbols returns an editable
  polynomial. Test a selected numerator inside a larger fraction as well.
- Differentiation: a polynomial and a product containing sine return supported
  expressions. Differentiation with respect to a selected symbol is explicit.
- Substitution: replace a free scalar symbol with a compound expression.
  A substitution involving a bound variable either respects scope or returns
  a documented unsupported status; silent capture fails the experiment.
- Assumptions: the square root of a squared symbol must not be presented as
  the symbol unconditionally. Record domains and assumptions required by each
  supported operation, and preserve returned conditions or refuse the import.
- Matrix and function structure: convert a small matrix and an unknown named
  function if supported; otherwise report unsupported without flattening them
  into ambiguous strings. Distinguish matrix and scalar multiplication.
- Incomplete or ambiguous input: reject a hole or unresolved operator row
  locally, before a backend call. Identify the affected source node.
- Unsupported output: an unhandled function/result type leaves the source
  unchanged and produces a usable message. It must not become a fake symbol
  that appears fully editable and computable.
- Dual-representation fidelity: every supported imported result survives
  notation-to-text-to-notation conversion without loss. Equivalent edits made
  through the text and 2D views produce the same semantic request. Holes,
  malformed-text nodes, and unresolved notation remain editable in both views
  but are rejected locally for computation.

Test cancellation, backend errors, missing dependencies, malformed/oversized
responses, document closure, superseded requests, and edits made while a request
runs. Request generations and document revisions are separate checks. A response
must pass both before becoming eligible for in-place application.

## Measurements and evidence

Pin engine, compiler, Python, and dependency versions. Record host, build flags,
selected arithmetic backend, thread configuration, and whether binaries were
built locally or supplied by a package manager. Capture:

- Clean build/install steps and resulting distributable dependencies and size.
- Cold startup and first operation, then repeated warm operations at several
  expression sizes. Include sample count, median, p95, p99, and maximum.
- End-to-end request time split into export, transport, compute, and import.
  Record UI frame behavior during a deliberately slow request separately.
- Allocation/handle lifecycle checks, retained memory after repeated requests,
  queue limits, and restart behavior. Report unavailable memory tooling plainly.
- Round-trip fidelity for supported semantic constructs and the actual set of
  result nodes needed. Cosmetic ordering differences are not algebra errors;
  lost assumptions, changed domains, or invented semantics are failures.
- Amount of application glue and the complexity of the Mojo binding or worker
  protocol. Keep source fixtures with the results so the comparison is reviewable.

Use hand-checked expected results for the small corpus and structural/domain
checks appropriate to each operation. Agreement between engines is useful
evidence but is not a proof of correctness. Report unsupported cases separately
from incorrect results and from transport failures.

## Licensing and packaging decision

Our original code should use a permissive license. SymEngine is MIT licensed
with third-party notices; SymPy is BSD licensed. Verify the pinned distribution's
complete notices rather than treating the top-level license as a dependency
inventory. [SymEngine license](https://github.com/symengine/symengine/blob/master/LICENSE),
[SymPy overview](https://www.sympy.org/en/index.html).

GMP can be used under LGPLv3-or-later, allowing our own code to remain permissive
while carrying redistribution obligations. A bundled dynamic library must
remain replaceable as required by the license, with notices and compliant source
availability. Static distribution needs suitable relinking/rebuilding materials.
Check the actual packaged/signed application, not just an unbundled development
binary. [GMP terms](https://gmplib.org/manual/Copying),
[LGPL section 4](https://www.gnu.org/licenses/lgpl-3.0.html#section4).

If entirely permissive dependencies are a requirement, add a SymEngine build
with `INTEGER_CLASS=boostmp` to the comparison. Its documentation describes a
permissive dependency configuration, but this configuration excludes FLINT,
ARB, and MPFR integrations. The Boost types stay inside the C++ implementation.
Measure build/deployment cost and required-operation coverage before preferring
or rejecting it. [Build options](https://github.com/symengine/symengine#cmake-options),
[configuration constraints](https://github.com/symengine/symengine/blob/master/CMakeLists.txt).

The decision record must distinguish a permissive license for our code from an
entirely permissive dependency stack. Neither policy has been established as a
hard prohibition on GMP. Do not choose a slower or less capable configuration
solely on an inferred policy.

## Exit decision

Choose the candidate that passes the shared editing/computation contract with
the least integration and distribution burden for the initial supported cases.
Native performance is a reason to choose SymEngine only when measured at the
application boundary. Wider algorithm coverage is a reason to choose SymPy
when it serves an actual required operation.

If both pass, pick one for the first workbench and retain the other probe as
evidence. Implement a second supported adapter when it supplies a concrete
capability or deployment advantage. If neither passes, record the exact blocker
and the smallest corrective experiment; the typesetting/editor milestones
continue independently.

Deliver the runnable probes, fixture corpus, measurement report, packaging
notes, and a short decision record linked from the main plan. The report must
identify untested platforms, skipped cases, and capability gaps. No benchmark
or binding success is assumed by the current plan.
