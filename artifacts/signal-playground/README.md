# Moxi Signal Playground

Open `index.html` for four native frames with matching audio, or play `walkthrough.mp4`. All walkthrough assets live in this directory.

Run the native app from the repository root:

```sh
pixi run signal-playground
```

Press Play, drag a waveform dot vertically, and watch the harmonic bars change. Sine, Triangle, and Pulse provide quick comparisons. The app starts muted and plays at a fixed 220 Hz with low output gain.

The demonstration connects Moxi's pointer input and Metal scene rendering to a Mojo waveform model. Sixteen editable points produce one periodic 128-sample table. A discrete Fourier transform measures its harmonics; a small macOS AudioToolbox bridge plays that same table. Edits center and bound the waveform. Audio is an example-specific bridge, not an existing cross-platform Moxi audio API.

The frames are exported directly by `MacOSMetalRenderer` after scripted interactions with the same model used by the live app. They are renderer captures without operating-system window chrome. The WAV clips use the same synthesis interpolation as live playback. They do not record the physical speaker output.

Regenerate the assets (macOS with Metal, Pixi, and ffmpeg):

```sh
pixi run signal-playground-capture
```

Sources: `examples/signal_playground.mojo`, `examples/signal_playground_model.mojo`, `examples/signal_playground_capture.mojo`, and `native/signal_playground_audio.c`. Capture checks cover pointer editing/release, preset switching, bounded zero-mean samples, expected harmonic patterns, and zero renderer fallbacks. This MVP uses pointer controls and a fixed pitch; keyboard accessibility and cross-platform audio are not implemented.

Final verification: the native build, capture assertions, pixel/audio checks, native scene parity, and whitespace checks passed. All four slideshow images and two-second audio clips loaded in the browser. Live native checks confirmed preset switching, click-to-edit waveform changes, and successful audio start/stop. Automated continuous dragging did not produce a visible edit, so live dragging remains unverified despite the model-level drag tests passing. Physical speaker output was not independently listened to, and the full repository test suite was not run.
