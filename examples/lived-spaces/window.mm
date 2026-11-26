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
enum class Action { SwitchRoute, Seek, West, East, Earlier, Later, Undo };
struct Step {
  Action action;
  double seconds = 0; // Used only by Seek.
};
enum class Mode { Studio, Recording, Stepping, Exploring };

static NSString *describe(Step step) {
  switch (step.action) {
  case Action::SwitchRoute: return @"Switch visitor route";
  case Action::Seek: return [NSString stringWithFormat:@"Set elapsed time to %@ s", @(step.seconds)];
  case Action::West: return @"Move partition −1 m";
  case Action::East: return @"Move partition +1 m";
  case Action::Earlier: return @"Move lighting peak 1 s earlier";
  case Action::Later: return @"Move lighting peak 1 s later";
  case Action::Undo: return @"Undo last score edit";
  }
}

@interface Studio : NSView {
@public
  StudioSession session;
  std::optional<StudioSession> checkpoint;
  Mode mode;
  StudioSession origin, returnPoint;
  std::vector<Step> steps;
  size_t cursor;
  NSButton *record, *advance, *sequencePlay, *branch;
  NSTextView *transcript;
  NSTextField *position;
  NSTimer *sequenceTimer;
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
    record = [self button:@"Record new" x:22 y:568 action:@selector(record:)];
    advance = [self button:@"Step" x:180 y:568 action:@selector(advance:)];
    sequencePlay = [self button:@"Play sequence" x:287 y:568 action:@selector(sequencePlay:)];
    branch = [self button:@"Explore" x:460 y:568 action:@selector(branch:)];
    for (NSButton *b in @[record, advance, sequencePlay, branch]) {
      NSUInteger number = [@[record, advance, sequencePlay, branch] indexOfObject:b] + 1;
      b.keyEquivalent = @(number).stringValue;
      b.keyEquivalentModifierMask = NSEventModifierFlagCommand;
      [b setFrameSize:NSMakeSize(b == advance ? 100 : 151, b.frame.size.height)];
    }
    position = [NSTextField labelWithString:@""];
    position.frame = NSMakeRect(630, 572, 280, 24);
    [self addSubview:position];
    NSScrollView *scroll = [[NSScrollView alloc] initWithFrame:NSMakeRect(25, 608, 870, 92)];
    scroll.hasVerticalScroller = YES;
    transcript = [[NSTextView alloc] initWithFrame:scroll.contentView.bounds];
    transcript.editable = NO;
    [transcript setAccessibilityLabel:@"Authored steps"];
    scroll.documentView = transcript;
    [self addSubview:scroll];
    [self showSteps];
  }
  return self;
}
- (void)refresh {
  bool stepping = mode == Mode::Stepping, exploring = mode == Mode::Exploring;
  bool recording = mode == Mode::Recording;
  for (NSButton *b in buttons) {
    if (sel_isEqual(b.action, @selector(save:)) || sel_isEqual(b.action, @selector(restore:)))
      b.enabled = mode == Mode::Studio;
    else if (b == play)
      b.enabled = mode == Mode::Studio || exploring;
    else if (b != inspect && !sel_isEqual(b.action, @selector(focusFormula:)))
      b.enabled = !stepping;
  }
  clockSlider.enabled = !stepping;
  // A drag authors one time destination, on release.
  clockSlider.continuous = !recording;
  record.enabled = !exploring;
  record.title = recording ? @"Finish ⌘1" : @"Record new ⌘1";
  advance.enabled = sequencePlay.enabled = !recording && !exploring && !steps.empty();
  advance.title = @"Step ⌘2";
  sequencePlay.title = sequenceTimer ? @"Pause steps ⌘3" : @"Play steps ⌘3";
  branch.enabled = stepping || exploring;
  branch.title = exploring ? @"Return ⌘4" : @"Explore ⌘4";
  NSString *state = recording ? @"Recording" : exploring ? @"Exploring" : stepping ? @"On path" : @"Authored steps";
  position.stringValue = [NSString stringWithFormat:@"%@ · %zu / %zu", state, cursor, steps.size()];
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
- (void)showSteps {
  NSMutableArray *lines = [NSMutableArray array];
  for (size_t i = 0; i < steps.size(); ++i)
    [lines addObject:[NSString stringWithFormat:@"%@ %zu. %@", i+1 == cursor ? @"▶" : @"  ",
                                                i+1, describe(steps[i])]];
  transcript.string = lines.count ? [lines componentsJoinedByString:@"\n"] :
      @"Choose Record new, perform actions in the studio, then choose Finish.";
  if (cursor) {
    NSUInteger offset = 0;
    for (size_t i = 0; i + 1 < cursor; ++i) offset += [lines[i] length] + 1;
    [transcript scrollRangeToVisible:NSMakeRange(offset, [lines[cursor-1] length])];
  }
  [self refresh];
}
- (void)pauseSteps {
  [sequenceTimer invalidate];
  sequenceTimer = nil;
}
- (void)record:(id)s {
  [self stop];
  [self pauseSteps];
  if (mode == Mode::Recording) {
    mode = Mode::Studio;
  } else {
    origin = session;
    steps.clear();
    mode = Mode::Recording;
  }
  cursor = 0;
  message = @"";
  [self showSteps];
}
- (bool)apply:(Step)step {
  Score next = session.score;
  switch (step.action) {
  case Action::SwitchRoute:
    [self stop];
    session.route = session.route == Path::North ? Path::South : Path::North;
    session.time = std::min(session.time, double(duration(session.route)));
    return true;
  case Action::Seek:
    if (session.time == step.seconds) return false;
    session.time = step.seconds;
    return true;
  case Action::West: --next.partition; break;
  case Action::East: ++next.partition; break;
  case Action::Earlier: --next.peak; break;
  case Action::Later: ++next.peak; break;
  case Action::Undo:
    if (session.undo()) { message = @"Edit undone"; return true; }
    message = @"No edits to undo";
    return false;
  }
  bool ok = session.edit(next);
  message = ok ? @"Edit committed" : @"Outside score range · edit rejected";
  return ok;
}
- (void)performStep:(Step)step {
  message = @"";
  if ([self apply:step] && mode == Mode::Recording) {
    steps.push_back(step);
    cursor = steps.size();
    [self showSteps];
  } else [self refresh];
}
- (void)advance:(id)s {
  if (mode == Mode::Studio) {
    [self stop];
    session = origin;
    cursor = 0;
    mode = Mode::Stepping;
  }
  message = @"";
  [self apply:steps[cursor++]];
  if (cursor == steps.size()) {
    mode = Mode::Studio;
    [self pauseSteps];
  }
  [self showSteps];
}
- (void)sequencePlay:(id)s {
  if (sequenceTimer) [self pauseSteps];
  else {
    sequenceTimer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(advance:)
                                                   userInfo:nil repeats:YES];
    [self advance:s];
  }
  [self refresh];
}
- (void)branch:(id)s {
  [self pauseSteps];
  [self stop];
  if (mode == Mode::Stepping) {
    returnPoint = session;
    mode = Mode::Exploring;
  } else {
    session = returnPoint;
    mode = Mode::Stepping;
  }
  message = @"";
  [self refresh];
}
- (void)route:(id)s { [self performStep:{Action::SwitchRoute}]; }
- (void)west:(id)s { [self performStep:{Action::West}]; }
- (void)east:(id)s { [self performStep:{Action::East}]; }
- (void)earlier:(id)s { [self performStep:{Action::Earlier}]; }
- (void)later:(id)s { [self performStep:{Action::Later}]; }
- (void)undo:(id)s { [self performStep:{Action::Undo}]; }
- (void)scrub:(id)s { [self performStep:{Action::Seek, clockSlider.doubleValue}]; }
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
  double timeX = left + step * session.time;
  line({timeX, 92}, {timeX, 295}, ink(), 1);
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
static void shortcut(Studio *v, NSString *key) {
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
}

