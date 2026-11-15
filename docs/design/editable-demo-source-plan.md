# Editable Demo Source and In-Browser Live Re-Runs Plan

**Status:** Proposed architectural plan for Moxi Playground / Demo Browser.  
**References:**
- `docs/demo-browser.md` (Moxi Playground architecture and Storybook-style workbench)
- `docs/design/ui-architecture-evolution-plan.md` (UI architecture evolution plan)
- `docs/authoring/ui-ingredients.md` (Taxonomy of GUI library ingredients)
- `examples/demo_browser.mojo` & `src/moxi_demo/demo_browser.mojo` (Playground host and browser state)
- `examples/editable_showcase.mojo` & `tests/live_reload.mojo` (Existing live-reload ABI)
- `native/macos_window.m` & `src/moxi/macos.mojo` (`MacOSLiveScript`, `moxi_dev_build_live_script`)

---

## 1. Executive Summary & Problem Context

The Moxi Playground (`pixi run demo` / `demo-browser`) provides a wxPython-inspired learning workbench:
- A searchable catalog rail groups runnable examples by domain.
- The work area provides `Overview`, `Source`, and `Demo` tabs.
- Live pages mount in-process inside a Storybook-style split workbench: the mounted `LIVE PREVIEW` sits beside an `EXAMPLE SOURCE` code panel showing the lesson's authoring code.

Currently, both the dedicated `Source` tab (`DEMO_SOURCE_TEXT_ID`) and the split Storybook `EXAMPLE SOURCE` panel (`DEMO_STORY_CODE_TEXT_ID`) use read-only multiline widgets (`root.set_enabled(..., False)`). 

While Moxi already implements an ahead-of-time live reload pipeline for `examples/editable_showcase.mojo` using filesystem mtime watching (`MacOSFileWatcher` + `MacOSLiveScript`), exploring and modifying code currently forces developers out of the Playground into an external editor. 

As noted in `docs/demo-browser.md`:
> *"The editable page adds a real source-watch/build/load loop for an explicit ABI; a full in-browser source editor and modified-source persistence remain follow-up work."*

This plan details the design and staged delivery to make the source in demos editable for **live-ish in-browser re-runs**, enabling interactive exploration, immediate experimentation, and robust error recovery without leaving the running application.

---

## 2. Core Architectural Challenges & Trade-Offs

### 2.1 The "Live-ish" Reality: Ahead-of-Time Compilation in Mojo
Unlike dynamic runtimes (JavaScript or Python) that support instant in-process `eval()`, Mojo is an ahead-of-time compiled, LLVM-backed language with strict value semantics and type checking:
- Compiling a Mojo shared library via `mojo build --emit shared-lib` requires **~1.0 to 2.5 seconds** (parsing, AST analysis, MLIR lowerings, LLVM code generation, and linking).
- Compiling synchronously on every keystroke is completely infeasible: it would saturate CPU cores and freeze the 60fps AppKit/Moxi rendering loop.
- **Decision:** Re-runs are designed to be **"live-ish"**:
  1. Triggered explicitly on keyboard shortcut (`Cmd+Enter` / `Ctrl+Enter`) or a visible **"Run / Rebuild"** button.
  2. Optionally triggered on debounced editing pause (e.g., 1.5 seconds after the user stops typing).

### 2.2 Main-Thread Responsiveness vs. Compilation Latency
Currently, `moxi_dev_build_live_script` in `native/macos_window.m` uses synchronous process execution:
```objc
[process waitUntilExit];
```
If called on the main thread, this stalls AppKit for >1 second, dropping between 60 and 150 frames and preventing window resizing, portal scrolling, or cancelation.

- **Decision:** Decouple compilation from the main thread:
  - Spawn `NSTask` inside a background GCD queue (`dispatch_async`).
  - Capture compilation status and `stderr` diagnostics asynchronously.
  - Dispatch a completion event back into Moxi's native event queue so the browser updates state and hot-swaps dynamically without dropping a single frame.

