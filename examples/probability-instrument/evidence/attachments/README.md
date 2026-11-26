# V08 attachment replay

Chrome 158.0.8127.37 on macOS 27.2.1 arm64, 2026-11-26 02:59 UTC. Playwright drove a fresh local tab at 1280 × 800 and 390 × 844 CSS pixels. Full-page screenshots use device scale 1. The server bound an ephemeral port on 127.0.0.1 and served the synthetic (0.25, 0.5, 0.25) fixture from this checkout. The tested implementation is the change accompanying these captures on base `3995b082387b`.

| Action and expected result | Observed at both sizes | Desktop | Narrow |
| --- | --- | --- | --- |
| Pin the mean, select outcome 1 and enter 0.2 on the plot. | Pass. Preview (0.4, 0.2, 0.4), reading 0.2, reference 0.5, change −0.3. Committed mean stays 1. | [Plot](1280-plot.png) | [Plot](390-plot.png) |
| Attach the pending edit to the triangle. | Pass. Selection, pin, input, units, reference and reading carried over. Dot at (266, 121) SVG units. Enter committed the preview and advanced the reference to 0.2. | [Triangle](1280-triangle.png) | [Triangle](390-triangle.png) |
| Select outcome 2, press halfway up the triangle, hold through Escape, move and release. Repeat and commit, then enter 0.8. | Pass. Escape cleared the first preview and disabled Apply. The second edit committed (0.5, 0, 0.5). The infeasible request retained that reading and disabled Apply on both attachments. | [Rejection](1280-rejected.png) | [Rejection](390-rejected.png) |

Reload restored the initial distribution and plot. After reload, a single triangle position yielded 0.5, 0.3 and 0.2 for the three selected basis weights within 0.01 pointer tolerance. Both runs passed the prior plot drag/numeric equivalence, held-Escape, pinned rejection, released-mean and point-mass checks. Neither run produced a page exception or horizontal overflow at the checked states.

From the repository root:

```sh
PYTHONPATH=python python3 -m unittest discover -s examples/probability-instrument
PYTHONPATH=python uv run --no-project --with playwright python examples/probability-instrument/check_browser.py --capture /tmp/v08-captures
```

All three unit tests passed, including 4,356 feasibility requests. The regenerated Mojo affine transform fixture compared byte-for-byte equal. The observations cover software behavior with synthetic inputs. Human understanding, physical touch, assistive technology and other browser engines were untested.
