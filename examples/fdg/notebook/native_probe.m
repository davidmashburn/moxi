// Test-only observation of the actual compiled viewer, loaded with DYLD_INSERT_LIBRARIES.
// Commands live in a private temporary directory, one file per child PID.
// cacheDisplay captures the live content view, not desktop/window chrome.
#import <Cocoa/Cocoa.h>
#include <unistd.h>

__attribute__((constructor)) static void notebook_probe_start(void) {
    const char *directory = getenv("MOXI_NOTEBOOK_PROBE_DIR");
    if (!directory) return;
    NSString *command = [[NSString stringWithUTF8String:directory]
        stringByAppendingPathComponent:[NSString stringWithFormat:@"%d.json", getpid()]];
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSTimer scheduledTimerWithTimeInterval:0.05 repeats:YES block:^(NSTimer *timer) {
            (void)timer;
            NSData *data = [NSData dataWithContentsOfFile:command];
            if (!data) return;
            NSDictionary *request = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            NSWindow *window = nil;
            for (NSWindow *candidate in NSApp.windows) {
                if ([candidate.title isEqualToString:@"Moxi Force Graph"] && candidate.visible) {
                    window = candidate;
                    break;
                }
            }
            if (!window) return;
            NSString *capture = request[@"capture"];
            if (capture) {
                NSView *view = window.contentView;
                [view layoutSubtreeIfNeeded];
                [view displayIfNeeded];
                NSBitmapImageRep *bitmap = [view bitmapImageRepForCachingDisplayInRect:view.bounds];
                [view cacheDisplayInRect:view.bounds toBitmapImageRep:bitmap];
                NSData *png = [bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
                if (![png writeToFile:capture atomically:YES]) abort();
            }
            if ([request[@"close"] boolValue]) [window performClose:nil];
            [[NSFileManager defaultManager] removeItemAtPath:command error:nil];
        }];
    });
}
