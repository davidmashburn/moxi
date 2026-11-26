# Style, alignment and scrolling defaults

Implementation baseline is main at 5d85208, inspected November 22, 2026.

## Intended behavior

A new view should have readable body text, quiet ordinary buttons and recognizable primary actions. Construct the default styles from the same semantic tokens used by the named palettes. Test an ordinary control alongside a primary and a destructive action in dark and light themes.

A root theme supplies defaults to existing and future controls. The nearest explicitly themed container supplies subtree defaults. A local appearance choice survives a theme change. Preserve recipe identity so changing a palette updates the colors without erasing distinctions among actions. Keep box decoration local to its owner. A global selector grammar is outside this change.

Center content within its allocated space. Check actual text and control bounds and exercise compact and expanded layouts so centering does not clip longer content. Identify the host or layout owner that introduces redundant scroll regions. Give one viewport responsibility for a single continuous document while preserving independent panes, keyboard access and wheel scrolling to the end.

## Verification

Exercise theme selection, insertion order, nested scopes, local overrides and recipe identity. Exercise the affected centered controls and scrolling surface at two sizes, including an overflow case. Inspect rendered output and record the tested host and any remaining limits. Keep the implementation on main and planning history on this branch.

## Delivered November 22, 2026

The root and nearest container now supply theme defaults to descendants, including controls added later. Recipes retain their roles as the palette changes. An explicit property on a control takes precedence for that property. An explicitly supplied complete style owns the entire control appearance. The authoring and lower-level APIs both expose this model. [Usage and examples](https://github.com/davidmashburn/moxi/blob/135c46d/README.md)

The alignment, scroll ownership and viewport clipping changes shipped in [135c46d](https://github.com/davidmashburn/moxi/commit/135c46d). The [Fractal follow-up](https://github.com/davidmashburn/moxi/commit/e7892c3) leaves space for the thumb beside the canvas. AppKit capture and routed-scroll tests cover this path. Browser shells were inspected at source. The November 23 [benchmark reference](https://github.com/davidmashburn/moxi/commit/045f9a5) records the resulting default scene.

## Style management patterns compared

November 26, 2026. The native Moxi examples below describe main at `df63f5c`. A style system answers three separate questions. Where does the author write a rule? Which controls does it reach? When two choices affect the same property, which one wins?

| Pattern | How a choice reaches a control | Where it works well and what it costs |
| --- | --- | --- |
| CSS selectors and cascade | A selector such as `.inspector button` matches elements. The cascade resolves competing declarations per property. Separately, properties such as text color can inherit from the parent. | One rule can restyle an existing document. Moving a control under a different ancestor can change which rules match. [CSS cascade and inheritance](https://www.w3.org/TR/css-cascade-5/) |
| Component-colocated CSS and CSS Modules | Marko bundles a template’s ordinary style block as global CSS. Its CSS Modules option gives classes local names that the template applies explicitly. A descendant selector inside a module can still reach nested elements. | Colocation makes ownership easy to find. Class scoping prevents name collisions. Neither alone supplies a subtree theme. [Marko styling](https://markojs.com/docs/guide/styling) |
| Inherited design tokens | A web component can consume an inherited CSS custom property such as `--accent`. An ancestor can replace that value for a region. | A nested palette can change one value and inherit the rest. Components need to agree on the meaning of the token. [CSS custom properties](https://www.w3.org/TR/css-variables-1/) |
| Typed subtree themes | A component reads the nearest theme provider. In Moxi, a root or container supplies a complete `Theme`, including control defaults. Flutter also supports extending the parent theme when creating a local one. | Fits a dark inspector inside a light application. A complete nested Moxi theme owns its defaults when the outer theme changes. [Moxi usage](https://github.com/davidmashburn/moxi/blob/df63f5c/README.md#styling-a-view-tree) · [Flutter themes](https://docs.flutter.dev/cookbook/design/themes) |
| Explicit component parameters | A caller passes a style, color, or role to a component. The component decides which internal element consumes it. Deep overrides need forwarding through intermediate components. | Good for a deliberate per-instance choice. Passing the same palette through every layer adds work. [React props and context](https://react.dev/learn/passing-data-deeply-with-context) |
| Semantic recipes | A Moxi control retains a role such as primary or destructive. The role resolves against the active theme, including after a theme change. | A Save button keeps its prominence in light and dark regions. This depends on the author choosing the right role at the declaration. [Moxi recipes](https://github.com/davidmashburn/moxi/blob/df63f5c/src/moxi/recipes.mojo) |
| Per-element utilities and overrides | Tailwind classes select individual CSS declarations at the element. Moxi’s typed setters pin one field directly on a node. | Both make a one-off exception easy to find. In Moxi an explicit corner radius survives retheming while the fill still follows the palette. Repeated exceptions are candidates for a shared recipe. [Tailwind utilities](https://tailwindcss.com/docs/styling-with-utility-classes) · [Moxi override tests](https://github.com/davidmashburn/moxi/blob/df63f5c/tests/style_theme.mojo) |
| Complete style values | Moxi’s `set_style` assigns the whole appearance to one node. Demo helpers also construct complete styles from fixed dark tokens. | Useful for deliberately fixed presentation. Even a field that happens to equal the current default is now owned locally. This can explain why controls on the same screen respond differently to a theme change. [Demo helpers](https://github.com/davidmashburn/moxi/blob/df63f5c/src/moxi_demo/demo_style.mojo) · [Explicit style contract](https://github.com/davidmashburn/moxi/blob/df63f5c/tests/style_theme.mojo) |

### Applying the comparison to Moxi

Use a light root theme, put a dark theme on an inspector, declare Save as primary, and give Save one explicit corner radius. A button added to the inspector tomorrow picks up the dark defaults. Changing the root palette updates unscoped siblings. Clearing the inspector scope makes Save use the enclosing primary colors again, while keeping its radius. Decorating the inspector with a full panel style changes the panel’s own paint. Its child buttons still resolve their own styles. Keyed authoring scopes group identities. A theme on the host, view container, or mounted component controls appearance. Browser-hosted examples can separately use document CSS for their HTML controls. [Native contract](https://github.com/davidmashburn/moxi/blob/df63f5c/tests/style_theme.mojo) · [Authoring API](https://github.com/davidmashburn/moxi/blob/df63f5c/README.md#styling-a-view-tree) · [Oscillator stylesheet](https://github.com/davidmashburn/moxi/blob/df63f5c/examples/oscillator/style.css)

Keep this provider-and-recipe model as the native default. The application chooses its palette, the inspector owns its local theme, and Save declares its role. A repeated need to change one token across a subtree while tracking later parent changes would justify a typed partial-theme override. A requirement to restyle arbitrary third-party markup without changing its source would make selectors worth reconsidering.

Centering and scrolling each need an identifiable layout owner. A toolbar places its buttons in the available row. Each button aligns the label within its own bounds. A document has one vertical scrolling viewport. An independently navigable list or canvas can own another when its content actually overflows. Changing the palette should preserve those choices.

Both focused Mojo contracts, `tests/style_theme.mojo` and `tests/tokens_recipes.mojo`, passed against the inspected main revision. This comparison uses implementation and framework documentation. Visual appearance, platform parity and author preference were outside the checks run for this entry.
