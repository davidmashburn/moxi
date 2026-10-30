#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
folder=experiments/handler-api
mkdir -p "$folder/generated"
pixi run --locked mojo run -I src -I "$folder" "$folder/check.mojo"
for fixture in invalid-handler render-mutation captured-handler; do
  if pixi run --locked mojo build -I src -I "$folder" "$folder/diagnostics/$fixture.mojo" \
      -o "$folder/generated/$fixture" > "$folder/generated/$fixture.log" 2>&1; then
    echo "FAIL $fixture unexpectedly compiled"
    exit 1
  fi
  case "$fixture" in
    invalid-handler) pattern='invalid-handler.mojo:10:.*error:' ;;
    render-mutation) pattern='render-mutation.mojo:8:.*error:' ;;
    captured-handler) pattern='captured-handler.mojo:11:.*error:' ;;
  esac
  if ! rg -q "$pattern" "$folder/generated/$fixture.log"; then
    cat "$folder/generated/$fixture.log"
    exit 1
  fi
  echo "PASS expected compiler rejection: $fixture"
done
pixi run --locked mojo build -I src -I "$folder" "$folder/diagnostics/duplicate-scope.mojo" -o "$folder/generated/duplicate-scope"
set +e
"$folder/generated/duplicate-scope" > "$folder/generated/duplicate-scope.log" 2>&1
result=$?
set -e
if [[ "$result" != 1 ]] || ! rg -q 'Handler API error: duplicate identity: /k4:same' "$folder/generated/duplicate-scope.log"; then
  cat "$folder/generated/duplicate-scope.log"
  echo "FAIL duplicate-scope rejection (exit $result)"
  exit 1
fi
echo 'PASS duplicate scope rejection'
