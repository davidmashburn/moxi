#import <Cocoa/Cocoa.h>

@interface MoxiWindowDelegate : NSObject <NSWindowDelegate>
@end

@interface MoxiCanvasView : NSView
@end

#define MOXI_MAX_DRAW_COMMANDS 32

static NSWindow *moxi_window;
static MoxiWindowDelegate *moxi_delegate;
static MoxiCanvasView *moxi_canvas;
static BOOL moxi_window_opened;
static BOOL moxi_click_pending;
static float moxi_last_click_x;
static float moxi_last_click_y;
static int moxi_label_count;
static NSString *moxi_label_texts[MOXI_MAX_DRAW_COMMANDS];
static NSRect moxi_label_frames[MOXI_MAX_DRAW_COMMANDS];
static float moxi_label_text_colors[MOXI_MAX_DRAW_COMMANDS][4];
static float moxi_label_font_sizes[MOXI_MAX_DRAW_COMMANDS];
static int moxi_button_count;
static NSString *moxi_button_texts[MOXI_MAX_DRAW_COMMANDS];
static NSRect moxi_button_frames[MOXI_MAX_DRAW_COMMANDS];
static float moxi_button_fill_colors[MOXI_MAX_DRAW_COMMANDS][4];
static float moxi_button_text_colors[MOXI_MAX_DRAW_COMMANDS][4];
static float moxi_button_radii[MOXI_MAX_DRAW_COMMANDS];
static float moxi_button_font_sizes[MOXI_MAX_DRAW_COMMANDS];
static float moxi_surface_fill[4];
static BOOL moxi_panel_present;
static NSRect moxi_panel_frame;
static float moxi_panel_fill[4];
static float moxi_panel_radius;

static void moxi_copy_color(float destination[4], float red, float green, float blue, float alpha) {
    destination[0] = red;
    destination[1] = green;
    destination[2] = blue;
    destination[3] = alpha;
}

static NSColor *moxi_color(const float color[4]) {
    return [NSColor colorWithCalibratedRed:color[0]
                                     green:color[1]
                                      blue:color[2]
                                     alpha:color[3]];
}

static void moxi_reset_commands(void) {
    moxi_label_count = 0;
    moxi_button_count = 0;
    moxi_panel_present = NO;
    moxi_panel_frame = NSZeroRect;
    moxi_panel_radius = 0.0;
    moxi_copy_color(moxi_surface_fill, 0.08, 0.10, 0.16, 1.0);
    moxi_copy_color(moxi_panel_fill, 0.16, 0.20, 0.30, 1.0);
    for (int i = 0; i < MOXI_MAX_DRAW_COMMANDS; i++) {
        moxi_label_texts[i] = nil;
        moxi_button_texts[i] = nil;
        moxi_label_frames[i] = NSZeroRect;
        moxi_button_frames[i] = NSZeroRect;
        moxi_copy_color(moxi_label_text_colors[i], 1.0, 1.0, 1.0, 1.0);
        moxi_label_font_sizes[i] = 24.0;
        moxi_copy_color(moxi_button_fill_colors[i], 0.18, 0.48, 0.92, 1.0);
        moxi_copy_color(moxi_button_text_colors[i], 1.0, 1.0, 1.0, 1.0);
        moxi_button_radii[i] = 10.0;
        moxi_button_font_sizes[i] = 16.0;
    }
}

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
    [moxi_color(moxi_surface_fill) setFill];
    NSRectFill(self.bounds);

    if (moxi_panel_present) {
        [moxi_color(moxi_panel_fill) setFill];
        [[NSBezierPath bezierPathWithRoundedRect:moxi_panel_frame
                                          xRadius:moxi_panel_radius
                                          yRadius:moxi_panel_radius] fill];
    }

    for (int i = 0; i < moxi_label_count; i++) {
        NSDictionary *attributes = @{
            NSFontAttributeName: [NSFont systemFontOfSize:moxi_label_font_sizes[i]
                                                       weight:NSFontWeightSemibold],
            NSForegroundColorAttributeName: moxi_color(moxi_label_text_colors[i]),
        };
        [moxi_label_texts[i] drawInRect:moxi_label_frames[i]
                          withAttributes:attributes];
    }

    for (int i = 0; i < moxi_button_count; i++) {
        [moxi_color(moxi_button_fill_colors[i]) setFill];
        [[NSBezierPath bezierPathWithRoundedRect:moxi_button_frames[i]
                                          xRadius:moxi_button_radii[i]
                                          yRadius:moxi_button_radii[i]] fill];
        NSDictionary *buttonAttributes = @{
            NSFontAttributeName: [NSFont systemFontOfSize:moxi_button_font_sizes[i]
                                                       weight:NSFontWeightSemibold],
            NSForegroundColorAttributeName: moxi_color(moxi_button_text_colors[i]),
        };
        [moxi_button_texts[i] drawInRect:moxi_button_frames[i]
                          withAttributes:buttonAttributes];
    }
}

