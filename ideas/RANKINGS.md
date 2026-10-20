# Comparative rankings

These rankings express judgment on October 20, 2026, using the
[21 captured ideas](README.md). They compare potential and experiment value,
not measured adoption, implementation estimates, or market novelty.
Confidence in the overall order is **moderate**; adjacent items and ties are
especially uncertain. A real user task, a bounded prototype, or substantially
different integration cost should change the assessment.

## Criteria

Scores use a five-point ordinal scale. **Higher is better in every column**;
feasibility is ease of a meaningful first experiment, not a promise that the
complete vision is easy.

| Code | Criterion | 1 | 3 | 5 |
| --- | --- | --- | --- | --- |
| V | User value | Peripheral convenience or unclear beneficiary | Useful to a narrower workflow | Central recurring task with a concrete consumer |
| D | Distinctiveness | Familiar isolated interaction | Useful combination of familiar behaviors | An unusually expressive experience relative to Moxi's current surface |
| F | Fit with Moxi | Weak link to reactive native interaction | Uses several relevant contracts | Directly exercises clean composition, smooth interaction, and domain computation |
| E | Feasibility | Several major uncertain boundaries even for a useful slice | Bounded experiment, but important new surfaces | Mostly composition of verified existing contracts |
| R | Reuse | Bespoke demo with little transferable behavior | Benefits several related consumers | Broad reusable interaction or component contracts |

Scores 2 and 4 are intermediate judgments. Distinctiveness is not a claim
that no other software implements the idea. Every document gives its local
rationale, missing work, confidence, and evidence that could change the score.

## Overall opportunity order

The provisional opportunity index uses **25% value, 25% fit, 20% reuse,
20% feasibility, and 10% distinctiveness**. It favors a useful next experiment
over spectacle alone. Formula: `(25V + 10D + 25F + 20E + 20R) / 5`, yielding a
maximum of 100. These arithmetic results summarize subjective ratings; a
one-point difference is not a measured advantage.

Product, framework, and demonstrator entries are labeled because they compete
for attention differently. Framework items may rank highly through reuse but
should be extracted inside a consumer, not built as standalone platform gates.
Equal scores share a competition rank; ID order within a tie is only stable
display order.

| Rank | Idea | Kind | V | D | F | E | R | Index / 100 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | [I10 — A laboratory where observations become tools](i10-investigations-become-tools.md) | Product | 5 | 4 | 5 | 4 | 5 | 94 |
| 2 | [I19 — An interaction as an inspectable object](i19-inspectable-interactions.md) | Framework | 4 | 4 | 5 | 4 | 5 | 89 |
| 3 | [I09 — Make an instrument panel from what matters](i09-curated-instrument-panels.md) | Product | 4 | 3 | 5 | 4 | 5 | 87 |
| 3 | [I13 — A visual debugger you can climb inside](i13-visual-execution-debugger.md) | Product | 4 | 3 | 5 | 4 | 5 | 87 |
| 3 | [I18 — Coordinated representations of the same object](i18-coordinated-representations.md) | Framework | 4 | 3 | 5 | 4 | 5 | 87 |
| 3 | [I20 — Application operations across interaction styles](i20-reusable-application-operations.md) | Framework | 4 | 3 | 5 | 4 | 5 | 87 |
| 7 | [I05 — Instruments you can pick up and attach](i05-attachable-instruments.md) | Product | 4 | 4 | 5 | 3 | 5 | 85 |
| 8 | [I02 — Mathematics you can physically interrogate](i02-tangible-mathematics.md) | Product | 4 | 5 | 5 | 3 | 4 | 83 |
| 9 | [I04 — Mind maps of possible worlds](i04-possible-worlds.md) | Product | 4 | 4 | 5 | 3 | 4 | 81 |
| 9 | [I06 — Semantic zoom as a way of thinking](i06-semantic-zoom.md) | Product | 4 | 4 | 5 | 3 | 4 | 81 |
| 9 | [I21 — A living linkage sketch](i21-living-linkage-sketch.md) | Demonstrator | 4 | 4 | 5 | 3 | 4 | 81 |
| 12 | [I03 — Design by pulling on consequences](i03-inverse-design.md) | Product | 5 | 5 | 5 | 1 | 4 | 80 |
| 12 | [I17 — One instrument with several bodies](i17-one-instrument-many-bodies.md) | Product | 4 | 4 | 4 | 3 | 5 | 80 |
| 14 | [I01 — A sketch that gradually becomes an instrument](i01-progressively-executable-sketch.md) | Product | 4 | 5 | 5 | 2 | 4 | 79 |
| 14 | [I12 — An application that grows new instruments while you use it](i12-live-tool-authoring.md) | Product | 4 | 5 | 5 | 1 | 5 | 79 |
| 16 | [I14 — A playable mathematics and motion studio](i14-mathematics-and-motion-studio.md) | Product | 3 | 5 | 5 | 2 | 4 | 74 |
| 17 | [I07 — An explanation you can perform](i07-performed-explanations.md) | Product | 4 | 4 | 4 | 2 | 4 | 72 |
| 17 | [I08 — A debugger for your reasoning](i08-reasoning-debugger.md) | Product | 4 | 4 | 4 | 2 | 4 | 72 |
| 17 | [I11 — Agents that work visibly inside your tools](i11-visible-agent-work.md) | Product | 4 | 4 | 4 | 2 | 4 | 72 |
| 17 | [I15 — A flight recorder for experiments and incidents](i15-experiment-flight-recorder.md) | Product | 4 | 4 | 4 | 2 | 4 | 72 |
| 17 | [I16 — An executable essay that becomes a workbench](i16-executable-essay.md) | Product | 4 | 4 | 4 | 2 | 4 | 72 |

