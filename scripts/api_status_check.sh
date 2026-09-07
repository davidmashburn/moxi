#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"

init_file="src/moxi/__init__.mojo"
status_file="docs/api-status.md"
lane_file="docs/api-lanes.tsv"
write_file=false
if [ "${1:-}" = "--write" ]; then
  write_file=true
elif [ "${1:-}" != "" ]; then
  echo "usage: $0 [--write]" >&2
  exit 2
fi

if [ ! -f "$lane_file" ]; then
  echo "$lane_file is missing; every public module needs an explicit support lane" >&2
  exit 1
fi

tmp_file="$(mktemp "${TMPDIR:-/tmp}/moxi-api-status.XXXXXX")"
trap 'rm -f "$tmp_file"' EXIT

awk -v lane_file="$lane_file" '
function lane(module) {
  if (!(module in module_lane)) {
    print "Unclassified public module: " module > "/dev/stderr"
    classification_error = 1
    return "internal"
  }
  return module_lane[module]
}

function known_module(module) {
  return module in module_lane
}

function ownership(module) {
  return module_owner[module]
}

function emit_name(module, name) {
  if (name == "") return
  if (!known_module(module)) {
    print "Unclassified public module: " module > "/dev/stderr"
    classification_error = 1
    return
  }
  printf "| `%s` | `moxi.%s` | %s | %s |\n", name, module, lane(module), ownership(module)
}

function parse_payload(payload,   parts, count, i, name) {
  gsub(/[(),]/, " ", payload)
  count = split(payload, parts, /[[:space:]]+/)
  for (i = 1; i <= count; i++) {
    name = parts[i]
    if (name ~ /^[A-Za-z_][A-Za-z0-9_]*$/) emit_name(current_module, name)
  }
}

BEGIN {
  while ((getline record < lane_file) > 0) {
    if (record ~ /^#/ || record == "") continue
    count = split(record, lane_fields, "\t")
    if (count != 3 || lane_fields[1] == "" || lane_fields[2] == "" || lane_fields[3] == "") {
      print "Malformed API lane row: " record > "/dev/stderr"
      classification_error = 1
      continue
    }
    if (lane_fields[1] in module_lane) {
      print "Duplicate API lane row: " lane_fields[1] > "/dev/stderr"
      classification_error = 1
      continue
    }
    module_lane[lane_fields[1]] = lane_fields[2]
    module_owner[lane_fields[1]] = lane_fields[3]
  }
  close(lane_file)
  print "# Moxi API status"
  print ""
  print "Generated from `src/moxi/__init__.mojo` and `docs/api-lanes.tsv`. Run `pixi run api-status-check -- --write` after changing the public re-export list or a support lane. Unknown public modules fail the check. The support lane is a compatibility statement, not a claim that every host implements every backend feature."
  print ""
  print "- `stable-core`: compatibility-oriented value, component, layout, event, paint, and runtime contracts."
  print "- `provisional`: useful support APIs that may still change before a 1.0 stability promise."
  print "- `host-adapter`: platform, export, and native-host seams whose availability is backend-dependent."
  print "- `demo/support`: examples, recipes, scenarios, and validation helpers; not package compatibility promises."
  print "- `experimental`: optional integrations and capability/GPU/text slices still under active design."
  print ""
  print "| Export | Module | Support lane | Ownership |"
  print "| --- | --- | --- | --- |"
  in_block = 0
  current_module = ""
}

/^from \.[A-Za-z_][A-Za-z0-9_]* import/ {
  line = $0
  sub(/^from \./, "", line)
  split(line, parts, / import /)
  current_module = parts[1]
  payload = parts[2]
  if (index(payload, "(") > 0) {
    in_block = 1
    parse_payload(payload)
  } else {
    parse_payload(payload)
    current_module = ""
  }
  next
}

{
if (in_block) {
  if ($0 ~ /^\)/) {
    in_block = 0
    current_module = ""
  } else {
    parse_payload($0)
  }
}
}
END {
  emit_name("__init__", "moxi_version")
  if (classification_error) exit 1
}
' "$init_file" > "$tmp_file"

if [ "$write_file" = true ]; then
  cp "$tmp_file" "$status_file"
  echo "Wrote $status_file"
  exit 0
fi

if [ ! -f "$status_file" ]; then
  echo "$status_file is missing; run $0 --write" >&2
  exit 1
fi

if ! cmp -s "$tmp_file" "$status_file"; then
  echo "$status_file is stale; run $0 --write and commit the regenerated file" >&2
  diff -u "$status_file" "$tmp_file" || true
  exit 1
fi

export_count="$(awk -F'|' 'NR > 6 && $2 ~ /`/ { count += 1 } END { print count + 0 }' "$status_file")"
if [ "$export_count" -eq 0 ]; then
  echo "$status_file contains no exports" >&2
  exit 1
fi

echo "Moxi API status check passed ($export_count exports)"