### 2.3 C-ABI Dynamic Swapping vs. Retained Mojo Component Trees
Moxi examples fall into two distinct architectural categories:

1. **Canvas / Scene-Backed Demos** (e.g. `EditableShowcase`, `Fractal`, Plot Gallery, Metal scenes):
   - These declare a real `Canvas` node in the retained view tree.
   - The scene generation logic is cleanly isolated behind the C ABI:
     ```mojo
     @export
     def moxi_live_frame(x: Float32, y: Float32, width: Float32, height: Float32) abi("C") -> Int32:
     ```
   - These can be dynamically reloaded via `dlopen`/`dlsym` and hot-swapped into the running canvas immediately.

2. **Retained Declarative Components** (e.g. `Counter`, `Form`, `Workspace`, `Editors`):
   - These are parameterized Mojo generic structs (`HandlerHost[T]`, `ComponentSlot[T]`) compiled statically into the host binary.
   - Mojo does not currently support cross-dylib dynamic reflection of generic traits or arbitrary struct layouts.
   - **Decision:** Phase the execution strategy:
     - **Phase A (Native In-Process Hot-Swap):** Generalize the `moxi_live_frame` C ABI across all canvas/scene-oriented demos.
     - **Phase B (Subprocess Runner / Ephemeral Sandbox):** For full standalone scripts and authoring models, write the draft to a temporary file and launch it in an embedded child process or companion preview window via the existing `MacOSDemoRunner` (`moxi_demo_launch`).

---

## 3. Detailed Component Design

### 3.1 In-Browser Editor State (`DemoEditorBuffer`)

Extend `DemoBrowserState` with persistent editing buffers so switching tabs or catalog entries does not destroy in-progress edits:

```mojo
struct DemoEditorBuffer:
    var original_text: String
    var draft: MultilineTextState
    var dirty: Bool
    var last_build_status: String
    var last_error_log: String
    var is_building: Bool
```

#### Key Capabilities:
- **State Preservation:** Each catalog entry retains its `draft` state while the browser is open.
- **Dirty Indication:** The editor header displays an indicator (e.g. `Source · examples/editable_showcase.mojo [Modified]`).
- **Revert to Clean:** A dedicated **"Revert"** button resets `draft` back to `original_text`.
- **Keyboard Shortcuts:**
  - `Cmd+Enter`: Trigger immediate compile & re-run.
  - `Cmd+R` (when focused in editor): Revert draft to clean.
  - Standard editing: Cursor navigation, newline insertion, text selection, and clipboard integration (`Copy`, `Cut`, `Paste`).

### 3.2 Asynchronous Compilation Engine (`native/macos_window.m`)

Refactor the native live compilation bridge to support non-blocking asynchronous compilation and diagnostic capture:

```objc
typedef void (^MoxiLiveBuildCallback)(int success, const char *outputPath, const char *diagnostics);

int moxi_dev_build_live_script_async(
    const char *sourceCodeText,
    const char *outputDylibPath,
    uint64_t buildId,
    MoxiLiveBuildCallback completion
);
```

#### Lifecycle & Sandboxing:
1. Write the edited text buffer to a unique scratch file in `/tmp/moxi_playground_<entry_id>_<build_id>.mojo`.
2. Invoke `mojo build --emit shared-lib -I src -I examples ... -o /tmp/moxi_playground_<entry_id>_<build_id>.dylib`.
3. Pipe `stderr` to an in-memory buffer.
4. On exit:
   - If `status == 0` and the `.dylib` exists: invoke completion with `success = 1`.
   - If `status != 0`: invoke completion with `success = 0` and the captured compiler diagnostics.
5. Post a synthetic `Event` into the AppKit event loop with target `DEMO_LIVE_BUILD_COMPLETE_ID`.

### 3.3 Dynamic Swapping & Error Resilience

When the completion event arrives in `DemoBrowserState.update()`:

