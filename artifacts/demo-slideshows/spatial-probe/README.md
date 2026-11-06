# Spatial-probe captures

Run `python3 experiments/spatial-probe/gallery.py` from the repository root.
This builds both real candidates, executes focused assertions/measurements and
captures the live Moxi NSWindow content view through AppKit `cacheDisplay`.
Open `index.html` for the offline slideshow with keyboard navigation and contact
sheet. PNGs and self-contained HTML remain local review artifacts under the
repository's existing ignore rules; JSON provenance/measurements are compact.

These are genuine native content-view captures driven by scripted native mouse
and key callbacks, plus an explicitly synthetic host wheel packet. They exclude
window chrome, compositor effects and physical-device behavior and are classified
as `offscreen-render`. No screen or microphone recording, VoiceOver, device configuration, external communication or
production writes are performed. Resource recreation and comparisons execute
before capture; these are not illustrative mockups.

The manifest uses `scripts/demo_slideshows.py`'s schema. `revision` identifies the
base commit; `fixture` and `provenance.json` identify the actual source and scoped
working-tree status; PNG hashes identify captures. Timings describe this machine/run only; see the
experiment README for definitions and acceptance limits. The gallery script writes
only this demo's index; integration owns updating the shared gallery master index.
