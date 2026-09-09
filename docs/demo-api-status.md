# moxi_demo API status

Generated from `src/moxi_demo/__init__.mojo`, `docs/demo-api-lanes.tsv`, and the compatibility snapshots. Run `pixi run api-status-check -- --write` after changing the public re-export list or a support lane. Unknown public modules fail the check. The support lane is a compatibility statement, not a claim that every host implements every backend feature.

- `stable-core`: compatibility-oriented value, component, layout, event, paint, and runtime contracts.
- `provisional`: useful support APIs that may still change before a 1.0 stability promise.
- `host-adapter`: platform, export, and native-host seams whose availability is backend-dependent.
- `demo/support`: examples, recipes, scenarios, and validation helpers; not package compatibility promises.
- `experimental`: optional integrations and capability/GPU/text slices still under active design.

| Export | Module | Support lane | Ownership |
| --- | --- | --- | --- |
| `SHOWCASE_ANIMATION` | `moxi_demo.showcase` | demo/support | examples, recipes, or validation support |
| `SHOWCASE_CORETEXT` | `moxi_demo.showcase` | demo/support | examples, recipes, or validation support |
| `SHOWCASE_HARFBUZZ` | `moxi_demo.showcase` | demo/support | examples, recipes, or validation support |
| `SHOWCASE_HELLO_COMPONENT` | `moxi_demo.showcase` | demo/support | examples, recipes, or validation support |
| `SHOWCASE_HELLO_WINDOW` | `moxi_demo.showcase` | demo/support | examples, recipes, or validation support |
| `SHOWCASE_METAL_SCENE` | `moxi_demo.showcase` | demo/support | examples, recipes, or validation support |
| `SHOWCASE_METAL_WINDOW` | `moxi_demo.showcase` | demo/support | examples, recipes, or validation support |
| `SHOWCASE_PLOT` | `moxi_demo.showcase` | demo/support | examples, recipes, or validation support |
| `SHOWCASE_PLOT_GALLERY` | `moxi_demo.showcase` | demo/support | examples, recipes, or validation support |
| `SHOWCASE_PLOT_SVG` | `moxi_demo.showcase` | demo/support | examples, recipes, or validation support |
| `SHOWCASE_CANVAS_ID` | `moxi_demo.showcase` | demo/support | examples, recipes, or validation support |
| `SHOWCASE_RESET_ID` | `moxi_demo.showcase` | demo/support | examples, recipes, or validation support |
| `SHOWCASE_PLOT_TOOLBAR_ID` | `moxi_demo.showcase` | demo/support | examples, recipes, or validation support |
| `SHOWCASE_PLOT_RESET_VIEW_ID` | `moxi_demo.showcase` | demo/support | examples, recipes, or validation support |
| `SHOWCASE_PLOT_CLEAR_SELECTION_ID` | `moxi_demo.showcase` | demo/support | examples, recipes, or validation support |
| `SHOWCASE_PLOT_TOGGLE_MARKS_ID` | `moxi_demo.showcase` | demo/support | examples, recipes, or validation support |
| `SHOWCASE_PLOT_STREAM_ID` | `moxi_demo.showcase` | demo/support | examples, recipes, or validation support |
| `SHOWCASE_PLOT_STATUS_ID` | `moxi_demo.showcase` | demo/support | examples, recipes, or validation support |
| `ShowcaseState` | `moxi_demo.showcase` | demo/support | examples, recipes, or validation support |
| `DEMO_CATEGORY_ALL` | `moxi_demo.demo_browser` | demo/support | examples, recipes, or validation support |
| `DEMO_CATEGORY_START` | `moxi_demo.demo_browser` | demo/support | examples, recipes, or validation support |
| `DEMO_CATEGORY_COMPONENTS` | `moxi_demo.demo_browser` | demo/support | examples, recipes, or validation support |
| `DEMO_CATEGORY_LAYOUT` | `moxi_demo.demo_browser` | demo/support | examples, recipes, or validation support |
| `DEMO_CATEGORY_PLOTTING` | `moxi_demo.demo_browser` | demo/support | examples, recipes, or validation support |
| `DEMO_CATEGORY_RENDERING` | `moxi_demo.demo_browser` | demo/support | examples, recipes, or validation support |
| `DEMO_CATEGORY_TEXT` | `moxi_demo.demo_browser` | demo/support | examples, recipes, or validation support |
| `DEMO_PAGE_STATIC` | `moxi_demo.demo_browser` | demo/support | examples, recipes, or validation support |
| `DEMO_PAGE_COUNTER` | `moxi_demo.demo_browser` | demo/support | examples, recipes, or validation support |
| `DEMO_PAGE_FORM` | `moxi_demo.demo_browser` | demo/support | examples, recipes, or validation support |
| `DEMO_PAGE_NESTED` | `moxi_demo.demo_browser` | demo/support | examples, recipes, or validation support |
| `DEMO_PAGE_COMPOSED` | `moxi_demo.demo_browser` | demo/support | examples, recipes, or validation support |
| `DEMO_PAGE_WX_STYLE` | `moxi_demo.demo_browser` | demo/support | examples, recipes, or validation support |
| `DEMO_PAGE_INTERACTION` | `moxi_demo.demo_browser` | demo/support | examples, recipes, or validation support |
| `DEMO_PAGE_ROW` | `moxi_demo.demo_browser` | demo/support | examples, recipes, or validation support |
| `DEMO_PAGE_ALIGNMENT` | `moxi_demo.demo_browser` | demo/support | examples, recipes, or validation support |
| `DEMO_PAGE_WRAPPED` | `moxi_demo.demo_browser` | demo/support | examples, recipes, or validation support |
| `DEMO_PAGE_SHOWCASE` | `moxi_demo.demo_browser` | demo/support | examples, recipes, or validation support |
| `DEMO_PAGE_FRACTAL` | `moxi_demo.demo_browser` | demo/support | examples, recipes, or validation support |
| `DEMO_PAGE_LIVE_SCRIPT` | `moxi_demo.demo_browser` | demo/support | examples, recipes, or validation support |
| `DEMO_PAGE_THEME_SHOWCASE` | `moxi_demo.demo_browser` | demo/support | examples, recipes, or validation support |
| `DEMO_PAGE_CAPABILITY_WALKTHROUGH` | `moxi_demo.demo_browser` | demo/support | examples, recipes, or validation support |
| `DEMO_HELLO_WINDOW_ID` | `moxi_demo.demo_browser` | demo/support | examples, recipes, or validation support |
| `DEMO_HELLO_COMPONENT_ID` | `moxi_demo.demo_browser` | demo/support | examples, recipes, or validation support |
| `DEMO_COUNTER_ID` | `moxi_demo.demo_browser` | demo/support | examples, recipes, or validation support |
| `DEMO_FORM_ID` | `moxi_demo.demo_browser` | demo/support | examples, recipes, or validation support |
| `DEMO_NESTED_ID` | `moxi_demo.demo_browser` | demo/support | examples, recipes, or validation support |
| `DEMO_COMPOSED_ID` | `moxi_demo.demo_browser` | demo/support | examples, recipes, or validation support |
| `DEMO_WX_STYLE_ID` | `moxi_demo.demo_browser` | demo/support | examples, recipes, or validation support |
| `DEMO_INTERACTION_ID` | `moxi_demo.demo_browser` | demo/support | examples, recipes, or validation support |
| `DEMO_ROW_ID` | `moxi_demo.demo_browser` | demo/support | examples, recipes, or validation support |
| `DEMO_ALIGNMENT_ID` | `moxi_demo.demo_browser` | demo/support | examples, recipes, or validation support |
| `DEMO_WRAPPED_ID` | `moxi_demo.demo_browser` | demo/support | examples, recipes, or validation support |
| `DEMO_ANIMATION_ID` | `moxi_demo.demo_browser` | demo/support | examples, recipes, or validation support |
| `DEMO_PLOT_ID` | `moxi_demo.demo_browser` | demo/support | examples, recipes, or validation support |
| `DEMO_PLOT_GALLERY_ID` | `moxi_demo.demo_browser` | demo/support | examples, recipes, or validation support |
| `DEMO_PLOT_SVG_ID` | `moxi_demo.demo_browser` | demo/support | examples, recipes, or validation support |
| `DEMO_FRACTAL_ID` | `moxi_demo.demo_browser` | demo/support | examples, recipes, or validation support |
| `DEMO_METAL_SCENE_ID` | `moxi_demo.demo_browser` | demo/support | examples, recipes, or validation support |
| `DEMO_METAL_WINDOW_ID` | `moxi_demo.demo_browser` | demo/support | examples, recipes, or validation support |
| `DEMO_CORETEXT_ID` | `moxi_demo.demo_browser` | demo/support | examples, recipes, or validation support |
| `DEMO_HARFBUZZ_ID` | `moxi_demo.demo_browser` | demo/support | examples, recipes, or validation support |
| `DEMO_LIVE_SCRIPT_ID` | `moxi_demo.demo_browser` | demo/support | examples, recipes, or validation support |
| `DEMO_THEME_SHOWCASE_ID` | `moxi_demo.demo_browser` | demo/support | examples, recipes, or validation support |
| `DEMO_CAPABILITY_WALKTHROUGH_ID` | `moxi_demo.demo_browser` | demo/support | examples, recipes, or validation support |
| `DEMO_TAB_OVERVIEW` | `moxi_demo.demo_browser` | demo/support | examples, recipes, or validation support |
| `DEMO_TAB_SOURCE` | `moxi_demo.demo_browser` | demo/support | examples, recipes, or validation support |
| `DEMO_TAB_DEMO` | `moxi_demo.demo_browser` | demo/support | examples, recipes, or validation support |
| `DEMO_SEARCH_ID` | `moxi_demo.demo_browser` | demo/support | examples, recipes, or validation support |
| `DEMO_CLEAR_SEARCH_ID` | `moxi_demo.demo_browser` | demo/support | examples, recipes, or validation support |
| `DEMO_ENTRY_VIEW_BASE` | `moxi_demo.demo_browser` | demo/support | examples, recipes, or validation support |
| `DEMO_CATEGORY_BUTTON_BASE` | `moxi_demo.demo_browser` | demo/support | examples, recipes, or validation support |
| `DEMO_COUNTER_ID_OFFSET` | `moxi_demo.demo_browser` | demo/support | examples, recipes, or validation support |
| `DEMO_WX_STYLE_ID_OFFSET` | `moxi_demo.demo_browser` | demo/support | examples, recipes, or validation support |
| `DEMO_INTERACTION_SLOT_ID` | `moxi_demo.demo_browser` | demo/support | examples, recipes, or validation support |
| `DEMO_INTERACTION_ID_OFFSET` | `moxi_demo.demo_browser` | demo/support | examples, recipes, or validation support |
| `DEMO_SHOWCASE_SLOT_ID` | `moxi_demo.demo_browser` | demo/support | examples, recipes, or validation support |
| `DEMO_FRACTAL_SLOT_ID` | `moxi_demo.demo_browser` | demo/support | examples, recipes, or validation support |
| `DEMO_SHOWCASE_ID_OFFSET` | `moxi_demo.demo_browser` | demo/support | examples, recipes, or validation support |
| `DEMO_FRACTAL_ID_OFFSET` | `moxi_demo.demo_browser` | demo/support | examples, recipes, or validation support |
| `DEMO_LIVE_SCRIPT_SLOT_ID` | `moxi_demo.demo_browser` | demo/support | examples, recipes, or validation support |
| `DEMO_LIVE_SCRIPT_ID_OFFSET` | `moxi_demo.demo_browser` | demo/support | examples, recipes, or validation support |
| `DEMO_THEME_SHOWCASE_SLOT_ID` | `moxi_demo.demo_browser` | demo/support | examples, recipes, or validation support |
| `DEMO_THEME_SHOWCASE_ID_OFFSET` | `moxi_demo.demo_browser` | demo/support | examples, recipes, or validation support |
| `DEMO_CAPABILITY_WALKTHROUGH_SLOT_ID` | `moxi_demo.demo_browser` | demo/support | examples, recipes, or validation support |
| `DEMO_CAPABILITY_WALKTHROUGH_ID_OFFSET` | `moxi_demo.demo_browser` | demo/support | examples, recipes, or validation support |
| `DEMO_HEADER_KICKER_ID` | `moxi_demo.demo_browser` | demo/support | examples, recipes, or validation support |
| `DEMO_PAGE_QUICKSTART_ID` | `moxi_demo.demo_browser` | demo/support | examples, recipes, or validation support |
| `DEMO_TAB_OVERVIEW_ID` | `moxi_demo.demo_browser` | demo/support | examples, recipes, or validation support |
| `DEMO_TAB_SOURCE_ID` | `moxi_demo.demo_browser` | demo/support | examples, recipes, or validation support |
| `DEMO_TAB_DEMO_ID` | `moxi_demo.demo_browser` | demo/support | examples, recipes, or validation support |
| `DEMO_RUN_BUTTON_ID` | `moxi_demo.demo_browser` | demo/support | examples, recipes, or validation support |
| `DEMO_RESET_BUTTON_ID` | `moxi_demo.demo_browser` | demo/support | examples, recipes, or validation support |
| `DEMO_NAV_PORTAL_ID` | `moxi_demo.demo_browser` | demo/support | examples, recipes, or validation support |
| `DEMO_NAV_TREE_ID` | `moxi_demo.demo_browser` | demo/support | examples, recipes, or validation support |
| `DEMO_CONTENT_PORTAL_ID` | `moxi_demo.demo_browser` | demo/support | examples, recipes, or validation support |
| `DEMO_SOURCE_TEXT_ID` | `moxi_demo.demo_browser` | demo/support | examples, recipes, or validation support |
| `DEMO_EMPTY_CLEAR_ID` | `moxi_demo.demo_browser` | demo/support | examples, recipes, or validation support |
| `DEMO_STORY_SPLIT_ID` | `moxi_demo.demo_browser` | demo/support | examples, recipes, or validation support |
| `DEMO_STORY_CODE_TEXT_ID` | `moxi_demo.demo_browser` | demo/support | examples, recipes, or validation support |
| `DemoEntry` | `moxi_demo.demo_browser` | demo/support | examples, recipes, or validation support |
| `DemoCatalog` | `moxi_demo.demo_browser` | demo/support | examples, recipes, or validation support |
| `DemoBrowserState` | `moxi_demo.demo_browser` | demo/support | examples, recipes, or validation support |
| `demo_category_name` | `moxi_demo.demo_browser` | demo/support | examples, recipes, or validation support |
| `demo_category_short_name` | `moxi_demo.demo_browser` | demo/support | examples, recipes, or validation support |
| `DEMO_WALKTHROUGH_EVENT` | `moxi_demo.demo_walkthrough` | demo/support | examples, recipes, or validation support |
| `DEMO_WALKTHROUGH_APPROVAL` | `moxi_demo.demo_walkthrough` | demo/support | examples, recipes, or validation support |
| `DemoWalkthroughAction` | `moxi_demo.demo_walkthrough` | demo/support | examples, recipes, or validation support |
| `DemoWalkthroughHandler` | `moxi_demo.demo_walkthrough` | demo/support | examples, recipes, or validation support |
| `DemoWalkthroughDriver` | `moxi_demo.demo_walkthrough` | demo/support | examples, recipes, or validation support |
