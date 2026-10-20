# Native mathematical typesetting and editing

Status: proposed scope and implementation sequence. The editor, math layout
engine, and computation adapters described here are new work. This proposal
does not change the release priorities in [project planning](../../PROJECT-PLANNING.md).

Build a reusable native WYSIWYG math editor and display component in Mojo.
Display-quality equations and structured editing ship together: users work
directly inside fractions, radicals, scripts, and matrices. Alongside the 2D
view, every document state has a one-to-one corresponding human-readable,
human-editable text representation. WYSIWYG is the primary authoring experience;
the secondary text form can inspect and edit the same content without loss.
Computed results return as editable expressions in both representations.

This is also a test of moxi's purpose: make highly reactive, interactive UIs
clean to author, smooth to use, and tactile in their response. Success requires
both a convincing editing experience and a small, understandable application
API. A separate symbolic computation project remains possible, but is not a
prerequisite for the editor.

## Product contract

The first supported experience is a macOS math workbench containing a few
editable expression blocks, a template palette, operation controls, and a
result area. The portable model and geometry tests run headlessly. Other
native hosts follow their actual font, input, and rendering capabilities.

The primary acceptance journey is:

1. Insert a fraction using a visible template action. Fill its numerator and
   denominator by typing ordinary symbols and numbers.
2. Wrap a selected range in a radical, add a superscript, and navigate into
   and out of the nested slots using the keyboard and pointer.
3. Insert a matrix, edit individual cells, and add or remove a row. Selection
   remains visible and predictable through layout changes.
4. Select a complete subexpression and request expansion or differentiation.
   Continue editing while the request runs.
5. Inspect the editable result and apply it to the original selection if the
   source revision is still current. Undo restores both content and selection.
6. Switch to the corresponding text, edit a nested construct, and return to
   the 2D view without losing notation or incomplete slots. Repeat in the
   opposite direction, including a temporarily malformed text edit.
7. Save, reopen, and continue editing the same notation without normalization.

All ordinary editing works with no computation backend installed. Templates,
keyboard shortcuts, and a searchable symbol palette expose the same commands.
No task in this journey requires learning a markup language. Ship the structured
math keyboard profile below as the default for the 2D editor;
familiar entry sequences must produce the expected structure and caret state.

## Initial scope and limits

Support number and identifier tokens, Greek symbols, named functions,
operators and relations, explicit grouping, fractions, square and indexed
radicals, superscripts and subscripts, and rectangular matrices. Add sums and
integrals with editable limits and bodies before the initial scope is complete.
The ability to display and edit a construct does not imply that a backend can
evaluate it. Incomplete expressions and empty slots are valid document states.

Provide inline and display sizing styles, baseline alignment, scalable
delimiters, selection, clipboard operations, undo/redo, and a versioned local
document format. The initial surface contains math blocks; a full mixed prose
document editor is deferred. Long equations scroll horizontally in their
viewport; automatic mathematical line breaking is deferred.

Also deferred: notebook execution dependencies, a programming language,
collaboration, pagination, general document import, handwriting recognition,
touch-first editing, automatic algebra during typing, and a general-purpose
CAS. Plotting can consume results later without becoming an editor dependency.
Image/vector export and interchange with external markup formats are follow-ups.
The editor's own lossless, editable text representation is required from the
first editing slice, including for constructs that have no external equivalent.

## Existing foundations and required work

The implementation inspected at `feat/data-workbench` commit `c8c7cbb`
provides useful seams, with different maturity levels. Implementation links below
are pinned to that commit; this planning branch contains no product code:

