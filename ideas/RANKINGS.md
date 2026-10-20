# Product potential and experiment cost

This is the active assessment of the [12 product visions](README.md#product-visions).
It asks what new agency and forms of expression Moxi might enable. Existing
implementation proximity, code reuse, and prototype cost do **not** contribute
to the potential order. Supporting architecture has its own
[framework synthesis](FRAMEWORK.md) and is not scored against products.

The earlier mixed index is preserved in [historical rankings](HISTORICAL-RANKINGS.md).
Its combination of fit, reuse, and feasibility repeatedly rewarded closeness
to the workbench. That index is superseded, not merely reweighted.

## Criteria

These ordinal scores express design judgments, not measurements. Higher is
better. They describe the full vision, while cost describes only the stated
first experiment. None measures similarity to current code or market novelty.

| Code | Criterion | 1 | 3 | 5 |
| --- | --- | --- | --- | --- |
| A | Agency gained | Small convenience | A substantial task becomes more directly controllable | A person can author or manipulate a class of things previously awkward to express within the assumed workflow |
| X | Expressive ambition | A familiar fixed control surface | Richer composition within an established medium | Users gain new notations, perceptual forms, or combinations of media |
| T | Transfer breadth | One narrow task | Several uses within a domain family | A plausible expressive method across substantially different domains |

Scores 2 and 4 are intermediate judgments. The portfolio is already a selected
set of ambitious ideas, so low scores are uncommon. Transfer means breadth of
human uses, not reusable implementation. Expression does not assert that an
idea has never appeared in other software. Agency is conditional on the product
working; it is not measured demand or proven accessibility.

## Potential order

This is an **editorial exploration order**, not a weighted sum. Agency and
expressive ambition lead; transfer breaks some close judgments, while each
row's rationale records the remaining judgment. Equal component scores do
not establish equal opportunities, and adjacent positions are weak preferences.
The exact order has **Low confidence**: no domain-user research, implementation
probes, or market comparison established it. A successful task and evidence of
transfer can outweigh the current order. Each brief gives more specific
confidence and evidence that would change its assessment.

| Order | Product vision | A | X | T | Why this position |
| --- | --- | --- | --- | --- | --- |
| 1 | [V03 — Invent a notation that becomes a tool](v03-invent-notations.md) | 5 | 5 | 5 | Lets people create new expressive languages and tools; unusually broad horizon, unusually uncertain usability. |
| 2 | [V01 — Draw executable behavior](v01-draw-executable-behavior.md) | 5 | 4 | 5 | Makes behavioral intent directly executable across several domains; a clear change in what an author can control. |
| 3 | [V08 — Make invisible phenomena manipulable](v08-instruments-for-invisible-phenomena.md) | 5 | 5 | 4 | Gives abstract relationships new perceptual handles; success depends on faithful, understandable metaphors. |
| 4 | [V12 — Make interfaces into personal instruments](v12-personal-instruments.md) | 5 | 4 | 5 | Gives people authorship over how they act across many kinds of tools; the expressive change centers on interaction mappings. |
| 5 | [V02 — Compose worlds through rules](v02-compose-worlds.md) | 4 | 5 | 4 | Composes rules and space into authored emergence, with room for many kinds of world. |
| 6 | [V06 — Compose an experience across media](v06-compose-across-media.md) | 4 | 5 | 4 | Treats relationships across sensory media as compositional material; intentional mapping is the central opportunity. |
| 7 | [V04 — Design across material, mechanism, and system](v04-design-across-scales.md) | 5 | 4 | 4 | Connects behavioral intent to physical design across scales; its representations depend on the physical domain. |
| 8 | [V07 — Learn by changing a system](v07-learn-by-changing-systems.md) | 4 | 4 | 5 | Has broad educational reach; understanding and transfer matter more than engaging demonstrations. |
| 9 | [V10 — Negotiate possible futures together](v10-negotiate-possible-futures.md) | 4 | 4 | 4 | Expands how groups express tradeoffs; social interpretation and explicit values are central uncertainties. |
| 10 | [V09 — Compose how a space is experienced](v09-compose-lived-spaces.md) | 4 | 4 | 3 | Unifies spatial and temporal authorship around a lived journey, with a more concentrated set of users. |
| 11 | [V11 — Turn patterns into structures](v11-patterns-become-structures.md) | 4 | 4 | 3 | Connects generative rules to tangible craft; each material practice brings a substantial semantic boundary. |
| 12 | [V05 — Make arguments spatial and executable](v05-executable-arguments.md) | 4 | 3 | 4 | Makes reasoning inspectable and revisable; a relatively smaller change in the authoring medium, still a significant product possibility. |

V03 leads because inventing a useful notation could change what people are
able to express. It is also one of the least established propositions. Its
position is a reason to investigate the authoring problem, not a reason to
start building a general language platform. V05's lower position reflects
relative expressive ambition, not low importance or evidence against demand.

## Rank order by individual criterion

Items in the same band are tied; ID order is only for stable display. These
views let an objective change the shortlist without hiding an ambitious idea
behind implementation cost.

### Agency gained

- **5/5:** [V01](v01-draw-executable-behavior.md), [V03](v03-invent-notations.md), [V04](v04-design-across-scales.md), [V08](v08-instruments-for-invisible-phenomena.md), [V12](v12-personal-instruments.md).
- **4/5:** [V02](v02-compose-worlds.md), [V05](v05-executable-arguments.md), [V06](v06-compose-across-media.md), [V07](v07-learn-by-changing-systems.md), [V09](v09-compose-lived-spaces.md), [V10](v10-negotiate-possible-futures.md), [V11](v11-patterns-become-structures.md).

### Expressive ambition

- **5/5:** [V02](v02-compose-worlds.md), [V03](v03-invent-notations.md), [V06](v06-compose-across-media.md), [V08](v08-instruments-for-invisible-phenomena.md).
- **4/5:** [V01](v01-draw-executable-behavior.md), [V04](v04-design-across-scales.md), [V07](v07-learn-by-changing-systems.md), [V09](v09-compose-lived-spaces.md), [V10](v10-negotiate-possible-futures.md), [V11](v11-patterns-become-structures.md), [V12](v12-personal-instruments.md).
- **3/5:** [V05](v05-executable-arguments.md).

### Transfer breadth

- **5/5:** [V01](v01-draw-executable-behavior.md), [V03](v03-invent-notations.md), [V07](v07-learn-by-changing-systems.md), [V12](v12-personal-instruments.md).
- **4/5:** [V02](v02-compose-worlds.md), [V04](v04-design-across-scales.md), [V05](v05-executable-arguments.md), [V06](v06-compose-across-media.md), [V08](v08-instruments-for-invisible-phenomena.md), [V10](v10-negotiate-possible-futures.md).
- **3/5:** [V09](v09-compose-lived-spaces.md), [V11](v11-patterns-become-structures.md).

## First-experiment cost, assessed separately

Cost is a coarse estimate of engineering and interaction-design burden for the
specific experiment in each brief. **Low** would mean a local composition with
little new semantic machinery; **Medium** means a bounded new domain model or
interaction contract; **High** means multiple uncertain boundaries must work
together. The current set has no Low-cost meaningful probes. A storyboard may
be cheaper, but cannot establish executable or tactile interaction quality.
These are not staffing or calendar estimates, and cost confidence is **Low**.

The table is ordered by cost band, then ID. Same-band items are tied. Full
products would be substantially larger; even a Medium probe says little about
shipping the entire vision. A native implementation spike could change any
band. Mocks can help choose language and workflows but must be labeled when
the behavior they show is simulated.

| Probe cost | Vision | What needs to work together in the first experiment |
| --- | --- | --- |
| Medium | [V01 — Draw executable behavior](v01-draw-executable-behavior.md) | A bounded motion model, curve intent, candidate fitting, and coherent editing. |
| Medium | [V02 — Compose worlds through rules](v02-compose-worlds.md) | A repeatable small simulation, rule editing, and understandable comparisons. |
| Medium | [V05 — Make arguments spatial and executable](v05-executable-arguments.md) | An argument structure, explicit premises, linked narrative, and a comprehension comparison. |
| Medium | [V07 — Learn by changing a system](v07-learn-by-changing-systems.md) | A bounded lesson, coordinated representations, and a test of transfer. |
| Medium | [V08 — Make invisible phenomena manipulable](v08-instruments-for-invisible-phenomena.md) | Finite probability manipulation, constraint preservation, and faithful feedback. |
| Medium | [V10 — Negotiate possible futures together](v10-negotiate-possible-futures.md) | Distinct preference ownership, finite alternatives, and interpretable group decisions. |
| Medium | [V12 — Make interfaces into personal instruments](v12-personal-instruments.md) | A mapping editor, stable focus/modes, two input routes, and participant use. |
| High | [V03 — Invent a notation that becomes a tool](v03-invent-notations.md) | A restricted grammar, editing behavior, meaning, and tools a second author can use. |
| High | [V04 — Design across material, mechanism, and system](v04-design-across-scales.md) | A mechanical model, constrained alternatives, and intelligible behavior-to-geometry edits. |
| High | [V06 — Compose an experience across media](v06-compose-across-media.md) | A motion path, sound envelope, timing discipline, and expressive mapping. |
| High | [V09 — Compose how a space is experienced](v09-compose-lived-spaces.md) | A useful 3D scene, spatial tests, picking, and temporal editing. |
| High | [V11 — Turn patterns into structures](v11-patterns-become-structures.md) | A credible fold model, linked flat/spatial editing, and a physical sample. |

## Choosing experiments without shrinking the horizon

Choose a question for its ability to change a product decision, then find the
smallest honest way to answer it. The following are alternatives, not a new
mandatory implementation sequence:

- **Test whether behavior can become an authoring medium:** V01's bounded
  response editor. A failure of representation ownership would challenge
  several other visions, even if the solver itself works.
- **Test tactile mathematical meaning:** V08's probability instrument. This
  can reveal whether manipulation improves understanding or creates a seductive
  misconception. Start in 2D; neither 3D nor a complete CAS is required.
- **Test the highest expressive ambition:** V03's restricted notation authoring
  task. A paper or scripted trial can test vocabulary first; only an editable
  executable probe can establish the proposed authoring experience.
- **Test creative composition:** V06 with an artist, or V02 with a world builder.
  Evaluate whether the person can intentionally produce and revise a result,
  rather than merely enjoy unexpected output.
- **Test human interpretation:** V07, V10, or V12 with intended participants.
  Developer satisfaction alone cannot establish learning, deliberation, or
  personally useful adaptation.

Select among these using an actual interested participant and the uncertainty
worth resolving. The current execution plan remains separate. No workbench
extension is a prerequisite or default first step for this portfolio.

## Evidence that should change the assessment

Raise potential when people express an intention they previously struggled to
formulate, revise it predictably, explain what the representations mean, and
carry the method into a second task. Lower it when an attractive metaphor
systematically misleads, experts must repair every edit, or combining the views
adds more translation work than it removes.

Revise cost when a concrete integration exposes its actual contracts, domain
requirements, latency, and authoring complexity. Reusable code can lower cost;
it cannot by itself establish user value. Maintain keyboard access, primary
modifier conventions, exact math text/layout correspondence, and recoverable
interaction as [shared requirements](README.md#evidence-and-shared-requirements).
No new dependencies, product commitments, or runtime support claims follow
from these rankings.
