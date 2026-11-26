// Native replay drives the same view callbacks as the interactive window.
#import "../../native/macos_window.m"
#include <assert.h>

void cohort_mouse(float x, float y, int down) {
    NSPoint location = [moxi_canvas convertPoint:NSMakePoint(x, y) toView:nil];
    NSEvent *event = [NSEvent mouseEventWithType:down ? NSEventTypeLeftMouseDown : NSEventTypeLeftMouseUp
        location:location modifierFlags:0 timestamp:0 windowNumber:moxi_window.windowNumber
        context:nil eventNumber:0 clickCount:1 pressure:down];
    if (down) [moxi_canvas mouseDown:event];
    else [moxi_canvas mouseUp:event];
}

void cohort_shortcut(void) {
    unichar key = NSF2FunctionKey;
    NSString *chars = [NSString stringWithCharacters:&key length:1];
    [moxi_canvas keyDown:[NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint
        modifierFlags:NSEventModifierFlagFunction timestamp:0 windowNumber:moxi_window.windowNumber
        context:nil characters:chars charactersIgnoringModifiers:chars isARepeat:NO keyCode:120]];
}

void cohort_snapshot(const char *name) {
    const char *dir = getenv("MOXI_COHORT_CAPTURE");
    if (!dir) return;
    NSView *view = moxi_window.contentView;
    [view layoutSubtreeIfNeeded];
    [view displayIfNeeded];
    NSBitmapImageRep *rep = [view bitmapImageRepForCachingDisplayInRect:view.bounds];
    assert(rep);
    [view cacheDisplayInRect:view.bounds toBitmapImageRep:rep];
    NSString *path = [@(dir) stringByAppendingPathComponent:@(name)];
    NSData *png = [rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
    assert([png writeToFile:path atomically:YES]);
}
