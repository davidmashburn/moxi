#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
node experiments/tags-authoring/compile.cjs
node experiments/tags-authoring/compiler-check.cjs
pixi run --locked mojo run -I src -I experiments/tags-authoring -I experiments/tags-authoring/generated experiments/tags-authoring/check.mojo
pixi run --locked mojo run -I src -I experiments/tags-authoring -I experiments/tags-authoring/generated experiments/tags-authoring/variations.mojo
