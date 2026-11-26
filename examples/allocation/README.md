# Orchard Commons allocation

Three fictional neighbors share a screen. Fern asks for garden plots, Ash for grove, and Pip for play. Compare the finite alternatives, edit each person's minimum independently, and inspect how many plots each person still lacks. Changing supply affects every branch. The play-to-grove transfer applies only to Commons.

Run from the repository root on macOS in a graphical session with the locked Pixi environment installed.

```sh
pixi run --locked bash examples/allocation/run.sh
pixi run --locked bash examples/allocation/run.sh check
pixi run --locked python examples/allocation/gallery.py
```

Use **Review a proposal** to cycle through branches, enter a reason and promote the selected allocation. The decision freezes the branch, counts, owner minimums and reason. Further edits update the working comparison. Undo restores the immediately preceding decision and keeps subsequent working edits. Restarting opens the same synthetic fixture. The session is held in memory.

The native replay uses AppKit accessibility actions on the running window. It checks individual preference edits, shared inheritance, the Commons override, promotion, disagreement after a later edit, and undo. Open the [offline slideshow](../../artifacts/demo-slideshows/allocation/index.html) to inspect the captures. The [static alternatives table](static-table.md) gives a facilitator the same opening and proposal comparisons.

Whether participants can better explain the compromise or retain dissent compared with the static table remains open. This replay covers one local scripted session. Participant trials, VoiceOver and physical keyboard navigation require separate checks.

With Playwright for Python and Google Chrome installed, run `python examples/allocation/check_slides.py` to decode the embedded captures offline and exercise keyboard, button and thumbnail navigation.