static void press(Studio *v, SEL action) {
  for (NSButton *button in v->buttons) {
    if (sel_isEqual(button.action, action) && button.enabled) {
      [button performClick:nil];
      return;
    }
  }
  require(false, "native control enabled");
}

static void replay(Studio *v, NSString *dir) {
  auto sight = [&] {
    return visible(v->session.score, v->session.route, v->session.time);
  };
  require(sight() && light(v->session.score, 7) == .75, "initial north reveal");
  capture(v, dir, @"01-routes.png");
  press(v, @selector(east:));
  require(!sight() && visible(v->session.score, Path::South, 7),
          "partition blocks only north at 7 s");
  capture(v, dir, @"02-partition.png");
  press(v, @selector(later:));
  require(!sight() && light(v->session.score, 7) == 1,
          "cue edit changes intensity while obscured");
  capture(v, dir, @"03-peak.png");
  press(v, @selector(undo:));
  require(!sight() && light(v->session.score, 7) == .75,
          "timing undo preserves spatial edit");
  press(v, @selector(undo:));
  require(sight() && v->session.score == Score{} && v->session.history.empty(),
          "undo restores both views");
  capture(v, dir, @"04-undo.png");
  press(v, @selector(restore:));
  require([v->message isEqual:@"Set a checkpoint first"],
          "missing checkpoint handled");
  // Performed explanation: switch visitor, scrub, move partition, change cue,
  // explore space.
  press(v, @selector(route:));
  v->clockSlider.doubleValue = 5;
  [v->clockSlider sendAction:v->clockSlider.action to:v];
  press(v, @selector(west:));
  press(v, @selector(save:));
  StudioSession saved = v->session;
  press(v, @selector(earlier:));
  press(v, @selector(west:));
  press(v, @selector(west:));
  require(v->session.score.partition == -2 && v->session.history.size() == 3 &&
              [v->message containsString:@"rejected"],
          "rejected spatial edit is atomic");
  capture(v, dir, @"05-rejected.png");
  press(v, @selector(restore:));
  require(v->session.route == Path::South && v->session.time == 5 &&
              v->session.score == saved.score &&
              v->session.history == saved.history,
          "checkpoint restores authoring context and history");
  capture(v, dir, @"06-restored.png");
  shortcut(v, @"f");
  shortcut(v, @"d");
  capture(v, dir, @"07-definition.png");
  shortcut(v, @"d");
  require(v.window.firstResponder == v->formula &&
              NSEqualRanges(v->formula.selectedRange, NSMakeRange(32, 5)),
          "definition returns to selected formula text");
  capture(v, dir, @"08-selection.png");
  press(v, @selector(togglePlay:));
  NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:1];
  while (v->session.time == 5 && deadline.timeIntervalSinceNow > 0)
    [NSRunLoop.currentRunLoop
        runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.04]];
  require(v->session.time > 5, "native playback advances shared playhead");
  press(v, @selector(togglePlay:));
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
static void checkPerformance(Studio *v, NSString *dir) {
  auto seek = [&](double seconds) {
    require(v->clockSlider.enabled, "time control enabled");
    v->clockSlider.doubleValue = seconds;
    [v->clockSlider sendAction:v->clockSlider.action to:v];
  };
  auto same = [](const StudioSession &a, const StudioSession &b) {
    return a.route == b.route && a.time == b.time && a.score == b.score && a.history == b.history;
  };
  // A non-default origin with prior history makes a reset-to-default bug observable.
  press(v, @selector(earlier:));
  press(v, @selector(save:));
  StudioSession original = v->session;
  shortcut(v, @"1");
  press(v, @selector(route:));
  seek(4);
  press(v, @selector(west:));
  StudioSession third = v->session;
  press(v, @selector(later:));
  seek(5);
  seek(5); // No-op must not enter the path.
  StudioSession fifth = v->session;
  require(v->steps.size() == 5 && v->cursor == 5 && !v->clockSlider.continuous,
          "five committed semantic actions");
  shortcut(v, @"1");
  NSString *authored = [v->transcript.string copy];
  require([authored containsString:@"5. Set elapsed time to 5 s"], "textual sequence");
  capture(v, dir, @"01-authored.png");
  shortcut(v, @"3");
  require(v->sequenceTimer && v->cursor == 1, "automatic play from origin");
  NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:4];
  while (v->cursor < 3 && deadline.timeIntervalSinceNow > 0)
    [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.04]];
  shortcut(v, @"4");
  require(v->mode == Mode::Exploring && !v->sequenceTimer && v->cursor == 3 &&
          same(v->session, third), "interrupt automatic playback after action three");
  NSString *pathAtThree = [v->transcript.string copy];
  press(v, @selector(undo:));
  press(v, @selector(route:));
  seek(9);
  press(v, @selector(earlier:));
  press(v, @selector(east:));
  require(v->session.history != third.history && v->session.score != third.score &&
          v->session.route != third.route && v->session.time != third.time &&
          [v->transcript.string isEqual:pathAtThree], "exploration isolated");
  capture(v, dir, @"02-exploring.png");
  shortcut(v, @"4");
  require(v->mode == Mode::Stepping && same(v->session, third) && v->cursor == 3 &&
          [v->transcript.string isEqual:pathAtThree], "return restores complete prefix");
  capture(v, dir, @"03-returned.png");
  shortcut(v, @"2");
  require(v->cursor == 4 && v->session.score == fifth.score && v->session.time == 4,
          "resume at authored lighting edit");
  shortcut(v, @"2");
  require(v->mode == Mode::Studio && same(v->session, fifth) && v->cursor == 5 &&
          v->steps.size() == 5, "resume to authored endpoint and history");
  capture(v, dir, @"04-resumed.png");
  press(v, @selector(undo:));
  require(v->session.score == third.score && v->session.history == third.history &&
          v->session.route == Path::South && v->session.time == 5 &&
          light(v->session.score, 5) == 1 && !visible(v->session.score, Path::South, 5), "undo lighting before geometry");
  capture(v, dir, @"05-undo-light.png");
  press(v, @selector(undo:));
  require(v->session.score == original.score && v->session.history == original.history &&
          visible(v->session.score, Path::South, 5),
          "undo partition preserves pre-recording history");
  capture(v, dir, @"06-undo-partition.png");
  press(v, @selector(restore:));
  require(same(v->session, original), "manual checkpoint survives performance");
  puts("PASS: record five, timed replay, interrupt, explore, return, step twice, ordered undo, manual checkpoint");
}
int main(int argc, char **argv) {
  @autoreleasepool {
    [NSApplication sharedApplication];
    [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
    NSWindow *win = [[NSWindow alloc]
        initWithContentRect:NSMakeRect(0, 0, 920, 714)
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
    else if (argc == 3 && strcmp(argv[1], "--check-performance") == 0)
      checkPerformance(view, [NSString stringWithUTF8String:argv[2]]);
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
