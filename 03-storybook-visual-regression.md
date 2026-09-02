# Storybook & Visual Regression

While the Moxi Demo Browser already functions as a rudimentary Storybook, it currently shows live components in a single state. To rapidly iterate on themes and catch visual bugs, we need to adapt two key concepts from the Storybook ecosystem.

## 1. The "All States" Showcase

Extend the `demo_browser` (or create a dedicated `theme_browser.mojo`) to render an exhaustive catalog of every component in every visual state simultaneously.

**Example layout:**
- **Row 1 (Button):** [Default] [Hovered] [Pressed] [Focused] [Disabled]
- **Row 2 (Input):**  [Empty] [Filled] [Focused] [Error] [Disabled]
- **Row 3 (Checkbox):** [Unchecked] [Checked] [Focused] [Disabled]

**Why this is crucial:**
When you tweak `theme.primary` or change a border radius, you need to verify instantly that you haven't broken the contrast ratio on disabled buttons or made focused inputs unreadable. A side-by-side visual catalog makes this verification instantaneous.

## 2. Headless Screenshot Diffing

Moxi already has `TestRenderer` and deterministic headless output capabilities. We can use this to create a robust visual regression pipeline, similar to Chromatic for Storybook.

**Workflow:**
1. **Generate Baselines:** Run the "All States" catalog through `TestRenderer` and save the output as baseline PNG/SVG images.
2. **CI Integration:** In `.github/workflows/ci.yml`, run the test suite to generate new snapshots for every PR.
3. **Diffing:** Compare the new snapshots against the baselines. Fail the build if the pixel diff exceeds a small threshold (to catch unintended regressions) and require manual approval to update baselines (when styles change intentionally).

**Why this is crucial:**
It provides confidence. Because Moxi controls its own rendering pipeline down to the Metal pixels (or software paths), you don't have to rely on a browser's quirks. Deterministic headless output means snapshot tests will be incredibly reliable.
