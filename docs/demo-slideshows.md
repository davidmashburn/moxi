# Demo screenshot slideshows

Capture the built application, then create a manifest in
`artifacts/demo-slideshows/<demo-id>/manifest.json`. Keep the original PNGs in
that directory. Each demo and distinct plot family has its own sequence.
Do not reuse a polished end state as evidence of an intermediate interaction.

Use the collaborative preview for browser captures. For native demos, package
the executable in a local `.app` bundle with an `Info.plist`, bind that app with
the native UI tool, and save the bytes returned by its screenshot operation.
This captures just the application window and excludes unrelated desktop content.
The native UI tool can also exercise actual controls before capturing the result.
The existing `native/macos_window_bounds.c`/`screencapture` workflow is an
alternative when the terminal has window-capture access. A running window may
be accessible to the native UI tool while that helper cannot enumerate it.
Record offscreen renders explicitly; they are not native-window evidence.

The version 1 manifest has these required fields:

```json
{
  "version": 1,
  "demo_id": "demo-name",
  "title": "Demo name",
  "scenario": "The actual tested scenario",
  "revision": "abcdef0",
  "host": "macOS arm64",
  "backend": "Cocoa",
  "scale": 2,
  "fixture": "fixture name or seed",
  "reproduce": "Exact build, run and interaction instructions",
  "slides": [
    {
      "phase": "initial",
      "capture_kind": "native-window",
      "image": "01-initial.png",
      "dimensions": [1600, 1000],
      "caption": "Initial state",
      "action": "Launch the specified fixture",
      "expected": "Describe the expected visible state"
    }
  ]
}
```

The abbreviated example above needs additional slides before validation passes.
Each sequence must contain `initial`, `interaction`, `result`, and `recovery`
phases. Recovery can show cancel, undo, rejection, stale work or reconnection.
Capture kinds are `native-window`, `browser`, `offscreen-render`, and `terminal`.
Dimensions are physical PNG pixels; scale records device pixel ratio. Revision
identifies the committed source actually captured. Captions and commands are
treated as text, never executed by the gallery generator.

```sh
python3 scripts/demo_slideshows.py --check
python3 scripts/demo_slideshows.py
python3 tests/demo_slideshows_test.py
```

The generator validates required evidence and image metadata before writing
anything. It emits an index and a self-contained HTML slideshow per demo with
embedded images, previous/next controls, arrow-key navigation, captions and a
contact sheet. The original PNGs and manifests remain available separately.
Keep compact manifests and reproduction recipes in Git. Images and generated
HTML remain local artifacts by default.

Screenshots do not prove scientific correctness, responsiveness, physical IME,
screen-reader behavior or independent human usability. Track those acceptance
gates separately. Missing hardware produces a missing sequence, not a mockup.
