#import <UIKit/UIKit.h>

@interface ScoutController : UIViewController
@property(nonatomic, strong) UILabel *touchLabel;
@property(nonatomic, strong) UILabel *pinchLabel;
@property(nonatomic) NSUInteger tapCount;
@end

@implementation ScoutController
- (BOOL)prefersStatusBarHidden { return YES; }
- (UIInterfaceOrientationMask)supportedInterfaceOrientations { return UIInterfaceOrientationMaskLandscape; }
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithRed:.10 green:.14 blue:.17 alpha:1];
    UIScrollView *scroll = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    scroll.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:scroll];
    UIStackView *stack = [[UIStackView alloc] initWithFrame:CGRectZero];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 18;
    stack.alignment = UIStackViewAlignmentLeading;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [scroll addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor constant:40],
        [stack.trailingAnchor constraintLessThanOrEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor constant:-40],
        [stack.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor constant:32],
        [stack.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor constant:-32],
        [stack.widthAnchor constraintLessThanOrEqualToConstant:900],
        [scroll.contentLayoutGuide.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor]
    ]];
    [stack addArrangedSubview:[self label:@"AgePad · Hardware Scout" size:34 weight:UIFontWeightBold color:UIColor.whiteColor]];
    [stack addArrangedSubview:[self label:@"Native iPad test build" size:18 weight:UIFontWeightSemibold color:[UIColor colorWithRed:.75 green:.81 blue:.84 alpha:1]]];
    [stack addArrangedSubview:[self label:@"The iPad can install and run this native test. The Age of Empires game is not in this build yet. The current Steam DE game only runs in the Mac-assisted Simulator setup." size:19 weight:UIFontWeightRegular color:UIColor.whiteColor]];
    [stack addArrangedSubview:[self label:@"Next for a playable iPad build: compile the game for iPad hardware, move imported data into the app's Documents folder, and replace the Mac Steam helper with an on-device path." size:17 weight:UIFontWeightRegular color:[UIColor colorWithRed:.75 green:.81 blue:.84 alpha:1]]];
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:@"Test tap" forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont boldSystemFontOfSize:22];
    button.tintColor = UIColor.whiteColor;
    button.backgroundColor = [UIColor colorWithRed:.27 green:.35 blue:.25 alpha:1];
    [button.widthAnchor constraintGreaterThanOrEqualToConstant:160].active = YES;
    [button.heightAnchor constraintEqualToConstant:58].active = YES;
    button.layer.cornerRadius = 10;
    [button addTarget:self action:@selector(tapped) forControlEvents:UIControlEventTouchUpInside];
    [stack addArrangedSubview:button];
    self.touchLabel = [self label:@"Taps: 0" size:19 weight:UIFontWeightMedium color:UIColor.whiteColor];
    [stack addArrangedSubview:self.touchLabel];
    self.pinchLabel = [self label:@"Pinch on this screen: waiting" size:19 weight:UIFontWeightMedium color:UIColor.whiteColor];
    [stack addArrangedSubview:self.pinchLabel];
    UIPinchGestureRecognizer *pinch = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(pinched:)];
    [self.view addGestureRecognizer:pinch];
}
- (UILabel *)label:(NSString *)text size:(CGFloat)size weight:(UIFontWeight)weight color:(UIColor *)color {
    UILabel *label = [UILabel new];
    label.text = text;
    label.font = [UIFont systemFontOfSize:size weight:weight];
    label.textColor = color;
    label.numberOfLines = 0;
    return label;
}
- (void)tapped { self.touchLabel.text = [NSString stringWithFormat:@"Taps: %lu", (unsigned long)++self.tapCount]; }
- (void)pinched:(UIPinchGestureRecognizer *)gesture {
    self.pinchLabel.text = [NSString stringWithFormat:@"Pinch scale: %.2f", gesture.scale];
}
@end

@interface ScoutDelegate : UIResponder <UIApplicationDelegate>
@property(nonatomic, strong) UIWindow *window;
@end
@implementation ScoutDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options {
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.rootViewController = [ScoutController new];
    [self.window makeKeyAndVisible];
    return YES;
}
- (UIInterfaceOrientationMask)application:(UIApplication *)application supportedInterfaceOrientationsForWindow:(UIWindow *)window {
    return UIInterfaceOrientationMaskLandscape;
}
@end

int main(int argc, char *argv[]) {
    @autoreleasepool { return UIApplicationMain(argc, argv, nil, NSStringFromClass(ScoutDelegate.class)); }
}
