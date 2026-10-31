# Before implementation

`Workbench` is the owner of the shared `Services` value. `Services` contains the
shared `Document` and `Settings`; the document carries the current name,
identity, revision, commit count, and history, while settings carry permission
and the name-length limit. The existing `Editor` instances own their private
`draft`, `note`, error, and the document identity/revision they last observed.
The editor does not write a draft or note into `Services` until its Apply
method runs. Apply validates against the shared document and settings, then
reloads the editor after a successful rename.

The screen owns the existing pane instances and routes keyed actions to them.
The left and right editors, settings panel, activity panel, and preview each
have a stable route key. A route passes either the shared services, shared
settings, or a deliberately copied read-only preview context. Scratchpad gets
no context. The route method is the ownership boundary: it should dispatch a
matching event to the current pane and should not dispatch an event for another
key.

I expect an update-triggering event to be a callback such as a text input,
button, or root action. The callback mutates the owning pane or the context
passed by the route; a subsequent render should read the current shared
document/settings and therefore expose shared changes to every mounted editor.
I have not verified the runtime's exact invalidation or callback-retention
rules.

For the third editor, the root should own a separate `Editor` value but route
it with the same shared `Services` as the existing document editors. Its draft
and note should remain in that editor until Apply. A hidden child should be
omitted from render and should be treated as unmounted. Because a field could
otherwise retain its old state, I expect hiding to replace/reset the editor,
and showing to construct a new editor from the current shared document. I also
expect a mount generation in the child key and a route guard against the
current generation to prevent an event retained from the old mount from
reaching the newly mounted editor.

Uncertainties:

- I do not know whether a root `ui.button` callback has the same no-context
  signature used by pane buttons.
- I do not know whether omission alone destroys a field's state, so the design
  explicitly resets the field and uses a new key.
- I do not know whether a retained callback carries the old key, the old pane
  reference, or both; the route guard can only reject it if the key is part of
  the delivered event.
- I have not read runtime internals or previous experiment conclusions, so I
  have not assumed stronger lifetime or invalidation guarantees.
