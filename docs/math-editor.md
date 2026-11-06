# Native math editor

`moxi_math` is an optional Mojo component with a macOS native font/input adapter.
The primary canvas edits notation directly. Its Text / 2D switch exposes a
lossless, human-editable notation language using the same document and history.
The standalone consumer has no Python or CAS dependency. The workbench adds an
optional persistent SymPy process through the existing D01 boundary.

This implementation is a local D02 candidate. See [measured evidence and remaining
acceptance gates](math-editor-evidence.md); physical keyboard, IME, VoiceOver,
and event-to-display acceptance are not established by automated replays.

## Build and run

The tested host is macOS arm64. Install the repository's locked Pixi environment,
Xcode command line tools, and HarfBuzz with OpenType MATH support. The scripts use
`/opt/homebrew/opt/harfbuzz`; override `MOXI_HARFBUZZ_PREFIX` for another installation.
The bundled, pinned STIX Two Math font and its OFL notice are in `assets/math`.

```sh
bash scripts/math/build.sh
/tmp/moxi-d02/consumer
```

The consumer opens an actual Moxi `App`, `MacOSWindow`, and `MacOSRenderer` with
an editable nested expression. Run it from the checkout so its example font path
resolves. Build outputs/logs default to `/tmp/moxi-d02`; override
`MOXI_D02_BUILD_DIR` when needed.

For computation, use Python 3.11+ and the D01 pinned dependencies:

```sh
python3 -m venv /tmp/moxi-math-python
/tmp/moxi-math-python/bin/pip install 'sympy==1.14.0' 'mpmath==1.3.0'
export MOXI_SYMPY_PYTHON=/tmp/moxi-math-python/bin/python
# Mojo embeds CPython for the optional bridge; select an installed shared library.
export MOJO_PYTHON_LIBRARY="$(python3 -c 'import sysconfig; print((sysconfig.get_config_var("PYTHONFRAMEWORKPREFIX") or sysconfig.get_config_var("LIBDIR")) + "/" + sysconfig.get_config_var("LDLIBRARY"))')"
bash scripts/math/run.sh
```

`run.sh` sets the two local Python import paths and launches the real workbench.
It defaults the worker executable to `python3`, not a developer-specific virtual
environment. The worker reports unavailable SymPy, protocol errors and deadlines
in the workbench status. A missing CPython shared library prevents this optional
workbench from starting; the backend-free consumer remains available. A missing
or non-MATH font raises an explicit startup diagnostic rather than substituting
metrics from another font.

## Notation v1

The following are all document constructs. They describe layout and preserve
spelling; parsing does not simplify or normalize mathematics.

| Text | Visual slots, in order |
| --- | --- |
| `x`, `12`, `α`, `"a b"` | Literal token; quote whitespace or punctuation |
| `?` | Editable empty slot |
| `row(x, +, y)` | Ordered adjacent items; explicit operator tokens |
| `frac(a, b)` | Numerator, denominator |
| `root(?, x)` or `root(3, x)` | Index, radicand; empty index is a square root |
| `scripts(x, i, 2, n, k)` | Base, subscript, superscript, underscript, overscript |
| `group("(", ")", x)` | Explicit left/right delimiters and body |
| `fn("sin", x)` | Named unary function and argument |
| `matrix(row(a, b), row(c, d))` | Rectangular rows/cells |
| `sum(i, 0, n, x)` | Variable, lower limit, upper limit, body |
| `integral(x, 0, 1, y)` | Variable, lower limit, upper limit, body; displays differential |
| `error("frac(x,")` | Literal malformed text, displayed with a diagnostic |

Quoted strings escape quotes, backslashes, newline, carriage return and tab.
Literal-error layout abbreviates previews longer than 160 codepoints; Text mode
retains the complete spelling. Malformed source is retained exactly in an error node; it is never silently
replaced by the last valid expression. Syntax repair occurs in Text mode.
External clipboard text is parsed conservatively as this grammar. Unknown syntax
is preserved as a literal error, not executed or guessed as another algebra
language. Explicit `error(...)` fragments round-trip just like every other node.

Documents are bounded to 20,000 nodes, depth 64, canonical text of 1 MiB,
individual tokens of 4,096 bytes, and matrices of at most 100 × 100 cells.
Over-budget inputs fail explicitly or become a literal-error preview; layout
never recursively expands an over-depth tree. The measured interactive target
is 1,000 nodes; 10,000-node documents are stress cases, not a frame-rate promise.

