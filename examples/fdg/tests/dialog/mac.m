#import <Cocoa/Cocoa.h>
#import <ApplicationServices/ApplicationServices.h>
#import <CommonCrypto/CommonDigest.h>
#import <objc/runtime.h>
#include <limits.h>

// Test-only instrumentation in the real viewer. Never replaces a panel response
// or calls the exporter. A trusted external driver supplies the modal key events.
typedef NS_ENUM(NSInteger, Phase) {
    PhasePause, PhaseSearch, PhaseFind, PhaseNeighbors, PhaseOpen, PhaseModal, PhaseStatus, PhaseDone
};
typedef NS_ENUM(NSInteger, InputMode) { InputExternal, InputLocal };
typedef struct { const char *name; BOOL cancel; } Scenario;
static const Scenario scenarios[] = {
    {"current.svg", NO}, {"cancelled.svg", YES}, {"recovered.svg", NO},
    {"current.png", NO}, {"cancelled.png", YES}, {"recovered.png", NO},
    {"current.pdf", NO}, {"cancelled.pdf", YES}, {"recovered.pdf", NO},
};
static const NSUInteger scenarioCount = sizeof(scenarios) / sizeof(scenarios[0]);
static NSString *root, *exports;
static Phase phase;
static InputMode inputMode;
static NSUInteger scenarioIndex;
static NSTimeInterval deadline;
static BOOL ready;
static NSString *selectedPath;
static NSDictionary *before;
static NSModalResponse (*originalModal)(id, SEL);

