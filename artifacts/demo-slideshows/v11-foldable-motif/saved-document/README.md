# V11 saved-document round trip

This evidence covers offline export/import in the existing six-panel editor. Implementation commit: `b1cd61f26a532891753a29b5b3451eda89f8ea53`, based directly on `ae1663fe323b6955a6a5d96aae8cad00420b68d2`. The editor, tests and documentation are scoped to `examples/foldable-motif`; no shared planning row, ledger, slideshow index or manifest was changed.

[results.json](results.json) records the capture times, committed source revision, source/build SHA-256 hashes, browser/host, viewports, scenario steps, expected/observed results, invalid-case diagnostics, exact downloaded documents and screenshot states. The source was clean when this document run began. The build is the documented single-file application at a local `file:` URL, using this checkout's unchanged Moxi spatial samples. Two independently built HTML files were byte-identical.

The environment was headless Google Chrome 158.0.8127.37 on macOS arm64, device scale 1, at 1180 × 900 and 390 × 844 CSS pixels. Contexts were offline. The fixture and all files are synthetic; no authentication, personal documents, remote writes or external communication was used. No HTTP(S) page requests or page/console errors were recorded in the document run. The hashes in `results.json` identify the tested bytes independently of later evidence-only commits.

The recorded entry was `file:///tmp/v11-document-current.html` (SHA-256 `2ac85ab14ba311474ff854ed6a5d6fec185dfdee0980754c943c2c031cb9f1ed`); no server or backend account was involved. The final capture interval was 2026-11-26 04:52:12–04:52:34 UTC. No mismatch between the committed source and tested HTML was found.

## Observed scenarios

All five scenarios passed at both widths, with no horizontal overflow:

| Scenario | Steps and observed result |
| --- | --- |
| Committed-only export | Commit 24.5 mm / 60°, select panel 5 and attach measurement; preview 27.1 mm / 23°; activate Export with Enter. The actual download contains only committed geometry, panel and measurement. Preview, inputs and undo remain intact. Export also preserves a separate invalid numeric draft. |
| Fresh-process round trip | Close the exporting Chrome process and launch another Chrome process/context. Click Import and select the actual downloaded JSON via Playwright's file chooser. Both views' exact panel coordinates, selection, values, comparison, measurement and trace match the committed export. Flat pitch and folded tilt remain editable; edit/import undo works. Reload resets the fixture; importing the saved file restores it again. |
| Atomic import and undo | Import over a pending preview. Import clears the draft; one undo restores the preceding committed geometry, selection and measurement. Earlier history still works. Equal-geometry and identical imports also undo as complete documents, including selection and measurement. Discarded drafts do not return. |
| Rejection and recovery | Run 30 malformed/schema/type/range/size cases per width with an invalid numeric draft pending, plus malformed JSON during a handle preview and an injected read failure. Every failure retains the geometry, controls, selection, measurement, pending draft/preview and usable history. Choosing no file is inert. Correcting and reselecting the same file succeeds; subsequent undo reaches each preceding committed state. |
| Supported boundaries | Import and re-export 10 mm / 0°, 30 mm / 75°, and 16.1 mm / 1°, with panels 1/6 and both measurement states. Exact values and linked measurements hold. Measurement can be added/undone on imported work, and consecutive document imports undo in order. |

Downloads and chooser selection go through the visible UI. Page evaluation only reads state/geometry. The single test fault overrides `Blob.text` for the synthetic filename `unreadable.json`; this checks the read-error branch without relying on OS permission changes. Picker cancellation is automated by selecting zero files, not by exercising a native Escape key. The test closes each browser process before the importing process starts; it does not infer a fresh instance from a reload or an extra tab.

The saved-document policy is explicit in the UI and [example documentation](../../../../examples/foldable-motif/README.md): export excludes drafts/previews and undo history; successful import clears drafts and adds one undo step; failed import changes none of those states. Version 1 validates all six required fields, disallows extra fields/unsupported versions and limits file size to 16 KiB.

## Captures and actual documents

Full-page PNGs from the recorded run:

