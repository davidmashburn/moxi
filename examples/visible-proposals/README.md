# Visible fit proposals (I11)

Run the macOS app from the repository root in a graphical session.

```sh
pixi run --locked bash examples/visible-proposals/run.sh
```

Request a fit for the two fixed observations. The simulated worker receives a
copy of the line parameters and their revision. Its result contains only the
original and proposed gain and offset. Compare them in the preview. Reject
discards the proposal. Apply publishes both values in one revision.

To reproduce a conflict, request a proposal, increase the live gain, then press
Apply. The app checks the captured revision, discards the stale proposal and
preserves the edit. Request again to fit the new revision.

## Reproduce the evidence

```sh
pixi run --locked bash examples/visible-proposals/run.sh check
pixi run --locked python examples/visible-proposals/gallery.py
```

The replay invokes AppKit accessibility presses in a running window, drains the
Moxi event queue and checks the resulting labels and button availability. The
gallery command also records six content-view PNGs and generates an offline
keyboard-navigable slideshow beside its [manifest](../../artifacts/demo-slideshows/visible-proposals/manifest.json).
Open `artifacts/demo-slideshows/visible-proposals/index.html` after generation.
Physical pointer and keyboard input, VoiceOver use and independent human
assessment of the conflict message remain untested.
