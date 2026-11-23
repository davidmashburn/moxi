# Demo catalog audit — November 23, 2026

All 59 manifests loaded and all 481 referenced PNGs were present in the review workspace. A clean clone contains 95 of those frames. The audit ran at 2026-11-23T07:56:33.504802+00:00 against [`e9fd68f`](https://github.com/davidmashburn/moxi/tree/e9fd68f799760d46381a014d483b39fee09db9a5). The [machine-readable results](catalog-audit.json) identify each manifest, image and recorded source inventory.

| Check | Result |
| --- | --- |
| Schema, image presence and dimensions in the review workspace | 59/59 pass |
| Recorded image SHA-256 | 413 match, 0 mismatch |
| Images with no recorded SHA-256 | 68 |
| Frame references backed by PNGs in Git | 95/481 |
| Frame references available only as local generated files | 386/481 |
| Recorded source inventories | 6 match the audited files, 45 differ, 8 lack per-file hashes |

The matching source inventories are `e04-python-native`, `mindmap`, `plot-contour-followup`, `plot-ridgeline-followup`, `spatial-assembly`, `sws-native`. A match covers the files the producer actually recorded. The JSON lists changed and absent files for each differing inventory. Eight older galleries carry no per-file inventory. The external SeedWater application was verified separately in its [packaged replay](sws-native/README.md). The catalog auditor checks its Moxi namespace.

The [November 23 baseline](https://github.com/davidmashburn/moxi/blob/eed5663/artifacts/demo-slideshows/CATALOG-AUDIT.md) identified 13 missing SeedWater frames. All 13 [historical originals](https://github.com/davidmashburn/moxi/tree/f253097/artifacts/demo-slideshows/sws-native) were recovered at their recorded hashes. The current catalog carries a new source-bound replay. The [26 historical plot family comparisons](plot-wave-b-c-review/RESULTS.md) also open directly from Git.

The [mindmap](mindmap/REPRODUCE.md), [assembly](spatial-assembly/README.md), [contour and radial plots](plot-contour-followup/README.md), [ridgeline](plot-ridgeline-followup/README.md) and [installed Python renderer](e04-python-native/REVIEW.md) have dedicated visual and interaction records. Other generated galleries may require their documented replay on a new checkout. This catalog check does not independently establish visual quality, complete dependency coverage, physical-input behavior or performance.

Run the audit from the repository root.

```sh
python3 scripts/audit_demo_manifests.py --output artifacts/demo-slideshows/catalog-audit.json
```
