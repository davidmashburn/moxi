#import <UIKit/UIKit.h>

#import "MoxiDemoViewController.h"

@interface MoxiAppDelegate : UIResponder <UIApplicationDelegate>
@property(nonatomic, strong) UIWindow *window;
@end

@implementation MoxiAppDelegate

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    (void)application;
    (void)launchOptions;
    self.window = [[UIWindow alloc] initWithFrame:CGRectMake(0.0, 0.0, 375.0, 812.0)];
    self.window.rootViewController = [[MoxiDemoViewController alloc] init];
    [self.window makeKeyAndVisible];
    return YES;
}

@end

int main(int argc, char *argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass(MoxiAppDelegate.class));
    }
}
