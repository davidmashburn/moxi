---
name: review-demo-design
description: Evaluate a working demo's visual design against anchored criteria, prioritize observable problems, and verify improvements. Use for design critiques and polish passes on interactive demos.
---

# Review demo design

Read and apply the `use-a-rubric` skill before scoring. Resolve it from the active skills catalog or the local skills-library checkout (`skills/use-a-rubric/SKILL.md`, commonly under `~/code/skills-library`). If it cannot be found, report the missing dependency. Use its evaluation workflow with the demo-specific criteria and evidence below.

Identify the visitor's first meaningful action and the artifact they came to inspect. If choosing among demos, record the selection and its limits. Open each at its normal entry point with a representative fixture. Capture the same initial state at a wide and narrow viewport before editing. A broken entry point needs its own finding. Restore access and label any baseline captured after the repair.

Before scoring, state the visitor's task, required behaviors, and applicable rows below. Treat a working entry point and completion of the required action as gates. Record pass, fail, or unknown for each. A failed gate blocks acceptance. For each quality row, record the observation first, then apply the existing scale. Use 0 for an observed blocker, 1 for repeated interference, 2 for localized friction, and 3 when the check passes in the tested states. Mark missing evidence untested and explain any inapplicable row.

| Criterion | Check |
| --- | --- |
| Hierarchy | Can a visitor identify the subject, see it early, and distinguish the primary action from maintenance controls? |
| Legibility | Can the visitor read labels, values, and instructions at actual size and distinguish overlapping marks or text when needed? |
| Layout | Do related elements align, and can the visitor reach content and controls on both viewport sizes without unintended clipping or page overflow? |
| Interaction | Can the visitor discover and perform the first action, see keyboard focus, recognize the result, and recover from a relevant failure? |

Inspect the first screen, including controls drawn inside canvases or SVG. Count the visible actions and group them by the task they serve. Treat duplicate commands, maintenance controls that compete with exploration, and actions offered before their prerequisites as hierarchy findings. When reducing clutter, verify that a visitor can discover the secondary controls and use them when needed.

Prioritize blockers and the weakest rows by their impact on the visitor's task. Keep judgments of taste explicit. For an implementation request, change the smallest layer that owns the defect and preserve the demo's real behavior. Retest with the same fixture, viewport and state, then exercise the primary action and recovery. Pair each revised rating with evidence, remaining defects and checks skipped. Never average away a blocked task.
