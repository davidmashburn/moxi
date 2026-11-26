# Chord, calendar and Sankey replay

These comparisons use the synthetic edge list and leap-year dates in `tests/fixtures/wave_c/cases.json`. Each frame pairs the actual pinned dataviz PNG with the Moxi chart at 640×480. The chord panel shows the native Canvas raster. The calendar and Sankey panels show the native Scene SVG rendered by headless Chrome. The captures use a 1316×532 viewport at device scale 1.

| Family | Reference behavior | Check |
| --- | --- | --- |
| [Chord](chord.png) | `dataviz/chord.mojo` allocates two subarcs per edge and draws one ribbon between them. Its diameter is 90% of the smaller plot dimension. | Check the native and Python raster footprint and compare each of five ribbons and four sectors against its corresponding SVG fill on a two-pixel sample grid. Hit the five source subarcs and resize to portrait. |
| [Calendar](calendar_heatmap.png) | `dataviz/calendar_heatmap.mojo` reserves a header row and places each month at its first Sunday-based week column. | Compare seven weekday and twelve month strings, alignment and both anchor coordinates in native and Python SVG. |
| [Sankey](sankey.png) | `dataviz/sankey.mojo` labels the right-hand midpoint of each real node. Long-edge subdivisions carry flow across intermediate columns. | Compare the four node strings, alignment and both anchor coordinates in both SVG exports. Click a flow and verify the source key. |

The reference is [dataviz_mojo at the Wave C pin](https://github.com/randyzwitch/dataviz_mojo/tree/3fd5a7e7c622d6130c99a290b88c4fee039deab2/dataviz). The historical E03 and radial galleries retain the pre-change renders. The square frame and family-specific axes apply to standalone specialized plots. Ribbons and sectors have sampled boundaries, and palettes and text styling differ. SVG carries labels in both implementations. Portable Canvas, software raster, Python PNG and Python PDF lack the text backend used for these captures.

The Moxi implementation is `f67c4b1`, based on `b95bfba`. The [capture record](results.json) includes the browser version, capture time, click coordinates, source keys, object comparisons and replay input hashes. The Python suite passed all 375 cases.

## Reproduce

Use the repository's locked Moxi environment, a clean checkout at the reference pin with its locked environment, and Python with pytest, Pillow, numpy, matplotlib and Playwright. Capture uses installed Google Chrome. Run from the worktree root. The `--as-is` Pixi settings below reuse installed environments.

```sh
export PIXI_NO_INSTALL=true PIXI_FROZEN=true PYTHONPATH=python
python -m pytest -q tests/test_specialized_c.py tests/python
python scripts/wave_c/verify.py output/e03-replay
python scripts/wave_c/upstream.py "$REFERENCE_CHECKOUT" output/e03-reference \
  --font-dir "$(python -c 'import matplotlib; print(matplotlib.get_data_path()+"/fonts/ttf")')"
python scripts/wave_c/compare_flow_calendar.py output/e03-reference output/e03-replay \
  artifacts/demo-slideshows/e03-flow-calendar-followup \
  > artifacts/demo-slideshows/e03-flow-calendar-followup/results.json
```

The native verifier dispatches synthetic clicks through PlotView and exports a source table, Scene SVG, selected Canvas PNG and Python PNG/SVG/PDF. For each family it replaces the data, rejects invalid replacements and verifies that restoration reproduces the original Canvas pixels. Detailed geometry, selection and rejected-update records stay in the replay output directory. The comparison command prints the measurements, host, capture time and browser version. No native-window or physical input, VoiceOver session, independent scientific review or performance acceptance is included.
