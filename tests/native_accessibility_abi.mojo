"""Exercise native semantic publication across the real Mojo/C ABI."""

from std.ffi import external_call
from moxi import AccessibilitySnapshot, ROLE_BUTTON, Semantics, test_check
from moxi.macos import MacOSRenderer


def main() raises:
    var renderer = MacOSRenderer()
    for pattern in range(64):
        var node = Semantics(122, ROLE_BUTTON, "ABI probe")
        node.enabled = (pattern & 1) != 0
        node.focused = (pattern & 2) != 0
        node.selected = (pattern & 4) != 0
        node.checked = (pattern & 8) != 0
        node.expanded = (pattern & 16) != 0
        node.has_value_range = (pattern & 32) != 0
        node.value_min = -2.5
        node.value_max = 12.5
        node.value_now = 3.25
        node.actions = 37
        var snapshot = AccessibilitySnapshot()
        snapshot.append(node)
        renderer.update_accessibility(snapshot)
        test_check(external_call["moxi_test_accessibility_snapshot", Int32](
            Int32(pattern)
        ) == 1)
    print("Native accessibility ABI passed: all 64 flag combinations")
