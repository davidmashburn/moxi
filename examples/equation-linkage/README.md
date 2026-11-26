# Living linkage: bounded equation editing (I21)

Edit the length or angle in equation text or structured layout, then inspect
the linked arm and its endpoint trace. Drag the endpoint, use the range
control, or focus the arm and press arrow keys to preview a whole-degree pose.
Apply stores one change. Cancel or Escape restores the exact applied source.
Undo and Redo share the document history across all three editing routes.
History buttons operate on applied changes, discarding any pending draft.

Build the offline page from the repository root:

```sh
PYTHONPATH=python python3 examples/equation-linkage/build.py /tmp/linkage.html
```

Open `/tmp/linkage.html` in a browser. The generated page has no server,
network or computation-backend dependency. Reload starts a new session.

## Contract and ownership

This is the smallest experiment from project-planning's
[I21 living linkage proposal](https://github.com/davidmashburn/moxi/blob/project-planning/ideas/i21-living-linkage-sketch.md)
and its I21 scenario in `DEFERRED-IMPLEMENTATION-MASTER.md`: one degree of
freedom, one editable length, an endpoint trace, pointer and keyboard routes,
exact text/layout round trips, cancellation and shared undo. The implementation
starts at public `origin/main` `033596d`; it uses no private math ancestry.
It adds only this consumer and its evidence, leaving V01, V07 and the existing
math, spring-linkage and foldable-motif implementations untouched.

The finite grammar is four equations, in this order:

```text
L = 100.00 mm
θ = 30.0 deg
x = L * cos(θ)
y = L * sin(θ)
```

`L` is 40–140 mm; `θ` is 0–90 degrees. Numeric leaves accept ordinary
nonnegative decimal spelling, including a leading plus, padded integers and
trailing decimal zeros. The multiplication mark may be `*` or `·`. Whitespace
and trailing `#` comments are retained. Unsupported relations, holes, malformed
numbers, out-of-range values and source exceeding the 4096-character evaluation
bound remain intact as drafts. They cannot apply, and show the last applied
geometry. Layout displays unsupported drafts as inert text, with a route back
to text editing. While an invalid layout leaf is focused, it can be repaired
in place; other numeric leaves wait until it is valid.

`model.mjs` owns lossless source, numeric token spans, limits, preview and
100-entry session history. It never serializes derived floating-point values
back into source. Layout edits replace one token with exactly what was typed.
Pose controls replace only the angle token, preserving the sign, integer
padding, decimal point and fractional width. Returning to the original pose
preserves the original token. Coordinates are floating-point projections;
their three-decimal readouts are not source text. Browser textarea entry uses
the browser's newline normalization; model-level CRLF fixtures verify that
parsing, structural replacement, geometry updates and history preserve CRLF
when it is supplied directly to the model.

The structured view exposes the two editable numeric leaves and lays out the
two fixed endpoint relations using MathML. It is a bounded notation consumer,
not a general equation or symbolic editor. Apply or cancel equation drafts
before moving geometry. Pointer cancellation and window focus loss cancel a
geometry preview. Both length and angle edits may be applied together as one
history entry; a no-op adds none.

`build.py` adapts the public
[spring-linkage consumer's common-scale projection](../spring-linkage/build.py):
Moxi's public `PlotSpec.add_line`, `plot` and `Figure.to_svg` project the
91-sample endpoint trajectory with fixed scale anchors. The browser scales
that trace with length and projects the endpoint in the same coordinates.
No solver, CAS, spring dynamics or native math-editor API is involved.

## Checks and evidence

With Node, desktop Google Chrome and Playwright available:

```sh
node --test examples/equation-linkage/model.test.mjs
PYTHONPATH=python python3 examples/equation-linkage/build.py /tmp/linkage.html
node examples/equation-linkage/check.cjs /tmp/linkage.html /tmp/linkage-frames
python3 examples/equation-linkage/deck.py /tmp/linkage-frames
```

If Playwright is installed outside Node's lookup path, set `NODE_PATH` to its
`node_modules` parent. Browser checks use an isolated offline Chrome context.
The manifest records the source revision, exact file hashes, generated HTML
hash, browser, capture time, viewport, scenario steps, expected and observed
results, pass/fail outcome, screenshots, errors and failed requests.

The model suite covers precise spelling and spans, CRLF, incomplete and
unsupported source, range limits, minimal scalar replacement, source and
geometry cancellation, shared undo/redo and 273 length/angle samples.
The normal browser replay covers text/layout switching, sibling leaf edits,
incomplete-leaf recovery, malformed source, rejection, keyboard/slider/pointer
previews, cancellation, commit/undo, geometry projection, narrow layout and
session-only reload. Pointer cancellation and window blur are synthetic events;
the other editing actions use normal browser input.

The recorded [navigable screenshot deck](../../artifacts/demo-slideshows/i21-equation-linkage/index.html)
and [manifest](../../artifacts/demo-slideshows/i21-equation-linkage/manifest.json)
are the scoped verification record. Raw fail-first and replay logs were kept
in a temporary directory and are not product source. The baseline model check
failed for the missing equation model; the existing public V11 browser
consumer failed the equation-surface check. These establish a missing feature,
not a regression in V11.

## Limits

No arbitrary equations, joint graph, alternative branches, CAD/physics,
saved-document persistence, native host, other browser engines, real touch or
hardware-input trial, independent usability assessment, physical mechanism or
fabrication validation is claimed. VoiceOver remains paused; keyboard replay
does not establish screen-reader acceptance. No global ledger or planning index
is changed by this consumer.
