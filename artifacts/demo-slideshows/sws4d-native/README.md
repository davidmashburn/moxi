# Linked 4D slice editor

The separate local application repository `moxi-sws4d` contains the native editor. Run its `build.sh` with `MOXI_ROOT` pointing to a Moxi checkout and use its pinned Python requirements. Run `python -m unittest -v`, `python replay.py` and `python native_regression.py OUTPUT` from the installed app environment.

At application revision `c19f78f`, five tests passed, including twelve full-volume comparisons with the pinned unmasked reference. The native replay exercised seed and mask edits through the XY, XZ and YZ views, undo and redo, save and reopen, stale worker results, failure and recovery. All 42 displayed voxel centers matched the expected colors within tolerance. Chrome opened all 14 frames offline and verified their hashes, captions and navigation. [Open the replay](index.html) · [Fixture, revisions and measurements](native-replay.json)

After the toolbar repair, twelve pointer selections reached the intended time at four window sizes. Closing the window with a blocked worker allowed the process to exit. The test used injected Tk events on macOS with a synthetic time series. [820-point toolbar](02-toolbar-0-820-t0.png) · [860-point toolbar](04-toolbar-1-860-t2.png)

### Legacy outline masks

Application revision `cb17bae` adds the legacy outline as an opt-in mode. In the single-marker fixture, raising the outline let label 17 reach all 231 voxels. Hard exclusion confined it to the 45 tissue voxels. Existing saved studies reopen with hard exclusion.

All 24 seeded masked fixtures and 12 unmasked fixtures matched the pinned reference. All 24 hard-exclusion outputs matched the previous editor. A fresh application process reopened the saved legacy result. The recorded native replay also exercised an invalid mode, a seedless run, retry and a stale worker. [Native frame](legacy-outline.png) · [Source hashes and replay outcomes](legacy-outline.json)

From the app checkout, run `python -m unittest -v` and `python masked_replay.py OUTPUT` in its documented environment. The app README gives the independent reference regeneration command and versions. Original sparse document import, real volumes, representative memory and performance, physical input and other hosts remain open. The application repository has no configured remote.
