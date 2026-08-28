#import <Cocoa/Cocoa.h>

@interface MoxiWindowDelegate : NSObject <NSWindowDelegate>
@end

@interface MoxiCanvasView : NSView
@property(nonatomic, copy) NSString *labelText;
@property(nonatomic) NSRect labelFrame;
@property(nonatomic, copy) NSString *buttonText;
@property(nonatomic) NSRect buttonFrame;
@end

static NSWindow *moxi_window;
static MoxiWindowDelegate *moxi_delegate;
static MoxiCanvasView *moxi_canvas;
static BOOL moxi_window_opened;
static BOOL moxi_click_pending;
static float moxi_last_click_x;
static float moxi_last_click_y;

@implementation MoxiWindowDelegate
- (void)windowWillClose:(NSNotification *)notification {
    moxi_window_opened = NO;
    [NSApp stop:nil];
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

    [[NSColor colorWithCalibratedRed:0.18
                               green:0.48
                                blue:0.92
                               alpha:1.0] setFill];
    [[NSBezierPath bezierPathWithRoundedRect:self.buttonFrame
                                      xRadius:10.0
                                      yRadius:10.0] fill];

    NSDictionary *buttonAttributes = @{
        NSFontAttributeName: [NSFont systemFontOfSize:16.0 weight:NSFontWeightSemibold],
        NSForegroundColorAttributeName: [NSColor whiteColor],
    };
    [self.buttonText drawInRect:self.buttonFrame withAttributes:buttonAttributes];
}

- (void)mouseDown:(NSEvent *)event {
    NSPoint point = [self convertPoint:[event locationInWindow] fromView:nil];
    if (NSPointInRect(point, self.buttonFrame)) {
        moxi_last_click_x = point.x;
        moxi_last_click_y = point.y;
        moxi_click_pending = YES;
    }
}
@end

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
        moxi_canvas.buttonText = @"";
        moxi_canvas.buttonFrame = NSMakeRect(0, 0, 0, 0);
        [moxi_window setContentView:moxi_canvas];
        [moxi_window center];
        [moxi_window makeKeyAndOrderFront:nil];
        [NSApp activateIgnoringOtherApps:YES];
        moxi_window_opened = YES;
        moxi_click_pending = NO;
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

void moxi_window_set_button(
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

        NSString *button = text == NULL
            ? @""
            : [NSString stringWithUTF8String:text];
        moxi_canvas.buttonText = button;
        moxi_canvas.buttonFrame = NSMakeRect(x, y, width, height);
        [moxi_canvas setNeedsDisplay:YES];
    }
}

void moxi_window_pump(void) {
    @autoreleasepool {
        NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:0.016];
        NSEvent *event = [NSApp nextEventMatchingMask:NSEventMaskAny
                                            untilDate:deadline
                                               inMode:NSDefaultRunLoopMode
                                              dequeue:YES];
        if (event != nil) {
            [NSApp sendEvent:event];
        }
        [NSApp updateWindows];
    }
}

int moxi_window_is_open(void) {
    return moxi_window_opened ? 1 : 0;
}

int moxi_window_poll_click(void) {
    BOOL hasClick = moxi_click_pending;
    moxi_click_pending = NO;
    return hasClick ? 1 : 0;
}

float moxi_window_click_x(void) {
    return moxi_last_click_x;
}

float moxi_window_click_y(void) {
    return moxi_last_click_y;
}
