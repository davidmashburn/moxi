#import <Cocoa/Cocoa.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#include <stdint.h>
#include <string.h>

// Main-thread application service. 0 means cancelled, -1 means invalid path.
int64_t fdg_choose_svg_path(uint8_t *buffer, int64_t capacity) {
    NSSavePanel *panel = [NSSavePanel savePanel];
    panel.title = @"Export graph as SVG";
    panel.nameFieldStringValue = @"moxi-fdg.svg";
    panel.allowedContentTypes = @[UTTypeSVG];
    panel.canCreateDirectories = YES;
    if ([panel runModal] != NSModalResponseOK) return 0;
    NSString *path = panel.URL.path;
    const char *utf8 = path.UTF8String;
    if (!utf8) return -1;
    size_t length = strlen(utf8);
    if (length >= (size_t)capacity) return -1;
    memcpy(buffer, utf8, length + 1);
    return (int64_t)length;
}

// Present only after both widget and graph commands have been submitted.
extern void *moxi_window_canvas_view(void);
void fdg_present_frame(void) {
    NSView *view = (__bridge NSView *)moxi_window_canvas_view();
    [view displayIfNeeded];
}

void fdg_close_window(void) {
    NSView *view = (__bridge NSView *)moxi_window_canvas_view();
    [view.window performClose:nil];
}
