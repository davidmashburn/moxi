#import <UIKit/UIKit.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>

#include "moxi_host.h"

#define MOXI_IOS_MAX_ACCESSIBILITY_NODES 128

#define MOXI_ROLE_BUTTON 2
#define MOXI_ROLE_TEXT_INPUT 3
#define MOXI_ROLE_CHECKBOX 6
#define MOXI_ROLE_PROGRESS_INDICATOR 7
#define MOXI_ROLE_SLIDER 8
#define MOXI_ROLE_SWITCH 9
#define MOXI_ROLE_RADIO 10
#define MOXI_ROLE_IMAGE 11
#define MOXI_ROLE_TEXT_AREA 12
#define MOXI_ROLE_COMBO_BOX 13
#define MOXI_ROLE_LIST 14
#define MOXI_ROLE_TABLE 15
#define MOXI_ROLE_TREE 16
#define MOXI_ROLE_MENU 17
#define MOXI_ROLE_DIALOG 18
#define MOXI_ROLE_TAB_GROUP 19
#define MOXI_ROLE_CANVAS 20

@interface MoxiIOSAccessibilityElement : UIAccessibilityElement
@property(nonatomic, assign) int moxiIdentifier;
@property(nonatomic, assign) int moxiParentIdentifier;
@property(nonatomic, assign) int moxiRole;
@property(nonatomic, copy) NSString *moxiLabel;
@property(nonatomic, copy) NSString *moxiValue;
@property(nonatomic, copy) NSString *moxiHint;
@property(nonatomic, assign) CGRect moxiBounds;
@property(nonatomic, assign) BOOL moxiEnabled;
@property(nonatomic, assign) BOOL moxiFocused;
@property(nonatomic, assign) BOOL moxiSelected;
@property(nonatomic, assign) BOOL moxiChecked;
@property(nonatomic, assign) BOOL moxiExpanded;
@property(nonatomic, assign) BOOL moxiHasValueRange;
@property(nonatomic, assign) float moxiValueMin;
@property(nonatomic, assign) float moxiValueMax;
@property(nonatomic, assign) float moxiValueNow;
@property(nonatomic, assign) int moxiActions;
@property(nonatomic, assign) MoxiHostCallbacks moxiCallbacks;
@property(nonatomic, assign) void *moxiCallbackContext;
@property(nonatomic, strong) NSMutableArray *moxiChildren;
@end

@interface MoxiIOSHostView : MTKView <MTKViewDelegate>
@property(nonatomic, assign) MoxiHostCallbacks callbacks;
@property(nonatomic, assign) void *callbackContext;
@property(nonatomic, assign) CGSize lastReportedSize;
@property(nonatomic, assign) CGFloat lastReportedScale;
@property(nonatomic, strong) NSMutableArray *moxiAccessibilityElements;
@property(nonatomic, strong) NSMutableArray *moxiAccessibilityRootElements;
- (void)rebuildAccessibilityElements;
- (void)syncAccessibilityFrames;
@end

@implementation MoxiIOSAccessibilityElement

- (UIAccessibilityTraits)accessibilityTraits {
    UIAccessibilityTraits traits = UIAccessibilityTraitNone;
    switch (self.moxiRole) {
        case MOXI_ROLE_BUTTON:
        case MOXI_ROLE_CHECKBOX:
        case MOXI_ROLE_SWITCH:
        case MOXI_ROLE_RADIO:
        case MOXI_ROLE_COMBO_BOX:
        case MOXI_ROLE_MENU:
        case MOXI_ROLE_DIALOG:
            traits |= UIAccessibilityTraitButton;
            break;
        case MOXI_ROLE_SLIDER:
            traits |= UIAccessibilityTraitAdjustable;
            break;
        case MOXI_ROLE_IMAGE:
            traits |= UIAccessibilityTraitImage;
            break;
        case MOXI_ROLE_PROGRESS_INDICATOR:
            traits |= UIAccessibilityTraitUpdatesFrequently;
            break;
        default:
            break;
    }
    if (self.moxiSelected || self.moxiChecked) {
        traits |= UIAccessibilityTraitSelected;
    }
    if (!self.moxiEnabled) {
        traits |= UIAccessibilityTraitNotEnabled;
    }
    return traits;
}

- (NSString *)accessibilityLabel {
    return self.moxiLabel == nil ? @"" : self.moxiLabel;
}

