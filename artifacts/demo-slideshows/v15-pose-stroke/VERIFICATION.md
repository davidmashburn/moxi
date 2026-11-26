# V15 Moxi consumer verification

The normal loopback consumer renders both brushes through compiled Mojo using
Moxi `ScenePath`, `Scene.append_typed_path`, and
`SvgSceneRenderer.render_scene`. Browser interactions request those scenes before
committing controller state. Rendering failure retains the previous frame; there
is no substitute brush renderer.

Tested source: `9c8a19585f6c4cefac0996354e1597bde7b13951`, based on
`caa6e4addf3559138ca12282431a6feb19860b50`. The source tree was clean when the
captures were made at `2026-11-26T02:57:02.181096+00:00`. Evidence changes made
afterward do not alter the tested source.

## Reproduce

Follow the build, host, regression, and capture commands in the
[consumer README](../../../examples/pose-stroke/README.md). The host serves only
loopback; the gallery runner starts its own host and temporary Chrome context.
Inputs are eleven authored numeric samples and synthetic authoring/error cases.
No camera, human, physical device, remote service, or external account is used.

The build used the repository-pinned Mojo 1.1.0 (`8189361e`) environment, with the
include path pointing at this checkout's `src`. Build succeeded with one linker
warning: an object targeted macOS 27.2 while the link target was 27.0. The binary
ran on the recorded Darwin 27.2.0 arm64 host. Its SHA256 was
`e66bb8ab579dc3d09353687a3f83856f1676c09b715393589c499798034f7fc1`.
The binary is a local build product, not a committed artifact.

## Observed results

- Model regression passed: 100 exact replays per mode and 1,100 seeded perturbed
  widths per mode. Direct RMS/max: 0.2271/0.8518 px; interpolated: 0.1521/0.5915 px.
  Calibration validation, curve edits, versioned save/reopen and no-jump remapping
  also passed.
- All four consumer tests passed through actual HTTP, Mojo and Moxi rendering,
  including comparison with direct executable output, malformed request rejection,
  origin restrictions, and failure when the renderer is absent.
- All four slideshow tests passed. Manifest dimensions and all eleven image
  SHA256 values were verified; committed deck content matches the manifest renderer.
- Chrome 158.0.8127.37 with Playwright 1.65.2 / Python 3.12.12 passed all five
  browser scenarios at 960×1000 and 390×844. All eleven default replay states and
  widths matched an independent table. The response SVGs matched the mounted
  scenes and the sample-four native output.
- Keyboard control, narrow layout, edited calibration, save/reopen after reload
  and in another tab, malformed saved data rejection, hold/reacquisition, and
  synthetic render failure/retry passed. The offline deck decoded all eleven
  captures and passed keyboard/contact-sheet navigation. No page errors or
  external requests were observed.
- Visually inspected wide and narrow replay captures, the reopened mapping and
  the retained scene after rendering failure. Labels and displayed widths matched
  the recorded states; controls remained readable without horizontal overflow.

The [browser record](browser-record.json) contains source and binary hashes,
environment, local URL, fixture, steps, expected/observed outcomes, and capture
links. The [manifest](manifest.json) pins the images. Open the
[offline deck](index.html) to review them. These are implementation verification
results, not an independent review.

## Limits and remaining integration

Confidence is **high** for the tested synthetic consumer and saved calibration
flows. A failure of the native-output comparison, clean rebuild, or recorded
Chrome scenarios would change that conclusion. The captures demonstrate the
bounded consumer; they do not establish full V15 acceptance.

Skipped: the full Mojo/native suite and CI, other browsers, screen-reader use,
browser/OS restart persistence, live camera/tracker/model/license evaluation,
human or physical repeatability, comfort, end-to-end live latency, accidental
activation, simultaneous multi-parameter fluency, and human slider comparisons.
Shared T3 preview DOM inspection worked; its screenshot tool timed out twice, so
the visual evidence uses installed Chrome instead.

The shared slideshow index and implementation ledger were left untouched for the
parent task. No push, external publication, or shared-system update was performed.
