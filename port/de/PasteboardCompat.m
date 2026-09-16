// Read-side bridge to the actual UIKit pasteboard. No fabricated contents.
#import <UIKit/UIKit.h>
@interface NSPasteboard : NSObject
@property(nonatomic,strong) UIPasteboard *uiPasteboard;
@end
@implementation NSPasteboard
+ (instancetype)generalPasteboard { static NSPasteboard *board;static dispatch_once_t once;dispatch_once(&once,^{board=[self new];board.uiPasteboard=UIPasteboard.generalPasteboard;});return board; }
- (NSInteger)changeCount { return self.uiPasteboard.changeCount; }
- (NSArray *)types { return self.uiPasteboard.pasteboardTypes; }
- (NSString *)stringForType:(NSString *)type { if (![type isEqualToString:@"public.utf8-plain-text"]) DEUnsupported("pasteboard string type");return self.uiPasteboard.string; }
- (NSString *)availableTypeFromArray:(NSArray<NSString *> *)types { for (NSString *type in types) if ([self.uiPasteboard containsPasteboardTypes:@[type]]) return type;return nil; }
+ (BOOL)resolveInstanceMethod:(SEL)sel {fprintf(stderr,"DE_UNSUPPORTED_SELECTOR -[NSPasteboard %s]\n",sel_getName(sel));DEUnsupported("NSPasteboard");}
+ (BOOL)resolveClassMethod:(SEL)sel {fprintf(stderr,"DE_UNSUPPORTED_SELECTOR +[NSPasteboard %s]\n",sel_getName(sel));DEUnsupported("NSPasteboard");}
@end
