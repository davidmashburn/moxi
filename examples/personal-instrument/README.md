# Phrase desk · V12

Shape an eight-step melody by applying accent or note length to individual steps. The pitches come from the first eight values in the repository's workbench-tail CSV, rounded to semitone offsets from middle C. Play phrase schedules the result with Web Audio at four steps per second.

Run from the repository root with Python 3.9+.

```sh
PYTHONPATH=python python3 examples/personal-instrument/app.py
```

Open http://127.0.0.1:8182/. Click a note, adjust Input, then Apply to step. Alternatively, Tab to Keyboard pad, change input with ↑ / ↓, apply with Space and advance with →. Next step and → wrap around the same eight steps. Shortcuts belong to the focused pad.

The editor binds Apply to one supported operation. Change the output midpoint to bend the two-segment response curve. Its endpoints stay at 0% and 100%. Moxi PlotSpec and the Python SVG renderer draw the same 101 integer input/output pairs used during performance. Compare Draft with the active step readout, then Save mapping to install it. Restore defaults reinstalls linear accent control. Reopening at the same origin restores the mapping and composition. Each uses a separate local storage record. An unreadable mapping activates defaults with a recovery message. Restore defaults repairs the stored record. A failed write leaves the previous value active. Selection and input position start fresh on reload.

## Reproduce the interaction check

With the server running, run the following in another shell from the repository root. The check uses local Node.js, an installed Chrome and a locally resolvable playwright-core package. When using an existing installation outside the repository, set NODE_PATH to its node_modules directory. The browser opens an isolated, temporary profile. Set PORT in the check environment if using the server's --port option.

```sh
node examples/personal-instrument/check.cjs
```

Pass a temporary output directory as the final argument to capture the four screenshot states. The check exercises the two control routes, the independent draft, reload persistence, an unsupported mapping version, explicit recovery, write failure, step wraparound, narrow viewport overflow and audio scheduling.

## Coverage and remaining evidence

- **V12 / I09** — The performer chooses the operation and curve for one panel control and reopens the saved panel against the edited score. Arbitrary control extraction from the data workbench remains outside this musical example.
- **I12** — Replacing a supported mapping retains the score and pad node. Failed writes retain the previous active calculation. Arbitrary live code replacement, compiler failure and editor caret retention remain open.
- **I17** — Pointer and keyboard exercise the same operations and score. Controls expose step names, selection and focus. Screen-reader navigation and switch-device use await direct trials.
- The fixed transition advances through the phrase and wraps. Response curves are editable. User-authored navigation graphs and key sequences remain open.
- Automated browser checks observe scheduled playback. Audibility, physical input comfort, independent configuration authoring and repeat use by people with different interaction preferences require human observation.
