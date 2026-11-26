# Native FDG Save dialog replay

The GTK replay launches the compiled viewer on a new 1280×1024 Xvfb display with a private home directory and session bus. It pauses the graph, searches for `A`, selects the result and enables Neighbors. Each destination goes through the viewer's Export… button and GTK file chooser. The driver types the absolute path, presses Return or Escape, and waits for the chooser to close.

On Linux, build FDG using the existing [Linux instructions](../../P06.md#linux-lane). Run the following command with Xvfb, xauth, xdotool, dbus-run-session, rsvg-convert, Pillow with XCB support, pypdfium2, and Tesseract with English data (`tesseract-ocr` and `tesseract-ocr-eng` on Ubuntu) available. Tesseract is a replay dependency, not a viewer dependency.

```sh
python examples/fdg/tests/dialog/linux.py
```

The script prints its newly allocated temporary directory. It retains the actual files, screenshots of every chooser and response, binary and export digests, and the [reopen verifier](../verify_artifacts.py) output. A timeout or failed assertion exits nonzero. Each capture first reads the expected text from the X11 screen pixels, then requires a second identical frame. A mapped title or an unchanged earlier graph frame cannot satisfy the check. Choosers must show the typed filename and both Cancel and Save; response captures must show the expected status. OCR ignores whitespace differences, including inserted spaces around filename punctuation, but requires the expected characters without fuzzy matching. The replay fixes the locale to English and uses the initial window geometry.

Cancellation must visibly say “Export cancelled” and leave the directory contents byte for byte unchanged. The before/after digests are retained in `result.json` alongside each capture's text regions, recognized text, timestamp and screenshot digest. Timeout images and recognized text are retained separately and never marked verified. Another Save after cancellation must reproduce the original SVG exactly.

The pixel regression tests use the retained real GTK/X11 images, including both negative controls, without targeting a desktop session:

```sh
python -m unittest discover -s examples/fdg/tests/dialog -p test_capture.py
```

On a logged-in Mac, build with `bash examples/fdg/scripts/build.sh` and run the cancellation check.

```sh
python3 examples/fdg/tests/dialog/mac_cancel.py
```

A test library loaded into that child presses its accessible Export… control, cancels its visible NSSavePanel using AppKit and checks for the viewer's “Export cancelled” status. It retains the app content capture in a fresh temporary directory. The check requires only the cancellation capture to exist in the destination.

For Save → Cancel → Save in each of SVG, PNG and PDF, install Pillow, pypdfium2, Tesseract with English data and rsvg-convert, then run:

```sh
python3 examples/fdg/tests/dialog/mac.py
```

This replay owns one private child of the freshly built app. Its test library pauses the synthetic graph and selects the neighborhood through the viewer's accessibility controls; it does not use VoiceOver. It configures the disposable directory and filename **before** calling the original `NSSavePanel.runModal`. For each `request.json` with `ready: true`, an external native input driver must inspect the actual chooser and send Return for Save or Escape for Cancel. The response is never stubbed, and an unexpected Save URL stops the child before the exporter can write. The driver must retain its own chooser observations; the replay's AppKit content captures do not capture the remote chooser.

Each response, directory digest, result capture and timestamp is retained separately. The verifier requires rendered status text as well as the accessibility label, unchanged directory bytes after Cancel, matching recovery exports, and independent SVG/PNG/PDF reopen checks. A missing response, child failure or failed assertion exits nonzero with `result.json` marked incomplete. `--local-events` tries process-local NSEvents as a diagnostic; it timed out here and is not an established replacement for an external driver. Neither command requests TCC permissions.

## Recorded verification

The retained GTK evidence was produced for `4bd6636`, directly from `cf68880c3b051611a48c93d857252cb7ee2836fb`. It reuses the reviewed ELF built from `b95bfbac3ed7c3d5ca870c51ff98052c29233534` and the synthetic [four-node fixture](../fixtures/export.json). All 269 files in `src`, `native`, `examples/fdg/src` and `examples/fdg/native` match the retained build source byte for byte. That repair changed only replay code and evidence. The [verification record](evidence/verification.json) records the exact replay source digests and environment; [result.json](evidence/result.json) records capture times, recognized text, screenshot digests and reopened-export assertions. The earlier macOS and Linux export checks called the exporter directly during replay; this GTK replay uses Export… and the real chooser for every destination. The AppKit follow-up leaves these GTK files and artifacts unchanged; all four GTK pixel regression tests passed again.

| Scenario | Expected and observed | Capture |
| --- | --- | --- |
| GTK Save SVG | The chooser accepted the typed destination. Reopened XML contains the three selected-neighborhood labels, two edge widths and the loop. | [Chooser](evidence/current.svg-chooser.png) · [Result](evidence/current.svg-result.png) |
| GTK Cancel | Escape dismissed the chooser, the viewer displayed “Export cancelled” and the export directory retained its original contents. | [Chooser](evidence/cancelled.svg-chooser.png) · [Result](evidence/cancelled.svg-result.png) |
| GTK Save PNG | Pillow decoded the 1068×560 output. The three colored node centers match the independently rasterized PDF. | [Chooser](evidence/current.png-chooser.png) · [Result](evidence/current.png-result.png) · [PNG](evidence/current.png) |
| GTK Save PDF | PDFium reopened one page, extracted the expected Unicode text and rasterized it at 96 DPI. | [Chooser](evidence/current.pdf-chooser.png) · [Reopened page](evidence/reopened-pdf.png) |
| GTK Save again | The final SVG matched the first SVG byte for byte. Native label ink and node centers were present in the captured viewer. | [Chooser](evidence/recovered.svg-chooser.png) · [Result](evidence/recovered.svg-result.png) · [Assertions and digests](evidence/result.json) |
| Negative: invisible GTK chooser | The real chooser remained mapped with the correct X11 title but was moved outside the display. Two equal graph frames satisfied the old stability rule. The repaired capture timed out with no accepted chooser image or export. | [Rejected frame](evidence/negative/unpainted-chooser.png) · [Control record](evidence/negative/controls.json) |
| Negative: incorrect cancellation message | A private ELF copy replaced the sole `Export cancelled` literal with equal-length `Export incorrect`. The unchanged normal route saved SVG, opened the next chooser and cancelled. It exited nonzero at the visible-status assertion; destination SVG bytes remained unchanged. | [Rejected status](evidence/negative/wrong-cancellation.png) · [Control record](evidence/negative/controls.json) |
| AppKit Cancel | The existing cancellation check passed again with the fresh build. It uses AppKit's Cancel action, not a synthetic Escape key. Its capture is byte-identical to the retained earlier capture. | [App content](evidence/mac-cancel.png) |
| AppKit Save SVG and reopen | An exploratory probe configured the real panel before opening it. External native Return completed Save; the viewer rendered the saved status. XML parsing and independent librsvg rendering reopened the saved 1068×560 Unicode neighborhood with five edge segments. | [Result](evidence/mac/current.svg-result.png) · [SVG](evidence/mac/current.svg) · [Reopened SVG](evidence/mac/reopened-svg.png) |
| AppKit recovery Save, PNG and PDF | Incomplete. Subsequent native automation could not select the live app window (`cgWindowNotFound`). The new nine-step replay stopped at its first SVG panel, exited nonzero and produced no exports. Process-local Return also timed out. | [AppKit verification record](evidence/mac/verification.json) |

Linux used Ubuntu 24.04.5 x86-64 under Docker emulation, GTK 4.14.5, X11 with Cairo software rendering, librsvg 2.58.0, Pillow 13.0.0 and pypdfium2 5.15.2. Each replay used a new private home, session bus and 1280×1024 Xvfb display, with the 1100×800 viewer and no window manager. Linux UI images are screenshots of that display. The retained reopened PDF image is a PDFium rasterization. Captures contain synthetic graph data and disposable container paths; PNG metadata, PDF text/metadata, SVG text, filenames and the textual diff were inspected for private content.

The macOS follow-up rebuilt `4bd6636` on macOS 27.2.1 ARM64 and used a 1100×800 AppKit content view at 2× scale. The [AppKit record](evidence/mac/verification.json) separates the successful exploratory SVG Save from the incomplete new replay and records their identity limits. AppKit result images are captures of the app's own content view, not screen captures. A cached remote chooser image was black and was rejected as paint evidence. The SVG result contains only synthetic labels and a disposable temporary path.

Calling the configured panel's OK action still hung until the outer 45-second timeout; process-local Return routes also failed, including a key-equivalent attempt whose responder was `NSRemoteView`. Since external native Return did save SVG, the OK-action timeout is insufficient evidence of an exporter defect. No application change was justified. Confidence is high in the observed SVG Save/reopen and GTK regressions, and moderate in attributing the failed probes to input delivery; the native tool's window-selection failure remains unexplained. A supported-host nine-step run, a source/binary identity mismatch or a reopened-file discrepancy would change this assessment. Recovery Save, normal Escape cancellation, AppKit PNG/PDF Save and reopen, a fresh live GTK replay, physical input, Wayland, VoiceOver, clean distribution installation, the full repository suite and remote CI were not verified.