- (NSString *)accessibilityValue {
    if (self.moxiValue != nil && self.moxiValue.length > 0) {
        return self.moxiValue;
    }
    if (self.moxiHasValueRange) {
        return [NSString stringWithFormat:@"%.3g", self.moxiValueNow];
    }
    return nil;
}

- (NSString *)accessibilityHint {
    return self.moxiHint == nil || self.moxiHint.length == 0
        ? nil
        : self.moxiHint;
}

- (NSArray *)accessibilityElements {
    return self.moxiChildren == nil ? @[] : self.moxiChildren;
}

- (BOOL)moxiPerformAction:(int)action {
    if (!self.moxiEnabled || (self.moxiActions & action) == 0) {
        return NO;
    }
    if (self.moxiCallbacks.action != NULL) {
        self.moxiCallbacks.action(self.moxiCallbackContext, self.moxiIdentifier, action);
    }
    return YES;
}

- (BOOL)accessibilityActivate {
    return [self moxiPerformAction:MOXI_HOST_ACTION_PRESS];
}

- (void)accessibilityIncrement {
    (void)[self moxiPerformAction:MOXI_HOST_ACTION_INCREMENT];
}

- (void)accessibilityDecrement {
    (void)[self moxiPerformAction:MOXI_HOST_ACTION_DECREMENT];
}

@end

/* A UIKit-owned MTKView is the smallest useful native iOS vertical slice:
 * UIKit owns lifecycle/input, MetalKit owns drawable acquisition, and Moxi
 * receives only normalized scalar callbacks. Scene encoding remains in the
 * shared renderer until an iOS Metal resource adapter is linked. */
@implementation MoxiIOSHostView

- (instancetype)initWithFrame:(CGRect)frame device:(id<MTLDevice>)device {
    self = [super initWithFrame:frame device:device];
    if (self != nil) {
        self.moxiAccessibilityElements = [[NSMutableArray alloc] initWithCapacity:
            MOXI_IOS_MAX_ACCESSIBILITY_NODES];
        self.moxiAccessibilityRootElements = [[NSMutableArray alloc] initWithCapacity:
            MOXI_IOS_MAX_ACCESSIBILITY_NODES];
    }
    return self;
}

- (BOOL)isAccessibilityElement {
    return NO;
}

- (NSArray *)accessibilityElements {
    return self.moxiAccessibilityRootElements == nil
        ? @[]
        : self.moxiAccessibilityRootElements;
}

- (NSInteger)accessibilityElementCount {
    return (NSInteger)self.accessibilityElements.count;
}

- (id)accessibilityElementAtIndex:(NSInteger)index {
    if (index < 0 || index >= (NSInteger)self.accessibilityElements.count) {
        return nil;
    }
    return self.accessibilityElements[(NSUInteger)index];
}

- (NSInteger)indexOfAccessibilityElement:(id)element {
    return [self.accessibilityElements indexOfObject:element];
}

- (void)syncAccessibilityFrames {
    for (id candidate in self.moxiAccessibilityElements) {
        if (![candidate isKindOfClass:[MoxiIOSAccessibilityElement class]]) {
            continue;
        }
        MoxiIOSAccessibilityElement *element = (MoxiIOSAccessibilityElement *)candidate;
        element.accessibilityFrame = [self convertRect:element.moxiBounds toView:nil];
    }
}

- (void)rebuildAccessibilityElements {
    [self.moxiAccessibilityRootElements removeAllObjects];
    for (id candidate in self.moxiAccessibilityElements) {
        if ([candidate isKindOfClass:[MoxiIOSAccessibilityElement class]]) {
            MoxiIOSAccessibilityElement *element = (MoxiIOSAccessibilityElement *)candidate;
            [element.moxiChildren removeAllObjects];
        }
    }
    for (id candidate in self.moxiAccessibilityElements) {
        if (![candidate isKindOfClass:[MoxiIOSAccessibilityElement class]]) {
            continue;
        }
        MoxiIOSAccessibilityElement *element = (MoxiIOSAccessibilityElement *)candidate;
        MoxiIOSAccessibilityElement *parent = nil;
        for (id possible in self.moxiAccessibilityElements) {
            if (![possible isKindOfClass:[MoxiIOSAccessibilityElement class]]) {
                continue;
            }
            MoxiIOSAccessibilityElement *possibleParent = (MoxiIOSAccessibilityElement *)possible;
            if (possibleParent.moxiIdentifier == element.moxiParentIdentifier) {
                parent = possibleParent;
                break;
            }
        }
        if (parent == nil || element.moxiParentIdentifier < 0) {
            [self.moxiAccessibilityRootElements addObject:element];
        } else {
            [parent.moxiChildren addObject:element];
        }
    }
    [self syncAccessibilityFrames];
    [self setNeedsLayout];
    UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, nil);
    for (id candidate in self.moxiAccessibilityElements) {
        if ([candidate isKindOfClass:[MoxiIOSAccessibilityElement class]]) {
            MoxiIOSAccessibilityElement *element = (MoxiIOSAccessibilityElement *)candidate;
            if (element.moxiFocused) {
                UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, element);
                break;
            }
        }
    }
}

