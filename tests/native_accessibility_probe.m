// Test-only access to the native adapter's stored snapshot. This translation
// unit replaces macos_window.o; no probe symbols ship in the application.
#include "../native/macos_window.m"

int moxi_test_accessibility_snapshot(int pattern) {
    if (moxi_accessibility_count != 1) return 0;
    return moxi_accessibility_enabled[0] == ((pattern & 1) != 0) &&
        moxi_accessibility_focused[0] == ((pattern & 2) != 0) &&
        moxi_accessibility_selected[0] == ((pattern & 4) != 0) &&
        moxi_accessibility_checked[0] == ((pattern & 8) != 0) &&
        moxi_accessibility_expanded[0] == ((pattern & 16) != 0) &&
        moxi_accessibility_has_value_range[0] == ((pattern & 32) != 0) &&
        moxi_accessibility_value_min[0] == -2.5f &&
        moxi_accessibility_value_max[0] == 12.5f &&
        moxi_accessibility_value_now[0] == 3.25f &&
        moxi_accessibility_actions[0] == 37;
}
