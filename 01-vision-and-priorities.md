# Moxi UI Polish: Vision & Priorities

Moxi 0.5 has achieved the most difficult part of building a native declarative UI framework: a functional reconciliation loop, a working Metal renderer, native event routing (including IME), and cross-platform architectural groundwork.

The next evolutionary step is turning "ugly but correct" into an opinionated, beautiful, and developer-friendly UI layer. We will tackle this by borrowing proven concepts from the modern web ecosystem (specifically shadcn/ui and Storybook) and adapting them to Moxi's retained-mode, Mojo-based architecture.

## Priority Checklist

Given the current state (v0.5), here is the highest-ROI path forward:

1. **Design Tokens & A Single Coherent Theme**
   - **Why:** Transforms the library from "ugly" to "opinionated" with a single PR. Ensures every control inherits good defaults.
   - **Action:** Create a `Theme` struct (colors, typography scales, spacing, radii) and inject it into the environment or pass it down.
2. **README Polish**
   - **Why:** Adoption hinges on first impressions.
   - **Action:** Add a 10-second screen recording/GIF showing a working interaction (e.g., clicking a counter or text input) on macOS.
3. **Visual Snapshot Testing (Headless)**
   - **Why:** You already have deterministic headless output (`TestRenderer`). Wiring this up ensures style tweaks don't cause visual regressions.
   - **Action:** Integrate a CI step that diffs snapshots of each component state against a known baseline.
4. **"shadcn-style" Recipes / Builders**
   - **Why:** Developers want composable, copy-pasteable patterns above raw `ViewNode`s.
   - **Action:** Create semantic builder functions like `card(title, body)` or `button_destructive("Delete")` that apply the tokens for you.
5. **Storybook-style "All States" View**
   - **Why:** Speeds up theme development and QA.
   - **Action:** Extend the `demo_browser` to display every control (button, input, etc.) in every possible state (default, hover, pressed, focused, disabled) on a single page.
