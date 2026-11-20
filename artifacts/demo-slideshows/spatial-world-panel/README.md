# D08 native world-panel slideshow

Regenerated on published `d7fa3ed563948860f4baf18bcc9f3eb279197135`.
Read [REVIEW.md](REVIEW.md) for the six scenario outcomes, visual observations,
source comparison, checks and physical-input limits. [review.json](review.json)
records each reviewed frame/hash and the retained log hashes.

Verify the retained evidence from repository root:

```sh
python3 artifacts/demo-slideshows/spatial-world-panel/verify.py
```

Regenerate raw evidence and rerun the focused package/consumer checks:

```sh
pixi install --locked
python3 artifacts/demo-slideshows/spatial-world-panel/capture.py
bash examples/spatial-world-panel/check.sh --skip-build
```

[capture.py](capture.py) runs the published gallery with a 900-second command bound
(the original 240-second build bound timed out), copies build/replay logs locally,
and normalizes their provenance links. It changes no application or published
capture source. A new capture invalidates the existing visual review and log hashes;
review the new frames and refresh the review record before verification.

The [local slideshow](index.html) contains six real AppKit `cacheDisplay` offscreen
captures, including an experimental Metal perspective texture/depth pass. Pointer,
keyboard and text protocols are emulated/synthetic. These captures do not establish
desktop presentation, physical IME or assistive-technology acceptance. World-panel
promotion remains [rejected](decision.json); screen-space editing is the supported
alternative within this experiment.

[provenance.json](provenance.json) records all 189 source hashes, clean scoped
status, compiler/SDK versions, binary hash and portable [replay logs](review-logs/replay-2.log).
[manifest.json](manifest.json) references all six PNG hashes;
[timing.json](timing.json) contains 3 cold / 90 warm observations, without a
performance guarantee. PNGs and HTML remain **ignored and available locally**;
metadata is tracked, while new review files/tooling/logs are untracked for integration.
The [experiment README](../../../examples/spatial-world-panel/README.md) describes
ownership, copying and unsupported capabilities. A source change requires recapture;
committing only these evidence files does not change the captured source fingerprint.
