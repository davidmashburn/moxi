# Synthetic pose stroke study

Open `index.html` directly in Chrome. Advance samples with the button or Tab and Enter. “Hold clutch open” overrides the recorded clutch until toggled again. Restart returns to sample one. The eleven numeric samples in `model.js` were authored for this probe. The demo uses local scripts and accepts no device or network input.

Direct control uses curl alone. The other brush bilinearly interpolates four synthetic calibration widths. At zero spread, relaxed and curled poses yield 4 and 28 px. At full spread they yield 16 and 12 px. Both brushes start at 12 px and apply changes in mapped width, bounded to 4–28 px. Releasing the clutch or dropping below 0.70 confidence clears the previous target. The first valid engaged sample takes a new reference at the held width. Movement after that changes width again.

## Reproduce

From the repository root, run `node examples/pose-stroke/check.cjs` for calibration, replay and recovery assertions. For each mapping, the check compares 100 exact replays with a baseline. A second set of 100 runs adds independent uniform perturbations of ±0.01 to both normalized features using the same seed (15) for each mapping. RMS and maximum absolute errors compare the 1,100 perturbed widths to the corresponding baseline widths, including held samples. For this path, direct RMS/max were 0.2271/0.8518 px and interpolated RMS/max were 0.1521/0.5915 px.

The demo-specific [offline deck](../../artifacts/demo-slideshows/v15-pose-stroke/index.html) includes the screenshots. To regenerate after committing the example, use local Chrome and Python with Playwright. The checked environment used Python 3.12 and Playwright 1.65.2, installed from a local cache.

```sh
uv venv --offline --python 3.12 .pixi/v15-verify
uv pip install --offline --python .pixi/v15-verify/bin/python playwright==1.65.2
.pixi/v15-verify/bin/python examples/pose-stroke/gallery.py
```

The runner checks rendered widths and labels through clutch release, confidence loss, reacquisition and resumed control. It also exercises keyboard advance, manual clutch override, restart, reload, narrow layout, slideshow navigation and image decoding with Chrome offline. All captures are page content from a temporary browser profile.

This browser experiment measures simulated repeatability for one stroke parameter. Native Moxi integration, camera/model selection and licensing, live latency, accidental activation, comfort, multi-parameter fluency and comparisons with human slider performance remain open.
