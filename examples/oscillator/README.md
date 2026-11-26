# Oscillator lesson (V07)

Predict how quadrupling mass will change a spring's period. Compare your trial with the reference, probe both traces at an exact time, then explain a second case before revealing its period. All runs use an ideal, undamped spring released from rest. The natural period still exists at zero amplitude, even though the motion has no observable cycles.

From the repository root, create a disposable Python environment and run the local consumer. The browser UI needs only Python and the Moxi package from this checkout. The capture additionally uses Playwright and installed Google Chrome.

```sh
V07_ENV=$(mktemp -d)/venv
uv venv --python 3.12 "$V07_ENV"
uv pip install --python "$V07_ENV/bin/python" . playwright==1.58.0
"$V07_ENV/bin/python" examples/oscillator/serve.py
```

Open the printed loopback URL. Reload to start a fresh lesson. The only saved output is the HTML report you explicitly export.

The optional **Start recorded example** button replaces the lesson with a fixed, versioned five-action explanation: predict, set a 4 kg trial, compare, inspect velocity at 0.5 s, and explain the comparison. **Next recorded step** advances one semantic command at a time. After action three the player saves a checkpoint and pauses in an exploration copy. Change values, inspect notation, or try and reveal the unfamiliar case; **Restore checkpoint** returns the saved result, text, lesson stage and answer disclosure state. Continue with actions four and five. Playback uses semantic commands and parameter values, independent of screen coordinates. This is one authored fixture for the undamped spring model, not an arbitrary-action recorder or a durable replay format.

Manual **Explore a copy** checkpoints the same state, including partially written or already revealed explanations. Restore uses the saved model result and discards late exploration responses. Inserted reports stay frozen across restore. Their SVG compares the 1 kg reference with the exploration trial, labels all three plotted strokes, and explicitly identifies the checkpoint parameters/period as not plotted.

```sh
V07_EVIDENCE="$(mktemp -d)/regressions" PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=python:examples/oscillator \
  "$V07_ENV/bin/python" -B -m unittest discover -s examples/oscillator -v
"$V07_ENV/bin/python" examples/oscillator/capture.py "$(mktemp -d)/slideshow"
```

## Verified scenarios

[Open the original nine-frame slideshow](../../artifacts/demo-slideshows/oscillator/index.html), captured at `7059391`. Its [manifest](../../artifacts/demo-slideshows/oscillator/manifest.json) identifies those historical sources, not the repaired player. Run the commands above for fresh capture and regression evidence, including screenshots, an offline report, source hashes, environment and scenario outcomes. Both browser drivers launch this checkout's loopback server on a free port and use fresh headless Chrome contexts. Inputs and written explanations are synthetic.

| Scenario | Steps and observed result |
| --- | --- |
| V07 prediction and manipulation | An empty prediction blocked the controls. After recording a prediction, mass 0 produced HTTP 400 and no result. Correcting to 4 kg produced 3.142 s against the 1.571 s reference. |
| I02 matrix and singular case | The selected sample uses the diagonal phase matrix with columns (A, 0) and (0, −Aω). Keyboard selection exposed the velocity term. Editing amplitude to 0 collapsed both columns and the trial trace. |
| I06 formula and return | Forward/backward selections of characters 3..6 retain their active end on both Shift+Left and Shift+Right after Return or Escape. The test waits for the dialog close event. |
| I07 interruption | Play three of five recorded semantic actions, explore 9 kg and reveal a branch answer, restore 4 kg with the original undisclosed answer, then resume actions four/five at a changed viewport. Native Tab/Enter activates playback and restore controls. |
| I16 executable lesson | Checkpoint 4 kg, explore 9 kg, insert and export, then restore. The offline report retains 9 kg, identifies the 1 kg plotted control and unplotted 4 kg checkpoint with periods, and contains the curve/probe legend without external requests. |
| V07 unfamiliar case | With 2 kg, 32 N/m and 0.75 m, an empty explanation kept the answer hidden. Entering an explanation revealed 1.571 s. Reload reset the lesson. |

All lesson actions in the nine-frame capture route use Tab, editing keys and Enter. That replay also clicks the trajectory slider midpoint and checks the linked 4 s measurement. Both drivers check for page exceptions and horizontal overflow at 390 px. Six core tests cover period scaling, the transfer case, phase and velocity, singular motion, rejected values, deterministic SVG, shared amplitude scale, cursor position and reference/legend provenance. Eight browser regressions additionally cover checkpoint disclosure/text, selection direction, offline export, the five-step path, stale responses, network-free restore and request-failure retries. The consumer supplies common domain endpoints to Moxi's independently fitted line layers and removes those endpoints from the displayed strokes.

## Open gates

The screenshots establish the synthetic route on one Chrome/macOS environment. Actual learners, transfer of understanding, assistive technology, physical input, other browser engines and other operating systems remain untested. The fixed transfer prompt can be anticipated through free exploration. The phase matrix is constrained by the spring model, the notation inspector uses fixed expressions, and the checkpoint and report last for one page session. Teacher authoring beyond editing the fixtures and prompts is open.
