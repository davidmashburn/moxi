# When does the shuttle cost less?

An offline Moxi consumer for V05. Both proposals serve the same synthetic riders on one run. Change demand or shuttle dispatch cost to test the author's conclusion. The plot shows the difference between fitted voucher spend and modeled shuttle spend. Its dashed zero line marks a tie. A withdrawn demand premise removes the point estimate.

From the repository root, build and open the article using Python 3.10+:

```sh
python3 -m venv /tmp/moxi-v05
cd examples/executable-argument
PYTHONPATH=../../python /tmp/moxi-v05/bin/python build.py /tmp/shuttle.html
open /tmp/shuttle.html   # macOS; elsewhere open the file in a browser
```

The build uses the checkout's public `moxi.PlotSpec`, `moxi.plot` and `Figure.to_svg()`. It bundles all 183 supported input pairs in the article. No service, account or external dataset is needed.

## Reader paths

- **V05.** At 40 riders and $120 dispatch the shuttle saves $40. Follow **Inspect premises**, reduce demand below 30, then restore the original. At 30, both cost $180. Demand is a whole number from 0 to 60. Dispatch can be $80, $120 or $160.
- **I07.** Tab to **Next action** and advance three times. Use the arrow keys on the demand slider to explore a reversal. **Restore step 3** returns to the tie. Continue twice to complete the explanation.
- **I08.** Follow **Trace cost rates** and expand the observations. Save a disputed premise with a note, then withdraw demand or enter 61 riders. The point result clears and inserting or saving becomes unavailable. Reopen the alternative to recover both inputs and its note. The saved alternative lasts for this page session.
- **I16.** Edit the exploration copy, explicitly insert its finding, then restore the original. Export the static essay and reopen it to compare the original and inserted results with their formula, figure, fit and limitation. For a static copy of the baseline, restore the original before inserting.

## Reproduce the checks

From this directory, with Google Chrome installed:

```sh
PYTHONPATH=../../python /tmp/moxi-v05/bin/python -m unittest -v test_model
/tmp/moxi-v05/bin/python -m pip install playwright==1.58.0
PYTHONPATH=../../python /tmp/moxi-v05/bin/python capture.py /tmp/replay/v05-executable-argument
```

Open the generated `index.html` to view the screenshots, captions and contact sheet. Capture uses a temporary article, a fresh headless Chrome context and synthetic fixture T1. The venue, rider counts and costs have no empirical transport interpretation. Whether readers can explain reversals better after using this article than after reading its static version requires a participant comparison.
