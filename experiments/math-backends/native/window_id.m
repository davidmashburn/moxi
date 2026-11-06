#import <Cocoa/Cocoa.h>
#include <stdint.h>
int64_t moxi_math_window_id(void) {
    for (NSWindow *window in NSApp.windows) {
        if ([window.title hasPrefix:@"Moxi D01"]) return (int64_t)window.windowNumber;
    }
    return 0;
}

/* Snapshot the content of the running AppKit window on its UI thread. This is
 * not an offscreen Moxi renderer or a reconstruction of the scene. */
int32_t moxi_math_capture_window(const char *path) {
    for (NSWindow *window in NSApp.windows) {
        if (![window.title hasPrefix:@"Moxi D01"]) continue;
        NSView *view = window.contentView;
        [view displayIfNeeded];
        NSBitmapImageRep *bitmap = [view bitmapImageRepForCachingDisplayInRect:view.bounds];
        if (!bitmap) return 0;
        [view cacheDisplayInRect:view.bounds toBitmapImageRep:bitmap];
        NSData *png = [bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
        return [png writeToFile:[NSString stringWithUTF8String:path] atomically:YES] ? 1 : 0;
    }
    return 0;
}
