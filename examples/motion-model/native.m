/* The normal Moxi AppKit host plus narrow replay/capture hooks. No alternate UI. */
#import "../../native/macos_window.m"
#include <assert.h>

void motion_press(int id) {
    int index = moxi_accessibility_index_for_id(id);
    assert(index >= 0 && moxi_accessibility_enabled[index]);
    assert([(MoxiAccessibilityElement *)moxi_accessibility_elements[index] accessibilityPerformPress]);
}

void motion_pointer(int phase, float x, float y) {
    NSPoint point = [moxi_canvas convertPoint:NSMakePoint(x, y) toView:nil];
    NSEventType type = phase == 0 ? NSEventTypeLeftMouseDown :
        phase == 1 ? NSEventTypeLeftMouseDragged : NSEventTypeLeftMouseUp;
    NSEvent *event = [NSEvent mouseEventWithType:type location:point modifierFlags:0
        timestamp:0 windowNumber:moxi_window.windowNumber context:nil
        eventNumber:0 clickCount:1 pressure:1];
    if (phase == 0) [moxi_canvas mouseDown:event];
    else if (phase == 1) [moxi_canvas mouseDragged:event];
    else [moxi_canvas mouseUp:event];
}

void motion_key(int key, int modifiers) {
    unichar character = (unichar)key;
    if (key == 1000) character = NSLeftArrowFunctionKey;
    else if (key == 1001) character = NSRightArrowFunctionKey;
    else if (key == 1002) character = NSUpArrowFunctionKey;
    else if (key == 1003) character = NSDownArrowFunctionKey;
    NSString *text = [NSString stringWithCharacters:&character length:1];
    NSEventModifierFlags flags = 0;
    if (modifiers & 1) flags |= NSEventModifierFlagShift;
    if (modifiers & 2) flags |= NSEventModifierFlagCommand;
    NSEvent *event = [NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint
        modifierFlags:flags timestamp:0 windowNumber:moxi_window.windowNumber context:nil
        characters:text charactersIgnoringModifiers:text isARepeat:NO keyCode:0];
    [moxi_canvas keyDown:event];
}

void motion_resize(float width, float height) {
    [moxi_window setContentSize:NSMakeSize(width, height)];
}

int motion_capture(const char *path) {
    NSView *view = moxi_window.contentView;
    [view layoutSubtreeIfNeeded];
    [view displayIfNeeded];
    NSBitmapImageRep *bitmap = [view bitmapImageRepForCachingDisplayInRect:view.bounds];
    if (bitmap == nil) return 0;
    [view cacheDisplayInRect:view.bounds toBitmapImageRep:bitmap];
    NSData *png = [bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
    return [png writeToFile:[NSString stringWithUTF8String:path] atomically:YES] ? 1 : 0;
}

void motion_assert_host(void) {
    assert(moxi_event_dropped_count == 0 && moxi_command_overflow_count == 0);
    assert(moxi_window.visible);
}
