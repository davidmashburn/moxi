# Deferred proposal implementation

The approved contract is the [master list on the planning branch](https://github.com/davidmashburn/moxi/blob/project-planning/DEFERRED-IMPLEMENTATION-MASTER.md),
recorded at planning commit `fe79a32`. Implementation starts from `6c92242` on
`feat/deferred-proposals`. Planning history is not merged into the product.

The [delivery ledger](deferred-implementation.json) tracks all 50 independent
plans: 28 feature/platform tracks, 15 vision experiments, and seven additional
idea tracks. The other 14 idea briefs are acceptance scenarios mapped into those
consumers by the approved master list. Scope descriptions link to source plans
relative to the planning branch, not this implementation checkout.

Each plan receives a separate Astra High worker in an isolated checkout. The
integrator reviews changes, runs focused validation, commits each coherent
slice locally and integrates dependencies before starting dependent work.
No remote publication is part of this task.

An implemented state requires executable evidence for the scoped behavior.
An experiment can complete with a negative feasibility result, but that does
not establish support for the target. Partial and blocked rows retain their
missing gates explicitly. Screenshots, compilation and automated checks do not
stand in for independent usability, scientific accuracy or hardware acceptance.
The previously paused VoiceOver session remains paused.

The browser and server-backed reducer baselines are preserved in `82e0578` and
`7cc89f7`. Their focused build/probe checks passed on November 6, 2026. These
are starting points for P01/P02, not completion of those plans.

See [demo slideshow capture and manifest instructions](demo-slideshows.md).
The local gallery will be `artifacts/demo-slideshows/index.html`. Missing
captures stay missing until the corresponding demo actually runs.
