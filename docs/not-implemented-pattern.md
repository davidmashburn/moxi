# Proposed pattern: Not implemented

Status: scoped; no implementation or public export is included in this plan.

This proposal was moved from `docs/project-planning.md` in the implementation
worktree. Paths below refer to the implementation repository. It is a candidate
follow-up linked from [the execution plan](../PROJECT-PLANNING.md); capturing its
scope does not change the workbench-hardening priority.

Provide a reusable `NotImplemented` component for an intentionally unfinished
feature surface. For example, an application can keep its Export section
navigable while displaying “Export — Not implemented yet” and a short
explanation. This is an application-authoring pattern composed from existing
controls, with no new view kind, renderer command, or platform contract.

## First slice

- A proposed `NotImplemented(Component)` value in
  `src/moxi/not_implemented.mojo`, mounted through the existing `ComponentSlot`
  contract. It accepts a required feature name and optional explanatory text;
  its `build(bounds)` stays pure and its default event handler is inert.
- A visible feature heading, an explicit “Not implemented yet” label, and
  optional wrapped explanation. Use existing style/theme primitives and
  normal layout/overflow behavior so the same component fits a page or an
  embedded panel. The message must remain understandable without color or an
  icon, and must not imply a release date.
- Standard container/label accessibility semantics. The informational content
  creates no focus stops, claims no executable action, and uses no progress
  or error role. A host may place a working Back or documentation action
  beside it using ordinary controls; those actions remain host-owned.
- One runnable example and Playground entry demonstrating the pattern itself,
  including two independently namespaced instances. A planned feature does
  not become a runnable catalog entry merely because it can show this message.
- Document the focused import and intended use. Select its public API lane
  explicitly and update the applicable API inventory/compatibility files when
  implementing it; a root export is not assumed by this scope.

Use this pattern only when application code intentionally selects unfinished
functionality. Keep empty search results, loading, runtime errors, denied
permissions, and unsupported backend capabilities on their own behavior paths.
Do not automatically catch exceptions or replace unsupported renderer output
with this component. Feature flags, roadmap metadata, issue links, telemetry,
automatic discovery of stubs, and an extensible generic status framework are
outside the first slice.

## Acceptance and implementation checks

1. Default and explanatory variants show the feature name and status as visible
   text and in the semantic tree; long text stays reachable at narrow bounds.
2. Two instances compose without duplicate IDs. Rebuilding and resizing retain
   stable identity, produce deterministic output, and introduce no effects.
3. Pointer, keyboard, and action events on the placeholder initiate no work;
   keyboard navigation still reaches working controls around it.
4. A parent can replace the placeholder with its implemented component without
   changes to `Component`, `App`, renderer, or host interfaces.
5. Add focused headless composition/semantics tests, check the example/catalog
   and API inventories, and run the repository regression checks. Verify the
   rendered example at ordinary and narrow sizes; record native visual and
   screen-reader checks separately from headless semantic assertions.

The existing composition contract in `src/moxi/component.mojo`, label/wrapping
APIs in `src/moxi/column_view.mojo`, and explicit empty-state composition in
`src/moxi_demo/demo_browser.mojo` provide the implementation seams. The existing
“No matches” state keeps its current meaning and is not replaced by this work.

## Implementation boundary and validation commands

Owner boundary: application-authoring composition in `moxi`; the demo owns its
host and navigation. Expected implementation files are
`src/moxi/not_implemented.mojo`, `examples/not_implemented.mojo`,
`tests/not_implemented.mojo`, `src/moxi_demo/demo_entry.mojo`, and
`src/moxi_demo/demo_browser.mojo`, plus the relevant Pixi task and API inventory
entries. Reuse the existing style, layout, semantics, and component-slot APIs.

Run from the implementation checkout after implementing the slice:

```sh
pixi run test
pixi run demo-catalog-check
pixi run api-status-check
pixi run check
```

The new test must be included in the test runner, and the example must be
reachable from its declared Pixi task and the Playground. These commands are
planned validation, not results from scoping. Native visual and screen-reader
acceptance remain separate observations as described above.
