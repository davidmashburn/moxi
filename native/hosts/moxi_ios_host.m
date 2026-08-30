#import <UIKit/UIKit.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>

#include "moxi_host.h"

/* A UIKit-owned MTKView is the smallest useful native iOS vertical slice:
 * UIKit owns lifecycle/input, MetalKit owns drawable acquisition, and Moxi
 * receives only normalized scalar callbacks. Scene encoding remains in the
 * shared renderer until an iOS Metal resource adapter is linked. */
@interface MoxiIOSHostView : MTKView <MTKViewDelegate>
@property(nonatomic, assign) MoxiHostCallbacks callbacks;
@property(nonatomic, assign) void *callbackContext;
@property(nonatomic, assign) CGSize lastReportedSize;
@property(nonatomic, assign) CGFloat lastReportedScale;
@end

@implementation MoxiIOSHostView

- (BOOL)canBecomeFirstResponder { return YES; }

- (void)emitResizeIfNeeded {
    CGFloat scale = self.window.screen.scale > 0.0 ? self.window.screen.scale : UIScreen.mainScreen.scale;
    CGSize size = self.bounds.size;
    if (CGSizeEqualToSize(size, self.lastReportedSize) && scale == self.lastReportedScale) return;
    self.lastReportedSize = size;
    self.lastReportedScale = scale;
    if (self.callbacks.resize != NULL) {
        self.callbacks.resize(self.callbackContext, (float)size.width, (float)size.height, (float)scale);
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [self emitResizeIfNeeded];
}

- (void)drawInMTKView:(MTKView *)view {
    (void)view;
    if (self.callbacks.frame != NULL) self.callbacks.frame(self.callbackContext);
}

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {
    (void)view;
    (void)size;
    [self emitResizeIfNeeded];
}

- (void)emitTouch:(UITouch *)touch kind:(int)kind event:(UIEvent *)event {
    (void)event;
    if (self.callbacks.event == NULL) return;
    CGPoint point = [touch locationInView:self];
    int pointerID = (int)[touch hash];
    self.callbacks.event(self.callbackContext, kind, pointerID, (float)point.x, (float)point.y, 1, 0);
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    for (UITouch *touch in touches) [self emitTouch:touch kind:MOXI_HOST_TOUCH_BEGIN event:event];
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    for (UITouch *touch in touches) [self emitTouch:touch kind:MOXI_HOST_TOUCH_UPDATE event:event];
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    for (UITouch *touch in touches) [self emitTouch:touch kind:MOXI_HOST_TOUCH_END event:event];
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    for (UITouch *touch in touches) [self emitTouch:touch kind:MOXI_HOST_POINTER_CANCEL event:event];
}

@end

void *moxi_ios_host_create(
    float width,
    float height,
    MoxiHostCallbacks callbacks,
    void *context
) {
    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    if (device == nil) return NULL;
    CGRect frame = CGRectMake(0.0, 0.0, width > 0.0f ? width : 1.0f, height > 0.0f ? height : 1.0f);
    MoxiIOSHostView *view = [[MoxiIOSHostView alloc] initWithFrame:frame device:device];
    if (view == nil) return NULL;
    view.callbacks = callbacks;
    view.callbackContext = context;
    view.colorPixelFormat = MTLPixelFormatBGRA8Unorm;
    view.paused = NO;
    view.enableSetNeedsDisplay = NO;
    view.preferredFramesPerSecond = 60;
    view.userInteractionEnabled = YES;
    [view becomeFirstResponder];
    [view emitResizeIfNeeded];
    return (__bridge_retained void *)view;
}

void moxi_ios_host_destroy(void *handle) {
    if (handle == NULL) return;
    (void)CFBridgingRelease(handle);
}

void moxi_ios_host_request_frame(void *handle) {
    if (handle == NULL) return;
    MoxiIOSHostView *view = (__bridge MoxiIOSHostView *)handle;
    [view draw];
}

void moxi_ios_host_resize(void *handle, float width, float height) {
    if (handle == NULL) return;
    MoxiIOSHostView *view = (__bridge MoxiIOSHostView *)handle;
    CGRect frame = view.frame;
    frame.size = CGSizeMake(width > 0.0f ? width : 1.0f, height > 0.0f ? height : 1.0f);
    view.frame = frame;
    [view setNeedsLayout];
    [view layoutIfNeeded];
}

void moxi_ios_host_text(void *handle, const char *text, int start, int end) {
    if (handle == NULL) return;
    MoxiIOSHostView *view = (__bridge MoxiIOSHostView *)handle;
    if (view.callbacks.text != NULL) view.callbacks.text(view.callbackContext, text, start, end);
}

void moxi_ios_host_composition(void *handle, const char *text, int start, int end) {
    if (handle == NULL) return;
    MoxiIOSHostView *view = (__bridge MoxiIOSHostView *)handle;
    if (view.callbacks.composition != NULL) view.callbacks.composition(view.callbackContext, text, start, end);
}