Save/Reopen uses `moxi-math/1` followed by a newline and canonical notation. The
workbench saves the active block to `/tmp/moxi-d02-document.moxi`; the minimal
consumer uses `/tmp/moxi-math-consumer.moxi`. These are example host destinations,
not an editor-imposed storage service. Tabs, cursor, history and viewport are not
persisted. Unknown envelope versions are rejected.

Runtime IDs are not serialized. Text edits reconcile unchanged prefixes/suffixes
and corresponding changed slots; unchanged siblings retain identity across a
local insertion/deletion. Source spans map a selected visual node to its spelling
and a source selection to its smallest enclosing node. Copy emits canonical text
and `org.moxi.math.fragment.v1`; paste prefers the supported structured envelope
and assigns fresh IDs. Every content mutation, text-view toggle, paste, move,
reopen and result application participates in shared undo/redo. Revision numbers
remain monotonic across undo/reopen, preventing old worker results from matching
restored content accidentally.

## Editing and navigation

Click the nearest published caret stop; arrows traverse grapheme boundaries and
slots. Up/down use published geometry and preserve horizontal intent. Home/End
go to the document's first/last leaf. Tab/Shift+Tab visit holes, wrapping inside
the expression. Leave exits one structural level and eventually releases math
focus. Click the canvas to re-enter. Palette buttons use the same command IDs
as keyboard bindings. Their hints come from the same remappable `MathKeymap`.

| macOS default | Action |
| --- | --- |
| Cmd+/ | Wrap current token/subtree in fraction; enter denominator |
| Cmd+6 or Cmd+^ | Enter superscript |
| Cmd+- or Cmd+_ | Enter subscript |
| Cmd+2 or Cmd+@ | Wrap in square root; enter radicand |
| Cmd+5 or Cmd+% | Switch paired script, root or limit slots |
| Cmd+7 or Cmd+& | Enter overscript / upper limit |
| Cmd+Shift+, | Enter underscript / lower limit |
| Cmd+Space | Leave one expression level |
| Cmd+. | Select current node, then enclosing nodes |
| Cmd+Enter / Cmd+, | Add matrix row / column |
| Cmd+A/C/X/V | Select all / copy / cut / paste |
| Cmd+Z / Cmd+Shift+Z | Undo / redo |
| Escape, abbreviation, Escape | Insert a symbol |

Cmd+Space is commonly reserved by macOS input-source settings; Cmd+, may be
claimed by a host menu. The visible Leave and + Col controls remain available.
A host can bind an alternate key using
`editor.keymap.bind(MathCommand.EXIT, key, modifiers, "display hint")`.
Physical layout-specific conflict resolution remains an acceptance gate; the
synthetic native replay does not prove OS hotkey delivery.

Selection is structural: Cmd+. grows from a token to its parent; keyboard
extension and pointer drag across leaves select enclosing subtrees. Arbitrary
partial-token 2D ranges are not supported; Text mode provides ordinary character
selection. Template insertion wraps the current token or selected subtree.
Backspace/Delete remove a grapheme within a token; structural-boundary deletion
unwraps its container, while deleting a selected node leaves a hole. Unwrap is
also a named palette operation. All these operations are reversible.

Matrix creation wraps the selected row (or a single item). Growth inserts after
the active row/column and focuses the new slot; removal preserves at least one
row/column. Option-drag a selected non-root subtree into a hole to move it as one
transaction. The preview outlines the target. Escape cancels; self/descendant,
root and occupied-target moves cannot commit. This is a notation move, with no
claim of algebraic equivalence.

Escape starts symbol entry. Type an abbreviation and Escape to commit; Backspace
edits it, and Escape on an empty abbreviation cancels. Unknown abbreviations
stay visible for repair. Aliases include `a`/`alpha`, `b`/`beta`, `g`/`gamma`,
`d`/`delta`, `th`/`theta`, `pi`, `inf`/`infinity`, `times`, `le`, `ge`. Search and
click the same symbols in the palette.

The math-local `NSTextInputClient` retains marked text outside the document until
commit, converts UTF-16 ranges at the native boundary, and reports a candidate
rectangle from the published caret geometry. Structural commands are blocked
during preedit. CJK text survives commit but the initial STIX repertoire does not
supply CJK glyphs; a red missing-glyph diagnostic is intentional. Native semantic
children expose structural roles, text values, focus/selection labels and bounds.
They are not a claim of complete VoiceOver interaction.

## Computation

