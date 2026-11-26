# I20 · One cohort operation

This macOS Moxi notebook collects sensor readings at or above 70. Click the
button, press F2 anywhere in the window, or run the deterministic CLI script.
Each adapter invokes the registered `observations.collect_high.v1` capability.
The application handler owns the threshold, membership and write policy.
The fixed input fixture includes a reading on the boundary and one below it.

From the repository root with the pinned Pixi environment:

```sh
bash examples/application-operations/build.sh
dist/application-operations/notebook
dist/application-operations/notebook --script
dist/application-operations/notebook --agent
```

The script prints `[104,318]` and exits 0. The agent adapter prints its
read-only rejection and exits 1. Both CLI paths start headless with fresh
in-memory data. Caller roles are assigned by the local adapters. The experiment
models application policy within a trusted process.

## Replay and evidence

Run `python3 examples/application-operations/check.py` in a macOS graphical
session. To reuse an installed matching Pixi environment, set
`MOXI_PIXI_MANIFEST` to its manifest. The build compiles this checkout's
Mojo component and Objective-C window backend.

The check verifies both CLI processes, sends AppKit mouse and F2 callbacks to
a running window, and compares the resulting domain IDs. It clicks a replacement
button with a different view ID and verifies the write count. Finally it applies
the agent adapter to a populated notebook and checks that the rejected call
preserves its members and write count.

[Open the captured slideshow](i20-application-operations/index.html) or
[inspect the capture manifest](i20-application-operations/manifest.json).
Physical input, screen-reader behavior and human usability remain untested.
