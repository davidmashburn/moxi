#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"

init_file="src/moxi/__init__.mojo"
status_file="docs/api-status.md"
lane_file="docs/api-lanes.tsv"
surface_file="docs/api-surface.tsv"
compatibility_file="docs/api-compatibility.tsv"
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
tmp_surface_file="$(mktemp "${TMPDIR:-/tmp}/moxi-api-surface.XXXXXX")"
trap 'rm -f "$tmp_file" "$tmp_surface_file"' EXIT

awk -v lane_file="$lane_file" -v surface_file="$tmp_surface_file" '
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
  printf "%s\tmoxi.%s\t%s\t%s\n", name, module, lane(module), ownership(module) > surface_file
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
  print "Generated from `src/moxi/__init__.mojo`, `docs/api-lanes.tsv`, and the compatibility snapshots. Run `pixi run api-status-check -- --write` after changing the public re-export list or a support lane. Unknown public modules fail the check. The support lane is a compatibility statement, not a claim that every host implements every backend feature."
  print ""
  print "- `stable-core`: compatibility-oriented value, component, layout, event, paint, and runtime contracts."
  print "- `provisional`: useful support APIs that may still change before a 1.0 stability promise."
  print "- `host-adapter`: platform, export, and native-host seams whose availability is backend-dependent."
  print "- `demo/support`: examples, recipes, scenarios, and validation helpers; not package compatibility promises."
  print "- `experimental`: optional integrations and capability/GPU/text slices still under active design."
  print ""
  print "| Export | Module | Support lane | Ownership |"
  print "| --- | --- | --- | --- |"
  print "# name\tmodule\tsupport lane\towner" > surface_file
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
  close(surface_file)
  if (classification_error) exit 1
}
' "$init_file" > "$tmp_file"

if [ ! -f "$compatibility_file" ]; then
  echo "$compatibility_file is missing; add the explicit compatibility manifest" >&2
  exit 1
fi

compatibility_error=false
while IFS=$'\t' read -r name kind replacement introduced remove_after extra; do
  if [[ -z "$name" || "$name" == \#* ]]; then
    continue
  fi
  if [[ -n "$extra" || -z "$kind" || -z "$replacement" || -z "$introduced" || -z "$remove_after" ]]; then
    echo "Malformed API compatibility row: $name" >&2
    compatibility_error=true
    continue
  fi
  if [[ ! "$name" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
    echo "Invalid API compatibility name: $name" >&2
    compatibility_error=true
  fi
  case "$kind" in
    deprecated|moved|removed) ;;
    *)
      echo "Invalid API compatibility kind for $name: $kind" >&2
      compatibility_error=true
      ;;
  esac
  if [[ "$kind" != "removed" && "$replacement" = "-" ]]; then
    echo "API compatibility row needs a replacement for $kind export $name" >&2
    compatibility_error=true
  fi
  if [[ ! "$introduced" =~ ^[0-9]+\.[0-9]+$ ]]; then
    echo "API compatibility introduced release must be major.minor for $name" >&2
    compatibility_error=true
  fi
  if [[ "$remove_after" != "never" && ! "$remove_after" =~ ^[0-9]+\.[0-9]+$ ]]; then
    echo "API compatibility remove_after must be major.minor or never for $name" >&2
    compatibility_error=true
  fi
done < "$compatibility_file"
if [ "$compatibility_error" = true ]; then
  exit 1
fi

if [ "$write_file" = true ]; then
  cp "$tmp_file" "$status_file"
  cp "$tmp_surface_file" "$surface_file"
  echo "Wrote $status_file and $surface_file"
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

if [ ! -f "$surface_file" ]; then
  echo "$surface_file is missing; run $0 --write" >&2
  exit 1
fi
if ! cmp -s "$tmp_surface_file" "$surface_file"; then
  echo "$surface_file is stale; run $0 --write and review the public-surface change" >&2
  diff -u "$surface_file" "$tmp_surface_file" || true
  exit 1
fi

compatibility_check="$(mktemp "${TMPDIR:-/tmp}/moxi-api-compatibility.XXXXXX")"
trap 'rm -f "$tmp_file" "$tmp_surface_file" "$compatibility_check"' EXIT
awk -F '\t' -v baseline="$surface_file" -v current="$tmp_surface_file" -v compat="$compatibility_file" '
BEGIN {
  while ((getline row < baseline) > 0) {
    if (row ~ /^#/ || row == "") continue
    split(row, fields, "\t")
    if (fields[1] != "") old[fields[1]] = 1
  }
  close(baseline)
  while ((getline row < current) > 0) {
    if (row ~ /^#/ || row == "") continue
    split(row, fields, "\t")
    if (fields[1] != "") now[fields[1]] = 1
  }
  close(current)
  while ((getline row < compat) > 0) {
    if (row ~ /^#/ || row == "") continue
    split(row, fields, "\t")
    if (fields[1] != "") {
      exceptions[fields[1]] = fields[2]
      exception_count[fields[1]] += 1
    }
  }
  close(compat)
}
END {
  for (name in old) {
    if (!(name in now) && !(name in exceptions)) {
      print "Removed API export needs a deprecated/moved/removed manifest row: " name > "/dev/stderr"
      failed = 1
    }
  }
  for (name in exceptions) {
    if (exception_count[name] != 1) {
      print "Duplicate API compatibility row: " name > "/dev/stderr"
      failed = 1
    }
    if (exceptions[name] == "removed" && (name in now)) {
      print "Removed API compatibility row still exports the name: " name > "/dev/stderr"
      failed = 1
    }
    if ((exceptions[name] == "deprecated" || exceptions[name] == "moved") && !(name in now)) {
      print "Deprecated/moved API compatibility row must retain the name until removal: " name > "/dev/stderr"
      failed = 1
    }
  }
  if (failed) exit 1
}
' > "$compatibility_check"

export_count="$(awk -F'|' 'NR > 6 && $2 ~ /`/ { count += 1 } END { print count + 0 }' "$status_file")"
if [ "$export_count" -eq 0 ]; then
  echo "$status_file contains no exports" >&2
  exit 1
fi

echo "Moxi API status check passed ($export_count exports)"
