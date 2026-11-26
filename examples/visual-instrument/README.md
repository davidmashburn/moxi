# V13 · Pulse instrument

Build a five-node instrument around the checked-in Signal Playground pulse WAV. From the repository root, run with Python 3.9+ and open the loopback address printed by the server.

```sh
PYTHONPATH=python python3 examples/visual-instrument/app.py
```

Select an output and input, then press **Connect**. Wire WAV source → Low-pass → Block RMS and fan Block RMS out to Trace and Recorder. The selects support Tab and letter navigation. **Load wired example** installs those four connections. For a filter bypass, wire WAV source directly to Block RMS. Each input accepts one upstream output. Sample streams and block features have distinct contracts.

**Record** retains one run. Adjust the low-pass coefficient and choose **Preview** (or press P with focus on a button) to compare the traces. Select a probe and scrub the block index to read the last sample, filter memory, or RMS and its logical timestamp. Escape discards the preview and restores the recorded controls. Record again to accept an edit, or **Undo record** to restore the preceding run and wiring. **Save recorded run** downloads its patch, coefficient, timing, and all 32 observation rows. Reloading the page reconnects to the same single instrument. Stopping the server clears its memory.

## Execution and failure

The source reads the first 1,024 signed little-endian mono PCM samples from the existing synthetic capture at 44,100 Hz. Every run starts with filter memory zero. For each sample the filter adds α × (sample − memory) to its memory. State carries across 32-sample blocks. Block RMS reduces the selected upstream samples to one normalized amplitude. Block end time comes from the sample count. Browser redraws and wire inspection consume the last completed result without advancing the source clock.

Select 22,050 Hz to reject a rate mismatch before processing. Attempt WAV source → Recorder to reject a sample-to-feature wire without changing the patch. Select **Fail block 7** to interrupt RMS after seven successful blocks. The executor publishes only complete runs. Clear the fault and retry from sample zero. The preceding recording stays available throughout.

## Reproducible check

From the repository root, with Node 18+, Chrome and a locally available Puppeteer Core:

```sh
node examples/visual-instrument/check.cjs
```

Set `NODE_PATH` to the directory containing an existing `puppeteer-core` installation if needed, `CHROME` for a nonstandard Chrome executable, or `PYTHON` to select Python. The check starts a fresh server on a loopback port, drives a fresh headless Chrome profile and shuts both down. An optional output directory captures seven PNGs.

The check constructs the patch with the keyboard, records, probes block 31, compares button/P/script previews, rejects a scripted write, cancels an edit, rejects a rate and a wire, injects a processing failure, recovers, undoes, reloads and exercises the bypass at mobile width. The script adapter shares the preview operation with the panel and has a preview-only caller policy. This covers the V13 consumer portion of I20. The dedicated cohort scenario lives in the application-operations example.

The run covers a recorded synthetic source and a bounded fixed node palette. Independent authors constructing and diagnosing an instrument, assistive technology, physical acquisition, wall-clock scheduling, audio output, and other browser/platform combinations remain unverified. General-purpose node creation, cyclic feedback, and device integration are outside this slice.

Open the [offline slideshow](evidence/v13-visual-instrument/index.html) for seven captured states. The [manifest](evidence/v13-visual-instrument/manifest.json) gives the tested revision, fixture, viewport, actions and expected observations. All seven passed in headless Chrome. The automated check also verified identical recorded JSON after the failed attempt and after undo/reload. The downloaded file was checked through its HTTP endpoint. OS save dialogs and human or physical trials were skipped.

To validate the committed captures from the repository root, run `python3 scripts/demo_slideshows.py examples/visual-instrument/evidence --check`.
