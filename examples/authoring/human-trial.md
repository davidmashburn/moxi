# Try building a group action

Status: the author made a brief attempt, then received implementation help. The
current workspace includes the resulting reference-iteration solution; use the
baseline below for a fresh attempt. This was not a completed unassisted usability
trial, and the author's stated preference is to avoid indexing where reasonable.

This is a small authoring trial, not a tutorial with a supplied solution. It asks
whether Moxi's ordinary methods and shared context are understandable when you
extend an application. A successful compile alone cannot answer that question.

## The task

Add a **Revert group** button to each group in
[workspace.mojo](workspace.mojo). It should replace every draft's text in that
group with the document's **current saved title**.

The saved title and the other group's draft text must stay unchanged. Keep the
same drafts, identities, and order. The action must still affect the correct group
after reversing groups or drafts. It should also work for an empty group and for
newly added drafts. Existing controls should keep working.

Use the public authoring API. There is no prescribed number of lines or preferred
implementation to guess. If the task seems to require framework changes, stop and
record why rather than working around it silently.

## Start here

The baseline is commit `f98ae21` on `feat/data-workbench`; this exercise adds no
solution code. Run these commands from the repository root on macOS:

```sh
pixi run --locked authoring-workspace-build
./dist/moxi-authoring-workspace
```

Rebuild and reopen after edits. On other platforms, the headless example runs with:

```sh
pixi run --locked mojo run -I src examples/authoring/workspace.mojo
```

The headless entry point only constructs the application and prints the group
count; it does not provide interactive editing or verify your new action.

You can consult the [authoring overview](../../docs/authoring/README.md),
[application guide](../../docs/authoring/application-guide.md), and neighboring
examples. Begin with those public materials. Record any need to inspect runtime
internals or ask for implementation help. Help is allowed, but the rest of the
attempt is then assisted; a stopped attempt is useful evidence too.

## Check the visible behavior

Use a fresh application for the first row, then continue in order. Alpha and Beta
are group names; find them by name after reversing their positions. Scroll as
needed. Apply and individual Revert already exist on each draft.

| Do this | Expected result |
| --- | --- |
| Click Revert group in Alpha. | Both Alpha drafts show `Shared title` and Clean. Both Beta texts stay as they were. The saved title is unchanged. |
| Change one Beta draft to `Published B`, then click its Apply. | Saved title becomes `Published B`. Alpha's texts remain `Shared title`, now Dirty. |
| Reverse groups and reverse Alpha's drafts. Click Alpha's Revert group. | Both Alpha drafts show `Published B` and Clean. Beta's texts and the saved title stay unchanged. |
| Edit one Alpha draft to `Unsaved A`, then click Revert group in Beta. | Alpha keeps `Unsaved A`; both Beta drafts show `Published B` and Clean. |
| Add a draft to Alpha, then click Alpha's Revert group. | All three Alpha drafts show `Published B`; none is removed or reordered. |
| Close Alpha's drafts until it is empty, then click its Revert group. | No crash; Alpha stays empty; Beta and the saved title are unchanged. |
| Add a draft to Alpha, then click Alpha's Revert group again. | The new draft shows `Published B` and Clean. |

These visual checks do not prove stable identity or delayed-action behavior. A
maintainer will check those separately after the attempt: capture Alpha's action,
save a new title in Beta, reorder both levels, then deliver the captured action.
It must update the original Alpha's current drafts from the title at delivery,
preserving draft keys and order. An action captured before that group is removed
must be rejected after removal, including when another group is added.

Existing regression checks can be run with:

```sh
pixi run --locked mojo run -I src examples/authoring/workspace_check.mojo
pixi run --locked mojo run -I src examples/authoring/draft_revert_check.mojo
```

They do not test the new group action. Their structural control selectors may
need adjustment if you change declaration order; record that friction separately
from application implementation effort.

## What to bring back

Share the diff, whether the visible checks passed, and a few notes:

- Before coding, where did you expect this behavior to belong?
- Which API signatures or ownership rules made you pause?
- Which documentation, compiler errors, runtime internals, or help did you need?
- After finishing, can you explain how the action reaches the current group and
  current saved title? What still feels like a rule you have to memorize?
- Would the next similar action feel routine? Why or why not?

Do not optimize for a short diff or a fast finish. We are looking for confusion,
unexpected ceremony, and whether the resulting code matches your mental model.
One familiar user's attempt can identify friction; it cannot establish universal
ease of use, large-application scalability, or rendering performance.
