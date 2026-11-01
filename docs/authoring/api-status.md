# moxi.authoring API status

Generated from `src/moxi/authoring/__init__.mojo`, `docs/authoring/api-lanes.tsv`, and the compatibility snapshots. Run `pixi run api-status-check -- --write` after changing the public re-export list or a support lane. Unknown public modules fail the check. The support lane is a compatibility statement, not a claim that every host implements every backend feature.

- `stable-core`: compatibility-oriented value, component, layout, event, paint, and runtime contracts.
- `provisional`: useful support APIs that may still change before a 1.0 stability promise.
- `host-adapter`: platform, export, and native-host seams whose availability is backend-dependent.
- `demo/support`: examples, recipes, scenarios, and validation helpers; not package compatibility promises.
- `experimental`: optional integrations and capability/GPU/text slices still under active design.

| Export | Module | Support lane | Ownership |
| --- | --- | --- | --- |
| `Action` | `moxi.authoring.actions` | stable-core | current-owner action descriptors |
| `Entry` | `moxi.authoring.composition` | stable-core | field projection and keyed child ownership |
| `Keyed` | `moxi.authoring.composition` | stable-core | field projection and keyed child ownership |
| `field` | `moxi.authoring.composition` | stable-core | field projection and keyed child ownership |
| `CapturedAction` | `moxi.authoring.delivery` | stable-core | lifetime-scoped delivery envelopes |
| `QueuedEvent` | `moxi.authoring.delivery` | stable-core | lifetime-scoped delivery envelopes |
| `MountKey` | `moxi.authoring.identity` | stable-core | child mount identity |
| `ActionRequest` | `moxi.authoring.runtime` | stable-core | bounded authoring and session lifecycle |
| `HandlerHost` | `moxi.authoring.runtime` | stable-core | bounded authoring and session lifecycle |
| `Pane` | `moxi.authoring.runtime` | stable-core | bounded authoring and session lifecycle |
| `Screen` | `moxi.authoring.runtime` | stable-core | bounded authoring and session lifecycle |
| `UI` | `moxi.authoring.runtime` | stable-core | bounded authoring and session lifecycle |
| `complete_action` | `moxi.authoring.runtime` | stable-core | bounded authoring and session lifecycle |
| `deliver` | `moxi.authoring.runtime` | stable-core | bounded authoring and session lifecycle |
| `reset` | `moxi.authoring.runtime` | stable-core | bounded authoring and session lifecycle |
| `reset_headless` | `moxi.authoring.runtime` | stable-core | bounded authoring and session lifecycle |
| `schedule_action` | `moxi.authoring.runtime` | stable-core | bounded authoring and session lifecycle |
| `update_model` | `moxi.authoring.runtime` | stable-core | bounded authoring and session lifecycle |