| State | Desktop | Narrow |
| --- | --- | --- |
| Export leaves pending preview visible | [1180 px](1180-export-preview.png) | [390 px](390-export-preview.png) |
| Fresh-process import restores committed work | [1180 px](1180-fresh-import.png) | [390 px](390-fresh-import.png) |
| Undo import restores prior committed work | [1180 px](1180-undo-import.png) | [390 px](390-undo-import.png) |
| Invalid document retains an invalid draft and valid geometry | [1180 px](1180-rejected-import.png) | [390 px](390-rejected-import.png) |

The actual exported files imported by the fresh browser are [1180-document.json](1180-document.json) and [390-document.json](390-document.json). They contain 24.5 mm / 60°, panel 5 and an attached measurement. Separate [desktop](1180-invalid-draft-export.json) and [narrow](390-invalid-draft-export.json) downloads show that a 9 mm draft does not replace committed 20 mm / 30° geometry in the export. Screenshots substantiate appearance; behavioral assertions and file contents substantiate the round trip and undo.

## Regression checks and preservation

[document-check.log](logs/document-check.log): 10 scenarios, 60 matrix rejection cases, additional preview rejection/read failure/recovery checks, no page/console errors or HTTP(S) requests.

[original-check.log](logs/original-check.log): all 76 samples against the analytic camera and panel constraints, linked picking, numeric/slider preview, rejection, measurement/draft undo and narrow layout passed.

[editing-check.log](logs/editing-check.log): 20 scenarios passed, including pointer/numeric parity for all circles, keyboard traversal/limits, in-flight cancellation, all-panel centroid picking at bounds, interleaved measurement undo and original offline deck images/navigation. No page errors. These two regression checks ran before the implementation commit against identical final editor/test bytes; their source hashes were reconciled with the implementation commit. No native/Mojo source changed, and the broader native/Mojo suites were not rerun.

All 29 previously tracked files under `v11-foldable-motif` retain their original bytes, including the original deck/manifest/PNGs and `flat-folded-editing` evidence. Their combined filename/content digest is in `results.json`. New evidence lives only in this sibling `saved-document` directory; historical claims were not relabeled as current.

## Reproduce

Use an existing C++20 compiler, Python 3, Node, Playwright and Google Chrome. If Playwright is outside normal Node lookup, set `NODE_PATH` to its already-installed `node_modules` directory. No installation or server is needed. From the repository root:

```sh
examples/foldable-motif/build.sh /tmp/v11-document.html
examples/foldable-motif/build.sh /tmp/v11-document-repeat.html
cmp /tmp/v11-document.html /tmp/v11-document-repeat.html
node examples/foldable-motif/check.cjs /tmp/v11-document.html /tmp/v11-document-original
node examples/foldable-motif/editing-check.cjs /tmp/v11-document.html /tmp/v11-document-editing
node examples/foldable-motif/document-check.cjs /tmp/v11-document.html /tmp/v11-document-new-evidence
```

Use fresh temporary output directories to preserve these captures. Tests exit nonzero on failure. For manual use, open the built HTML, edit/apply, select a panel, attach measurement and export; close the browser, reopen the HTML, then import that file. Try a malformed JSON file over pending work, then retry with the valid export and use Undo.

## Limits

High confidence in the bounded saved-document round trip for this fixture and tested Chrome environment, based on real downloads, newly launched importing browsers, exact state/geometry assertions and recovery/undo replays. A failing replay in another engine or with an actual native picker/device would narrow that conclusion.

VoiceOver remained paused and was not invoked; no screen-reader or independent accessibility/usability assessment was performed. Native picker OS interactions, actual OS file-read failures, download-manager failure/cancellation, other browser engines, touch hardware, fabrication/paper samples, maker trials, native platform UI, the full Moxi suite and performance were not tested. Read failure was injected as described above. The editor does not autosave, persist drafts/history or model arbitrary folding documents; reload requires explicit reimport to resume saved work.

T3 `preview_open` rejected `file:` with `unsupported-protocol: file:`; the existing local Playwright/Chrome environment exercised the public offline app instead. No browser-preview capture is represented as successful evidence here. No delegation, personal profile/worklog access or shared ledger/index updates were used.
