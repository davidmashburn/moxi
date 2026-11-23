# Moxi project planning

This orphan branch holds durable proposals and decisions. Product code and
shipped-behavior documentation live on `main`; do not merge planning history
into implementation. Edit this branch in its dedicated planning worktree.

## Current status — November 23, 2026

The native package repair and one editable Demo Browser scene shipped at
`d7fa3ed`. All six hosted jobs passed, including the installed-package
consumer. The [gallery handoff](https://github.com/davidmashburn/moxi/blob/5d85208e820446d0ebd4072987fce1f39fa1e8ed/docs/deferred-pause-handoff.md)
records the subsequent review of 30 galleries against that implementation.
The [November 23 acceptance record](PROJECT-PLANNING.md#remaining-work-after-the-gallery-review)
covers contour references, installed Python rendering, packaged workbench behavior
and the measured world-panel caret mismatch.

The November 9 ledger counted 7 implemented proposals, 2 completed experiments,
13 partial tracks and 28 pending proposals. The gallery review preserves those
50 delivery states. VoiceOver remains paused.

| Start here | Purpose |
| --- | --- |
| [Current-state audit](CURRENT-STATE.md#current-audit--november-9-2026) | November 9 audit against `b2361c2`, with delivered scope and evidence limits |
| [Remaining work](PROJECT-PLANNING.md#remaining-work-after-the-gallery-review) | Current priorities after CI and gallery verification |
| [50-plan master list](DEFERRED-IMPLEMENTATION-MASTER.md#current-delivery-status) | Per-ID delivery status plus original scope, dependencies and storyboards |
| [Workbench hardening](WORKBENCH-HARDENING-PLAN.md) / [application validation](APPLICATION-VALIDATION-PLAN.md) | Existing native, performance and independent authoring acceptance |
| [Host architecture](CROSS-PLATFORM-HOST-ARCHITECTURE-PLAN.md) | Desktop profile and deferred host/GPU work |
| [Ecosystem convergence](ECOSYSTEM-CONVERGENCE-PLAN.md) | Partial plot waves/native Python and outstanding parity/distribution gates |

The structural [S2 decision](PROJECT-PLANNING.md#s2-oversized-struct-boundary--settled)
is settled: retain the five current owners under ADR-006. Do not reopen completed
structural or authoring work solely because an older proposal uses future tense.
Untouched P08–P11, E05–E06, V01–V15 and I10/I11/I13/I15/I18/I19/I20 remain deferred;
this reconciliation does not schedule them.

## Owning plans

- [Style, alignment and scrolling defaults](docs/design/style-layout-defaults.md)

- [Example authoring migration](docs/design/example-authoring-migration.md)
- [Browser API usability](docs/design/browser-api-usability.md) — proposed reusable
  mount lifecycle and second-application proof; observed November 20, 2026
- [Browser execution](docs/design/browser-execution.md),
  [server-backed views](docs/design/server-backed-views.md) and
  [Jupyter integration](docs/design/jupyter-integration.md)
- [FDG export/distribution](docs/design/fdg-port.md),
  [watershed app](docs/design/sws-port.md) and
  [deferred SWS4D](docs/design/sws4d-port.md)
- [Math backend comparison](docs/design/math-backend-experiment.md) and
  [math editor](docs/design/math-editing.md)
- [Canvas interaction](docs/design/canvas-interaction.md) and
  [mindmap](docs/design/mind-mapping.md)
- [Spatial renderer and applications](docs/design/3d-interaction.md)
- [NotImplemented component](docs/not-implemented-pattern.md)
- [UI architecture evolution plan](docs/design/ui-architecture-evolution-plan.md)
- [Editable demo source and live re-runs plan](docs/design/editable-demo-source-plan.md)
- [Idea collection](ideas/README.md),
  [composition experiments](ideas/README.md#composition-experiments),
  [rankings](ideas/RANKINGS.md) and
  [framework questions](ideas/FRAMEWORK.md)

## Historical research and decisions

These records retain their own experiment baselines and reasoning. Their old
recommendations are not a second active backlog; production extraction and the
current authoring migration supersede the earlier exploration where stated.

- [Authoring documentation and production extraction](docs/design/authoring-production.md)
- [Lifetime integration decision](docs/design/lifetime-integration-decision.md)
- [Explicit assignment and reset contract](docs/design/explicit-lifetime-contract.md)
- [Scoped identity and retained storage](docs/design/scoped-identity-retention.md)
- [Composition acceptance evaluation](docs/design/composition-acceptance.md)
- [Simple composition](docs/design/simple-composition.md)
- [Paint cost isolation](docs/design/paint-cost-isolation.md)
- [Typed-boundary confidence](docs/design/typed-boundary-confidence.md)
- [Selective method updates](docs/design/selective-method-updates.md)
- [Marko 6 Tags API reactivity](docs/design/marko-tags-reactivity.md)
- [State access and update work](docs/design/state-access-comparison.md)
- [Direct method bindings](docs/design/direct-method-binding.md)
- [Shared-document comparison](docs/design/shared-document-comparison.md)
- [Composition gate](docs/design/composition-gate.md)
- [Ownership decision](docs/design/ownership-decision.md)
- [Three complete form ownership designs](docs/design/form-ownership-comparison.md)
- [interactive source comparison](docs/design/form-ownership-comparison.html)
- [UI pattern inventory](docs/design/ui-pattern-inventory.md)
- [interactive table](docs/design/ui-pattern-inventory.html)
- [Composition authoring draft](docs/design/composition-authoring-draft.md)
- [Child routing experiment](docs/design/child-routing-experiment.md)
- [Ordinary Mojo handler experiment](docs/design/handler-api-experiment.md)
- [Ordinary Mojo render experiment](docs/design/render-api-experiment.md)
- [Scoped reactivity experiment](docs/design/scoped-reactivity-experiment.md)
- [authoring comparison](docs/design/authoring-comfort-experiment.md)
- [Modular/Mojo ecosystem research](docs/modular-ecosystem-research.md)
- [Post-0.5 roadmap](docs/post-0.5-roadmap.md)

## Rules of record

1. Reconcile against code, tests and measured evidence at a named revision.
   A completion claim in another document is not sufficient.
2. Keep owner boundaries, acceptance signals and non-goals explicit. Separate
   portable contracts, buildable host artifacts and linked runtime evidence.
3. Preserve dated results as history. Do not present old timings, worker images
   or agent exercises as fresh performance, integrated-source or human evidence.
4. Keep delivered items out of the pending queue while retaining unmet acceptance
   gates. Record what was not verified and keep VoiceOver paused until resumed.
5. Product docs describe shipped behavior beside code; this branch holds proposed
   work and planning decisions. A planning commit does not imply a push or release.
