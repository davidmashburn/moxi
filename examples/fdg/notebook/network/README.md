# P04 separate kernel network fixture

This optional fixture reuses `interactive.ipynb`, `InlineFDG`, its prepared Wasm
and its existing bounded comm protocol. JupyterLab/Jupyter Server run in one
container; Jupyter Kernel Gateway and ipykernel run in another. Lab uses its
standard `GatewayClient` integration. Each container has its own network and PID
namespace and a separate copy of the minimal example workspace. No local kernel
is launched by Lab. The browser still owns the actual Mojo solver and Moxi view;
only widget assets, liveness and bounded summaries cross the kernel transport.

The kernel is attached only to a Docker **internal** bridge. Lab joins that
bridge plus a frontend bridge with IP masquerading disabled, needed for Docker
Desktop's port publishing. Only Lab's port is published, to `127.0.0.1`. The
fixture passes no account credentials, mounts no home directories or Docker
socket, drops Linux capabilities and uses synthetic P04 graphs. Public image and
Python dependency downloads occur during image construction, before the isolated
runtime test. Both containers run in the **same Docker Desktop Linux VM on one
physical machine**: this is a real TCP/HTTP/WebSocket path across local network
namespaces, **not physical remote-host or WAN acceptance**.

## Run

Build the P04 assets and install its optional Python/browser requirements as in
[INTERACTIVE.md](../INTERACTIVE.md). The Wasm build remains on the validated Apple
Silicon compiler lane; running its prepared assets on Linux is not a Linux
compiler validation. Docker Desktop and installed Google Chrome are required.
Then, from the repository root:

```sh
python3 examples/fdg/notebook/network/fixture.py up \
  --directory /tmp/moxi-p04-two-hosts --port 8927 \
  > /tmp/moxi-p04-two-hosts-up.log 2>&1
/tmp/moxi-p04-venv/bin/python examples/fdg/notebook/network/capture.py \
  --directory /tmp/moxi-p04-two-hosts \
  > /tmp/moxi-p04-two-hosts-capture.log 2>&1
python3 examples/fdg/notebook/network/fixture.py down \
  --directory /tmp/moxi-p04-two-hosts
```

Use a fresh output directory for each run. `up` builds a runtime image from a
curated context containing only the Dockerfile and public requirements;
`--no-build` reuses `moxi-p04-network:local`. The state file has mode 0600 and
contains disposable authentication tokens. Keep it, server logs and executed
notebooks local. `down` deletes only the two named containers and their networks;
it retains local evidence. To open the running fixture manually, use its loopback
port and the token in the local state file. Never expose the port beyond loopback.

`capture.py` launches real Google Chrome in an isolated profile, executes the
original notebook and checks both graph sizes, gestures, output isolation, busy
kernel coalescing, narrow controls, network partition/retry, backend rejection,
kernel restart, rerun disposal and saved offline fallback. It removes the kernel
container's network interface with `docker network disconnect`, waits for both
leases to stop their runtime resources, restores the same IP, then explicitly
retries the widgets. `cut` and `restore` expose the same operations for manual
investigation. It records the actual executing kernel's hostname, PID and network
namespace through Lab, compares that namespace with the containers, and checks
that Lab has no ipykernel process.

The busy check observes changed node coordinates, pin state and submitted SVG
before the execution finishes, then checks release while still busy and the
final remote ACK. Retry is the first kernel-bound operation after interface
restoration; no execute request warms up the connection. At 480 px, trusted
Tab/Left/Right events must scroll the viewport and retain focus; arrows must
still select nodes after Tab enters the graph. Real horizontal wheel and pointer
input exercise all six first-row SVG actions plus the search hit target, empty-query
Find and both repulsion controls (including their reheat effect). Text/IME entry
is outside this adapter's input contract. Shift+wheel must pass through without
zoom; its observed scroll distance is recorded separately from unverified
physical axis conversion. Rerun captures lifecycle mutation order and stopped
resources before the replacement's live event, rather than polling only the
eventual states.

## Evidence and limits

The local output directory contains `evidence.json` (scenario steps, expected and
observed outcomes, environment, source/build hashes and raw bounded metrics),
`topology.json`, Chrome screenshots under `captures/`, a Chrome Paint trace,
current exported SVG and a saved offline HTML export. These artifacts include
synthetic graph data only. They are not checked into the repository.

Comm roundtrip includes browser scheduling, both Jupyter transports, gateway and
Python dispatch; it is not network-only latency. Solver/layout, scene, SVG,
Wasm transfer, DOM submission, input feedback and Chromium Paint remain separate
measurements. Next-rAF is not display scan-out. Samples from a short local run
support the tested sequence, not sustained performance or a WAN latency budget.

A passing run closes the local **separate namespace topology** experiment only.
Physical remote hardware, WAN routing/latency, TLS/SSH/tunnel configuration,
production authentication and policy, other browsers/frontends, physical input,
independent usability and VoiceOver remain unverified. Narrow controls are made
reachable through wrapping and explicit horizontal scrolling; dense graph labels
and shared SVG clipping are separate acceptance limits.