- **On Compilation Success:**
  1. Call `moxi_dev_load_live_script(dylib_path)`.
  2. Atomically swap `moxi_live_frame` function pointer.
  3. Update status message: `"Live build succeeded · running in this window."`
  4. Trigger view invalidation (`app.rebuild()`) so the canvas repaints with the new module.
- **On Compilation Failure (Syntax / Type Errors):**
  1. **Preserve running module:** Keep the previously loaded `.dylib` active so the canvas never blanks or crashes.
  2. Expand the **Diagnostics Drawer** below the code editor displaying the exact compiler error lines.
  3. Update status message: `"Compilation failed · previous build retained."`

---

## 4. UI Layout & Storybook Split Integration

The Storybook-style split layout (`build_demo` in `src/moxi_demo/demo_browser.mojo`) will be refined to accommodate editor controls and diagnostics:

```
+-----------------------------------------------------------------------------+
| [Browse Examples]  | Search: [               ] | [Overview] [Source] [*Demo*] |
+--------------------+--------------------------------------------------------+
| Catalog Items      | LIVE PREVIEW                | EXAMPLE SOURCE (Editable)  |
| - Hello Window     | +-------------------------+ | [Run (Cmd+Enter)] [Revert] |
| - Counter          | |                         | | +------------------------+ |
| - Form             | |   Mounted Live Scene    | | | 1: def scene(bounds):  | |
| - Editable Showcase| |   or Component Canvas   | | | 2:     var scene = ... | |
| - Plot Gallery     | |                         | | | 3:     return scene    | |
| - Interaction Lab  | +-------------------------+ | +------------------------+ |
|                    | Status: Running rev #3      | Diagnostics (collapsible): |
|                    |                             | [No errors · build: 1.2s]  |
+-----------------------------------------------------------------------------+
```

---

## 5. Phased Implementation Sequence

```
Phase 1: Multiline Text Editing in Demo Browser
  ├── Enable MultilineTextState for DEMO_SOURCE_TEXT_ID and DEMO_STORY_CODE_TEXT_ID
  ├── Wire keyboard events (character entry, enter, navigation, selection)
  └── Implement copy/cut/paste and "Revert to Original" action

Phase 2: Asynchronous Native Compiler Bridge
  ├── Implement non-blocking background compilation in native/macos_window.m
  ├── Capture stderr diagnostics and execution exit codes
  └── Post completion events into Moxi event queue

Phase 3: Scratch Buffer & Hot-Swap Lifecycle
  ├── Temporary file management in /tmp/ for edited buffers
  ├── Hook MacOSLiveScript to dlopen and atomically hot-swap moxi_live_frame
  └── Add build generation counters and cache cleanup

Phase 4: Compiler Diagnostics Drawer & UI Polish
  ├── Add collapsible diagnostics panel under the editor
  ├── Highlight compile errors and warnings
  └── Display build progress spinner / latency indicator

Phase 5: Automated Contract & Regression Tests
  ├── Headless test for in-browser edit -> async build -> reload loop
  ├── Verification that syntax errors preserve the previous valid scene
  └── CapabilityBus audit verification during live editing
```

---

## 6. Acceptance Criteria & Verification Signals

1. **Responsiveness Gate:** Initiating a background compile never drops frames or blocks pointer/wheel handling on the main UI loop.
2. **Safety Gate:** Introducing a deliberate syntax or type error in the editor never crashes the browser; the existing module remains running and the error is displayed in the diagnostics panel.
3. **Identity Gate:** Editing and reloading a live scene preserves the browser shell, catalog scroll position, and search filter without recreating the native window.
4. **Revert Gate:** Clicking "Revert" restores the exact checked-in example source code and clean build status.
5. **Headless Verification:** Add a companion CLI test (`pixi run live-editor-check`) that simulates buffer modification, asynchronous compilation, and ABI frame verification without requiring manual GUI interaction.