- (BOOL)canBecomeFirstResponder { return YES; }

- (void)emitResizeIfNeeded {
    CGFloat scale = self.window.windowScene.screen.scale;
    if (scale <= 0.0) scale = self.traitCollection.displayScale;
    if (scale <= 0.0) scale = 1.0;
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
    [self syncAccessibilityFrames];
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
    view.clearColor = MTLClearColorMake(0.055, 0.067, 0.10, 1.0);
    view.delegate = view;
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

static NSString *moxi_ios_accessibility_string(const char *value) {
    if (value == NULL) return @"";
    NSString *result = [NSString stringWithUTF8String:value];
    return result == nil ? @"" : result;
}

void moxi_ios_host_begin_accessibility(void *handle) {
    if (handle == NULL) return;
    MoxiIOSHostView *view = (__bridge MoxiIOSHostView *)handle;
    [view.moxiAccessibilityElements removeAllObjects];
    [view.moxiAccessibilityRootElements removeAllObjects];
}

void moxi_ios_host_set_accessibility_node(
    void *handle,
    int index,
    int identifier,
    int parent_id,
    int role,
    const char *label,
    const char *value,
    const char *hint,
    float x,
    float y,
    float width,
    float height,
    int enabled,
    int focused,
    int selected,
    int checked,
    int expanded,
    int has_value_range,
    float value_min,
    float value_max,
    float value_now,
    int actions
) {
    if (handle == NULL || index < 0 || index >= MOXI_IOS_MAX_ACCESSIBILITY_NODES) {
        return;
    }
    MoxiIOSHostView *view = (__bridge MoxiIOSHostView *)handle;
    while ((NSInteger)view.moxiAccessibilityElements.count <= index) {
        [view.moxiAccessibilityElements addObject:[NSNull null]];
    }
    id candidate = view.moxiAccessibilityElements[(NSUInteger)index];
    MoxiIOSAccessibilityElement *element = nil;
    if ([candidate isKindOfClass:[MoxiIOSAccessibilityElement class]]) {
        element = (MoxiIOSAccessibilityElement *)candidate;
    } else {
        element = [[MoxiIOSAccessibilityElement alloc]
            initWithAccessibilityContainer:view];
        view.moxiAccessibilityElements[(NSUInteger)index] = element;
    }
    element.moxiIdentifier = identifier;
    element.moxiParentIdentifier = parent_id;
    element.moxiRole = role;
    element.moxiLabel = moxi_ios_accessibility_string(label);
    element.moxiValue = moxi_ios_accessibility_string(value);
    element.moxiHint = moxi_ios_accessibility_string(hint);
    element.moxiBounds = CGRectMake(x, y, width, height);
    element.moxiEnabled = enabled != 0;
    element.moxiFocused = focused != 0;
    element.moxiSelected = selected != 0;
    element.moxiChecked = checked != 0;
    element.moxiExpanded = expanded != 0;
    element.moxiHasValueRange = has_value_range != 0;
    element.moxiValueMin = value_min;
    element.moxiValueMax = value_max;
    element.moxiValueNow = value_now;
    element.moxiActions = actions;
    element.moxiCallbacks = view.callbacks;
    element.moxiCallbackContext = view.callbackContext;
    element.moxiChildren = [[NSMutableArray alloc] init];
}

void moxi_ios_host_end_accessibility(void *handle) {
    if (handle == NULL) return;
    MoxiIOSHostView *view = (__bridge MoxiIOSHostView *)handle;
    [view rebuildAccessibilityElements];
}
