// Test-only AppKit probe loaded into a newly launched FDG process.
#import <Cocoa/Cocoa.h>

static id findLabel(id element, NSString *fragment) {
    if ([[element accessibilityLabel] containsString:fragment]) return element;
    for (id child in [element accessibilityChildren]) {
        id match = findLabel(child, fragment);
        if (match) return match;
    }
    return nil;
}

__attribute__((constructor)) static void start(void) {
    const char *dir = getenv("FDG_DIALOG_DIR");
    if (!dir) return;
    NSString *root = [NSString stringWithUTF8String:dir];
    unsetenv("DYLD_INSERT_LIBRARIES");
    unsetenv("FDG_DIALOG_DIR");
    dispatch_async(dispatch_get_main_queue(), ^{
        __block BOOL requested = NO;
        __block BOOL cancelled = NO;
        NSTimer *timer = [NSTimer timerWithTimeInterval:0.2 repeats:YES block:^(NSTimer *timer) {
            for (NSWindow *window in NSApp.windows) {
                if (!window.visible) continue;
                if (requested && !cancelled && [window isKindOfClass:NSSavePanel.class] &&
                    [window.title isEqual:@"Export graph (SVG, PNG or PDF)"]) {
                    NSSavePanel *panel = (NSSavePanel *)window;
                    panel.directoryURL = [NSURL fileURLWithPath:root isDirectory:YES];
                    panel.nameFieldStringValue = @"cancelled.svg";
                    [panel cancel:nil];
                    cancelled = YES;
                    return;
                }
                if (![window.title isEqual:@"Moxi Force Graph"]) continue;
                NSView *view = window.contentView;
                if (!requested) {
                    requested = [findLabel(view, @"Export…") accessibilityPerformPress];
                } else if (cancelled && findLabel(view, @"Export cancelled")) {
                    [timer invalidate];
                    [view displayIfNeeded];
                    NSBitmapImageRep *bitmap = [view bitmapImageRepForCachingDisplayInRect:view.bounds];
                    [view cacheDisplayInRect:view.bounds toBitmapImageRep:bitmap];
                    NSData *png = [bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
                    if (![png writeToFile:[root stringByAppendingPathComponent:@"cancelled.png"] atomically:YES]) abort();
                    [window performClose:nil];
                    return;
                }
            }
        }];
        [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
        [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSModalPanelRunLoopMode];
    });
}