- (void)mouseDown:(NSEvent *)event {
    NSPoint point = [self convertPoint:[event locationInWindow] fromView:nil];
    for (int i = moxi_button_count - 1; i >= 0; i--) {
        if (NSPointInRect(point, moxi_button_frames[i])) {
            moxi_last_click_x = point.x;
            moxi_last_click_y = point.y;
            moxi_click_pending = YES;
            break;
        }
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
                                  NSWindowStyleMaskMiniaturizable |
                                  NSWindowStyleMaskResizable;
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
        [moxi_canvas setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
        moxi_reset_commands();
        [moxi_window setContentView:moxi_canvas];
        [moxi_window center];
        [moxi_window makeKeyAndOrderFront:nil];
        [NSApp activateIgnoringOtherApps:YES];
        moxi_window_opened = YES;
        moxi_click_pending = NO;
    }
}

void moxi_window_begin_frame(void) {
    moxi_reset_commands();
    if (moxi_canvas != nil) {
        [moxi_canvas setNeedsDisplay:YES];
    }
}

void moxi_window_set_surface(
    float red,
    float green,
    float blue,
    float alpha
) {
    moxi_copy_color(moxi_surface_fill, red, green, blue, alpha);
    if (moxi_canvas != nil) {
        [moxi_canvas setNeedsDisplay:YES];
    }
}

void moxi_window_set_panel(
    float x,
    float y,
    float width,
    float height,
    float red,
    float green,
    float blue,
    float alpha,
    float radius
) {
    moxi_panel_frame = NSMakeRect(x, y, width, height);
    moxi_copy_color(moxi_panel_fill, red, green, blue, alpha);
    moxi_panel_radius = radius;
    moxi_panel_present = YES;
    if (moxi_canvas != nil) {
        [moxi_canvas setNeedsDisplay:YES];
    }
}

void moxi_window_set_label_at(
    int index,
    const char *text,
    float x,
    float y,
    float width,
    float height,
    float text_red,
    float text_green,
    float text_blue,
    float text_alpha,
    float font_size
) {
    @autoreleasepool {
        if (moxi_canvas == nil || index < 0 || index >= MOXI_MAX_DRAW_COMMANDS) {
            return;
        }

        NSString *label = text == NULL
            ? @""
            : [NSString stringWithUTF8String:text];
        moxi_label_texts[index] = label;
        moxi_label_frames[index] = NSMakeRect(x, y, width, height);
        moxi_copy_color(moxi_label_text_colors[index], text_red, text_green, text_blue, text_alpha);
        moxi_label_font_sizes[index] = font_size;
        if (index + 1 > moxi_label_count) {
            moxi_label_count = index + 1;
        }
        [moxi_canvas setNeedsDisplay:YES];
    }
}

void moxi_window_set_label(
    const char *text,
    float x,
    float y,
    float width,
    float height
) {
    moxi_window_set_label_at(0, text, x, y, width, height, 1.0, 1.0, 1.0, 1.0, 24.0);
}

void moxi_window_set_button_at(
    int index,
    const char *text,
    float x,
    float y,
    float width,
    float height,
    float fill_red,
    float fill_green,
    float fill_blue,
    float fill_alpha,
    float text_red,
    float text_green,
    float text_blue,
    float text_alpha,
    float radius,
    float font_size
) {
    @autoreleasepool {
        if (moxi_canvas == nil || index < 0 || index >= MOXI_MAX_DRAW_COMMANDS) {
            return;
        }

        NSString *button = text == NULL
            ? @""
            : [NSString stringWithUTF8String:text];
        moxi_button_texts[index] = button;
        moxi_button_frames[index] = NSMakeRect(x, y, width, height);
        moxi_copy_color(moxi_button_fill_colors[index], fill_red, fill_green, fill_blue, fill_alpha);
        moxi_copy_color(moxi_button_text_colors[index], text_red, text_green, text_blue, text_alpha);
        moxi_button_radii[index] = radius;
        moxi_button_font_sizes[index] = font_size;
        if (index + 1 > moxi_button_count) {
            moxi_button_count = index + 1;
        }
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
    moxi_window_set_button_at(
        0, text, x, y, width, height,
        0.18, 0.48, 0.92, 1.0,
        1.0, 1.0, 1.0, 1.0,
        10.0, 16.0
    );
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

float moxi_window_width(void) {
    if (moxi_canvas == nil) {
        return 0.0;
    }
    return NSWidth(moxi_canvas.bounds);
}

float moxi_window_height(void) {
    if (moxi_canvas == nil) {
        return 0.0;
    }
    return NSHeight(moxi_canvas.bounds);
}
