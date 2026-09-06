#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"

init_file="src/moxi/__init__.mojo"
status_file="docs/api-status.md"
write_file=false
if [ "${1:-}" = "--write" ]; then
  write_file=true
elif [ "${1:-}" != "" ]; then
  echo "usage: $0 [--write]" >&2
  exit 2
fi

tmp_file="$(mktemp "${TMPDIR:-/tmp}/moxi-api-status.XXXXXX")"
trap 'rm -f "$tmp_file"' EXIT

awk '
function lane(module) {
  if (module == "__init__") return "stable-core"
  if (module ~ /^(accessibility|backend|component|event|geometry|layout|layout_primitives|paint|scene|software|runtime|app_runtime|style|measure|text_boundary|clipboard|window|view)$/) return "stable-core"
  if (module ~ /^(controls|control_state|collection_state|scrollbar|popup|reorder|animation|invalidation|reactivity|tasks|resources|performance|execution|virtual_view|windowing|text_layout|text_shaping|plotting|plot_data|plot_spec|plot_runtime|plot_view|plot_selection|plot_link|plot_render)$/) return "provisional"
  if (module ~ /^(platform|platform_adapters|host_contract|targets|native_widgets|macos|svg)$/) return "host-adapter"
  if (module ~ /^(app|alignment|composed|form|nested|row|wxstyle|wrapped|testing|tokens|recipes|showcase|demo_browser|demo_walkthrough|interaction_showcase|theme_showcase|capability_walkthrough|live_script|scenarios)$/) return "demo/support"
  if (module ~ /^(capability|conversation|coretext|fractal|harfbuzz|metal)$/) return "experimental"
  return "experimental"
}

function known_module(module) {
  return module == "__init__" || lane(module) != "experimental" || module ~ /^(capability|conversation|coretext|fractal|harfbuzz|metal)$/
}

function ownership(module) {
  if (module == "__init__") return "package version boundary"
  if (module == "accessibility") return "portable semantics and actions"
  if (module == "backend") return "backend capability profiles"
  if (module == "component") return "value-owned component contracts"
  if (module == "event") return "normalized input events"
  if (module == "geometry") return "portable geometry values"
  if (module == "layout" || module == "layout_primitives") return "layout and virtualization math"
  if (module == "paint" || module == "scene" || module == "software") return "portable paint/scene rendering"
  if (module == "runtime" || module == "app_runtime") return "retained reconciliation and lifecycle"
  if (module == "style" || module == "measure" || module == "text_boundary" || module == "text_layout" || module == "text_shaping") return "portable styling, measurement, or text boundaries"
  if (module == "clipboard" || module == "window") return "host-neutral clipboard or window contracts"
  if (module ~ /^plot/) return "typed plotting data, specification, or runtime"
  if (module ~ /^(controls|control_state|collection_state|scrollbar|popup|reorder|animation|invalidation|reactivity|tasks|resources|performance|execution|virtual_view|windowing)$/) return "stateful UI support primitives"
  if (module ~ /^(platform|platform_adapters|host_contract|targets|native_widgets|macos|svg)$/) return "platform and native-host adapters"
  if (module ~ /^(app|alignment|composed|form|nested|row|wxstyle|wrapped|testing|tokens|recipes|showcase|demo_browser|demo_walkthrough|interaction_showcase|theme_showcase|capability_walkthrough|live_script|scenarios)$/) return "examples, recipes, or validation support"
  if (module ~ /^(capability|conversation|coretext|fractal|harfbuzz|metal)$/) return "experimental or optional integration"
  return "experimental or optional integration"
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
  print "# Moxi API status"
  print ""
  print "Generated from `src/moxi/__init__.mojo`. Run `pixi run api-status-check -- --write` after changing the public re-export list. The support lane is a compatibility statement, not a claim that every host implements every backend feature."
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
