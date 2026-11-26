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

```sh
"$V07_ENV/bin/python" -m unittest discover -s examples/oscillator -v
"$V07_ENV/bin/python" examples/oscillator/capture.py "$(mktemp -d)/slideshow"
```

## Verified scenarios

[Open the nine-frame slideshow](../../artifacts/demo-slideshows/oscillator/index.html). The [manifest](../../artifacts/demo-slideshows/oscillator/manifest.json) records capture time, source hashes, Chrome/Python versions and viewport. The replay launches this checkout's loopback server on a free port and uses a fresh headless Chrome context. Inputs and written explanations are synthetic.

| Scenario | Steps and observed result |
| --- | --- |
| V07 prediction and manipulation | An empty prediction blocked the controls. After recording a prediction, mass 0 produced HTTP 400 and no result. Correcting to 4 kg produced 3.142 s against the 1.571 s reference. |
| I02 matrix and singular case | The selected sample uses the diagonal phase matrix with columns (A, 0) and (0, −Aω). Keyboard selection exposed the velocity term. Editing amplitude to 0 collapsed both columns and the trial trace. |
| I06 formula and return | At t = 0.5 s the 4 kg run displayed x = 0.270 m. Opening the formula and its definition, then returning, restored observation focus and the selected final character. |
| I07 interruption | Record prediction, set mass, compare. Checkpoint that third state, then explore zero amplitude and restore. The original amplitude and sampled displacement returned. |
| I16 executable lesson | Insert the copied run, export HTML, then restore the checkpoint. The download contained the Moxi SVG, originating parameters and copied result. The inserted result retained zero amplitude after restore. |
| V07 unfamiliar case | With 2 kg, 32 N/m and 0.75 m, an empty explanation kept the answer hidden. Entering an explanation revealed 1.571 s. Reload reset the lesson. |

All lesson actions in the captured route used Tab, editing keys and Enter. The replay also clicked the trajectory slider midpoint and checked the linked 4 s measurement. It checked for page exceptions and horizontal overflow at 390 px. Five core tests cover period scaling, the transfer case, phase and velocity, singular motion, rejected values, deterministic SVG, shared amplitude scale and cursor position. The consumer supplies common domain endpoints to Moxi's independently fitted line layers and removes those endpoints from the displayed strokes.

## Open gates

The screenshots establish the synthetic route on one Chrome/macOS environment. Actual learners, transfer of understanding, assistive technology, physical input, other browser engines and other operating systems remain untested. The fixed transfer prompt can be anticipated through free exploration. The phase matrix is constrained by the spring model, the notation inspector uses fixed expressions, and the checkpoint and report last for one page session. Teacher authoring beyond editing the fixtures and prompts is open.
