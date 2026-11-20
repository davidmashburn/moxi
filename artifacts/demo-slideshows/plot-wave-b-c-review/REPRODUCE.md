# E02/E03 integrated-source gallery review

Scope: planning section 2 (`origin/project-planning:PROJECT-PLANNING.md`),
published Moxi `d7fa3ed563948860f4baf18bcc9f3eb279197135`. Only capture tooling
and evidence change. The Moxi runtime, native assertions and source fixtures
remain byte-identical to that commit. This is offscreen Canvas rendering and
recorded synthetic PlotView event replay, not physical input or a live plot UI.

The batch contains 14 E02 galleries (98 slides) and 12 E03 galleries (72 slides).
[Results](RESULTS.md), [individual-frame review](review.json), [checks and prior-hash comparison](checks.json),
[browser capture plan](capture-plan.json), and [capture metrics](captures.json)
use repository-relative paths. PNG/HTML/SVG/PDF files are generated and ignored;
manifests and JSON/Markdown evidence are reviewable source files. New files are
left untracked for integration; no staging, commits, pushes or shared writes.

## Regenerate

Run from the repository root. Commands below create only local artifacts.
The read-only upstream clone must be clean at the required pin; do not replace
it with a different reference renderer. A fresh clone needs network access.

```sh
pixi install --locked
python3 -m venv output/e02-e03-d7fa3ed/venv
output/e02-e03-d7fa3ed/venv/bin/pip install pillow==13.0.0 numpy==2.5.5 matplotlib==3.10.7 playwright==1.65.2
git clone https://github.com/randyzwitch/dataviz_mojo.git output/e02-e03-d7fa3ed/upstream
git -C output/e02-e03-d7fa3ed/upstream checkout --detach 3fd5a7e7c622d6130c99a290b88c4fee039deab2
export PYTHONPATH=python
GALLERY_PY=output/e02-e03-d7fa3ed/venv/bin/python
GALLERY_FONT_DIR=$("$GALLERY_PY" -c 'import matplotlib; print(matplotlib.get_data_path()+"/fonts/ttf")')
"$GALLERY_PY" scripts/wave_b/fixtures.py
"$GALLERY_PY" scripts/wave_b/verify.py output/e02-e03-d7fa3ed/e02-actual
"$GALLERY_PY" scripts/wave_c/verify.py output/e02-e03-d7fa3ed/e03-actual
"$GALLERY_PY" scripts/wave_b/upstream.py output/e02-e03-d7fa3ed/upstream output/e02-e03-d7fa3ed/e02-reference --font-dir "$GALLERY_FONT_DIR"
"$GALLERY_PY" scripts/wave_c/upstream.py output/e02-e03-d7fa3ed/upstream output/e02-e03-d7fa3ed/e03-reference --font-dir "$GALLERY_FONT_DIR"
"$GALLERY_PY" scripts/wave_b/compare.py output/e02-e03-d7fa3ed/e02-reference output/e02-e03-d7fa3ed/e02-actual
"$GALLERY_PY" scripts/wave_b/evidence.py output/e02-e03-d7fa3ed/e02-reference output/e02-e03-d7fa3ed/e02-actual
"$GALLERY_PY" scripts/wave_c/evidence.py output/e02-e03-d7fa3ed/e03-reference output/e02-e03-d7fa3ed/e03-actual
python3 -m http.server 8796 --bind 127.0.0.1 --directory artifacts/demo-slideshows
```

The T3 shared preview loaded a page but its snapshot operation twice returned
`Preview automation snapshot timed out after 15000ms`. This batch therefore
uses local headless Chrome through Playwright, with an isolated temporary
profile. Run the next commands in another terminal while the local server runs.
The capture tool locates installed Chrome/Chromium; use `--browser /path/to/chrome`
on another platform, or install Playwright Chromium (`python -m playwright install
chromium`) when no local browser exists. The exact browser version, user agent,
CSS viewport, DPR, capture time, loaded images, errors and screenshot SHA256 are
recorded for every frame in `captures.json`. Height expands to include the full
page; no chart is substituted for an unavailable reference.
The optional static-site favicon returned one recorded 404; this is separated
from evidence page/image failures in the capture record.

```sh
PYTHONPATH=python output/e02-e03-d7fa3ed/venv/bin/python scripts/capture_plot_gallery_evidence.py
PYTHONPATH=python output/e02-e03-d7fa3ed/venv/bin/python scripts/check_plot_gallery_evidence.py --refresh
PYTHONPATH=python output/e02-e03-d7fa3ed/venv/bin/python scripts/check_plot_gallery_evidence.py --sheets
```

Review every frame and supporting image. Local `*-review-*.png` panels retain
original image resolution and identify each frame. Review results bind to image
hashes in `review.json`; regeneration requires another visual review, not simply
refreshing those hashes. Finish with the commands below. The `--check` command
on E03 is deliberately read-only; do not rebuild the common gallery index.

```sh
PYTHONPATH=python output/e02-e03-d7fa3ed/venv/bin/python scripts/wave_c/slideshows.py --check
PYTHONPATH=python output/e02-e03-d7fa3ed/venv/bin/python scripts/check_plot_gallery_evidence.py
git diff --check
git status --short
git check-ignore artifacts/demo-slideshows/e02-pie/01-source.png artifacts/demo-slideshows/e03-tree/01-source.png output/e02-e03-d7fa3ed/e02-actual/run.log
```

## Interpretation and limits

The [E02](../../../docs/plot-specialized-wave-b.md) and
[E03](../../../docs/plot-specialized-wave-c.md) algorithm and selection contracts
still apply. Palette, Cartesian grids on radial charts, missing Canvas text,
tessellation, ridgeline clipping, independently scaled circular geometry and
barb staff lengths prevent a blanket visual parity claim. Table exports and
semantic assertions establish source-key behavior; screenshots alone do not.
Reference gates for contour, contourf and tricontour are **blocked**: those APIs
are absent from the exact pinned upstream. Their Moxi outcomes can be reviewed
without inventing reference parity. These families remain partial overall.
All 26 families are partial for full visual acceptance. Their bounded semantic
checks pass. Wave C's existing driver checks click dispatch, semantic rows,
rejection return values and restored pixels; it does not exercise per-family
keyboard/linked traversal or capture the rejected scene before restoring.
Its rejection/recovery scenarios are therefore partial; Wave B captures and
compares the rejected state and exercises keyboard/linked selection.

Previous evidence is the committed manifests and observed results in `d7fa3ed`;
their own capture revisions predate integration. Prior ignored PNGs were absent
in this checkout. Hash equality establishes identical bytes where available;
changed hashes alone do not establish regression or improvement. The check
record keeps every previous/new frame hash, and the review records structural
and semantic comparisons against the committed observations.

Raw driver, CSV, SVG and raster results and run logs remain locally under
[output/e02-e03-d7fa3ed](../../../output/e02-e03-d7fa3ed/).
Full project suites, installed consumers, package CI, native/GPU/physical input,
screen-reader behavior, independent human/scientific acceptance and large-load
performance are outside this evidence task and are not certified by it.
