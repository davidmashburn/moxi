# Mind-map native replay

Run `pixi run d04-mindmap-replay` on macOS with an available AppKit session. The task compiles the real native app, runs its deterministic public-input replay, captures its actual content view with `cacheDisplayInRect`, records source/PNG SHA256 values, and uses `scripts/demo_slideshows.py` schema v1 to render only this demo's `index.html`. PNG and HTML outputs remain ignored.

The manifest identifies the build revision and any scoped dirty sources. The recipe snapshots revision and source hashes before compilation and refuses to write provenance if they change during build/replay. Rebuild and recapture after integration; a source hash mismatch invalidates prior capture provenance. Sources include Mojo imports, native `.m` and `.h` files, original fixtures, tasks, and capture scripts. The inventory conservatively includes the native directory; it does not imply all backends ran.

F2 crosses AppKit's `keyDown:` event queue. Other replay input is supplied as public `Event` values or the app's actual public command entrypoint. Pointer replay uses displayed header/destination geometry. The production loop polls real window input and uses the same controller and renderer. No frame is a mockup, diagram, HTML UI, or reference-app screenshot.

These are **offscreen-render** captures of actual AppKit content views, not `native-window` captures. They establish recorded transitions, not physical IME, VoiceOver, independent usability, latency, allocation, GPU/presentation, or expanded 10,000-topic native acceptance. VoiceOver remained paused.

Logs: `/tmp/moxi-d04-native-build.log`, `/tmp/moxi-d04-native-replay.log`, `/tmp/moxi-d04-manifest.log`. Disposable save/recovery fixture: `/tmp/moxi-d04-replay-<monotonic-time>.moxi` and its `.recovery`/`.lock` siblings. Each run uses a unique fixture path printed in the replay log.

The replay includes commit-start, 90 ms midpoint, 180 ms completion and reduced-motion frames. These use deterministic public frame ticks; the interactive host uses its monotonic clock and the macOS Reduce Motion preference. Animation is derived presentation and adds no semantic undo steps.
