# Style, alignment and scrolling defaults

Implementation baseline is main at 5d85208, inspected November 22, 2026.

## Intended behavior

A new view should have readable body text, quiet ordinary buttons and recognizable primary actions. Construct the default styles from the same semantic tokens used by the named palettes. Test an ordinary control alongside a primary and a destructive action in dark and light themes.

A root theme supplies defaults to existing and future controls. The nearest explicitly themed container supplies subtree defaults. A local appearance choice survives a theme change. Preserve recipe identity so changing a palette updates the colors without erasing distinctions among actions. Keep box decoration local to its owner. A global selector grammar is outside this change.

Center content within its allocated space. Check actual text and control bounds and exercise compact and expanded layouts so centering does not clip longer content. Identify the host or layout owner that introduces redundant scroll regions. Give one viewport responsibility for a single continuous document while preserving independent panes, keyboard access and wheel scrolling to the end.

## Verification

Exercise theme selection, insertion order, nested scopes, local overrides and recipe identity. Exercise the affected centered controls and scrolling surface at two sizes, including an overflow case. Inspect rendered output and record the tested host and any remaining limits. Keep the implementation on main and planning history on this branch.
