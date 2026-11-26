#include "score.hpp"
#import <Cocoa/Cocoa.h>
#import <objc/runtime.h>
#include <optional>
using namespace exhibition;

static NSColor *ink() { return NSColor.labelColor; }
static NSColor *teal() { return NSColor.systemTealColor; }
static NSColor *gold() { return NSColor.systemOrangeColor; }

static void label(NSString *s, double x, double y, double size,
                  NSColor *color) {
  [s drawAtPoint:NSMakePoint(x, y)
      withAttributes:@{
        NSFontAttributeName : [NSFont systemFontOfSize:size],
        NSForegroundColorAttributeName : color
      }];
}
static void line(NSPoint a, NSPoint b, NSColor *color, double width) {
  NSBezierPath *path = [NSBezierPath bezierPath];
  [path moveToPoint:a];
  [path lineToPoint:b];
  path.lineWidth = width;
  [color setStroke];
  [path stroke];
}
static void dot(NSPoint p, double radius, NSColor *color) {
  [color setFill];
  [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(p.x - radius, p.y - radius,
                                                     2 * radius, 2 * radius)]
      fill];
}
static NSPoint screen(Vec3 p) {
  Camera camera;
  camera.projection = Projection::Orthographic;
  camera.distance = 10;
  camera.yaw = -.38;
  camera.pitch = .69;
  auto v = project(p, camera, {10, 40, 500, 310, 1});
  return NSMakePoint(v.x, v.y);
}
@interface Studio : NSView {
@public
  StudioSession session;
  std::optional<StudioSession> checkpoint;
  NSSlider *clockSlider;
  NSMutableArray<NSButton *> *buttons;
  NSString *message;
  NSTextView *formula;
  enum class Detail { Formula, Definition };
  Detail detail;
  NSButton *inspect;
  NSRange selection;
  NSButton *play;
  NSTimer *timer;
  NSTimeInterval lastTick;
}
- (void)refresh;
@end
@implementation Studio
- (BOOL)isFlipped {
  return YES;
}
- (NSButton *)button:(NSString *)name x:(int)x y:(int)y action:(SEL)action {
  NSButton *b = [NSButton buttonWithTitle:name target:self action:action];
  [b sizeToFit];
  [b setFrameOrigin:NSMakePoint(x, y)];
  [self addSubview:b];
  [buttons addObject:b];
  return b;
}
- (instancetype)initWithFrame:(NSRect)rect {
  if ((self = [super initWithFrame:rect])) {
    buttons = [NSMutableArray array];
    message = @"";
    [self button:@"Switch route" x:22 y:364 action:@selector(route:)];
    [self button:@"Partition −1 m" x:145 y:364 action:@selector(west:)];
    [self button:@"Partition +1 m" x:283 y:364 action:@selector(east:)];
    [self button:@"Peak earlier" x:528 y:364 action:@selector(earlier:)];
    [self button:@"Peak later" x:644 y:364 action:@selector(later:)];
    [self button:@"Undo edit" x:760 y:364 action:@selector(undo:)];
    clockSlider = [NSSlider sliderWithValue:4
                                   minValue:0
                                   maxValue:14
                                     target:self
                                     action:@selector(scrub:)];
    clockSlider.frame = NSMakeRect(95, 426, 395, 24);
    [clockSlider setAccessibilityLabel:@"Elapsed seconds"];
    [self addSubview:clockSlider];
    [self button:@"Set checkpoint" x:525 y:421 action:@selector(save:)];
    [self button:@"Restore checkpoint" x:665 y:421 action:@selector(restore:)];
    formula = [[NSTextView alloc] initWithFrame:NSMakeRect(25, 488, 380, 40)];
    formula.string = @"light = max(0, 1 − |t − peak| / width)";
    formula.font = [NSFont systemFontOfSize:14];
    formula.editable = NO;
    formula.selectable = YES;
    [self addSubview:formula];
    [self button:@"Inspect cue formula"
               x:725
               y:55
          action:@selector(focusFormula:)]
        .keyEquivalent = @"f";
    inspect = [self button:@"Define width"
                         x:414
                         y:484
                    action:@selector(detail:)];
    inspect.keyEquivalent = @"d";
    for (NSButton *b in buttons)
      if (b.keyEquivalent.length)
        b.keyEquivalentModifierMask = NSEventModifierFlagCommand;
    [inspect setFrameSize:NSMakeSize(157, inspect.frame.size.height)];
    play = [self button:@"Play" x:25 y:452 action:@selector(togglePlay:)];
    [play setFrameSize:NSMakeSize(82, play.frame.size.height)];
    [self refresh];
  }
  return self;
}
- (void)refresh {
  clockSlider.maxValue = duration(session.route);
  clockSlider.doubleValue = session.time;
  self.needsDisplay = YES;
}
- (void)stop {
  [timer invalidate];
  timer = nil;
  play.title = @"Play";
}
- (void)tick:(NSTimer *)sender {
  auto now = NSProcessInfo.processInfo.systemUptime;
  session.time =
      std::min(double(duration(session.route)), session.time + now - lastTick);
  lastTick = now;
  if (session.time >= duration(session.route))
    [self stop];
  [self refresh];
}
- (void)togglePlay:(id)sender {
  if (timer) {
    [self stop];
    return;
  }
  if (session.time >= duration(session.route))
    session.time = 0;
  lastTick = NSProcessInfo.processInfo.systemUptime;
  timer = [NSTimer scheduledTimerWithTimeInterval:1. / 30
                                           target:self
                                         selector:@selector(tick:)
                                         userInfo:nil
                                          repeats:YES];
  play.title = @"Pause";
  [self refresh];
}
- (void)route:(id)sender {
  [self stop];
  session.route = session.route == Path::North ? Path::South : Path::North;
  session.time = std::min(session.time, double(duration(session.route)));
  message = @"";
  [self refresh];
}
- (void)change:(int)partition peak:(int)peak {
  message = session.edit({partition, peak})
                ? @"Edit committed"
                : @"Outside score range · edit rejected";
  [self refresh];
}
- (void)west:(id)s {
  [self change:session.score.partition - 1 peak:session.score.peak];
}
- (void)east:(id)s {
  [self change:session.score.partition + 1 peak:session.score.peak];
}
- (void)earlier:(id)s {
  [self change:session.score.partition peak:session.score.peak - 1];
}
- (void)later:(id)s {
  [self change:session.score.partition peak:session.score.peak + 1];
}
- (void)undo:(id)s {
  message = session.undo() ? @"Edit undone" : @"No edits to undo";
  [self refresh];
}
- (void)scrub:(id)s {
  session.time = clockSlider.doubleValue;
  message = @"";
  [self refresh];
}
- (void)save:(id)s {
  checkpoint = session;
  message = @"Checkpoint set";
  [self refresh];
}
- (void)restore:(id)s {
  if (checkpoint) {
    [self stop];
    session = *checkpoint;
  }
  message = checkpoint ? @"Checkpoint restored" : @"Set a checkpoint first";
  [self refresh];
}
- (void)focusFormula:(id)s {
  if (detail == Detail::Definition)
    [self detail:s];
  [self.window makeFirstResponder:formula];
  formula.selectedRange = [formula.string rangeOfString:@"width"];
}
- (void)detail:(id)s {
  if (detail == Detail::Formula) {
    detail = Detail::Definition;
    selection = formula.selectedRange;
    formula.string = @"Width is 2 s during the rise and 4 s during the fall.";
    inspect.title = @"Back to formula";
  } else {
    formula.string = @"light = max(0, 1 − |t − peak| / width)";
    detail = Detail::Formula;
    inspect.title = @"Define width";
    [self.window makeFirstResponder:formula];
    formula.selectedRange = selection;
  }
}
- (void)drawRect:(NSRect)dirty {
  [NSColor.windowBackgroundColor setFill];
  NSRectFill(self.bounds);
  label(@"Partition study", 24, 16, 26, ink());
  label(@"Exhibition floor   /   metres", 24, 53, 14, ink());
  for (int x = -4; x <= 4; x++)
    line(screen({double(x), 0, -3}), screen({double(x), 0, 3}),
         NSColor.separatorColor, 1);
  for (int z = -3; z <= 3; z++)
    line(screen({-4, 0, double(z)}), screen({4, 0, double(z)}),
         NSColor.separatorColor, 1);
  for (auto route : {Path::North, Path::South}) {
    auto a = eye(route, 0), b = eye(route, duration(route));
    a.y = b.y = 0;
    auto color = route == session.route ? teal() : NSColor.secondaryLabelColor;
    line(screen(a), screen(b), color, 3);
    auto start = screen(a);
    label(route == Path::North ? @"N" : @"S", start.x - 16, start.y - 10, 13,
          color);
  }
  auto wall = [NSBezierPath bezierPath];
  auto corners3 = corners(session.score);
  [wall moveToPoint:screen(corners3[0])];
  for (int i = 1; i < 4; ++i)
    [wall lineToPoint:screen(corners3[i])];
  [wall closePath];
  [NSColor.systemIndigoColor setFill];
  [wall fill];
  auto visitor = screen(eye(session.route, session.time)),
       target = screen(exhibit);
  bool clear = visible(session.score, session.route, session.time);
  line(visitor, target, clear ? teal() : NSColor.systemRedColor, 2);
  auto foot = eye(session.route, session.time);
  foot.y = 0;
  line(visitor, screen(foot), ink(), 1.5);
  double intensity = light(session.score, session.time);
  dot(target, 11,
      [NSColor colorWithCalibratedRed:.4 + .6 * intensity
                                green:.24 + .36 * intensity
                                 blue:.08
                                alpha:1]);
  dot(visitor, 6, ink());
  label(@"Exhibit", target.x + 15, target.y - 10, 13, ink());
  label(clear ? @"Sightline clear" : @"Partition blocks sightline", 24, 325, 16,
        ink());
  label(@"Reveal score", 530, 16, 26, ink());
  label(@"Cue intensity  /  0–100%", 530, 64, 14, ink());
  const double left = 544, step = 24, baseline = 180;
  line({left, baseline}, {left + 14 * step, baseline}, ink(), 1);
  for (int i = 0; i < 14; ++i)
    line({left + i * step, baseline - 72 * light(session.score, i)},
         {left + (i + 1) * step, baseline - 72 * light(session.score, i + 1)},
         gold(), 3);
  for (auto route : {Path::North, Path::South}) {
    double y = route == Path::North ? 240 : 284;
    label(route == Path::North ? @"North · 14 s" : @"South · 10 s", left,
          y - 25, 14, ink());
    for (int i = 0; i < duration(route) * 10; i++) {
      [(visible(session.score, route, (i + .5) / 10) ? teal()
                                                     : NSColor.systemGrayColor)
          setFill];
      NSRectFill(NSMakeRect(left + i * step / 10, y - 4, step / 10 + .5, 8));
    }
  }
  double cursor = left + step * session.time;
  line({cursor, 92}, {cursor, 295}, ink(), 1);
  label(@"Gray  blocked      Teal  visible      /      seconds", left, 303, 13,
        ink());
  label([NSString stringWithFormat:@"Peak %d s   ·   Light %.0f%%",
                                   session.score.peak,
                                   100 * light(session.score, session.time)],
        left, 329, 16, ink());
  label([NSString stringWithFormat:@"%@   %.1f s",
                                   session.route == Path::North ? @"N" : @"S",
                                   session.time],
        24, 428, 15, ink());
  label([NSString stringWithFormat:@"Partition %+d m   ·   %zu edits    %@",
                                   session.score.partition,
                                   session.history.size(), message],
        24, 540, 15, ink());
}
@end

