// Use the repository's native AX press and window capture helpers.
#import "../../tests/native_lifecycle_probe.m"

void allocation_set_reason(int id, const char *reason) {
    int index = moxi_accessibility_index_for_id(id);
    assert(index >= 0);
    MoxiAccessibilityElement *editor = (MoxiAccessibilityElement *)moxi_accessibility_elements[index];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    [editor accessibilitySetValue:[NSString stringWithUTF8String:reason]
                    forAttribute:NSAccessibilityValueAttribute];
#pragma clang diagnostic pop
}