- [Text input state](https://github.com/davidmashburn/moxi/blob/c8c7cbb7741519c9796a02ffa25c02e701b2f58a/src/moxi/controls_text.mojo) provides linear text,
  selection, clipboard state, and marked-text composition. Reuse applicable
  host events and text-leaf behavior; introduce structural positions and
  transactions for math editing.
- [Shaped glyphs](https://github.com/davidmashburn/moxi/blob/c8c7cbb7741519c9796a02ffa25c02e701b2f58a/src/moxi/text_shaping.mojo) carry glyph IDs, clusters,
  font IDs, and positions. [Scene text](https://github.com/davidmashburn/moxi/blob/c8c7cbb7741519c9796a02ffa25c02e701b2f58a/src/moxi/scene.mojo) currently
  carries strings and styles. Math needs a verified path from chosen glyphs
  and positions to pixels, including font resource lifetime.
- The [native paragraph slice](https://github.com/davidmashburn/moxi/blob/c8c7cbb7741519c9796a02ffa25c02e701b2f58a/docs/native-paragraph-layout.md) demonstrates
  committed geometry shared by drawing, hit testing, and accessibility.
  Its current paragraph/fixed-box protocol is provisional. Adapt its ownership
  and publication model through a bounded math-content seam; do not require
  the complete proposed layout system before shipping a math block.
- [HarfBuzz's current bridge](https://github.com/davidmashburn/moxi/blob/c8c7cbb7741519c9796a02ffa25c02e701b2f58a/native/harfbuzz_text.h) exposes shaping,
  but does not expose math constants, variants, or assemblies. These need a
  font-service extension or a separate narrow math-font adapter.
- [Runtime requests](https://github.com/davidmashburn/moxi/blob/c8c7cbb7741519c9796a02ffa25c02e701b2f58a/src/moxi/app_runtime.mojo) already have scoped
  generations, cancellation, and completion injection, exercised by
  [request tests](https://github.com/davidmashburn/moxi/blob/c8c7cbb7741519c9796a02ffa25c02e701b2f58a/tests/request_adapter.mojo). A real worker or process
  transport remains adapter work. Document revision checks are additional.
- [Python's accepted boundary](https://github.com/davidmashburn/moxi/blob/c8c7cbb7741519c9796a02ffa25c02e701b2f58a/docs/architecture/adr-002-python-value-boundary.md)
  concerns plotting values. It is not an existing symbolic session transport.

Keep generic improvements in moxi: font resources, positioned-glyph drawing,
committed geometry, input/focus integration, scoped updates, and request
lifetime support. Keep notation, math layout rules, structural editing policy,
and symbolic translation in a proposed `moxi_math` package. Prototype that
package in this repository; extraction is a later packaging decision.

## Document and editing model

Use a lossless notation tree as the authoritative document. A compact tagged
node model has stable IDs, explicit child roles, and document-owned storage.
Concrete Mojo storage and copy strategy are settled by a small compiled probe,
not by a speculative generic hierarchy.

Node families cover rows, tokens, holes, fractions, radicals, scripts,
delimiters, function applications, matrices, and operators with limits/bodies.
Preserve token spelling, explicit grouping, and displayed order. A fraction
containing 2 and 4 remains that fraction until the user requests a change.
Rows can contain unfinished operator sequences without becoming corrupt trees.

Structural invariants are independent of mathematical validity: no cycles or
shared mutable children, unique IDs, valid child roles, rectangular matrix
shape, and bounded document depth/size. Missing required content uses a hole.
Imported/pasted content is validated before an atomic change is committed.

### One document, two editable representations

Define a versioned text grammar and canonical printer alongside the notation
tree. Every supported 2D construct must have an unambiguous, human-readable and
human-editable text form before it ships. This includes holes, incomplete rows,
explicit grouping, token spelling, simultaneous scripts, matrix shape, binding
roles, and any persisted display distinctions. Text is a first-class document
representation, not a backend expression string or a best-effort export.

Keep the correspondence simple and structural: each layout construct maps
directly to one readable text construct, and its visual slots map to explicit
arguments or groups in the same order. Illustrative spellings are `frac(a, b)`
for a fraction, `sqrt(x)` for a radical, `sup(x, 2)` for a superscript, and
`matrix([a, b], [c, d])` for matrix rows. These illustrate the relationship,
not a settled grammar. Ordinary tokens and rows should stay concise; use only
the grouping and escaping needed to make the structure unambiguous. Avoid
verbose object dumps, exposed node IDs, hidden precedence rules that change
the layout tree, and a separate text-only algebra language. A person should
be able to identify a visual slot in the text and predict the layout change
from a local edit without understanding the renderer or computation backend.

The correspondence is between document content and canonical text: parsing
printed content reconstructs exactly the same notation, and printing parsed
text returns its canonical spelling. Alternative accepted whitespace or syntax
may canonicalize, but notation must not simplify, reorder, or disappear. Runtime
node IDs, focus, caches, and transient layout coordinates are editor state, not
part of this textual correspondence. Zoom and viewport changes do not alter it.

Provide a secondary text view or mode alongside the primary 2D editor, with
edits from either using the same transaction and undo history. The complete
text representation is mandatory; equal investment in text-editor features is
not. A source-code IDE, advanced completion, and simultaneous split-pane UI are
outside the initial requirement. Maintain source spans to relate text selections
and diagnostics to structural nodes. Reconcile unchanged
nodes when applying text edits so a local change does not reset unrelated focus
or identity. Do not maintain independently drifting text and visual documents.

Temporary syntax errors must also remain representable. Preserve malformed
text losslessly in explicit literal/error nodes with a visible diagnostic
layout in the 2D view; provide an escaped canonical spelling for those nodes.
No partially typed text is silently dropped or replaced with the last valid
expression. Holes and incomplete mathematical expressions remain ordinary
editable notation, distinct from text syntax errors. Unsupported or malformed
content cannot be sent to a computation backend.

Use the versioned text representation as the document-content format for
save/load and as the lossless plain-text clipboard form. A file envelope may
carry version and document metadata. The exact grammar is an M0 design/probe
decision; it must be practical to read and edit by hand and requires no CAS.

### Semantic projection and transactions

Project a complete selection into a small semantic value representation only
when computation is requested. Associate projected nodes with source IDs for
diagnostics. Preserve explicit distinctions such as function application,
scalar multiplication, matrix multiplication, and identifier subscripts.
Ambiguous notation, including a row whose multiplication/application intent
is unresolved, must be disambiguated or reported before evaluation. Bound
variables and assumptions travel explicitly with supported operations.

The semantic representation is a bounded adapter contract. It need not encode
every object from every CAS. Unsupported results produce an explicit status
and optional read-only diagnostic; they never masquerade as editable math or
replace the source. Extend the supported vocabulary when a real operation
needs it. Backend canonicalization must not rewrite the source document.

Represent caret positions as a node/slot plus a logical text or child boundary
and affinity. Selection supports text ranges, sibling ranges, and whole
subtrees. Matrix cell rectangles are an explicit selection mode. Cross-slot
dragging expands to a valid structural range using a documented policy rather
than flattening the expression into a character string.

Every edit is a transaction containing the document change, selection change,
and inverse information. Preserve IDs of unchanged nodes; allocate new IDs
for duplication and imported results. Coalesce ordinary typing into useful
undo units, but keep template insertion, matrix resizing, structural movement,
and applied computation results as distinct steps. Bound history memory and
make truncation policy explicit.

## Interaction behavior

Throughout this plan, **Primary means Cmd on macOS and Ctrl on Windows/Linux**.
Use the shared [platform modifier policy](canvas-interaction.md#platform-modifier-policy),
including native editing conventions and explicitly justified exceptions.

- Left/right traverse logical insertion positions. Up/down use geometry and
  slot relationships, retaining a preferred horizontal position. Tab/Shift+Tab
  visit placeholders according to the keyboard profile; provide an explicit
  focus-exit command without changing their placeholder-navigation behavior.
  Primary+Space leaves a nested expression. Escape participates in symbol entry
  or cancels an active gesture according to the scoped routing rules below.
- Pointer placement chooses the nearest valid caret stop from the published
  layout. Expanded hit targets around thin rules and small slots must resolve
  ties consistently. Drag selection and keyboard extension use the same
  structural range rules.
- Template insertion wraps the current valid selection where appropriate;
  otherwise it creates an empty template and focuses its first slot. Shortcut
  mappings are documented and remain equivalent to palette actions.
- Backspace/Delete within tokens remove grapheme units. Structural boundary
  deletion follows the interaction fixture, including empty-slot removal and
  destructuring. Do not impose a universal select-then-delete rule where it
  changes expected behavior. Keep each structural change reversible, preserve
  valid slots, and record any intentional exception explicitly. A named unwrap
  command also exposes the operation through menus and the palette.
- IME composition stays within a text leaf until commit. Structural commands
  resolve or cancel composition through the host contract before mutating the
  surrounding tree. Composition is never sent to a CAS.
- Dragging a selected subtree previews its insertion location. Commit is one
  transaction; Escape cancels. A move changes notation and does not claim
  algebraic equivalence. Invalid destinations never commit.
- Clipboard copy includes a versioned structured fragment and the corresponding
  lossless text form. Internal paste preserves structure with fresh IDs. Pasting
  the editor's text format reconstructs the same notation. Other external text
  uses a documented conservative token/row policy; it does not execute source
  or guess an arbitrary algebra language.

Here, tactile response means immediate selection feedback, visible insertion
targets, stable focus, and coherent undo. Small transitions may preserve
orientation after structural changes, but input never waits for animation.
If geometry is animated, painting and hit testing use the same sampled
presentation transform. Reduced-motion mode applies changes immediately.
Physical device vibration is outside the initial scope.

### Structured math keyboard profile

Ship the following bindings and entry semantics as the default 2D editing
profile. These are direct requirements for the editor, independent of the
computation backend and text serialization format. M0 records effective native
bindings on each supported platform and keyboard layout. The table uses the
platform Primary modifier, not literal Control on macOS. For example, fraction
entry is Cmd+/ on macOS and Ctrl+/ on Windows/Linux. Host-conflicting chords
require an explicit resolved alternative before release.

| Input | Required action |
| --- | --- |
| Primary+/ | Form a fraction and enter its denominator |
| Primary+6; Primary+^ alias | Enter a superscript |
| Primary+-; Primary+_ alias | Enter a subscript |
| Primary+2; Primary+@ alias | Insert a square root and enter its radicand |
| Primary+5; Primary+% alias | Switch complementary slots, including script pairs and radical index/radicand |
| Primary+7; Primary+& alias | Enter an overscript or supported upper-limit slot |
| Primary+Shift+, | Enter an underscript or supported lower-limit slot |
| Primary+Space | Leave one expression level; repeat to leave further levels |
| Primary+. | Expand structural selection to the next enclosing expression |
| Tab / Shift+Tab | Select next / previous placeholder |
| Primary+Enter / Primary+, | Add a matrix row / column at the active matrix position |
| Escape, abbreviation, Escape | Insert the corresponding symbol, such as `a` for alpha or `inf` for infinity |

This is the minimum inventory. M0 also specifies ordinary arrows, selection
extension, Home/End, deletion, clipboard, undo/redo, matrix creation from an
ordinary row, and platform-specific aliases. Distinguish numeric-key bindings
from shifted-symbol aliases. Start with Cmd on macOS and Ctrl on Windows/Linux;
any literal-Control exception needs the shared policy's specific justification.
Test actual native events on US and non-US layouts. Resolve host/app conflicts
for Primary+Space and Primary+comma in M0, recording effective platform chords
and visible alternatives. These entries are binding candidates until that check
passes, not a requirement to intercept system shortcuts. Use the resolved exit
binding in the replay examples below if Primary+Space is unavailable.

Binding identity alone is insufficient. Capture what a template takes as its
base or numerator with an empty selection, how a selected expression is wrapped,
where the caret lands, and how repeated shortcuts behave. For example, typing
`x`, Primary+/, `y`, Primary+Space must create a fraction and return the caret outside
it without requiring a palette or a manually selected numerator. Check paired
scripts, nested roots, operator limits, matrix insertion position, and selection
expansion with replay fixtures. Every resulting structure must have a lossless
text representation in the same milestone, including combined scripts and
above/below placements. Unsupported notation cannot silently become another
construct or trigger a different command.

Symbol abbreviations are a transient input session with visible feedback and
completion hints. A completed abbreviation inserts the same token as the
palette, through the same undoable command. It is not a separate document
syntax, and the abbreviation buffer is not an authoritative document mutation.
Unknown abbreviations retain the pending input for correction or explicit
cancellation; do not silently drop text. Specify completion and cancellation behavior in M0. Support the common aliases for the initial symbol vocabulary;
deferred symbols remain visibly unsupported rather than being misinterpreted.

Route keys through native composition/editor context, active symbol-entry or
manipulation session, focused math commands, then outer application commands.
An Escape closing a symbol abbreviation must not also dismiss the editor or
clear selection. An Escape cancelling a drag or popup must not also start an
abbreviation. At rest in the math editor it begins symbol entry; nested exit
uses Primary+Space. Do not use a timing heuristic to distinguish these actions.
The host owns IME composition until resolved; shortcuts must not mutate its
surrounding structure mid-composition.

Keep one remappable, scoped command table shared by key dispatch, menus, hints,
and the palette. Embedded math gets its own focus scope: a mind-map's Space,
Tab, or parent-insertion shortcuts cannot fire while editing math, and generic
canvas shortcuts cannot steal the math profile. Share command-routing mechanisms
with the [canvas framework](canvas-interaction.md#keyboard-command-and-navigation-contract)
when available, without making the math release wait for that package.
The secondary text editor retains ordinary text-editing behavior; 2D template
shortcuts do not insert source-format punctuation into it implicitly.

Reserve Shift+Enter for a future explicit evaluation capability. This profile does not add notebook evaluation or turn Shift+Enter
into an arbitrary algebra operation. Unsupported actions show their status and
are not reused for unrelated commands. New functionality uses verified unused
bindings or explicit menu/palette invocation.

Release acceptance includes a keyboard-only replay of the editing journey:
fractions, nested scripts/roots, matrix growth, symbol abbreviations, structural
selection, deletion, undo/redo, and a switch to text and back. Compare notation,
caret/selection, and command results with the documented interaction contract
for supported cases. Include held keys, incomplete abbreviation cancellation, IME commit,
non-US layouts, host shortcut conflicts, and math embedded in another editor.
An unresolved mismatch blocks acceptance for that operation. The bindings are
specified; native dispatch and interaction behavior remain unverified until the
recordings and replays exist.

## Typesetting and rendering

Implement recursive math layout in Mojo. Each node produces dimensions,
baseline, math axis where applicable, ink bounds, child placements, glyph
placements, caret stops, selection regions, and semantic-to-geometry mappings.
Publish these together as one immutable generation. Painting, hit testing,
caret movement, clipping, and accessibility bounds consume that generation.

Use a pinned redistributable OpenType math font, selected during the font
probe with its actual license and glyph coverage recorded. Font choice is not
yet settled. Read math constants, italic corrections, variants, and assemblies
from the font; implement spacing classes, script styles, fraction gaps,
radical rules, delimiter sizing, and matrix alignment in the layout engine.
The [OpenType MATH specification](https://learn.microsoft.com/en-us/typography/opentype/spec/math)
provides font data rather than a complete layout algorithm.
[HarfBuzz's math API](https://harfbuzz.github.io/harfbuzz-hb-ot-math.html)
is a candidate for querying that data.

The renderer must draw the glyph IDs and positions that were measured,
including assembled delimiters. Select either a positioned-glyph scene resource
or an equivalent retained native payload after the rendering probe. Define
ownership, font identity, scaling, clipping, and snapshot lifetime before
exposing that seam. Arbitrarily stretching ordinary text glyphs is not the
quality path for radicals or delimiters.

Cache layout by node revision, inherited math style, font/environment revision,
and relevant constraints. A change invalidates its ancestors and any dependents
whose layout truly changes. Matrix column widths and tall delimiters can cause
legitimate wider recomputation. Reuse unaffected subtree measurements; measure
actual visited work instead of claiming every edit has constant cost.

Follow the existing [text policy](https://github.com/davidmashburn/moxi/blob/c8c7cbb7741519c9796a02ffa25c02e701b2f58a/docs/text-policy.md): approximate portable
metrics can test model/geometry contracts, but display-quality acceptance uses
the real pinned font and native renderer. Missing math glyphs produce an
explicit fallback or unsupported indication. Full bidirectional math and a
general font fallback collection are later work; Unicode token editing and IME
must still be validated for the initial supported font/script profile.

## Computation boundary

SymEngine and SymPy are candidates. The initial implementation chooses one
after the [backend experiment](math-backend-experiment.md); supporting both is
optional. Editing, layout, and persistence must remain independent of that
decision. Prefer permissive licenses for our packages. The experiment separately
records dependency licensing and binary redistribution requirements.

An operation request contains operation/options, a semantic expression value,
explicit assumptions, target identity, document revision, and request generation.
The adapter returns a supported expression or a classified error/unsupported
result, plus any conditions and backend/version identity. Use exact integers
and rationals across the boundary; decimal tokens require an explicit exact
decimal or approximate-number policy rather than accidental binary conversion.

All computation runs outside the UI event loop. Reuse moxi request scopes and
reject detached or superseded completions. Logical cancellation suppresses a
result; interrupting the computation itself is a separate backend capability.
Bound concurrency and queue growth. A backend that cannot safely stop a task
must not accumulate unbounded abandoned work.

Results appear in a separate editable result block. Applying a result checks
the captured document revision and target identity again, then commits one
transaction. Initially, any source-document edit makes in-place application
stale; the user can rerun or explicitly copy the result. Do not introduce
automatic rebasing until this conservative behavior is proven useful.

Start with exact arithmetic, substitution, expansion, and differentiation.
Add factorization, integration, solving, or numerical approximation only when
the selected adapter's actual capabilities and result forms are covered.
An unavailable operation remains visibly unavailable with a reason.

## Application API and accessibility

Proposed public concepts are `MathDocument`, `MathEditorState`, `MathEditor`,
`MathView`, `MathCommand`, and a computation adapter. Names and signatures remain
provisional. The application owns document/editor state, dispatches commands,
mounts the view, and supplies an optional adapter. It should not maintain
parallel caret coordinates, manually synchronize every slot, or rebuild an
entire document to refresh selection.

Use one command path for keyboard, palette, pointer gestures, and any existing
capability-bus integration. Keep effects outside view construction. Compare a
minimal external consumer with the [API ergonomics baseline](https://github.com/davidmashburn/moxi/blob/c8c7cbb7741519c9796a02ffa25c02e701b2f58a/docs/api-ergonomics.md):
record compile time, public generic surface, diagnostics, and the application
code needed for a complete editor.

Keyboard operation is a release gate. Publish structural labels, focused slot,
selection state, and bounds derived from the committed geometry. A native
accessibility probe must verify navigation and announcements for a fraction,
script, and matrix. A flattened spoken expression is a fallback, not evidence
of full structured screen-reader support. Native IME candidate placement also
uses the current caret geometry.

## Delivery sequence and acceptance gates

### M0 Establish the risky boundaries

Create small compiled probes for document storage/transactions, the text
grammar and lossless parser/printer, math-font queries and glyph rendering,
and the backend comparison. Establish a shared fixture corpus and baseline
timing method. Choose a font, renderer seam, and
initial backend, recording evidence and remaining limits. The editor work can
proceed while the backend experiment runs. Produce a platform/layout keyboard
fixture covering the profile,
symbol-entry routing, template operand capture, and structural deletion.

Exit: a nested fraction with a radical is drawn from measured math glyphs;
pointer probes hit its published slot geometry; text round trips preserve
nested notation, holes, and malformed edits; both backend candidates have
a bounded integration result or a recorded blocker. No engine is selected on
an unmeasured speed assumption.

### M1 Deliver one complete editing slice

Implement tokens, rows, holes, fractions, grouping, and scripts with real math
layout. Add caret movement, structural selection, template insertion, deletion,
transactions, and undo/redo. Deliver the secondary text view and lossless
parser/printer for every construct in this slice. Publish a display component
and editor using the same layout implementation. Introduce only the moxi rendering/input
extensions needed by this slice. Deliver the corresponding default shortcut
bindings, placeholder traversal, selection expansion, and expression-level exit
with the same command path as palette actions.

Exit: users construct and edit a nested fraction entirely through the UI;
pointer and keyboard selection agree; edits in either representation round-trip
without notation loss; undo restores content and caret across view changes; idle
selection changes do not remeasure unchanged math; no CAS is installed.

### M2 Complete the notation and interaction surface

Add radicals, scalable delimiters, matrices and resizing, named functions,
sums/integrals with limits, the symbol palette, structured clipboard,
subtree drag/drop, and versioned save/load. Complete IME and accessibility
integration. Test variable font sizes, display scales, zoom, and narrow viewports.
Extend the text grammar and round-trip fixtures with every new construct.
Complete the keyboard profile for radicals, paired/above/below slots,
operator limits, matrix growth, and Escape-delimited symbol entry. Run the
keyboard-only journey and native conflict/IME checks before acceptance.

Exit: the acceptance journey works through matrix editing; files and structured
clipboard fragments preserve notation; matrix navigation and focus escape are
predictable; the native accessibility/IME checks have recorded results.

### M3 Connect one computational backend

Implement the selected adapter, worker ownership, supported semantic projection,
editable result import, operation controls, and revision-checked application.
Exercise success, unsupported constructs, malformed results, backend absence,
failure, cancellation, and late completion after editing or closing a block.

Exit: expansion and differentiation of selected supported expressions return
editable results. Slow computation leaves editing responsive. Applying a
current result is undoable; a stale result cannot overwrite newer edits.

### M4 Validate reuse and interaction quality

Build an external consumer from the documented package surface. Run native
interaction replays, visual review, keyboard/IME/accessibility acceptance,
performance measurements, and a clean package installation. Record exact
runtime dependencies, notices, and supported platforms. Add documentation and
public API inventories only for capabilities that actually ship.

Exit: all supported acceptance cases pass on the initial host, performance
meets the declared budgets below, and the consumer requires no private APIs or
duplicate geometry state. Backend or font absence has a usable failure mode.

M1 depends on the document and font probes from M0. M2 follows M1. M3 can start
after M1 and the backend decision, with unsupported notation gated explicitly.
M4 integrates M2 and M3. These are dependency gates, not calendar estimates;
estimate implementation effort after M0 exposes binding and font risks.

## Validation and performance targets

Use shared documents for model tests, geometry checks, rendering samples,
interaction replays, and benchmarks. Cover empty slots, nested fractions and
radicals, simultaneous scripts, tall delimiters, matrices with uneven cell
sizes, integrals with limits, Unicode composition, and long expression rows.

Model checks cover undo/redo round trips, identity preservation, structural
invariants, selection after deletion, serialization, and invalid import
rejection. Require tree-to-text-to-tree identity of document content and
text-to-tree-to-canonical-text stability for every node family and combination.
Include holes, incomplete rows, malformed text, Unicode/escaping, matrices,
persisted display distinctions, clipboard fragments, and imported computation
results. Replay alternating text/2D edits and undo/redo; test both linked views
for synchronization and source-span selection mapping. Review paired text and
2D fixtures for a direct, readable construct-to-slot correspondence; round-trip
correctness alone does not establish a clean syntax. Geometry checks cover
baseline/gap constraints, ink clipping, deterministic caret stops, and hit
testing through transforms and scrolling.
Native visual review verifies spacing and glyph quality; pixel checks use a
pinned font and documented tolerances rather than cross-platform equality.

Proposed performance targets, to be accepted or revised with explicit evidence
after the first baseline:

- On a recorded reference macOS host, a local edit in a visible expression of
  up to 1,000 notation nodes should spend at most 8 ms at p95 in dispatch,
  mutation, layout, and scene generation combined. Report p99 and worst cases.
- Target presentation on the next available frame at 60 Hz. Measure event to
  presentation separately; CPU timing is not an input-to-display measurement.
  Record the 8.33 ms frame budget when measuring 120 Hz rather than claiming
  that the 60 Hz target proves it.
- Selection/caret-only updates perform no math remeasurement. Changes in one
  block do not rebuild unrelated blocks. Record measurements, visited nodes,
  paint work, allocations where measurable, and retained cache/history size.
- Stress 100, 1,000, and 10,000-node documents, deep nesting within the declared
  limit, a 20-by-20 matrix, repeated edits, resizing, and a deliberately slow
  computation. Report cold start separately and test continuous widths that
  do not trivially fit a two-entry cache.

The initial supported document-size/depth limits are chosen from these results
and enforced before expensive traversal. Large inputs must remain bounded or
fail explicitly. A long-running kernel request must not consume the UI's frame
budget. Use the existing [benchmarking guidance](https://github.com/davidmashburn/moxi/blob/c8c7cbb7741519c9796a02ffa25c02e701b2f58a/docs/benchmarking.md) and
[native screenshot policy](https://github.com/davidmashburn/moxi/blob/c8c7cbb7741519c9796a02ffa25c02e701b2f58a/docs/text-policy.md) for result artifacts.

## Follow-on symbolic work

A separate permissively licensed symbolic library could own explicit rewrite
rules, assumptions, binding-aware substitution, and transformation provenance.
Its useful differentiator would be operations that explain their conditions
and relate source subexpressions to results, supporting previews and selection
continuity. General integration and solving are independent algorithm projects.

Extract this library when repeated editor/backend requirements establish a
coherent reusable contract. Keep moxi free of algebra-specific rules, and keep
the math editor usable with external computation throughout that evolution.

## Open decisions

M0 must resolve the first backend, pinned font, positioned-glyph resource seam,
text grammar, practical document storage strategy, and platform-specific
keyboard dispatch evidence. The default keyboard profile is decided;
remaining shortcut questions concern verified aliases, host conflicts, and new
commands, not replacement conventions. Set history limits through the shared
interaction cases.
Supporting a second backend, automatic line breaking, mixed prose documents,
and additional native hosts require separate scope decisions.

Confidence is high in separating lossless editing from computation and in
sharing committed geometry across consumers. Confidence is moderate in the
proposed renderer seam and backend integration until the compiled probes run.
Unexpected conversion losses, unbounded native operations, font gaps, or a
large application API burden are reasons to revise those choices at M0/M1.
