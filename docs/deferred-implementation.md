# Deferred proposal implementation

All 28 proposals reopened from the November 9 baseline now have runnable results on
main. Seven completed their bounded experiments and 21 have partial implementations.
Across all 50 tracks, seven are implemented, nine completed their experiments and
34 are partial as of November 26, 2026. The [delivery ledger](deferred-implementation.json)
records the evidence and remaining acceptance criteria for each track.

The [master plan on the planning branch](https://github.com/davidmashburn/moxi/blob/project-planning/DEFERRED-IMPLEMENTATION-MASTER.md)
defines 28 feature and platform tracks, 15 vision experiments and seven additional
idea tracks. Fourteen other idea briefs map into those consumers as acceptance
scenarios. Links to design briefs in the ledger resolve on the planning branch.
Planning commit `fe79a32` records the approved scope. Implementation began at
`6c92242`, and verified changes were published on main.

An implemented track has executable evidence for the scoped behavior. A completed
experiment can establish a feasibility limit. Each partial track lists the
remaining work, including any independent usability, scientific or hardware
checks it requires. VoiceOver verification remains paused.

The [gallery catalog](../artifacts/demo-slideshows/index.html) links the available
walkthroughs and reproduction instructions. The [capture guide](demo-slideshows.md)
explains how to regenerate and validate evidence. The original browser and
server-backed reducer baselines are preserved in `82e0578` and `7cc89f7`.
