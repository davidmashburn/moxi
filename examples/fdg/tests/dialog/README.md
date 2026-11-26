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

## Recorded verification

The refreshed GTK replay is based directly on `cf68880c3b051611a48c93d857252cb7ee2836fb`. It reuses the reviewed ELF built from `b95bfbac3ed7c3d5ca870c51ff98052c29233534` and the synthetic [four-node fixture](../fixtures/export.json). All 269 files in `src`, `native`, `examples/fdg/src` and `examples/fdg/native` match the retained build source byte for byte. Only replay code and evidence changed; neither platform was rebuilt for this repair. The [verification record](evidence/verification.json) records the exact replay source digests and environment; [result.json](evidence/result.json) records capture times, recognized text, screenshot digests and reopened-export assertions. The earlier macOS and Linux export checks called the exporter directly during replay; this GTK replay uses Export… and the real chooser for every destination.

| Scenario | Expected and observed | Capture |
| --- | --- | --- |
| GTK Save SVG | The chooser accepted the typed destination. Reopened XML contains the three selected-neighborhood labels, two edge widths and the loop. | [Chooser](evidence/current.svg-chooser.png) · [Result](evidence/current.svg-result.png) |
| GTK Cancel | Escape dismissed the chooser, the viewer displayed “Export cancelled” and the export directory retained its original contents. | [Chooser](evidence/cancelled.svg-chooser.png) · [Result](evidence/cancelled.svg-result.png) |
| GTK Save PNG | Pillow decoded the 1068×560 output. The three colored node centers match the independently rasterized PDF. | [Chooser](evidence/current.png-chooser.png) · [Result](evidence/current.png-result.png) · [PNG](evidence/current.png) |
| GTK Save PDF | PDFium reopened one page, extracted the expected Unicode text and rasterized it at 96 DPI. | [Chooser](evidence/current.pdf-chooser.png) · [Reopened page](evidence/reopened-pdf.png) |
| GTK Save again | The final SVG matched the first SVG byte for byte. Native label ink and node centers were present in the captured viewer. | [Chooser](evidence/recovered.svg-chooser.png) · [Result](evidence/recovered.svg-result.png) · [Assertions and digests](evidence/result.json) |
| Negative: invisible GTK chooser | The real chooser remained mapped with the correct X11 title but was moved outside the display. Two equal graph frames satisfied the old stability rule. The repaired capture timed out with no accepted chooser image or export. | [Rejected frame](evidence/negative/unpainted-chooser.png) · [Control record](evidence/negative/controls.json) |
| Negative: incorrect cancellation message | A private ELF copy replaced the sole `Export cancelled` literal with equal-length `Export incorrect`. The unchanged normal route saved SVG, opened the next chooser and cancelled. It exited nonzero at the visible-status assertion; destination SVG bytes remained unchanged. | [Rejected status](evidence/negative/wrong-cancellation.png) · [Control record](evidence/negative/controls.json) |
| AppKit Cancel (earlier run, retained) | The real panel opened and cancellation returned to the viewer. The only file in the destination was the post-cancel capture. | [App content](evidence/mac-cancel.png) |

Linux used Ubuntu 24.04.5 x86-64 under Docker emulation, GTK 4.14.5, X11 with Cairo software rendering, librsvg 2.58.0, Pillow 13.0.0 and pypdfium2 5.15.2. Each replay used a new private home, session bus and 1280×1024 Xvfb display, with the 1100×800 viewer and no window manager. Linux UI images are screenshots of that display. The retained reopened PDF image is a PDFium rasterization. Captures contain synthetic graph data and disposable container paths; PNG metadata, PDF text/metadata, SVG text, filenames and the textual diff were inspected for private content.

The retained macOS 27.2.1 ARM64 run used a 1100×800 AppKit content view at 2× scale. The cancellation capture was taken at 2026-11-26 02:50:47 UTC. Its binary SHA-256 was `47c50d1b6722f43c9c21393b558f4739151cde4b7169f4316371e3008ac91692`. A separate earlier Mac attempt set the visible panel's filename and confirmed the temporary directory, then called AppKit's OK action. No output appeared before timeout. No new practical consent-free Save method was established during this repair, so Mac Save and reopen remain open and were not retried. Physical input, Wayland, VoiceOver, fresh compiler builds, clean distribution installation, the full repository suite and remote CI were not exercised.

Confidence is high for the exercised GTK/X11 replay and its two rejection cases. A failing supported-host rerun, a source/binary identity mismatch or a reopened-export discrepancy would change that assessment. Mac Save is unverified.
