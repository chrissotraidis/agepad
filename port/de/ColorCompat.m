#import <UIKit/UIKit.h>
#include "UnsupportedBoundary.h"
// Keep the distinct runtime name: UIKit already has a private NSColor class.
// The builder aliases the original binary's NSColor class reference to this.
@interface DEDiagnosticNSColor : NSObject
@property(nonatomic,strong) UIColor *uiColor;
@end
@implementation DEDiagnosticNSColor
+ (instancetype)colorWithDeviceRed:(CGFloat)red green:(CGFloat)green blue:(CGFloat)blue alpha:(CGFloat)alpha {
    CGFloat values[]={red,green,blue,alpha};CGColorSpaceRef space=CGColorSpaceCreateDeviceRGB();CGColorRef cg=CGColorCreate(space,values);
    DEDiagnosticNSColor *color=[self new];color.uiColor=[UIColor colorWithCGColor:cg];CGColorRelease(cg);CGColorSpaceRelease(space);return color;
}
+ (instancetype)blackColor { return [self colorWithDeviceRed:0 green:0 blue:0 alpha:1]; }
+ (instancetype)whiteColor { return [self colorWithDeviceRed:1 green:1 blue:1 alpha:1]; }
+ (instancetype)clearColor { return [self colorWithDeviceRed:0 green:0 blue:0 alpha:0]; }
- (CGColorRef)CGColor { return self.uiColor.CGColor; }
- (CGFloat)alphaComponent { return CGColorGetAlpha(self.CGColor); }
+ (BOOL)resolveInstanceMethod:(SEL)sel {fprintf(stderr,"DE_UNSUPPORTED_SELECTOR -[NSColor %s]\n",sel_getName(sel));DEUnsupported("NSColor");}
+ (BOOL)resolveClassMethod:(SEL)sel {fprintf(stderr,"DE_UNSUPPORTED_SELECTOR +[NSColor %s]\n",sel_getName(sel));DEUnsupported("NSColor");}
@end
