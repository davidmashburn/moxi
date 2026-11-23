# Complete ridgeline peaks

The first density curve rose above its declared vertical domain. With three groups, the sampled peak is 3.3 but the previous domain ended at 3. Native projection clamped nine samples into a flat top; Python exports cropped the same samples. The corrected domain includes the complete 1.3-unit rise above the first baseline. Density values, category order, source identities and overlapping baseline spacing are unchanged.

Open `native.html` and `python.html` for the actual before/after exports. `interaction.html` and `recovery.html` show the native replay states. The five corresponding frame captures are also available through `manifest.json`.

The genuine dataviz 0.8.0 reference at `3fd5a7e7c622d6130c99a290b88c4fee039deab2` still clips its peak. `reference.html` makes this accepted framing difference visible. Every complete density SVG path vertex agrees within 1.1 pixels in the upstream category frame; that limit accounts for integer-rounded x coordinates and upstream's one-pixel bottom-axis offset. The raster silhouette IoU is 0.79345: the historical >0.98 gate fails on the repaired framing and is retained as an explicit historical failure in `verification.json`. It remains descriptive for this corrected implementation. This replaces the former ridge-specific >98% silhouette gate because the clipped image was itself the defect; the other family thresholds are unchanged. Full visual parity remains partial because labels, gridlines, palette and framing differ.

The new regression tests failed in 16 cases before the repair and pass afterward: one, two, three and six groups, constant and varying samples, and two viewport sizes. A native assertion also failed before the repair. Afterward, 134 focused Python tests and all 14 native Wave B cases passed, including geometry/source-key checks, actual Canvas/SVG rendering, click/keyboard/linked selection, source updates, rejected updates and restoration. All 12 available historical Wave B references pass their stated comparison checks. On the final combined runtime, 281 focused Python tests, all 26 native Wave B/C cases and all 23 currently bounded historical reference checks passed; the ridge silhouette failure remains explicit. The new ridge check covers all 96 complete KDE path vertices, with maximum error 1.000451 pixels. The existing 0.00002 data-unit Python/Mojo geometry tolerance is unchanged.

The current combined source revision, actual scoped dirty state and exact plot/runtime/driver/fixture hashes are recorded in `verification.json` and `manifest.json`. The scope follows local plot imports and the Python facade; unrelated gallery changes do not invalidate these captures. The before fixture remains base revision `49ebcdd`. Both current B verification/comparison drivers use the 560×400 plot viewport. The before native harness rendered successfully; its older Python verification wrapper subsequently failed the already-known stale-height beeswarm check. The corrected current-height wrapper passed all 14 cases after the repair. The raw local logs remain available to the integrating agent; `checks.txt` retains the relevant outcomes.

Reproduce with `PYTHONPATH=python` and the repository's locked Mojo environment:

```sh
python -m pytest tests/python/test_ridgeline_domain.py tests/python/test_wave_b.py tests/python/test_contour_scalar.py -q
python scripts/wave_b/verify.py output/ridgeline-after
python scripts/wave_b/compare.py "${REFERENCE_ROOT}" output/ridgeline-after
python scripts/ridgeline_followup.py "${BEFORE_ROOT}" output/ridgeline-after "${REFERENCE_ROOT}"
```

Generate the before fixture from base revision `49ebcdd`. Generate `REFERENCE_ROOT` through `scripts/wave_b/upstream.py` at the exact historical pin, using current 48/32/28/52 margins and the recorded DejaVu Sans font. The before and after native charts are 640×480. Browser pages use local Chrome at 1400×900 and scale 1; captures require decoded images, no horizontal overflow and no page/request errors. PNGs and HTML are deliberately included so the review works on clone. `artifact-sha256.json` fingerprints all image, vector and page artifacts.

Confidence is high in complete sampled-peak containment and the listed fixture checks. A failing rerun or any generated vertex outside its declared domain would change that assessment. Native-window input, GPU output, physical input, assistive-technology usability, independent scientific review and large-workload performance were not checked. Wave C was not rerun for this isolated Wave B change.
