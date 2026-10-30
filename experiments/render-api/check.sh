#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
pixi run --locked mojo run -I src -I experiments/render-api experiments/render-api/check.mojo
mkdir -p experiments/render-api/generated
pixi run --locked mojo build -I src -I experiments/render-api \
  experiments/render-api/duplicate-key.mojo -o experiments/render-api/generated/duplicate-key
set +e
experiments/render-api/generated/duplicate-key > experiments/render-api/generated/duplicate-key.log 2>&1
result=$?
set -e
if [[ "$result" != 1 ]] || ! rg -q 'Render API error: duplicate control key: same' experiments/render-api/generated/duplicate-key.log; then
  cat experiments/render-api/generated/duplicate-key.log
  echo "FAIL duplicate-key rejection (exit $result)"
  exit 1
fi
echo 'PASS duplicate-key rejection with a specific diagnostic'
