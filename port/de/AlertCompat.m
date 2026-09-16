// Original NSAlert content presented through a real UIKit alert. Responses are
// returned only after a user action; no automatic acceptance or fake result.
#import <UIKit/UIKit.h>
@interface DEAlertButton : NSObject
@property(nonatomic,copy) NSString *title,*keyEquivalent;
@property(nonatomic) NSUInteger keyEquivalentModifierMask;
@property(nonatomic,getter=isEnabled) BOOL enabled;
@end
@implementation DEAlertButton @end
@interface NSAlert : NSObject
@property(nonatomic,copy) NSString *messageText,*informativeText;
@property(nonatomic) NSInteger alertStyle;
@property(nonatomic,weak) id delegate;
@property(nonatomic,strong) NSMutableArray<DEAlertButton *> *deButtons;
@end
@implementation NSAlert
- (id)init { if((self=[super init])) {_messageText=@"";_informativeText=@"";_deButtons=[NSMutableArray array];}return self; }
- (id)initWithError:(NSError *)error { if((self=[self init])){self.messageText=error.localizedDescription;self.informativeText=error.localizedRecoverySuggestion ?: error.localizedFailureReason ?: @"";}return self; }
+ (id)alertWithError:(NSError *)error { return [[self alloc] initWithError:error]; }
- (void)setMessageText:(NSString *)text { _messageText=[text copy];fprintf(stderr,"DE_ALERT_MESSAGE %s\n",text.UTF8String); }
- (void)setInformativeText:(NSString *)text { _informativeText=[text copy];fprintf(stderr,"DE_ALERT_INFO %s\n",text.UTF8String); }
- (void)setAccessoryView:(id)view { if(view) {fprintf(stderr,"DE_ALERT_ACCESSORY class=%s\n",class_getName([view class]));DEUnsupported("non-nil alert accessory");} }
- (NSArray *)buttons { return self.deButtons.copy; }
- (id)addButtonWithTitle:(NSString *)title { DEAlertButton *button=[DEAlertButton new];button.title=title;button.enabled=YES;button.keyEquivalent=self.deButtons.count==0?@"\r":@"";[self.deButtons addObject:button];return button; }
- (void)setShowsSuppressionButton:(BOOL)show { if(show)DEUnsupported("alert suppression control not yet implemented"); }
- (BOOL)showsSuppressionButton { return NO; }
- (NSInteger)runModal {
 if(!NSThread.isMainThread)DEUnsupported("alert requires main thread");
 UIWindow *window=nil;for(UIWindow *candidate in UIApplication.sharedApplication.windows)if(candidate.isKeyWindow){window=candidate;break;}
 UIViewController *presenter=window.rootViewController;
 while(presenter.presentedViewController)presenter=presenter.presentedViewController;
 if(!presenter || !presenter.view.window)DEUnsupported("alert has no visible presenter");
 if(!self.deButtons.count)[self addButtonWithTitle:@"OK"];
 UIAlertController *alert=[UIAlertController alertControllerWithTitle:self.messageText message:self.informativeText preferredStyle:UIAlertControllerStyleAlert];
 __block BOOL chosen=NO;__block NSInteger response=0;
 for(NSUInteger i=0;i<self.deButtons.count;i++){
  DEAlertButton *button=self.deButtons[i];
  UIAlertAction *action=[UIAlertAction actionWithTitle:button.title style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){response=1000+(NSInteger)i;chosen=YES;}];
  action.enabled=button.enabled;[alert addAction:action];
 }
 fprintf(stderr,"DE_ALERT_PRESENT title=%s info=%s buttons=%lu\n",self.messageText.UTF8String,self.informativeText.UTF8String,(unsigned long)self.deButtons.count);
 [presenter presentViewController:alert animated:NO completion:nil];
 while(!chosen){CFRunLoopRunInMode(kCFRunLoopDefaultMode,0.01,true);}
 fprintf(stderr,"DE_ALERT_RESPONSE actual_action=%ld\n",(long)response);
 return response;
}
+ (BOOL)resolveInstanceMethod:(SEL)sel {fprintf(stderr,"DE_UNSUPPORTED_SELECTOR -[NSAlert %s]\n",sel_getName(sel));DEUnsupported("NSAlert");}
+ (BOOL)resolveClassMethod:(SEL)sel {fprintf(stderr,"DE_UNSUPPORTED_SELECTOR +[NSAlert %s]\n",sel_getName(sel));DEUnsupported("NSAlert");}
@end
