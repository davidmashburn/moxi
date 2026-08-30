#import "MoxiDemoViewController.h"

#import "../hosts/moxi_ios_host.h"

@interface MoxiDemoViewController ()
@property(nonatomic, assign) void *moxiHost;
@property(nonatomic, strong) UIView *surface;
@property(nonatomic, strong) UILabel *statusLabel;
@property(nonatomic, assign) NSUInteger frameCount;
@end

static MoxiDemoViewController *moxi_controller(void *context) {
    return (__bridge MoxiDemoViewController *)context;
}

static void moxi_demo_resize(void *context, float width, float height, float scale) {
    MoxiDemoViewController *controller = moxi_controller(context);
    dispatch_async(dispatch_get_main_queue(), ^{
        controller.statusLabel.text = [NSString stringWithFormat:
            @"Moxi iOS host  •  %.0f × %.0f  @ %.1fx\nUIKit lifecycle + MetalKit frame loop + touch callbacks",
            width, height, scale];
    });
}

static void moxi_demo_event(
    void *context,
    int kind,
    int pointer_id,
    float x,
    float y,
    int buttons,
    int modifiers
) {
    (void)buttons;
    (void)modifiers;
    MoxiDemoViewController *controller = moxi_controller(context);
    dispatch_async(dispatch_get_main_queue(), ^{
        controller.statusLabel.text = [NSString stringWithFormat:
            @"Moxi iOS host  •  event %d / pointer %d\nlocation %.0f, %.0f",
            kind, pointer_id, x, y];
    });
}

static void moxi_demo_key(void *context, int key, int modifiers) {
    (void)context;
    (void)key;
    (void)modifiers;
}

static void moxi_demo_text(void *context, const char *text, int start, int end) {
    (void)context;
    (void)text;
    (void)start;
    (void)end;
}

static void moxi_demo_composition(void *context, const char *text, int start, int end) {
    (void)context;
    (void)text;
    (void)start;
    (void)end;
}

static void moxi_demo_frame(void *context) {
    MoxiDemoViewController *controller = moxi_controller(context);
    controller.frameCount += 1;
}

@implementation MoxiDemoViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithRed:0.055 green:0.067 blue:0.10 alpha:1.0];

    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(24.0, 64.0, 327.0, 80.0)];
    self.statusLabel.numberOfLines = 0;
    self.statusLabel.textColor = [UIColor colorWithWhite:0.94 alpha:1.0];
    self.statusLabel.font = [UIFont monospacedSystemFontOfSize:14.0 weight:UIFontWeightRegular];
    self.statusLabel.text = @"Starting Moxi iOS host…";
    [self.view addSubview:self.statusLabel];

    MoxiHostCallbacks callbacks = {
        .event = moxi_demo_event,
        .key = moxi_demo_key,
        .text = moxi_demo_text,
        .composition = moxi_demo_composition,
        .resize = moxi_demo_resize,
        .frame = moxi_demo_frame,
    };
    self.moxiHost = moxi_ios_host_create(375.0f, 812.0f, callbacks, (__bridge void *)self);
    self.surface = (__bridge UIView *)self.moxiHost;
    self.surface.frame = self.view.bounds;
    self.surface.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.surface.backgroundColor = [UIColor clearColor];
    self.surface.opaque = NO;
    [self.view insertSubview:self.surface atIndex:0];
}

- (void)dealloc {
    if (self.moxiHost != NULL) {
        moxi_ios_host_destroy(self.moxiHost);
        self.moxiHost = NULL;
    }
}

@end
