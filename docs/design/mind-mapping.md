# Native mind mapping application

Status: proposed scope and delivery plan. Build a Freeplane-inspired native
mind-mapping application on moxi, together with the reusable
[canvas interaction framework](canvas-interaction.md). This plan describes a
useful initial product and explicit follow-ups, not complete feature parity.
It does not change the [execution plan's](../../PROJECT-PLANNING.md) existing
workbench priorities without a separate scheduling decision.

The primary experience is keyboard-first thought capture and restructuring: type a
topic, add siblings and children, fold detail, move branches, and connect ideas.
The map should feel stable under the hand. Direct manipulation must be smooth,
predictable, and reversible, while the code consuming moxi stays understandable.
Keyboard efficiency is a product requirement, including structural changes and
crosslinks. Pointer gestures complement that workflow; a mouse-free session
must not feel like navigating an accessibility fallback.

## Reference behavior and product boundaries

Freeplane's [first steps](https://docs.freeplane.org/user-documentation/first-steps.html)
describe keyboard creation/navigation, folding, and drag/drop. Its
[manual positioning guide](https://docs.freeplane.org/user-documentation/positioning-nodes.html)
is a reference for the relationship between automatic arrangement and user
placement. Use these workflows to design our own implementation and fixtures.
Detailed behavior should be compared against a pinned installed version during
the native probe; documentation review is not interactive equivalence testing.

The initial application runs on macOS, stores local files, and works offline.
Its model/layout/replay tests are portable. Native parity on other hosts is a
separate acceptance gate, following the project's host plans.

Initial scope:

- One rooted ordered topic tree, with left/right branches around a central topic
  and an alternative one-sided arrangement. Nodes have stable identities.
- Fast keyboard creation, inline Unicode text editing, reorder, reparent,
  multi-selection, parent insertion, cut/copy/paste, branch duplication, deletion,
  and undo/redo.
- Fold/unfold, pan/zoom, fit selection/map, search with reveal, and a synchronized
  outline for navigation and structural editing, plus a basic text filter and
  searchable node list on their reference shortcuts.
- Node notes, links, basic icons/tags, and a small named style palette. Start
  with plain multiline text and notes; a rich-document editor is not required.
- Explicit labeled crosslinks between topics, separate from parent/child edges.
- Human-readable versioned native persistence, recovery, and a bounded Freeplane
  `.mm` import path with an explicit supported subset and loss report.

Deferred: scripting/formulas, add-ons, cloned/live-alias nodes, conditional
style rules, task scheduling, cloud sync, collaboration, arbitrary HTML nodes,
embedded files/images, general graph editing in the mind-map UI, presentation
mode, mobile/touch-first parity, and complete `.mm` round-trip compatibility.
SVG/PDF/image export is follow-on work. Math nodes can use the separately planned
math editor later; neither product depends on the other shipping first.

## Primary acceptance journey

1. Create a central topic and a dozen branches using the keyboard. Enter a
   multiline topic and use an IME without losing focus or creating extra nodes.
2. Fold a large branch, navigate elsewhere, and reveal a search result inside
   it. The selected result appears without permanently destroying fold state.
3. Move a subtree between siblings and then under another topic using keyboard
   commands and a searchable destination picker. Preview exact parent/order;
   cancel once, commit once, and undo once. Repeat the operation by dragging
   and verify the same result and history behavior.
4. Move a branch across the root to change its side. Adjust local spacing with
   keyboard spacing commands and then a distinct placement handle; automatic
   layout respects that intention.
5. Add a labeled crosslink to another branch using keyboard source/target
   selection, edit a note, and use the outline to perform the same reparent
   operation. Switch between map and outline without losing the current topic.
6. Save, close, reopen, and recover the same content, hierarchy, crosslinks,
   styles, and placement intent. Recover a newer unsaved revision after a
   simulated interrupted session without overwriting the saved file.
7. Import a representative `.mm` file into a new native document, inspect the
   loss report, and continue editing. The source file remains unchanged.

The release fixture must include a large folded subtree, long labels, mixed
scripts, notes, crosslinks, and uneven node sizes. A balanced tree of short
English labels is insufficient evidence.

## Document, view, and history

`MindMapDocument` is application-owned. Each topic has a stable ID, parent ID,
ordered child IDs, text, optional note/link/tags/icons, style reference, and
placement intent. Crosslinks have separate stable IDs, endpoints, optional
labels, and style. A versioned view section can persist fold state and camera
preferences without confusing them with semantic hierarchy.

Enforce one root, one parent per non-root topic, no parent cycles, unique IDs,
valid ordering, and resolvable crosslink endpoints. Empty topic text is valid
while editing. Depth, node count, text length, and imported resource limits are
declared and enforced before expensive traversal. Tree operations use explicit
stacks where supported depth could exhaust the call stack.

Commands include create sibling/child, edit content, reorder, reparent,
insert parent, change branch side, adjust spacing, delete subtree, duplicate, and add/remove
crosslink. The same command handles keyboard, canvas, outline, and menus.
Deleting a subtree removes incident crosslinks in the same transaction; undo
restores IDs and links. Duplication allocates fresh IDs and remaps internal
links; outbound crosslinks are omitted by default with a visible summary.
Root deletion and moves beneath a descendant are rejected explicitly.

For multi-selection, normalize to the selected roots so an ancestor and its
selected child are not moved or deleted twice. Preserve relative order when
moving a forest. Crosslinks never acquire ownership semantics, and connecting
two topics must not silently reparent either one.

Keep transient hover, search reveal, drag preview, and layout interpolation
outside persisted content. Document commands are atomic and undoable. Typing
coalesces until a meaningful boundary; a subtree move is one undo step.
Ordinary navigation and camera changes do not pollute content history. Fold
preferences use view state and a separate restore action if needed.

## Layout and tactile behavior

Use a deterministic ordered tree layout in Mojo, based on measured topic boxes
and subtree extents. Parent/child topology is not the canvas framework's group
containment. Project the tree into ordinary canvas objects and edges; the app
supplies ancestry rules, insertion targets, and the layout strategy.

Persist root-branch side and bounded spacing adjustments, rather than trying
to persist every derived position as authoritative. A distinct spacing gesture
changes those constraints; branch-body drag changes parent/order. If layout
must clamp an adjustment to prevent overlap, show the result and preserve the
requested value for future space. A free-position diagram mode is not part of
this release.

Measure content independently of zoom. Recompute affected subtree extents and
the ancestors/neighbors whose positions actually change. Retain unaffected
measurements and stable IDs. A long root edit or a large reparent can cause
wide reflow; measure that cost rather than claiming all edits remain local.

During branch drag, the grabbed topic follows the pointer immediately and
descendants move as a preview group. The original structure remains committed
until drop. Show a gap/connector preview for the candidate parent and sibling
slot; reject the moved subtree as a target. Use stable hit regions or hysteresis
so preview reflow cannot make the insertion target oscillate. Large subtrees
may use an explicit bounded preview with a descendant count.

Hovering a folded target can temporarily reveal it after a dwell. Cancel restores
the prior fold state. Edge autopan is bounded and stops on release/cancel.
Commit revalidates the parent and order, performs one command, and animates
affected neighbors from their current presentation to the new layout. The
grabbed item does not lag behind input while dragging. Reduced motion produces
the same final state immediately. No idle force simulation is required.

Folding preserves a visual anchor: hold the selected topic at its screen
position when practical rather than jumping the whole map. If hiding a focused
descendant, move focus to the folding ancestor before it disappears. Hidden
crosslinks show a count/indicator on a visible ancestor when useful; do not
redraw them as if that ancestor were their actual endpoint. Unfold restores
the original links. The same sampled geometry drives paint and pointer targets.

## Keyboard, editing, and accessibility

Freeplane shortcut compatibility is the default, adapted to the shared
[platform modifier policy](canvas-interaction.md#platform-modifier-policy):
**Primary = Cmd on macOS, Ctrl on Windows/Linux**. Preserve command semantics
and key choices while using native modifiers. Freeplane already translates
ordinary Control accelerators to Command on macOS; this is consistent with our
policy, not a new adaptation we need to invent. Pin the reference to **Freeplane 1.13.3**, commit
`3a76de18523993a55bf885190438bffef38662a5`. Match bindings **and their command
semantics** for supported features, including focus, selection, branch side,
editor state, and key repeat. Do not substitute familiar shortcuts from another
editor or reserve existing bindings for our new commands.

The following baseline was checked against the release's
[menu definitions](https://github.com/freeplane/freeplane/blob/3a76de18523993a55bf885190438bffef38662a5/freeplane/src/external/resources/xml/mindmapmodemenu.xml).
The table expresses ordinary command modifiers as Primary. The release's
[accelerator manager](https://github.com/freeplane/freeplane/blob/3a76de18523993a55bf885190438bffef38662a5/freeplane/src/main/java/org/freeplane/core/ui/ActionAcceleratorManager.java#L510)
resolves shared `control` entries to `meta` on macOS. Its conversion explicitly
handles some Tab/Escape and Alt combinations differently; record those actual
exceptions individually rather than interpreting the raw menu XML as the final
macOS keymap. For example, sibling reorder is
Cmd+Up/Down on macOS and Ctrl+Up/Down on Windows/Linux. Check the source's
[macOS overrides](https://github.com/freeplane/freeplane/blob/3a76de18523993a55bf885190438bffef38662a5/freeplane/src/editor/resources/default_accelerators_mac.properties)
and actual behavior during N0, retaining separate source and target chords in
the compatibility fixture. Any departure from the Primary policy requires a
specific command-level rationale. Resolve host-reserved combinations such as
Primary+Space before release; do not silently fall back to literal Control.

| Action | Target binding | Scope requirement |
| --- | --- | --- |
| New sibling / previous sibling | Enter / Shift+Enter | Preserve insertion order |
| New child / insert parent | Tab / Shift+Tab | Shift+Tab is not outdent |
| Edit label / edit in dialog | F2 / Alt+Enter | A plain multiline dialog suffices initially |
| Move node up/down | Primary+Up / Primary+Down | Reorder, not viewport pan |
| Change node level left/right | Primary+Left / Primary+Right | Match side-dependent structural behavior |
| Fold/unfold | Space | Disable generic Space-pan in the map profile |
| Reveal next child / toggle children folded | Shift+Space / Primary+Space | Verify selection and fold behavior |
| Unfold/fold one level | Alt+PageDown / Alt+PageUp | Preserve reference scope |
| Unfold/fold all | Alt+End / Alt+Home | Preserve reference scope |
| Select all / branch | Primary+A / Primary+Shift+A | Match selection scope |
| Go to root | Escape | Idle map; active editors/previews cancel first |
| Find / find next | Primary+G / Primary+Shift+G | Do not replace with generic find bindings |
| Filter / node list | Primary+F / Primary+Shift+F | Separate filtering from finding |
| Add connector / hyperlink | Primary+L / Primary+K | Preserve selected-node connector behavior |
| Zoom in/out | Alt+Up / Alt+Down | Do not repurpose font-size shortcuts |
| Undo/redo | Cmd+Z / Cmd+Shift+Z on macOS; Ctrl+Z / Ctrl+Y on Windows/Linux | Native convention takes precedence |
| Delete | Delete; macOS override Backspace | Match map selection behavior |
| Focus outline | Primary+Shift+O | Return focus predictably |
| Focus/show notes on macOS | Cmd+. / Cmd+Shift+. | Explicit macOS overrides |

This is a starting inventory, not an exhaustive parity claim. N0 inventories
all shortcuts for the supported scope, including navigation/selection keys,
clipboard, file actions, notes, editing, and aliases outside menu resources.
Record effective bindings, command IDs, context, expected result, platform,
reference version, and evidence. Defaults for deferred features remain reserved:
for example, reserve Primary+D for clone rather than assigning it to duplicate.
New move-target search, spacing controls, and command discovery use verified
unoccupied bindings or menu/palette invocation. Remapping is available through
one table, while the shipped default retains compatibility subject to the
platform modifier policy.

Tab inside ordinary controls retains focus traversal; the map's Tab/Shift+Tab
creation commands require an explicit, discoverable focus-exit command that
does not steal another reference binding. Host-reserved combinations need a
recorded conflict and accessible alternative; do not silently remap the default.
Menus, hints, and the command palette all display the effective binding.

Define the common keyboard operations before designing gesture polish. The
behavior descriptions below are design intent; where a reference command has
more specific navigation, selection, or editing semantics, the N0 reference
fixture governs command semantics; the platform modifier policy governs chord
adaptation. Extensions must not change existing command results:

- **Capture:** create sibling or child and immediately focus the new label;
  commit-and-create-next makes successive ideas quick to enter. Empty-node
  cancellation removes only the still-provisional new node. Repeated creation
  must never reuse an ID or accidentally act on the previous editor.
- **Navigate:** inward moves toward the parent and outward toward children,
  respecting the branch's side of the root; Up/Down traverses visible siblings.
  Returning to a branch can restore its last focused child. Root-side choice,
  absent children, and navigation across folded branches have documented
  deterministic behavior. Separate commands traverse the full visible outline.
- **Select:** range selection follows visible outline order with a stable
  anchor; subtree selection is explicit. A status hint identifies count and
  scope before moving or deleting. Folding never silently expands a selection
  into unseen descendants except for a declared subtree command.
- **Restructure nearby:** reorder up/down, change level left/right with the
  reference side-dependent behavior, and change root-branch side are direct
  commands. Keyboard spacing adjustment uses the same constraints and preview
  as the placement handle. Invalid root/boundary moves show a reason and leave
  history alone.
- **Move elsewhere:** enter a move session, search topics by label/path, preview
  the candidate parent and insertion slot, adjust the slot, and commit or
  cancel. Disambiguate duplicate labels by breadcrumb. Reject descendants and
  retain the original location until commit. Hidden targets may be temporarily
  revealed; cancel restores the prior view. The same targets power drag/drop.
- **Connect:** preserve the reference connector command on a compatible
  selection, including source/target ordering. Additionally, from one selected
  topic, offer target search, preview, and commit through a distinct extension
  command. Edit its label or remove it through commands. Link
  navigation can return to the source without losing the user's place.
- **Inspect and return:** focus notes, outline, search, or command palette, then
  restore the invoking topic. Search-next and search-previous reveal matches
  with minimal camera motion and preserve user fold preferences.

Show prospective structural changes with the same insertion marker, ghost,
and connector preview used for pointer actions. A keyboard move should feel
like manipulating the map, not submitting a form in an unrelated dialog.
Contextual hints and the searchable command palette expose enabled actions and
shortcuts. Native announcements report the destination and result concisely.

Inline editing has clear enter/commit/cancel states. Enter commits an ordinary
label edit; a documented modified action inserts a newline. IME commit takes
precedence over node creation. Text selection and clipboard shortcuts stay
within the active editor. Canvas Space-pan is suppressed there, and the app's
fold shortcut owns Space in map navigation; use another declared pan gesture.

The outline is another view of the same topic IDs and commands, not a second
copy of the map. It supports tree expansion, reordering, reparent commands,
search, and focus synchronization. A canvas node can be revealed from outline
focus without resetting the user's camera on every selection change.

Publish native tree semantics, level/expanded state, labels, selected state,
notes/links where appropriate, and actions for move/fold/edit. The outline is
a reliable alternative to spatial navigation, but does not excuse incorrect
canvas focus or transformed bounds. Test with real screen-reader navigation,
IME candidate windows, keyboard-only use, zoom, and display scaling. Record
unverified host behavior rather than calling a semantic snapshot full support.

## Persistence and compatibility

Use a simple versioned UTF-8 JSON document with stable IDs, ordered children,
crosslinks, styles, and placement constraints. This is human-readable/editable
storage, not a requirement for a second full source editor. Derived layout
coordinates and animation/cache state are omitted. Validate edits on load and
report the object/field responsible for errors. Save through a temporary file
and atomic replacement where supported; save failure retains dirty state.

Autosave recovery is a separate revision-tagged file. Offer recovery on reopen;
do not silently replace the last explicit save. Define ownership/locking for
two windows opening the same file; initially detect external modification and
require reload or save-as instead of silent last-writer-wins. Bound retained
history and recovery files. Structured clipboard fragments preserve supported
content and remap IDs; indented plain text imports a basic subtree and does not
pretend to preserve notes or crosslinks.

For `.mm` import, pin a Freeplane release and generate small fixture files that
isolate each supported feature. The public
[file-format documentation](https://docs.freeplane.org/attic/old-mediawiki-content/Current_Freeplane_File_Format.html)
is in an archive and mixes historical material; treat it as a starting point,
not a complete current schema. Verify against files written by the pinned app.

Required initial subset: hierarchy/order, IDs, plain labels, fold state, branch
side, basic links, and crosslinks where the pinned representation is verified.
Read supported rich text as text with a visible formatting-loss report; preserve
notes when safely convertible. Report unsupported styles, attributes, embedded
objects, aliases, or executable content by count and location. Reject malformed
IDs/topology. Disable external XML entity resolution, network fetches, and all
script/formula execution. Import into a new native document and retain the
original source file; do not advertise lossless `.mm` export.

This is an independent permissive implementation. Freeplane publishes a
[GPL license](https://github.com/freeplane/freeplane/blob/1.12.x/license.txt);
use documented behavior and original fixtures for product design, without
copying its implementation or bundled assets into the permissive codebase.
Record actual licenses for any imported libraries, icons, and fonts. No Java
runtime or Freeplane library is required by this plan.

## Implementation boundaries and acceptance tasks

Proposed implementation locations are `src/moxi_mindmap/` for document,
commands, tree layout, projection, persistence, and import; a native workbench
example for the application shell; and `tests/mindmap_*.mojo` plus shared map
fixtures for contracts and replay. These paths and tasks below are new work.
The [canvas plan](canvas-interaction.md) owns generic geometry and gestures.
Keep one fixture set across model tests, replay, native demos, and benchmarks.

1. **N0: validate boundaries and interaction.** With canvas C0, prototype a
   measured/editable topic and a small ordered tree using the
   [rich-node probe's component-hosting path](canvas-interaction.md#c0-rich-node-acceptance-scenario).
   Verify that topic resizing publishes new connector anchors without app-owned
   geometry synchronization. Keep branch reparent/reorder as semantic tree
   commands; canvas placement and visual group membership do not define ancestry.
   Record reference keyboard
   and branch-move behavior using the pinned Freeplane release. Produce the
   platform-specific shortcut fixture and resolve host conflicts before setting
   defaults. Establish import
   fixtures and document invariants. Add `pixi run mindmap-probe`. Exit with
   native text/IME evidence and a reviewed branch-drag storyboard/replay plan.
2. **N1: useful keyboard map.** With C1, deliver create/edit/navigation,
   deterministic tree layout, fold, basic selection, undo/redo, and explicit
   save/load. Add `pixi run mindmap-contract`. Exit: create and reopen a useful
   map with keyboard-only input; node identity and content survive reflow.
   Include parent insertion, direct reorder/level changes, and command discovery
   in this slice, using verified bindings with the platform modifier policy.
3. **N2: tactile restructuring.** Deliver branch drag/reparent/reorder, side
   changes, spacing controls, preview/cancel, autopan, multi-selection, and
   synchronized outline and searchable keyboard move destinations. Add
   `pixi run mindmap-replay`. Exit: each gesture has
   an equivalent command, cancel is lossless, and a move is one undo step.
4. **N3: knowledge and interchange.** With C2, add crosslinks, notes, basic
   styles/tags/icons, search/reveal/filter/node list, structured clipboard,
   recovery, and `.mm`
   import with a feature/loss report. Add `pixi run mindmap-import-check`.
   Exit: the full acceptance journey passes on representative fixtures and
   unsupported imports leave the source intact.
5. **N4: native quality and packaging.** With canvas C3/C4, add
   `pixi run mindmap-native-check` and `pixi run mindmap-benchmark`, validate
   screen-reader/IME use, clean installation, recovery/failure cases, and API
   consumption. Exit: recorded native behavior meets the declared interaction
   and performance gates, and the app uses no private canvas internals.

Scope the first demonstration as N1 plus the smallest N2 branch move. The
initial useful release completes N4. The framework's second consumer develops
alongside these stages; do not finish a generic diagram platform before using
it. Effort estimates follow N0/C0 rather than guessing around host/input risks.

## Performance and review gates

Use the canvas plan's provisional 8 ms p95 hot-interaction CPU budget on a
recorded reference host. Measure end-to-display latency separately and target
the next available 60 Hz frame. The initial local edit/reparent target uses
1,000 visible topics with representative labels and crosslinks; report broad
layout changes separately, including p99 and maximum latency.

Benchmark 100, 1,000, and 10,000 total topics; folded and fully expanded maps;
deep chains; wide roots; large labels/notes; and high-crosslink cases. Track
visible versus total counts, measured nodes, changed positions, routed edges,
draw work, allocations, and retained memory. No node text remeasurement during
camera-only motion; hidden descendants incur no routine draw/hit work. Search
and fold may legitimately touch many records and must be bounded or scheduled
without blocking pointer feedback. Late search/layout results are revision-checked.

Model/replay tests cover cycles, multi-selection normalization, root handling,
undo/redo, incident crosslink deletion/restoration, ID remapping, fold/search
restoration, invalid import, save failure, external file changes, and interrupted
recovery. Native acceptance covers repeated branch moves, insertion-target
stability during reflow, capture loss, focus after fold, editing during zoom,
keyboard escape, reduced motion, and real assistive technology. Review code
needed for the app alongside its visible behavior: repeated canvas geometry or
gesture plumbing is a framework defect to resolve before API stabilization.

The keyboard release script completes the entire acceptance journey without
pointer input, including crosslink creation and distant reparenting. Record
actions required for frequent operations and unexpected focus/mode changes;
optimize against that evidence without imposing arbitrary keystroke-count
targets. Include duplicate topic names, left/right branches, folded targets,
non-US keyboard layouts, held keys, Escape during previews, and IME commit.
Test switching between keyboard and pointer mid-session. A single missing
essential keyboard command blocks release even if its drag gesture works.
Replay equivalent supported command sequences in Freeplane and this app,
starting from equivalent maps and translating modifiers through the declared
platform policy. Record source and target chords separately. Compare selection, hierarchy/order, folding, focus, editor
commit/cancel, and undo results. Include Shift+Tab parent insertion, left/right
level changes on both root sides, selected-node connectors, idle Escape-to-root,
and search/filter distinctions. Any mismatch needs resolution or an explicit
compatibility exception; unsupported features must not acquire different
meanings on their reserved shortcuts. Published key tables alone do not pass
this gate.

Confidence is high that an ordered tree plus separate crosslinks is the right
initial document model. Confidence is moderate in automatic layout plus manual
spacing and in transformed native inline editing. N0/C0 interaction recordings,
representative imports, and consumer code can change those decisions. Reference
documentation and moxi source were inspected for this proposal; no reference
app session, import implementation, native probe, or benchmark was run.