## Rank order by individual criterion

Each list is ordered highest to lowest. Items in one score band are tied;
there is no evidence to distinguish them more finely. Together these lists
provide alternative priorities without hiding a novel but difficult idea
behind the weighted index.

### User value

- **5/5:** [I03](i03-inverse-design.md), [I10](i10-investigations-become-tools.md).
- **4/5:** [I01](i01-progressively-executable-sketch.md), [I02](i02-tangible-mathematics.md), [I04](i04-possible-worlds.md), [I05](i05-attachable-instruments.md), [I06](i06-semantic-zoom.md), [I07](i07-performed-explanations.md), [I08](i08-reasoning-debugger.md), [I09](i09-curated-instrument-panels.md), [I11](i11-visible-agent-work.md), [I12](i12-live-tool-authoring.md), [I13](i13-visual-execution-debugger.md), [I15](i15-experiment-flight-recorder.md), [I16](i16-executable-essay.md), [I17](i17-one-instrument-many-bodies.md), [I18](i18-coordinated-representations.md), [I19](i19-inspectable-interactions.md), [I20](i20-reusable-application-operations.md), [I21](i21-living-linkage-sketch.md).
- **3/5:** [I14](i14-mathematics-and-motion-studio.md).

### Distinctiveness

- **5/5:** [I01](i01-progressively-executable-sketch.md), [I02](i02-tangible-mathematics.md), [I03](i03-inverse-design.md), [I12](i12-live-tool-authoring.md), [I14](i14-mathematics-and-motion-studio.md).
- **4/5:** [I04](i04-possible-worlds.md), [I05](i05-attachable-instruments.md), [I06](i06-semantic-zoom.md), [I07](i07-performed-explanations.md), [I08](i08-reasoning-debugger.md), [I10](i10-investigations-become-tools.md), [I11](i11-visible-agent-work.md), [I15](i15-experiment-flight-recorder.md), [I16](i16-executable-essay.md), [I17](i17-one-instrument-many-bodies.md), [I19](i19-inspectable-interactions.md), [I21](i21-living-linkage-sketch.md).
- **3/5:** [I09](i09-curated-instrument-panels.md), [I13](i13-visual-execution-debugger.md), [I18](i18-coordinated-representations.md), [I20](i20-reusable-application-operations.md).

### Fit with Moxi

- **5/5:** [I01](i01-progressively-executable-sketch.md), [I02](i02-tangible-mathematics.md), [I03](i03-inverse-design.md), [I04](i04-possible-worlds.md), [I05](i05-attachable-instruments.md), [I06](i06-semantic-zoom.md), [I09](i09-curated-instrument-panels.md), [I10](i10-investigations-become-tools.md), [I12](i12-live-tool-authoring.md), [I13](i13-visual-execution-debugger.md), [I14](i14-mathematics-and-motion-studio.md), [I18](i18-coordinated-representations.md), [I19](i19-inspectable-interactions.md), [I20](i20-reusable-application-operations.md), [I21](i21-living-linkage-sketch.md).
- **4/5:** [I07](i07-performed-explanations.md), [I08](i08-reasoning-debugger.md), [I11](i11-visible-agent-work.md), [I15](i15-experiment-flight-recorder.md), [I16](i16-executable-essay.md), [I17](i17-one-instrument-many-bodies.md).

### Feasibility of a meaningful first experiment

