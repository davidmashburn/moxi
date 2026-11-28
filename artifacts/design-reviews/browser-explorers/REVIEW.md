# Browser explorer design review

Two interactive demos expose the same first-use problem. The graph visitor wants to find a node, and the density visitor wants to inspect a cell. Both pages originally put runtime or maintenance controls ahead of those actions. This pass covers those two demos.

## Current design

The first pass earned too high a hierarchy score. Moving the canvas closer to the top helped, but Graph A still had two ways to search and a toolbar inside the plot. The revised rubric counts controls drawn by Moxi as well as those supplied by HTML. The first-use gates are to load both panes, select a node or cell directly, and reach search or exact records when needed. Both demos passed these gates in Chrome.

| Criterion (0–3) | Force-directed graph | Density explorer |
| --- | --- | --- |
| Hierarchy | **3.** The previous page exposed nine native buttons per graph plus six HTML buttons across the page. The initial view now has zero push buttons and one task menu per graph. Choosing Find a node reveals one field and one button. | **3.** Two record buttons and seven transport buttons previously appeared before any cell selection. The initial page now has zero push buttons. Picking a cell reveals the record action in that pane. |
| Legibility | **3 in tested states.** The phone plot uses more of its width, leaving space between the four clusters. The node and link counts give way to the selected node’s ID and degree. | **3 in tested states.** The grid shows its per-view count range. Darker cells have higher counts in that view. Selecting a cell replaces the previously clipped instructions with a short count summary. Color intensity is relative to each view’s range. |
| Layout | **3.** At 390 px the graph surface starts at y=196. Every Search, Simulation and Display control fits inside the pane. | **3.** At 390 px the surface starts at y=260. Technical settings sit below the plots, and the page fits without horizontal scrolling. |
| Interaction | **3.** A node can be selected directly. Typing node-12 and pressing Enter selects it. Simulation, disposal and recreation remain reachable. | **2.** Exact records appear after selection, and network loss, retry and restart worked. The grid accepts pointer selection. Its host still has no keyboard action for choosing a cell. |

### Compare the previous pass with this revision

| Viewport | Force-directed graph | Density explorer |
| --- | --- | --- |
| 390 × 850 | [Previous](after-browser-moxi-390.png) · [Current](focused-browser-moxi-390.png) | [Previous](after-server-backed-views-390.png) · [Current](focused-server-backed-views-390.png) |
| 1280 × 850 | [Previous](after-browser-moxi-1280.png) · [Current](focused-browser-moxi-1280.png) | [Previous](after-server-backed-views-1280.png) · [Current](focused-server-backed-views-1280.png) |

Phone interaction states show the [graph search result](focused-graph-search.png) and the [selected density cell with its record action](focused-density-selection.png).

### Verification of the current revision

Captured November 28, 2026 at 03:55 UTC. The working tree based on 60958b2 contained the graph tool modes and density presentation in this revision. Both Wasm modules were rebuilt from these sources. Chrome 158.0.8127.37 opened the graph at `http://127.0.0.1:18974/experiments/browser-moxi/` and the density view at `http://127.0.0.1:18975/`, using the repository’s 36-node graph and synthetic one-million-point dataset.

| Scenario | Expected and observed | Outcome |
| --- | --- | --- |
| Load, select a graph node and change tool modes at both screenshot widths | Both plots loaded without page overflow. Overview exposed no native action buttons. Simulation exposed four, Display three, and Find exposed a text field and one button. The native owner selected node-0 by pointer and node-12 by typed search. | Pass |
| Select a cell in A while B remains untouched | Only A offered exact records. The response contained 32 records. Restarting A cleared the action. | Pass |
| Keyboard focus, lifecycle, recovery and reload | Surface focus was visible. Enter opened the lifecycle disclosure. A could be disposed and recreated while B stayed live. Density disconnected and recovered. Reload restored two panes. | Pass |
| Repository browser workflows at 1440 × 1100 | Chrome completed 6,515 graph parity comparisons and eight route/delay runs for density. The WebKit 27.2 graph replay passed its twelve scenarios, including the forced unsupported state. All 11 density server tests and the transport adapter checks passed. | Pass |
| Firefox graph replay | The installed macOS Firefox exited before navigation because it could not find its temporary profile. | Blocked |

Physical devices, screen readers and independently observed first-time visitors were outside this pass.

## First pass

Scores use the [demo design rubric](../../../.agents/skills/review-demo-design/SKILL.md). A score of 3 means the criterion passed in the tested states. The density demo initially scored 0 for interaction because the local server refused its memory allocator module. Its visual baseline below was captured immediately after adding that missing route.

| Criterion | Force-directed graph, before → after | Density explorer, before → after |
| --- | --- | --- |
| Hierarchy | 1 → 3. On a 390 px screen the surface moved from y=511 to y=236. Search now sits beside the graph title. | 1 → 3. The surface moved from y=485 to y=277. Each pane pairs its title with the record request. |
| Legibility | 1 → 2. The initial node labels obscured clusters. Selecting a node now reveals its label, and “Show labels” restores the full set. The narrow frame still clips long status text. | 2 → 2. The revision hash moved into dataset details. The native narrow-view selection summary still clips. |
| Layout | 1 → 2. The compact view fits the graph and offers an expanded, scrollable toolbar. Reaching every native control on a phone still takes an extra action. | 1 → 3 for the page layout. Desktop grids now align at the top. Delay and heading stack on phones, and neither viewport has page-level horizontal overflow. |
| Interaction | 2 → 3. Search accepts Enter and the surface shows keyboard focus. Dispose and Recreate leave the other instance live. Baseline recovery was not replayed. | 0 → 3. The page loads both instances, returns exact records, displays connection failure and recovers on retry. |

## Screenshot pairs

| Viewport | Graph | Density |
| --- | --- | --- |
| 390 × 850 | [Before](before-browser-moxi-390.png) · [After](after-browser-moxi-390.png) | [Before](before-server-backed-views-390.png) · [After](after-server-backed-views-390.png) |
| 1280 × 850 | [Before](before-browser-moxi-1280.png) · [After](after-browser-moxi-1280.png) | [Before](before-server-backed-views-1280.png) · [After](after-server-backed-views-1280.png) |

## Verification

Local checkout at d0f1390 with the browser demo changes in the working tree, November 27, 2026. The documented loopback servers ran on ports 18974 (graph) and 18975 (density). Headless Chrome 158.0.8127.37 used the existing experimental Wasm binaries, sample 36-node graph and synthetic million-point dataset.

| Scenario | Expected and observed | Result |
| --- | --- | --- |
| Enter node-12 in Graph A and press Enter | The Mojo owner selected index 12 at both viewport widths. | Pass |
| Expand the phone graph controls | The frame became horizontally scrollable within the page. | Pass |
| Select a density cell and request exact records | The owner reported 32 exact records at both widths. | Pass |
| Disconnect and retry the density view | The adapter entered its error state and returned to ready at both widths. | Pass |
| Focus the surface, dispose A, recreate A, reload | Focus styling was visible to keyboard users. A disappeared, B survived, A remounted, and both views loaded on refresh in each demo. | Pass |

Both repository browser workflows passed at 1440 × 1100 with generated evidence redirected to temporary directories. Graph verification included 6,515 native comparisons. All 11 density server tests passed. Physical touch, assistive technology, other browsers and clean Wasm builds were outside this pass.

After integration onto 8c0a4e0, the focused browser scenarios above passed again at both widths using the same Wasm binaries. The After images are from that run. All 11 density tests also passed on the integrated tree. The longer browser workflows were run on the earlier checkout.
