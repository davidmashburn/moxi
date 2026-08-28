#import <Cocoa/Cocoa.h>

@interface MoxiWindowDelegate : NSObject <NSWindowDelegate>
@end

@interface MoxiCanvasView : NSView
@property(nonatomic, copy) NSString *labelText;
@property(nonatomic) NSRect labelFrame;
@end

@implementation MoxiWindowDelegate
- (void)windowWillClose:(NSNotification *)notification {
    [NSApp terminate:nil];
}
@end

@implementation MoxiCanvasView
- (BOOL)isFlipped {
    return YES;
}

- (void)drawRect:(NSRect)dirtyRect {
    [[NSColor colorWithCalibratedRed:0.08
                               green:0.10
                                blue:0.16
                               alpha:1.0] setFill];
    NSRectFill(self.bounds);

    NSRect panelFrame = NSInsetRect(self.bounds, 20.0, 20.0);
    [[NSColor colorWithCalibratedRed:0.16
                               green:0.20
                                blue:0.30
                               alpha:1.0] setFill];
    [[NSBezierPath bezierPathWithRoundedRect:panelFrame
                                      xRadius:14.0
                                      yRadius:14.0] fill];

    NSDictionary *attributes = @{
        NSFontAttributeName: [NSFont systemFontOfSize:24.0 weight:NSFontWeightSemibold],
        NSForegroundColorAttributeName: [NSColor whiteColor],
    };
    [self.labelText drawInRect:self.labelFrame withAttributes:attributes];
}
@end

static NSWindow *moxi_window;
static MoxiWindowDelegate *moxi_delegate;
static MoxiCanvasView *moxi_canvas;

void moxi_window_open(const char *title, float width, float height) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];

        NSRect frame = NSMakeRect(0, 0, width, height);
        NSWindowStyleMask style = NSWindowStyleMaskTitled |
                                  NSWindowStyleMaskClosable |
                                  NSWindowStyleMaskMiniaturizable;
        moxi_window = [[NSWindow alloc] initWithContentRect:frame
                                                   styleMask:style
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
        moxi_delegate = [[MoxiWindowDelegate alloc] init];
        [moxi_window setDelegate:moxi_delegate];

        NSString *windowTitle = title == NULL
            ? @"Moxi"
            : [NSString stringWithUTF8String:title];
        [moxi_window setTitle:windowTitle];

        moxi_canvas = [[MoxiCanvasView alloc] initWithFrame:NSMakeRect(0, 0, width, height)];
        moxi_canvas.labelText = @"";
        moxi_canvas.labelFrame = NSMakeRect(0, 0, width, height);
        [moxi_window setContentView:moxi_canvas];
        [moxi_window center];
        [moxi_window makeKeyAndOrderFront:nil];
        [NSApp activateIgnoringOtherApps:YES];
    }
}

void moxi_window_set_label(
    const char *text,
    float x,
    float y,
    float width,
    float height
) {
    @autoreleasepool {
        if (moxi_canvas == nil) {
            return;
        }

        NSString *label = text == NULL
            ? @""
            : [NSString stringWithUTF8String:text];
        moxi_canvas.labelText = label;

        moxi_canvas.labelFrame = NSMakeRect(x, y, width, height);
        [moxi_canvas setNeedsDisplay:YES];
    }
}

void moxi_window_run(void) {
    @autoreleasepool {
        [NSApp run];
    }
}
