# Phrase Studio

Build a movement score from motions, ordered sequences and parallel groups. Rename the three types, change sequence order, set a group capacity and scale motion beats into ticks. The editor previews candidate duration and checks every existing slot before replacing the schema. The browser stores the active schema, score, cursor and sketch together. Undo history lasts for the current page session. Use one tab per score.

From the repository root, run the loopback host and open its printed URL.

```sh
PYTHONPATH=python python3 examples/invent-notation/app.py --port 8763
```

For persistence across host launches, reopen `http://127.0.0.1:8763` in the same browser profile. Browser storage belongs to the full origin (scheme, hostname and port): `localhost` and `127.0.0.1` are different origins. Choose another fixed port if needed and keep using it. `--port 0` chooses an ephemeral port and does not guarantee the same origin on the next launch. Clearing browser data or using a temporary/private profile also removes or isolates saved scores.

If a saved score is malformed or incompatible, the editor shows the starter score and offers its original source as a download. Before selection, edits or undo can replace the active save, the exact unreadable source string must be retained in a separate browser recovery archive. Recovery downloads remain available after edits and reloads, including earlier retained sources. A failed archive write blocks replacement; a failed active-score write leaves the displayed document and undo history unchanged. If storage could not be read at startup, saving stays blocked until a successful reload. Recovery copies use the same origin and browser storage, so download them for safekeeping; automatic format migration and importing recovered files are not implemented.

The root is a sequence. Select a container and use the three insertion buttons to compose its children. Up and Down select adjacent slots in document order. Select a motion to change its duration. A group starts all children together and lasts until the longest child finishes. Each active motion contributes a half-sine rotation with a peak of 60 degrees. The slider samples their sum. Formalizing the joint attaches a length-editable arm to the sketch. Undo restores its previous state.

The browser owns the notation grammar, selection and motion evaluator. The loopback Python host passes the sampled angle series through the checkout’s public Moxi `PlotSpec.add_line`, `plot` and `Figure.to_svg` APIs for the live curve.

## Reproduce the checks

Use Node for core tests. The browser replay needs desktop Google Chrome and the Python Playwright package. It starts its own host on an ephemeral port, opens a temporary browser profile and closes both on exit.

```sh
node --test examples/invent-notation/score.test.mjs examples/invent-notation/persistence.test.mjs
runtime=$(mktemp -d)
uv venv "$runtime/env"
uv pip install --python "$runtime/env/bin/python" playwright==1.65.2
"$runtime/env/bin/python" examples/invent-notation/replay.py --images "$runtime/captures"
```

The second replay authors a nested Cluster / Run / Pulse score through the UI.
Use the same Python environment with its matching Playwright WebKit browser
installed. The replay saves six screenshots and their corresponding score
documents to the specified directory.

```sh
"$runtime/env/bin/python" -m playwright install webkit
"$runtime/env/bin/python" examples/invent-notation/replay_second.py --evidence "$runtime/second-score"
```

In the forward score, a six-beat run and a four-beat pulse play together.
A final two-beat pulse brings the total to eight ticks. Reversing sequence
order and setting three ticks per beat gives 24 ticks. The replay checks each
event's ID and endpoints, rejects a group capacity of one, and verifies the
saved tree after undo and reload. Both scores use the same three phrase types.

## Evidence and open gates

[Open the seven-slide offline slideshow](../../artifacts/demo-slideshows/v03-invent-notation/index.html). The [manifest](../../artifacts/demo-slideshows/v03-invent-notation/manifest.json) ties each original collaborative-preview PNG to the tested commit, fixture, viewport, action and expected observation. The original recovery replay used Chrome 158 on macOS, a 1280 × 800 viewport at 2× scale and a 390 × 844 reload check.

| Scenario | Observed |
| --- | --- |
| V03 composition | Keyboard selection reached group 3. Click and Enter inserted its two children. Three motions occupied four ticks. |
| I12 replacement | Preview showed six ticks while the active duration stayed four. Apply reversed sequence order and changed the active duration to six. The activated control kept focus and slot IDs, group selection and motion data survived. |
| V03 / I12 rejection | Capacity one failed against group 3. The replay compared the complete saved document before and after rejection, then reloaded and found the same revision, selected slot and duration. |
| I01 progressive formalization | A 41-unit arm rotated 70.5° at tick 0.60. Two undos restored the exact pre-arm document including the informal note and joint at (70, 85). |
| Render and recovery | Chrome decoded the Moxi SVG, rejected a malformed plot request with HTTP 400, and reopened the six-tick result at phone width without horizontal overflow. The replay recorded zero page exceptions. |

Five core tests cover schedule semantics, atomic rejection, identity, serialization, timing, sketch conversion and insertion constraints. Nine persistence tests cover exact source retention, selection/edit/reload, archive and active-write failures, earlier recovery copies and denied reads. The browser replay also checks actual recovery downloads, failed selection/edit/undo handlers and restarting the host on the same origin. This constrained replacement runs a fixed evaluator. The second-score replay adds WebKit coverage for nested composition, revisions, undo and reload; recovery and narrow-screen checks remain Chrome-only. Native Mojo UI, collaborative editing, a second substantially different notation and screen-reader behavior remain unverified. Second-author completion, discoverability and prediction accuracy require a participant study.
