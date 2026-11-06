# D08 native world-panel slideshow

Reproduce from repository root: `python3 examples/spatial-world-panel/gallery.py`.
Then run `bash examples/spatial-world-panel/check.sh --skip-build` for clean-package
consumer/application checks and focused D06/D07 regressions. See the experiment
README for interaction, ownership, copying and unsupported-capability details.

These are genuine AppKit `cacheDisplay` offscreen renders of the running native
application. The world panel is a Metal perspective texture in a depth pass.
They are not desktop/compositor captures or physical input acceptance evidence.

`provenance.json` records pre-build source hashes and matching post-replay hashes,
revision, scoped dirty status, exact compiler/SDK/Mojo versions and executable hash.
`timing.json` contains small cold/warm distributions; `decision.json` states the
negative promotion gate. `manifest.json` uses the existing slideshow render schema.
PNG/HTML remain ignored. Parent integration must rebuild and recapture after commit.
