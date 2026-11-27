# Browser explorer design review

Two interactive demos expose the same first-use problem. The graph visitor wants to find a node, and the density visitor wants to inspect a cell. Both pages originally put runtime or maintenance controls ahead of those actions. This pass covers those two demos.

## Rubric results

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
