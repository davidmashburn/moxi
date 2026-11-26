# Source atlas

A loopback Moxi Python consumer for I18. Select an ID on the source table, a
scatter mark, or a spatial card. Group means use the arithmetic mean on each
axis over visible members. Selecting a mean selects its contributing IDs.
Selecting one member highlights its group without selecting its peers.

Filtering preserves the selection. Delete accepts one visible source and
leaves its ID available as a tombstone. The URL records the collection,
source references, exclusions, and projection controls. Reload restores the
snapshot, Back restores the preceding view, and Reset starts over. Switching
collections opens a fresh view. All data is synthetic.

The specimen fixture contains depths, intensities and slide positions. The
transit adapter projects route-owned stops, hourly boarding counts and schematic
positions into the same local view model. The scatter plot uses Moxi Figure
geometry and its hit test to translate each visible point to the corresponding
mark's source IDs. This adapter assumes distinct projected anchors within each
fixture. The browser renders the semantic table and positioned links on a CSS
canvas. No shared library or renderer changes are required.

From the repository root, using Python 3.12 and an isolated environment:

```sh
uv venv --python 3.12 .pixi/i18
export PYTHONPATH="$PWD/python"
.pixi/i18/bin/python examples/coordinated-representations/app.py --port 8118
```

Open the printed loopback URL. In another shell at the repository root:

```sh
export PYTHONPATH="$PWD/python"
.pixi/i18/bin/python -m unittest discover -s examples/coordinated-representations -v
uv pip install --python .pixi/i18/bin/python playwright==1.58.0
.pixi/i18/bin/python -m playwright install chromium
.pixi/i18/bin/python examples/coordinated-representations/replay.py --output dist/i18-replay
```

The replay starts its own ephemeral loopback server and browser context. It
checks the storyboard, narrow layout and an invalid reference. Core tests cover
every filter, grouping and deletion subset in each fixture.
