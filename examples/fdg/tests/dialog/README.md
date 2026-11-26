# Native FDG Save dialog replay

The GTK replay launches the compiled viewer on a new 1280×1024 Xvfb display with a private home directory and session bus. It pauses the graph, searches for `A`, selects the result and enables Neighbors. Each destination goes through the viewer's Export… button and GTK file chooser. The driver types the absolute path, presses Return or Escape, and waits for the chooser to close.

On Linux, build FDG using the existing [Linux instructions](../../P06.md#linux-lane). Run the following command with Xvfb, xauth, xdotool, dbus-run-session, rsvg-convert, Pillow with XCB support, and pypdfium2 available.

```sh
python examples/fdg/tests/dialog/linux.py
```

The script prints its newly allocated temporary directory. It retains the actual files, screenshots of every chooser and response, binary and export digests, and the [reopen verifier](../verify_artifacts.py) output. A timeout or failed assertion exits nonzero. The cancellation check compares the directory contents byte for byte. Another Save after cancellation must reproduce the original SVG exactly.

On a logged-in Mac, build with `bash examples/fdg/scripts/build.sh` and run the cancellation check.

```sh
python3 examples/fdg/tests/dialog/mac_cancel.py
```

A test library loaded into that child presses its accessible Export… control, cancels its visible NSSavePanel using AppKit and checks for the viewer's “Export cancelled” status. It retains the app content capture in a fresh temporary directory. The check requires only the cancellation capture to exist in the destination.

## Recorded run

Both binaries were built from `b95bfbac3ed7c3d5ca870c51ff98052c29233534` using the existing Mojo compiler and the synthetic [four-node fixture](../fixtures/export.json). Only test code and evidence were added. The earlier macOS and Linux export checks called the exporter directly during replay.

| Scenario | Expected and observed | Capture |
| --- | --- | --- |
| GTK Save SVG | The chooser accepted the typed destination. Reopened XML contains the three selected-neighborhood labels, two edge widths and the loop. | [Chooser](evidence/current.svg-chooser.png) · [Result](evidence/current.svg-result.png) |
| GTK Cancel | Escape dismissed the chooser, the viewer displayed “Export cancelled” and the export directory retained its original contents. | [Chooser](evidence/cancelled.svg-chooser.png) · [Result](evidence/cancelled.svg-result.png) |
| GTK Save PNG | Pillow decoded the 1068×560 output. The three colored node centers match the independently rasterized PDF. | [Result](evidence/current.png-result.png) · [PNG](evidence/current.png) |
| GTK Save PDF | PDFium reopened one page, extracted the expected Unicode text and rasterized it at 96 DPI. | [Chooser](evidence/current.pdf-chooser.png) · [Reopened page](evidence/reopened-pdf.png) |
| GTK Save again | The final SVG matched the first SVG byte for byte. Native label ink and node centers were present in the captured viewer. | [Result](evidence/recovered.svg-result.png) · [Assertions and digests](evidence/result.json) |
| AppKit Cancel | The real panel opened and cancellation returned to the viewer. The only file in the destination was the post-cancel capture. | [App content](evidence/mac-cancel.png) |

Linux used Ubuntu 24.04.5 x86-64 under Docker emulation, GTK 4.14.5, X11 with Cairo software rendering, librsvg 2.58.0, Pillow 13.0.0 and pypdfium2 5.15.2. The result JSON records capture time. Linux UI images are screenshots of the isolated display. The retained reopened PDF image is a PDFium rasterization.

macOS 27.2.1 ARM64 ran a 1100×800 AppKit content view at 2× scale. The cancellation capture was taken at 2026-11-26 02:50:47 UTC. Its binary SHA-256 was `47c50d1b6722f43c9c21393b558f4739151cde4b7169f4316371e3008ac91692`. A separate Mac attempt set the visible panel's filename and confirmed the temporary directory, then called AppKit's OK action. No output appeared before timeout. Mac Save and reopen through the panel remain unverified. Physical input, Wayland and VoiceOver were outside this run.
