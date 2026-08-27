#import <Cocoa/Cocoa.h>

@interface MoxiWindowDelegate : NSObject <NSWindowDelegate>
@end

@implementation MoxiWindowDelegate
- (void)windowWillClose:(NSNotification *)notification {
    [NSApp terminate:nil];
}
@end

void moxi_show_window(void) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];

        NSRect frame = NSMakeRect(0, 0, 384, 144);
        NSWindowStyleMask style = NSWindowStyleMaskTitled |
                                  NSWindowStyleMaskClosable |
                                  NSWindowStyleMaskMiniaturizable;
        NSWindow *window = [[NSWindow alloc] initWithContentRect:frame
                                                        styleMask:style
                                                          backing:NSBackingStoreBuffered
                                                            defer:NO];
        MoxiWindowDelegate *delegate = [[MoxiWindowDelegate alloc] init];
        [window setDelegate:delegate];
        [window setTitle:@"Moxi"];

        NSTextField *label = [[NSTextField alloc] initWithFrame:NSMakeRect(32, 48, 320, 48)];
        [label setStringValue:@"Hello from Moxi"];
        [label setFont:[NSFont systemFontOfSize:24]];
        [label setAlignment:NSTextAlignmentCenter];
        [label setBezeled:NO];
        [label setEditable:NO];
        [label setDrawsBackground:NO];
        [[window contentView] addSubview:label];

        [window center];
        [window makeKeyAndOrderFront:nil];
        [NSApp activateIgnoringOtherApps:YES];
        [NSApp run];
    }
}