- **4/5:** [I09](i09-curated-instrument-panels.md), [I10](i10-investigations-become-tools.md), [I13](i13-visual-execution-debugger.md), [I18](i18-coordinated-representations.md), [I19](i19-inspectable-interactions.md), [I20](i20-reusable-application-operations.md).
- **3/5:** [I02](i02-tangible-mathematics.md), [I04](i04-possible-worlds.md), [I05](i05-attachable-instruments.md), [I06](i06-semantic-zoom.md), [I17](i17-one-instrument-many-bodies.md), [I21](i21-living-linkage-sketch.md).
- **2/5:** [I01](i01-progressively-executable-sketch.md), [I07](i07-performed-explanations.md), [I08](i08-reasoning-debugger.md), [I11](i11-visible-agent-work.md), [I14](i14-mathematics-and-motion-studio.md), [I15](i15-experiment-flight-recorder.md), [I16](i16-executable-essay.md).
- **1/5:** [I03](i03-inverse-design.md), [I12](i12-live-tool-authoring.md).

### Reuse

- **5/5:** [I05](i05-attachable-instruments.md), [I09](i09-curated-instrument-panels.md), [I10](i10-investigations-become-tools.md), [I12](i12-live-tool-authoring.md), [I13](i13-visual-execution-debugger.md), [I17](i17-one-instrument-many-bodies.md), [I18](i18-coordinated-representations.md), [I19](i19-inspectable-interactions.md), [I20](i20-reusable-application-operations.md).
- **4/5:** [I01](i01-progressively-executable-sketch.md), [I02](i02-tangible-mathematics.md), [I03](i03-inverse-design.md), [I04](i04-possible-worlds.md), [I06](i06-semantic-zoom.md), [I07](i07-performed-explanations.md), [I08](i08-reasoning-debugger.md), [I11](i11-visible-agent-work.md), [I14](i14-mathematics-and-motion-studio.md), [I15](i15-experiment-flight-recorder.md), [I16](i16-executable-essay.md), [I21](i21-living-linkage-sketch.md).

## Recommended experiment sequence

This sequence is a dependency-aware recommendation for later exploration.
It does not replace the current workbench-hardening priority. It deliberately
differs from a pure score sort.

1. **I10 — investigations become tools.** Start with a named cohort in the
   existing workbench. This is the highest-ranked product opportunity and
   provides a real task against which to judge composition quality.
2. **I13 — visual execution debugger.** Add a small diagnostic view while
   developing the first experiment, using existing counters and event
   fixtures. Measure whether it explains a real update problem.
3. **I09 — curated instrument panels.** Package a fixed selection of the
   workbench's controls and measurements. Extract only the necessary pieces
   of **I18–I20** through these consumers.
4. **I02 — tangible mathematics, then I21 — living linkage.** After the
   required math/canvas foundations are demonstrated, use a matrix first
   and a bounded planar mechanism second. Delay 3D until it adds value.
5. **I04 — possible worlds and I05 — attachable instruments.** Compare small
   explicit parameter alternatives and reuse one instrument across two
   consumers. Test I06 navigation when the workspace becomes genuinely dense.
6. **Select a domain expansion based on evidence.** I11 needs a real
   delegation task; I07/I16 need an author and audience; I14 needs a performance
   workflow; I15 needs an episode worth capturing. I01 can grow out of the
   successful modeling experiments. Avoid implementing all product families.
7. **Keep I03, I12, and the distributed portion of I17 as explicit research.**
   Inverse solving, live state migration, and multi-device ownership each
   need their own feasibility evidence. Local alternate views in I17 can be
   tested much earlier.

## How priorities change with the objective

- **Immediate usefulness:** I10 leads. I13 and I09 offer feasible supporting
  experiments with concrete consumers.
- **A distinctive demonstration:** I02 is the best balance in the top
  distinctiveness band; I21 combines it with a memorable mechanism. I03 and
  I12 have greater feasibility risk despite equally high distinctiveness.
- **Reusable framework learning:** I19 leads the overall index among framework
  concepts; I18 and I20 tie behind it. Exercise them through I10/I09 rather
  than defining a universal architecture first.
- **Expressive creative use:** I14 and I01 deserve more attention than their
  feasibility-weighted overall position suggests.
- **Teaching and communication:** I07 and I16 become the relevant product pair,
  with I06 navigation and I08 provenance as supporting capabilities.

## Evidence that should change the ordering

Raise a concept when a user finishes a recurring task with less friction,
two consumers share a small understandable API, or a prototype meets its
interaction budget across pointer and keyboard input. Lower it when domain
adapters require extensive synchronization glue, correctness is hard to
explain, native focus/accessibility degrades, or computation blocks feedback.

The ranking does not include staffing, calendar estimates, willingness to pay,
or measured demand. No user research, implementation probes, or performance
checks were performed for this comparison. Re-score after the first useful
consumer rather than treating the table as a permanent roadmap.
