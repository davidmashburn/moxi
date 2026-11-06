# D01 native Moxi captures

Follow the pinned prerequisites and build commands in
[the experiment README](../../../experiments/math-backends/README.md).
From the repository root in a macOS GUI session:

```sh
bash experiments/math-backends/run-demo.sh --capture /tmp/moxi-d01/captures \
  > /tmp/moxi-d01/demo.log 2>&1
PYTHONPATH=experiments/math-backends /tmp/moxi-d01/venv/bin/python \
  -m moxi_math_probe.gallery /tmp/moxi-d01/captures
open /tmp/moxi-d01/captures/index.html
```

The program launches the actual Moxi AppKit window, drives both real workers,
and exits after 27 captures. The slideshow embeds all images; adjacent originals,
manifest and frame intervals preserve the evidence. The manifest lists each
interaction and actual source/result state. No renderer changes are required.

OS screenshot capture was unavailable on the recorded host. These PNGs use
AppKit's cacheDisplay of the live window content view, not an offscreen Moxi
scene; they do not prove compositor or physical-display behavior. See
[the report](../../../experiments/math-backends/REPORT.md) for measured results
and unverified integration/distribution gates.
