#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"

# Each row is "package:init_file:lane_file:surface_file:status_file:version_fn".
# version_fn is the compatibility-root helper name to include in the surface
# (e.g. `moxi_version`); it is empty for packages with no such helper.
packages=(
  "moxi:src/moxi/__init__.mojo:docs/api-lanes.tsv:docs/api-surface.tsv:docs/api-status.md:moxi_version"
  "moxi_plot:src/moxi_plot/__init__.mojo:docs/plot-api-lanes.tsv:docs/plot-api-surface.tsv:docs/plot-api-status.md:"
  "moxi_demo:src/moxi_demo/__init__.mojo:docs/demo-api-lanes.tsv:docs/demo-api-surface.tsv:docs/demo-api-status.md:"
)
compatibility_file="docs/api-compatibility.tsv"
# Exported names are only half of the public contract: a trait's method set is
# a promise to every implementer, and adding or removing one is invisible to
# the export surface. This inventory makes those changes reviewable too.
trait_surface_file="docs/trait-surface.tsv"
trait_sources=(src/moxi src/moxi_plot src/moxi_demo)

write_file=false
if [ "${1:-}" = "--write" ]; then
  write_file=true
elif [ "${1:-}" != "" ]; then
  echo "usage: $0 [--write]" >&2
  exit 2
fi

tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/moxi-api-status.XXXXXX")"
cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

combined_baseline="$tmp_dir/combined-baseline.tsv"
combined_current="$tmp_dir/combined-current.tsv"
: > "$combined_baseline"
: > "$combined_current"

export_count=0

generate_package() {
  local package="$1" init_file="$2" lane_file="$3" version_fn="$4" \
    tmp_status="$5" tmp_surface="$6"

  if [ ! -f "$lane_file" ]; then
    echo "$lane_file is missing; every public module needs an explicit support lane" >&2
    exit 1
  fi

  awk -v package="$package" -v lane_file="$lane_file" -v surface_file="$tmp_surface" \
    -v version_fn="$version_fn" -v init_file_display="$init_file" '
  function lane(module) {
    if (!(module in module_lane)) {
      print "Unclassified public module in " package ": " module > "/dev/stderr"
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
      print "Unclassified public module in " package ": " module > "/dev/stderr"
      classification_error = 1
      return
    }
    printf "| `%s` | `%s.%s` | %s | %s |\n", name, package, module, lane(module), ownership(module)
    printf "%s\t%s.%s\t%s\t%s\n", name, package, module, lane(module), ownership(module) > surface_file
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
        print "Malformed API lane row in " lane_file ": " record > "/dev/stderr"
        classification_error = 1
        continue
      }
      if (lane_fields[1] in module_lane) {
        print "Duplicate API lane row in " lane_file ": " lane_fields[1] > "/dev/stderr"
        classification_error = 1
        continue
      }
      module_lane[lane_fields[1]] = lane_fields[2]
      module_owner[lane_fields[1]] = lane_fields[3]
    }
    close(lane_file)
    print "# " package " API status"
    print ""
    print "Generated from `" init_file_display "`, `" lane_file "`, and the compatibility snapshots. Run `pixi run api-status-check -- --write` after changing the public re-export list or a support lane. Unknown public modules fail the check. The support lane is a compatibility statement, not a claim that every host implements every backend feature."
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
    if (version_fn != "") emit_name("__init__", version_fn)
    close(surface_file)
    if (classification_error) exit 1
  }
  ' "$init_file" > "$tmp_status"
}

for row in "${packages[@]}"; do
  IFS=':' read -r package init_file lane_file surface_file status_file version_fn <<< "$row"
  tmp_status="$tmp_dir/${package}-status.md"
  tmp_surface="$tmp_dir/${package}-surface.tsv"

  generate_package "$package" "$init_file" "$lane_file" "$version_fn" "$tmp_status" "$tmp_surface"

  if [ "$write_file" = true ]; then
    cp "$tmp_status" "$status_file"
    cp "$tmp_surface" "$surface_file"
    echo "Wrote $status_file and $surface_file"
    continue
  fi

  if [ ! -f "$status_file" ]; then
    echo "$status_file is missing; run $0 --write" >&2
    exit 1
  fi
  if ! cmp -s "$tmp_status" "$status_file"; then
    echo "$status_file is stale; run $0 --write and commit the regenerated file" >&2
    diff -u "$status_file" "$tmp_status" || true
    exit 1
  fi

  if [ ! -f "$surface_file" ]; then
    echo "$surface_file is missing; run $0 --write" >&2
    exit 1
  fi
  if ! cmp -s "$tmp_surface" "$surface_file"; then
    echo "$surface_file is stale; run $0 --write and review the public-surface change" >&2
    diff -u "$surface_file" "$tmp_surface" || true
    exit 1
  fi

  cat "$surface_file" >> "$combined_baseline"
  cat "$tmp_surface" >> "$combined_current"

  package_export_count="$(awk -F'|' 'NR > 6 && $2 ~ /`/ { count += 1 } END { print count + 0 }' "$status_file")"
  if [ "$package_export_count" -eq 0 ]; then
    echo "$status_file contains no exports" >&2
    exit 1
  fi
  export_count=$((export_count + package_export_count))
done

# Inventory every public trait's method set across the packages. A trait method
# with a default body is source-compatible to add, but it still changes the
# contract every implementer inherits, so it must be an explicit review.
tmp_traits="$tmp_dir/trait-surface.tsv"
{
  printf '# package\ttrait\tmethod\n'
  for source_dir in "${trait_sources[@]}"; do
    package="$(basename "$source_dir")"
    for module in "$source_dir"/*.mojo; do
      awk -v package="$package" '
      /^trait [A-Za-z_][A-Za-z0-9_]*/ {
        current = $2
        sub(/[(:].*$/, "", current)
        next
      }
      current != "" && /^[ \t]+(def|fn) [A-Za-z_][A-Za-z0-9_]*\(/ {
        method = $2
        sub(/\(.*$/, "", method)
        if (method !~ /^__/) print package "\t" current "\t" method
        next
      }
      /^[^ \t#]/ { current = "" }
      ' "$module"
    done
  done | sort -u
} > "$tmp_traits"

if [ "$write_file" = true ]; then
  cp "$tmp_traits" "$trait_surface_file"
  echo "Wrote $trait_surface_file"
  exit 0
fi

if [ ! -f "$trait_surface_file" ]; then
  echo "$trait_surface_file is missing; run $0 --write" >&2
  exit 1
fi
if ! cmp -s "$tmp_traits" "$trait_surface_file"; then
  echo "$trait_surface_file is stale; run $0 --write and review the trait-contract change" >&2
  diff -u "$trait_surface_file" "$tmp_traits" || true
  exit 1
fi
trait_method_count="$(grep -vc '^#' "$trait_surface_file" || true)"

# The compatibility manifest is checked once across the union of every
# package's surface: a name that moved from one sibling package to another
# is not "removed" from the overall public API, so `moved`/`deprecated` rows
# only need to resolve against the combined current surface.
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

awk -F '\t' -v baseline="$combined_baseline" -v current="$combined_current" -v compat="$compatibility_file" '
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
'

echo "Moxi API status check passed ($export_count exports and $trait_method_count trait methods across ${#packages[@]} packages)"