static void writeJSON(NSString *name, id value) {
    NSData *data = [NSJSONSerialization dataWithJSONObject:value options:NSJSONWritingPrettyPrinted error:NULL];
    if (!data || ![data writeToFile:[root stringByAppendingPathComponent:name] atomically:YES]) abort();
}
static void fail(NSString *reason) {
    writeJSON(@"failure.json", @{@"reason": reason, @"phase": @(phase), @"scenario": @(scenarioIndex)});
    fprintf(stderr, "%s\n", reason.UTF8String);
    exit(2);
}
static void advance(Phase next) {
    phase = next;
    fprintf(stderr, "Phase %ld scenario %lu\n", (long)phase, (unsigned long)scenarioIndex);
    deadline = NSProcessInfo.processInfo.systemUptime + (inputMode == InputExternal ? 180 : 30);
}
static NSString *name(void) { return @(scenarios[scenarioIndex].name); }
static NSString *destination(void) { return [exports stringByAppendingPathComponent:name()]; }
static BOOL expectedURL(NSURL *url) {
    char parent[PATH_MAX];
    return url.isFileURL && realpath(url.URLByDeletingLastPathComponent.fileSystemRepresentation, parent) &&
        !strcmp(parent, exports.fileSystemRepresentation) && [url.lastPathComponent isEqual:name()];
}
static void requestInput(NSSavePanel *panel) {
    NSDictionary *request = @{
        @"scenario": @(scenarioIndex), @"filename": name(), @"cancel": @(scenarios[scenarioIndex].cancel),
        @"ready": @(ready),
        @"destination": destination(), @"window_number": @(panel.windowNumber),
        @"panel_title": panel.title, @"directory": exports,
        @"input_mode": inputMode == InputExternal ? @"external" : @"local",
        @"screen_capture_access": @(CGPreflightScreenCaptureAccess()),
        @"post_event_access": @(CGPreflightPostEventAccess()),
        @"accessibility_trusted": @(AXIsProcessTrusted()),
        @"requested_utc": [[NSISO8601DateFormatter new] stringFromDate:NSDate.date]
    };
    writeJSON(@"request.json", request);
    writeJSON([name() stringByAppendingString:@"-request.json"], request);
}
static NSString *digest(NSData *data) {
    unsigned char hash[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(data.bytes, (CC_LONG)data.length, hash);
    NSMutableString *hex = [NSMutableString new];
    for (NSUInteger i = 0; i < sizeof(hash); i++) [hex appendFormat:@"%02x", hash[i]];
    return hex;
}
static NSDictionary *manifest(void) {
    NSMutableDictionary *result = [NSMutableDictionary new];
    for (NSString *file in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:exports error:NULL]) {
        NSData *data = [NSData dataWithContentsOfFile:[exports stringByAppendingPathComponent:file]];
        if (!data) fail(@"Cannot read synthetic export");
        result[file] = digest(data);
    }
    return result;
}
static id findLabel(id element, NSString *text) {
    if ([[element accessibilityLabel] containsString:text]) return element;
    for (id child in [element accessibilityChildren]) {
        id match = findLabel(child, text);
        if (match) return match;
    }
    return nil;
}
static void key(NSWindow *window, NSString *text, unsigned short code) {
    for (int up = 0; up < 2; up++) {
        [NSApp postEvent:[NSEvent keyEventWithType:up ? NSEventTypeKeyUp : NSEventTypeKeyDown
            location:NSZeroPoint modifierFlags:0 timestamp:NSProcessInfo.processInfo.systemUptime
            windowNumber:window.windowNumber context:nil characters:text charactersIgnoringModifiers:text
            isARepeat:NO keyCode:code] atStart:NO];
    }
}
static void capture(NSView *view, NSString *filename) {
    [view displayIfNeeded];
    NSBitmapImageRep *bitmap = [view bitmapImageRepForCachingDisplayInRect:view.bounds];
    [view cacheDisplayInRect:view.bounds toBitmapImageRep:bitmap];
    NSData *png = [bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
    if (![png writeToFile:[root stringByAppendingPathComponent:filename]
              atomically:YES]) fail(@"Cannot capture viewer result");
}
static NSModalResponse runModal(NSSavePanel *panel, SEL selector) {
    if (phase != PhaseOpen || ![panel.title isEqual:@"Export graph (SVG, PNG or PDF)"])
        fail(@"Unexpected modal panel");
    // Configure before runModal creates the remote UI. Setters on a panel that
    // is already visible did not update that remote UI in the earlier probe.
    panel.directoryURL = [NSURL fileURLWithPath:exports isDirectory:YES];
    panel.nameFieldStringValue = name();
    before = manifest();
    ready = NO;
    advance(PhaseModal);
    requestInput(panel);
    NSModalResponse response = originalModal(panel, selector);
    NSModalResponse expected = scenarios[scenarioIndex].cancel ? NSModalResponseCancel : NSModalResponseOK;
    if (response != expected) fail(@"Unexpected native panel response");
    if (response == NSModalResponseOK && !expectedURL(panel.URL))
        fail(@"Save returned an unexpected destination");
    selectedPath = response == NSModalResponseOK ? panel.URL.path : @"";
    writeJSON([name() stringByAppendingString:@"-response.json"], @{
        @"response": @(response), @"cancel": @(scenarios[scenarioIndex].cancel),
        @"destination": destination(), @"selected_path": selectedPath, @"before": before,
        @"returned_utc": [[NSISO8601DateFormatter new] stringFromDate:NSDate.date]
    });
    advance(PhaseStatus);
    return response;
}

__attribute__((constructor)) static void start(void) {
    const char *directory = getenv("FDG_DIALOG_DIR");
    if (!directory) return;
    fprintf(stderr, "AppKit replay probe loaded\n");
    root = @(directory);
    exports = [root stringByAppendingPathComponent:@"exports"];
    const char *local = getenv("FDG_DIALOG_LOCAL_EVENTS");
    inputMode = local && *local ? InputLocal : InputExternal;
    unsetenv("DYLD_INSERT_LIBRARIES");
    unsetenv("FDG_DIALOG_DIR");
    unsetenv("FDG_DIALOG_LOCAL_EVENTS");
    Method method = class_getInstanceMethod(NSSavePanel.class, @selector(runModal));
    originalModal = (void *)method_setImplementation(method, (IMP)runModal);
    advance(PhasePause);
    dispatch_async(dispatch_get_main_queue(), ^{
        NSTimer *timer = [NSTimer timerWithTimeInterval:0.2 repeats:YES block:^(NSTimer *timer) {
            if (NSProcessInfo.processInfo.systemUptime > deadline)
                fail(phase == PhaseModal ? @"Timed out waiting for a native panel response" : @"Timed out waiting for viewer state");
            NSWindow *viewer = nil;
            for (NSWindow *window in NSApp.windows) {
                if (!window.visible) continue;
                if (phase == PhaseModal && [window isKindOfClass:NSSavePanel.class]) {
                    NSSavePanel *panel = (NSSavePanel *)window;
                    if (!ready) {
                        ready = YES;
                        requestInput(panel);
                        fprintf(stderr, "Ready: %s (%s)\n", name().UTF8String, scenarios[scenarioIndex].cancel ? "Escape" : "Return");
                        if (inputMode == InputLocal)
                            key(panel, scenarios[scenarioIndex].cancel ? @"\033" : @"\r", scenarios[scenarioIndex].cancel ? 53 : 36);
                    }
                    return;
                }
                if ([window.title isEqual:@"Moxi Force Graph"]) viewer = window;
            }
            if (!viewer) return;
            NSView *view = viewer.contentView;
            static BOOL observedViewer = NO;
            if (!observedViewer) {
                observedViewer = YES;
                capture(view, @"initial.png");
                writeJSON(@"viewer-ready.json", @{
                    @"window_number": @(viewer.windowNumber),
                    @"frame": NSStringFromRect(viewer.frame),
                    @"occlusion_state": @(viewer.occlusionState),
                    @"on_active_space": @(viewer.onActiveSpace),
                    @"pid": @(NSProcessInfo.processInfo.processIdentifier),
                    @"accessibility_children": @([[view accessibilityChildren] count]),
                    @"window_server": CFBridgingRelease(CGWindowListCopyWindowInfo(kCGWindowListOptionIncludingWindow, (CGWindowID)viewer.windowNumber)) ?: @[]
                });
            }
            switch (phase) {
                case PhasePause:
                    if (![findLabel(view, @"Pause") accessibilityPerformPress]) break;
                    advance(PhaseSearch);
                    break;
                case PhaseSearch:
                    if (!findLabel(view, @"Resume")) break;
                    // Exercise the text setter the native viewer implements;
                    // it queues a regular text-input event for this control.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
                    [findLabel(view, @"Find a node by ID") accessibilitySetValue:@"A" forAttribute:NSAccessibilityValueAttribute];
#pragma clang diagnostic pop
                    advance(PhaseFind);
                    break;
                case PhaseFind:
                    if (![[findLabel(view, @"Find a node by ID") accessibilityValue] isEqual:@"A"]) break;
                    [findLabel(view, @"Find next") accessibilityPerformPress];
                    advance(PhaseNeighbors);
                    break;
                case PhaseNeighbors:
                    if (!findLabel(view, @"degree 2")) break;
                    [findLabel(view, @"Neighbors") accessibilityPerformPress];
                    advance(PhaseOpen);
                    break;
                case PhaseOpen:
                    if (findLabel(view, @"All nodes")) [findLabel(view, @"Export…") accessibilityPerformPress];
                    break;
                case PhaseStatus: {
                    NSString *expected = scenarios[scenarioIndex].cancel ? @"Export cancelled" :
                        [@"Saved snapshot: " stringByAppendingString:selectedPath];
                    id status = findLabel(view, expected);
                    if (!status) break;
                    NSDictionary *after = manifest();
                    if (scenarios[scenarioIndex].cancel && ![before isEqual:after])
                        fail(@"Cancellation changed export directory bytes");
                    if (!scenarios[scenarioIndex].cancel && !after[name()]) fail(@"Saved export is missing");
                    capture(view, [name() stringByAppendingString:@"-result.png"]);
                    writeJSON([name() stringByAppendingString:@"-result.json"], @{
                        @"status": [status accessibilityLabel], @"after": after,
                        @"destination_bytes_unchanged": @([before isEqual:after]),
                        @"content_bounds": @[@(view.bounds.size.width), @(view.bounds.size.height)],
                        @"backing_scale": @(viewer.backingScaleFactor),
                        @"captured_utc": [[NSISO8601DateFormatter new] stringFromDate:NSDate.date]
                    });
                    scenarioIndex++;
                    if (scenarioIndex == scenarioCount) {
                        advance(PhaseDone);
                        writeJSON(@"complete.json", @{@"scenarios": @(scenarioIndex)});
                        [timer invalidate];
                        [viewer performClose:nil];
                    } else {
                        advance(PhaseOpen);
                    }
                    break;
                }
                case PhaseModal: case PhaseDone: break;
            }
        }];
        [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
        [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSModalPanelRunLoopMode];
    });
}
