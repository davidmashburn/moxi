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
