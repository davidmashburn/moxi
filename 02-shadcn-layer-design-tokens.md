# The shadcn Layer: Design Tokens & Recipes

The insight behind `shadcn/ui` isn't the components themselves—it's the **layering** and **ownership**. 
1. **Design tokens** define the visual language (colors, spacing, typography).
2. **Primitive components** consume those tokens.
3. **Users own the code** for the components rather than installing them as an opaque dependency.

## 1. The `Theme` Struct (Design Tokens)

Instead of manually setting fill, text color, font size, and corner radius on every node, Moxi needs a coherent `Theme`.

```mojo
struct Theme:
    # Palette
    var background: Color
    var surface: Color
    var primary: Color
    var text: Color
    var text_muted: Color
    var border: Color

    # Typography (Size & Weight)
    var text_sm: Int
    var text_base: Int
    var text_lg: Int

    # Geometry
    var radius_sm: Float32
    var radius_md: Float32
    var spacing_sm: Float32
    var spacing_md: Float32
```

**Implementation details:**
- Dark/Light mode becomes a simple swap of the active `Theme` struct, rather than a per-node style recalculation.
- Consider importing tokens from a JSON file (Figma tokens) to future-proof the styling system and allow designers to contribute.

## 2. Recipes (Pre-styled Builders)

Once we have a theme, we can provide "recipes". These are simple builder functions that return a `ViewNode` pre-populated with the correct styles and layout properties.

```mojo
def primary_button(label: String, action: String, theme: Theme) -> ViewNode:
    return button(label, action)
        .set_fill(theme.primary)
        .set_text_color(theme.background)
        .set_corner_radius(theme.radius_md)
        .set_padding(theme.spacing_md)
```

**Why this works for Moxi:**
It gives users a fluent, easy-to-read API for assembling UIs, while separating the *behavior* (focus management, keyboard handling, semantics handled by `button()` and `ControlState`) from the *styling* (handled by the recipe).

## 3. Tailwind-ish Fluent API (Optional)

For quick prototyping, a fluent styling API directly on `ViewNode` can be very ergonomic.

```mojo
# Instead of separate style structs:
label("Hello")
    .padding(8)
    .bg(theme.surface)
    .rounded(4)
```
