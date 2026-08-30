#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"

tests=(
  tests/smoke.mojo
  tests/layout.mojo
  tests/layout_primitives.mojo
  tests/component.mojo
  tests/counter.mojo
  tests/form.mojo
  tests/headless.mojo
  tests/alignment.mojo
  tests/nested.mojo
  tests/measurement.mojo
  tests/wx_style.mojo
  tests/wx_advanced.mojo
  tests/diff.mojo
  tests/constraints.mojo
  tests/animation.mojo
  tests/wrapped.mojo
  tests/composed.mojo
  tests/clipping.mojo
  tests/capability.mojo
  tests/controls.mojo
  tests/extended_controls.mojo
  tests/backend.mojo
  tests/platform.mojo
  tests/platform_adapters.mojo
  tests/native_widgets.mojo
  tests/virtual_view.mojo
  tests/targets.mojo
  tests/performance.mojo
  tests/virtualization.mojo
  tests/execution.mojo
  tests/plotting.mojo
  tests/metal_contract.mojo
  tests/text_layout.mojo
  tests/text_shaping.mojo
  tests/text_boundary.mojo
  tests/resources_scene.mojo
  tests/reactivity_tasks.mojo
  tests/input_routing.mojo
  tests/control_state.mojo
  tests/catalog_state.mojo
  tests/style_theme.mojo
  tests/widget_catalog.mojo
  tests/accessibility_contract.mojo
  tests/scene_renderer.mojo
  tests/property_contracts.mojo
  tests/action_dispatch.mojo
  tests/scroll_app.mojo
  tests/windowing.mojo
  tests/conversation.mojo
)

for test_file in "${tests[@]}"; do
  echo "==> $test_file"
  mojo run -I src "$test_file"
done

echo "Moxi test suite passed (${#tests[@]} files)"