static void require(bool result, const char *claim) {
  if (!result) {
    fprintf(stderr, "FAIL: %s\n", claim);
    exit(1);
  }
}
static void capture(Studio *view, NSString *dir, NSString *name) {
  [view.window displayIfNeeded];
  auto rep = [view bitmapImageRepForCachingDisplayInRect:view.bounds];
  [view cacheDisplayInRect:view.bounds toBitmapImageRep:rep];
  auto png = [rep representationUsingType:NSBitmapImageFileTypePNG
                               properties:@{}];
  require([png writeToFile:[dir stringByAppendingPathComponent:name]
                atomically:YES],
          "capture PNG");
}
static void replay(Studio *v, NSString *dir) {
  auto press = [&](SEL action) {
    for (NSButton *b in v->buttons)
      if (sel_isEqual(b.action, action)) {
        [b performClick:nil];
        return;
      }
    require(false, "control is reachable");
  };
  auto sight = [&] {
    return visible(v->session.score, v->session.route, v->session.time);
  };
  require(sight() && light(v->session.score, 7) == .75, "initial north reveal");
  capture(v, dir, @"01-routes.png");
  press(@selector(east:));
  require(!sight() && visible(v->session.score, Path::South, 7),
          "partition blocks only north at 7 s");
  capture(v, dir, @"02-partition.png");
  press(@selector(later:));
  require(!sight() && light(v->session.score, 7) == 1,
          "cue edit changes intensity while obscured");
  capture(v, dir, @"03-peak.png");
  press(@selector(undo:));
  require(!sight() && light(v->session.score, 7) == .75,
          "timing undo preserves spatial edit");
  press(@selector(undo:));
  require(sight() && v->session.score == Score{} && v->session.history.empty(),
          "undo restores both views");
  capture(v, dir, @"04-undo.png");
  press(@selector(restore:));
  require([v->message isEqual:@"Set a checkpoint first"],
          "missing checkpoint handled");
  // Performed explanation: switch visitor, scrub, move partition, change cue,
  // explore space.
  press(@selector(route:));
  v->clockSlider.doubleValue = 5;
  [v->clockSlider sendAction:v->clockSlider.action to:v];
  press(@selector(west:));
  press(@selector(save:));
  StudioSession saved = v->session;
  press(@selector(earlier:));
  press(@selector(west:));
  press(@selector(west:));
  require(v->session.score.partition == -2 && v->session.history.size() == 3 &&
              [v->message containsString:@"rejected"],
          "rejected spatial edit is atomic");
  capture(v, dir, @"05-rejected.png");
  press(@selector(restore:));
  require(v->session.route == Path::South && v->session.time == 5 &&
              v->session.score == saved.score &&
              v->session.history == saved.history,
          "checkpoint restores authoring context and history");
  capture(v, dir, @"06-restored.png");
  auto shortcut = [&](NSString *key) {
    auto event = [NSEvent keyEventWithType:NSEventTypeKeyDown
                                  location:NSZeroPoint
                             modifierFlags:NSEventModifierFlagCommand
                                 timestamp:0
                              windowNumber:v.window.windowNumber
                                   context:nil
                                characters:key
               charactersIgnoringModifiers:key
                                 isARepeat:NO
                                   keyCode:0];
    require([v.window performKeyEquivalent:event],
            "keyboard shortcut delivered");
  };
  shortcut(@"f");
  shortcut(@"d");
  capture(v, dir, @"07-definition.png");
  shortcut(@"d");
  require(v.window.firstResponder == v->formula &&
              NSEqualRanges(v->formula.selectedRange, NSMakeRange(32, 5)),
          "definition returns to selected formula text");
  capture(v, dir, @"08-selection.png");
  press(@selector(togglePlay:));
  NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:1];
  while (v->session.time == 5 && deadline.timeIntervalSinceNow > 0)
    [NSRunLoop.currentRunLoop
        runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.04]];
  require(v->session.time > 5, "native playback advances shared playhead");
  press(@selector(togglePlay:));
  require(!v->timer, "pause clears playback timer");
  require(!visible({}, Path::North, 0) && visible({}, Path::North, 14) &&
              !visible({}, Path::South, 0) && visible({}, Path::South, 10),
          "both routes enter hidden and leave visible");
  for (int peak = 2; peak <= 9; ++peak) {
    Score score{0, peak};
    require(light(score, peak - 2) == 0 && light(score, peak - 1) == .5 &&
                light(score, peak) == 1 && light(score, peak + 2) == .5 &&
                light(score, peak + 4) == 0,
            "envelope landmarks");
  }
  puts("PASS: both routes, scrub/play/pause, sightlines, cue landmarks, linked "
       "undo, rejection, checkpoint and keyboard focus");
}
int main(int argc, char **argv) {
  @autoreleasepool {
    [NSApplication sharedApplication];
    [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
    NSWindow *win = [[NSWindow alloc]
        initWithContentRect:NSMakeRect(0, 0, 920, 585)
                  styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable
                    backing:NSBackingStoreBuffered
                      defer:NO];
    win.title = @"Lived spaces · Exhibition study";
    win.releasedWhenClosed = NO;
    Studio *view = [[Studio alloc] initWithFrame:win.contentView.bounds];
    win.contentView = view;
    [win center];
    [win makeKeyAndOrderFront:nil];
    [NSApp finishLaunching];
    if (argc == 3 && strcmp(argv[1], "--check") == 0)
      replay(view, [NSString stringWithUTF8String:argv[2]]);
    else if (argc == 1) {
      [NSNotificationCenter.defaultCenter
          addObserverForName:NSWindowWillCloseNotification
                      object:win
                       queue:nil
                  usingBlock:^(NSNotification *note) {
                    (void)note;
                    [NSApp terminate:nil];
                  }];
      [NSApp activateIgnoringOtherApps:YES];
      [NSApp run];
    } else
      return 2;
  }
}
