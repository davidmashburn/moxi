#!/bin/sh
set -eu
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
root=$(CDPATH= cd -- "$here/../.." && pwd)
mkdir -p "$here/dist"
# An existing, identical pinned environment can be used without modifying it.
pixi run --manifest-path "${MOXI_PIXI_MANIFEST:-$root/pixi.toml}" mojo build -I "$root/src" "$here/linked.mojo" -o "$here/dist/moxi-linked"
