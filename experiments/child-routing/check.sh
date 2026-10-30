#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
pixi run --locked mojo run -I src -I experiments/handler-api -I experiments/child-routing experiments/child-routing/check.mojo
pixi run --locked mojo run -I src -I experiments/handler-api -I experiments/child-routing experiments/child-routing/check_settled.mojo
