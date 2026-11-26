# V08 · Probability instrument

Run from the repository root and open the printed loopback URL.

```sh
PYTHONPATH=python python3 examples/probability-instrument/instrument.py
```

Each column of the Moxi stacked-bar plot contains an outcome's probability and the space remaining up to 1. Edit any outcome directly on the plot or through the numeric field. Apply commits the preview in the current tab. Escape discards it. Reload starts a new experiment.

With the mean free, the other masses retain their relative proportions. With the mean pinned, assigning probability t to outcome k leaves mass 1 − t for the two remaining outcomes a and b. The mean is attainable precisely when it lies between kt + a(1 − t) and kt + b(1 − t), for a < b. The solver allows floating-point roundoff of 1e-12 at a boundary. The table displays seven significant digits.

## Verification

```sh
PYTHONPATH=python python3 -m unittest discover -s examples/probability-instrument
PYTHONPATH=python uv run --no-project --with playwright python examples/probability-instrument/check_browser.py
```

The browser check uses an installed Google Chrome. On macOS arm64 it passed at 1280 × 800 and 390 × 844. It compares a drag to the equivalent numeric edit, checks the committed row before and after Apply, rejects an impossible tail edit, releases the mean and redistributes from a point mass. The model tests exercise 4,356 edit requests across a grid of normalized distributions, including zero-mass and pinned boundary cases.

[Open the captured slideshow](evidence/v08-probability/index.html) or [inspect its reproduction manifest](evidence/v08-probability/manifest.json). Captures show the actual local browser application using the checkout's public Python PlotSpec and Figure APIs. The PMF and mean describe a synthetic model. No measurements or sampled outcomes enter the display.

Human evaluation remains open. Ask a participant to predict what changes when raising the right tail with the mean pinned to 1, then explain why assigning 0.8 to that tail fails. Physical touch and assistive-technology behavior were not exercised.

## Attachable probability probe

The plot and triangle share one outcome selector, numeric editor, mean constraint and transaction. Switching attachment also preserves a pending or rejected request. The readout uses dimensionless probability on both surfaces and compares the displayed mass to the committed mass of the same outcome. Apply advances that reference. An infeasible edit shows the committed reading while leaving the rejected request available for correction.

The triangle uses (P(1), P(2)) as its two affine coordinates, with P(0) = 1 − P(1) − P(2). The dot represents all three weights. The line through it holds the selected weight constant. Clicking the triangle reads that weight through the inverse transform and asks the existing solver to redistribute the remaining mass. With the mean pinned, the resulting dot can land elsewhere along the same line. Keyboard entry edits the same coefficient. Screen positions and entered values are synthetic interaction inputs. All displayed probabilities and means describe the model.

The offline geometry fixture comes from Moxi’s Mojo `geometry.Transform` and `inverse()`. From the repository root, reproduce and compare it with:

```sh
pixi run mojo run -I src examples/probability-instrument/triangle.mojo > /tmp/v08-triangle.json
diff examples/probability-instrument/triangle.json /tmp/v08-triangle.json
```

### Master scene mapping

- **I05** — The plot-to-geometry route carries a live probe and its preview across both representations. The [attachment evidence](evidence/attachments/README.md) records both viewports.
- **I02** — V08 exercises shared selection and numeric basis-weight editing under normalization and a pinned mean. The independent V07 oscillator record at `7059391989fc` documents keyboard selection of a phase-matrix term and a singular basis at zero amplitude (`examples/oscillator/README.md` and the oscillator capture manifest in that revision).
- **I14** — The independent V06 motion-envelope record at `4c486deb2556` documents a stopped apex edit and two performances of the edited trajectory (`examples/motion-envelope/README.md` and its capture manifest). V08 has no time axis. Freehand curve recording remains open in the V06 record.