Expression, Scratch and Result are editable blocks. Select a supported subtree
and press Expand or Differentiate (with respect to `x`). Computation runs on the
D01 controller's worker thread/process. The editor stays mutable while it runs.
Result opens editable imported notation. Return to the source block and Apply
explicitly; source revision and node identity must still match. Undo restores
exact source notation. Editing another block does not mutate the source block.
Copy a result to Scratch before submitting another operation from it.

Projection accepts scalar numbers/symbols, explicit arithmetic rows,
fractions, positive integer roots, superscripts, parentheses, supported unary
functions and matrices. Subscripts/under/over annotations, incomplete/malformed
nodes, ambiguous adjacent operands and binders are rejected. A selected subtree
beneath **any sum/integral ancestor** is also rejected. Backend canonicalization
changes only Result until explicit Apply. Imported sums used as multiplication
operands and composite power bases retain explicit grouping.

Evaluate performs exact arithmetic (for example, `frac(2, 4)` returns
`frac(1, 2)`). Differentiate uses `x`. For substitution, enter the replacement
expression in Scratch, return to Expression, select a subtree, and use
`x → Scratch`. The replacement is captured by value at submission and uses the
same conservative projection rules; later Scratch edits do not alter the request.

D01's SymPy choice remains provisional with moderate confidence. D02 does not
broaden its mathematical equivalence or assumption guarantees. Cancellation
invalidates the result and restarts the process on later work; closing the host
closes the owned session. Apply is rejected after stale, cancelled, failed or
closed requests. Editing after a ready result marks it stale without overwriting
edits in the Result block. No computation is performed during layout or ordinary editing.

## Public component and local package

`examples/math/consumer.mojo` uses the convenience host:

```mojo
from moxi_math import run_math_editor

def main() raises:
    run_math_editor("Moxi Math", "frac(x, y)", "path/to/STIXTwoMath-Regular.otf")
```

For an existing Moxi host, own a `MathEditor` inside `App`; call `route(event)`
before outer dispatch, `prepare(app.view)` after rebuild, and `present()` after
host rendering. Drain `poll_math_event()` as well as native window events.
Bracket the host with `open_math_font(path)` / `close_math_font()` and close
optional `MathComputation` on exit. One UI-thread math font/view session is
supported at a time. Do not call `present()` from two simultaneous math hosts.

The public API exports `MathEditor`, `MathEditorState`, `MathDocument`,
`MathNode`, `MathKind`, `MathPosition`, `MathCommand`, `MathKeymap`, `MathBinding`,
`MathLayout`, `MathSnapshot`, `MathRegion`, `MathCaret`, `MathFont`, `parse_math`,
`draw_math`, font lifetime functions, native event polling, and the convenience
host. Optional `MathComputation`/`MathOperation` live in `moxi_math.computation`.
The consumer does not duplicate coordinates, hit-testing or font geometry.

```sh
bash scripts/math/consumer-check.sh
```

This builds a local archive with precompiled `moxi`/`moxi_math` modules, a static
native adapter, font and notices; extracts it to a new `/tmp` directory; and
compiles/runs a consumer there using installed modules only. The existing Mojo
compiler/standard-library environment and separately installed HarfBuzz are
explicit prerequisites. This is not a fresh-machine installer, registry release,
signed application or conda package. The optional Python computation package is
not bundled in the editor-only archive.

## Validation and captures

```sh
MOXI_SYMPY_PYTHON=/tmp/moxi-math-python/bin/python bash scripts/math/check.sh
bash scripts/math/consumer-check.sh
MOXI_SYMPY_PYTHON=/tmp/moxi-math-python/bin/python \
  bash scripts/math/run.sh --capture /tmp/moxi-d02/gallery/d02-native-math-editor
python3 scripts/demo_slideshows.py /tmp/moxi-d02/gallery --check
python3 scripts/demo_slideshows.py /tmp/moxi-d02/gallery
```

The executable replay builds/edits a fraction and radical/scripts, grows a
matrix, preserves malformed text, undoes it, submits a real selected subtree,
rejects a stale result after an edit, resubmits/applies/undoes, and saves/reopens.
It writes twelve PNGs, the shared version-1 manifest, and separate `frames.json`
with notation, IDs, revisions, geometry generation, status and source fingerprint.

These images are **live AppKit content-view cache captures**, classified as
`offscreen-render` by the shared screenshot policy. They show the actual native
view drawing but do not capture the window compositor or establish physical
interaction. For release native-window evidence, package the executable in an
`.app`, capture that application's window with the native UI tool or authorized
`screencapture` workflow in [demo-slideshows.md](demo-slideshows.md), and preserve
that capture method in the metadata. Parent integration owns the final gallery
and committed revision reference.
