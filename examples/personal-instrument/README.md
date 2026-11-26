# Phrase desk · V12

Shape an eight-step melody with a personal panel of Accent and Length modes. Extract supported phrase controls, build their response curves, and edit the mode graph that Next follows. The pitches come from the first eight workbench-tail CSV values, rounded to semitone offsets from middle C. Play phrase schedules the score with Web Audio at four steps per second.

## Run and author a panel

Run from the repository root with Python 3.9+:

```sh
PYTHONPATH=python python3 examples/personal-instrument/app.py
```

Open http://127.0.0.1:8182/. The initial panel has one Accent mode. Select a note, adjust Input, then Apply to step. Alternatively, focus Keyboard pad: ↑ / ↓ change input, Space applies, and → follows the installed Next transition. Shortcuts belong to the focused pad. The installed mode buttons also allow direct mode selection.

1. Open **Phrase controls · extract into your panel**. Its two native sliders directly edit accent/length on the selected score step. **Extract Length control** adds that supported control as a new draft mode, independently of the score and installed panel.
2. In Mapping editor, select **Accent**, set Output at half input to **75**, set On Next to **Length**, and choose **Keep this step**. Select **Length**, set its midpoint to **37**, and set Next to **Accent / Advance one step**. The graph displays both directed transitions. **Mode on reopen** chooses the initial mode; changing the editor selection does not change the performance mode.
3. **Build preview** validates and builds the draft curves without installing them. Compare the draft plot/readout with the installed Performance readout. **Save mapping** builds and saves the entire panel before activating it. Ctrl+Enter from the midpoint field saves while retaining that field's focus and DOM node. A save retains the current step, input, score and current mode if still present.
4. Reload at the same origin. The panel, graph, calculations and composition reopen. Selection and performance input restart at step 1 / 50%; the configured initial mode is restored. At step 3, Next now enters Length on step 3; a second Next enters Accent on step 4. The pointer buttons and pad Right/Space invoke the same transitions and score operations.

Each response is a bounded versioned calculation with endpoints 0% and 100% and an integer midpoint from 0 to 100. The local Python `/build` endpoint computes all 101 values using half-even rounding; Moxi PlotSpec renders those same values. Custom midpoint calculations are rebuilt on reopening. No user code is evaluated. Draft edits during a pending build invalidate that result; a later build cannot overwrite newer authoring.

## Configuration and recovery

Mapping and score still use separate local storage records, `moxi.phrase.v1.mapping` and `moxi.phrase.v1.score`. The score schema is unchanged. Valid v1 mappings (`version`, `operation`, `midpoint` with one of 25/50/75) become one self-looping mode in memory, retaining the old advance-and-wrap behavior and response. Reading v1 does not rewrite it. Explicit Save writes mapping v2 with independently versioned calculations:

```json
{
  "version": 2,
  "startMode": "accent",
  "modes": [
    {"id": "accent", "calculation": {"version": 1, "midpoint": 75}, "next": {"mode": "length", "step": "keep"}},
    {"id": "length", "calculation": {"version": 1, "midpoint": 37}, "next": {"mode": "accent", "step": "advance"}}
  ]
}
```

The bounded graph has one or two unique supported modes, a valid starting mode, and one Next edge per mode. Step actions are `keep` or `advance`. Unknown mapping/calculation versions, unsupported operations/actions, duplicate nodes, dangling edges and invalid curve parameters are rejected. Compatibility means the new desk reads v1; the old desk cannot read v2.

Open **Versioned configuration**, use **Copy saved to editor**, then edit or paste JSON and **Load draft**. This validates a v1/v2 document without changing the installed or saved mapping. A rejected import, failed calculation build, renderer failure, stale build or failed storage write leaves the prior installed/saved mapping and score intact. Invalid draft text remains available for correction. Successful calculation replacement retains the performance pad and editor nodes.

An unreadable saved mapping activates defaults with a recovery message and leaves its raw record untouched. A failed rebuild on opening a custom saved panel also temporarily activates defaults while retaining the stored panel for a later retry. A valid score survives either case. **Restore defaults** explicitly saves the default one-mode Accent panel; it does not reset the composition. A failed restore write retains the previous panel. Score recovery is independent of mapping recovery.

## Reproduce verification

The checks use Node.js, locally resolvable `playwright-core`, and installed Chrome in an isolated temporary profile. Set `NODE_PATH` to an existing node_modules directory if needed. No dependency installation is required. Both checks launch with `--mute-audio`; playback validation observes scheduling, not audibility.

With the server running:

```sh
node examples/personal-instrument/check.cjs /tmp/phrase-baseline
node examples/personal-instrument/graph-check.cjs /tmp/phrase-graph
```

Set `PORT` if using a non-default server port. The optional directories receive screenshots; the graph check also writes per-scenario expected/observed results, capture times, browser/viewport, Git revision and source SHA-256 hashes. It verifies the served HTML matches the tested checkout. Fault injection and storage fixture resets happen only inside the temporary browser profile.

The [mode-graph verification record](evidence/mode-graph/verification.md) includes fail-first evidence, steps, results and screenshots for the final source. The earlier [four baseline slides](evidence/personal-instrument/index.html) remain historical evidence for `5768f2b`.

## Coverage and open gates

- **V12 / I09:** bounded extraction of the same instrument's real Accent/Length controls, editable graph and response curves, preview/save/reopen, and recovery. Extraction across arbitrary applications or workbench controls is not demonstrated.
- **I12:** a real versioned calculation build/replacement, retained editor/pad nodes and score, invalid calculation and renderer failures retaining the last good active/stored panel. This is a bounded response builder; arbitrary live code, plugin loading, native editor caret behavior and general compiler replacement remain open.
- **I17:** real pointer/keyboard input produces the same full score using the changed transitions; pad focus, labels and selection are checked. No screen-reader or switch-device trial was performed.
- Human configuration authoring, repeat-use utility, motor comfort, physical/custom hardware and audibility remain open. No personal-utility or universal accessibility claim follows from an automated replay. Cross-browser/device, native-host and multi-tab synchronization checks, broad suite/CI and central master/gallery integration were not run or changed.
