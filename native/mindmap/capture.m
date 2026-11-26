// Test-only capture of this application's content view; never a screen/window capture.
#import <Cocoa/Cocoa.h>
#include <time.h>

uint64_t moxi_mm_thread_cpu_ns(void) {
    return clock_gettime_nsec_np(CLOCK_THREAD_CPUTIME_ID);
}

static NSString *const MMTitle = @"Moxi · Mind map";
static NSWindow *ownWindow(void) {
    for (NSWindow *window in NSApp.windows) if ([window.title isEqualToString:MMTitle]) return window;
    return nil;
}
int moxi_mm_capture(const char *path) {
    NSView *view=ownWindow().contentView;
    if (!view) return 0;
    [view layoutSubtreeIfNeeded]; [view displayIfNeeded];
    NSBitmapImageRep *bitmap=[view bitmapImageRepForCachingDisplayInRect:view.bounds];
    if (!bitmap) return 0;
    [view cacheDisplayInRect:view.bounds toBitmapImageRep:bitmap];
    return [[bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}] writeToFile:@(path) atomically:YES];
}
int moxi_mm_native_key(int code, int command) {
    NSWindow *window=ownWindow(); if (!window) return 0;
    unichar key=(unichar)code;
    NSString *text=[NSString stringWithCharacters:&key length:1];
    NSEvent *event=[NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint modifierFlags:command ? NSEventModifierFlagCommand : 0 timestamp:NSProcessInfo.processInfo.systemUptime windowNumber:window.windowNumber context:nil characters:text charactersIgnoringModifiers:text isARepeat:NO keyCode:0];
    [window.contentView keyDown:event]; return 1;
}
int moxi_mm_native_click(double x, double y) {
    NSWindow *window=ownWindow(); if (!window) return 0;
    NSPoint location=[window.contentView convertPoint:NSMakePoint(x,y) toView:nil];
    for (int release=0; release<2; ++release) {
        NSEvent *event=[NSEvent mouseEventWithType:release ? NSEventTypeLeftMouseUp : NSEventTypeLeftMouseDown location:location modifierFlags:0 timestamp:NSProcessInfo.processInfo.systemUptime windowNumber:window.windowNumber context:nil eventNumber:0 clickCount:1 pressure:release ? 0 : 1];
        if (release) [window.contentView mouseUp:event];
        else [window.contentView mouseDown:event];
    }
    return 1;
}
