// Read-side bridge to the actual UIKit pasteboard. No fabricated contents.
// iOS shows a system permission prompt whenever pasteboard *contents* are read.
// The launcher's WebView probes paste availability at startup; answer that from
// metadata (which does not prompt) and read contents only for a user paste.
#import <UIKit/UIKit.h>
static CFTimeInterval DEPasteAllowedUntil;
static void DEArmUserPaste(void) { DEPasteAllowedUntil=CACurrentMediaTime()+2.0; }
@interface NSPasteboard : NSObject
@property(nonatomic,strong) UIPasteboard *uiPasteboard;
@end
@implementation NSPasteboard
+ (instancetype)generalPasteboard { static NSPasteboard *board;static dispatch_once_t once;dispatch_once(&once,^{board=[self new];board.uiPasteboard=UIPasteboard.generalPasteboard;});return board; }
- (NSInteger)changeCount { return self.uiPasteboard.changeCount; }
- (NSArray *)types { return self.uiPasteboard.hasStrings?@[@"public.utf8-plain-text"]:@[]; }
- (NSString *)stringForType:(NSString *)type {
    if (![type isEqualToString:@"public.utf8-plain-text"]) DEUnsupported("pasteboard string type");
    if (CACurrentMediaTime()>DEPasteAllowedUntil) { fprintf(stderr,"DE_PASTEBOARD_READ_DEFERRED no user paste in progress\n"); return nil; }
    return self.uiPasteboard.string;
}
- (NSString *)availableTypeFromArray:(NSArray<NSString *> *)types { for (NSString *type in types) if ([type isEqualToString:@"public.utf8-plain-text"] && self.uiPasteboard.hasStrings) return type;return nil; }
+ (BOOL)resolveInstanceMethod:(SEL)sel {fprintf(stderr,"DE_UNSUPPORTED_SELECTOR -[NSPasteboard %s]\n",sel_getName(sel));DEUnsupported("NSPasteboard");}
+ (BOOL)resolveClassMethod:(SEL)sel {fprintf(stderr,"DE_UNSUPPORTED_SELECTOR +[NSPasteboard %s]\n",sel_getName(sel));DEUnsupported("NSPasteboard");}
@end
