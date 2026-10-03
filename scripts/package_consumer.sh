#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
package_dir="$(mktemp -d "${TMPDIR:-/tmp}/moxi-package-channel.XXXXXX")"
consumer_dir="$(mktemp -d "${TMPDIR:-/tmp}/moxi-consumer.XXXXXX")"
cache_dir="$(mktemp -d "${TMPDIR:-/tmp}/moxi-pixi-cache.XXXXXX")"
build_cache_dir="$repo_dir/.pixi/bld"
layout_native="${MOXI_LAYOUT_NATIVE:-0}"

cleanup() {
    rm -rf "$package_dir" "$consumer_dir" "$cache_dir"
}
trap cleanup EXIT

pixi publish --clean --target-channel "$package_dir"
archive="$(find "$package_dir" -type f -name 'moxi-*.conda' -print -quit)"
if [[ -z "$archive" ]]; then
    echo "package build did not produce a moxi .conda archive" >&2
    exit 1
fi
canvas_archive="$(find "$package_dir" -type f -name 'canvas_mojo-*.conda' -print -quit)"
if [[ -z "$canvas_archive" ]]; then
    echo "workspace publish did not produce the canvas_mojo runtime archive" >&2
    exit 1
fi

# moxi_plot is an installable sibling package, but it is intentionally not a
# workspace package in the root manifest. Publish it after moxi so its regular
# runtime dependency resolves from the same local channel. Its build and host
# dependencies remain local source paths for the monorepo build.
pixi publish \
    --path "$repo_dir/packages/moxi_plot/pixi.toml" \
    --target-channel "$package_dir"
plot_archive="$(find "$package_dir" -type f -name 'moxi_plot-*.conda' -print -quit)"
if [[ -z "$plot_archive" ]]; then
    echo "moxi_plot package build did not produce an archive" >&2
    exit 1
fi

if [[ "$layout_native" == 1 ]]; then
    pixi publish \
        --path "$repo_dir/packages/moxi_layout_native/recipe.yaml" \
        --target-channel "$package_dir"
    native_archive="$(find "$package_dir" -type f -name 'moxi_layout_native-*.conda' -print -quit)"
    if [[ -z "$native_archive" ]]; then
        echo "native layout package build did not produce an archive" >&2
        exit 1
    fi
    cp "$repo_dir/tests/layout_consumer.mojo" "$consumer_dir/main.mojo"
    cat > "$consumer_dir/check_layout.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
test -f "$CONDA_PREFIX/lib/mojo/moxi.mojoc"
test -f "$CONDA_PREFIX/share/licenses/moxi_layout_native/KIWI-LICENSE"
# Discover Mojo through the installed environment; link only the installed archive.
mojo build -Xlinker "$CONDA_PREFIX/lib/libmoxi_layout_native.a" -Xlinker -lc++ \
    -Xlinker -framework -Xlinker Cocoa -Xlinker -framework -Xlinker CoreText \
    main.mojo -o consumer
./consumer
SH
fi

# The package build can be much larger than the local consumer environment.
# Drop only Pixi's generated build cache before materializing the consumer.
if [[ -d "$build_cache_dir" ]]; then
    find "$build_cache_dir" -mindepth 1 -depth -delete
fi

pixi init \
    --format pixi \
    --platform osx-arm64 \
    --channel "file://$package_dir" \
    --channel https://conda.modular.com/max \
    --channel conda-forge \
    "$consumer_dir"

if [[ "$layout_native" == 1 ]]; then
    cat >> "$consumer_dir/pixi.toml" <<'TOML'

[system-requirements]
macos = "14.0"
TOML
fi

packages=("moxi==0.6.0" "moxi_plot==0.6.0")
if [[ "$layout_native" == 1 ]]; then
    packages+=("moxi_layout_native==0.6.0")
fi
PIXI_NO_CONFIG=1 PIXI_CACHE_DIR="$cache_dir" \
    pixi add --manifest-path "$consumer_dir/pixi.toml" "${packages[@]}"
PIXI_NO_CONFIG=1 PIXI_CACHE_DIR="$cache_dir" \
    pixi run --manifest-path "$consumer_dir/pixi.toml" \
    mojo run "$repo_dir/tests/package_consumer.mojo"
if [[ "$layout_native" == 1 ]]; then
    cd "$consumer_dir"
    PIXI_NO_CONFIG=1 PIXI_CACHE_DIR="$cache_dir" \
        pixi run --manifest-path "$consumer_dir/pixi.toml" bash check_layout.sh
    echo "Installed native layout package consumer passed"
fi
