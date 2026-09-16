#!/usr/bin/env python3
"""Compile actual touch translation methods and verify rapid-interaction ordering."""
from pathlib import Path
import subprocess,hashlib,json
root=Path(__file__).resolve().parents[1]; out=root/'generated/de-touch-ordering-regression'
out.mkdir(parents=True,exist_ok=True)
s=(root/'port/de/WindowViewCompat.m').read_text()
mouse=s[s.index('- (void)sendGameMouse:'):s.index('- (void)touchesBegan:')]
key=s[s.index('static void DEPostGameKeyWithModifiers('):s.index('static void DEConnectGameKeyboard(void)')]
protocol=s[s.index('@protocol DEGameMouseEvent'):s.index('@interface DEGameViewHost')]
preamble=r'''
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/message.h>
#include "EventCompat.m"
#include "EventQueueCompat.m"
#include "PointerEventCompat.m"
static CGPoint testPointer;
CGPoint DEUIKitPointerPosition(void){return testPointer;}
void DEUIKitSetPointerPosition(CGPoint p){testPointer=p;}
@interface NSApplication:NSObject
@property(nonatomic,strong) DEEventQueue *queue;
+(instancetype)sharedApplication;
-(void)postEvent:(id)e atStart:(BOOL)start;
@end
@implementation NSApplication
+(instancetype)sharedApplication{static NSApplication *a; if(!a){a=[self new];a.queue=[DEEventQueue new];}return a;}
-(void)postEvent:(id)e atStart:(BOOL)start{[self.queue post:e atStart:start];}
@end
@interface FakeKeyWindow:UIWindow @end
@implementation FakeKeyWindow
-(BOOL)isKeyWindow{return YES;}
@end
@interface FakeContent:NSObject
@property(nonatomic,strong) UIView *deHost;
@end
@implementation FakeContent @end
@interface NSWindow:NSObject
@property(nonatomic) BOOL deVisible;
@property(nonatomic,strong) UIWindow *deUIKitWindow;
@property(nonatomic,strong) FakeContent *contentView;
@property(nonatomic) NSInteger windowNumber;
@end
@implementation NSWindow @end
@interface FakeOwner:NSObject
@property(nonatomic,strong) NSWindow *window;
@end
@implementation FakeOwner @end
@interface FakeTouch:NSObject
@property(nonatomic) CGPoint point;
@property(nonatomic) NSTimeInterval timestamp;
@property(nonatomic) NSUInteger tapCount;
-(CGPoint)locationInView:(UIView *)view;
@end
@implementation FakeTouch
-(CGPoint)locationInView:(UIView *)view{return self.point;}
@end
static __weak NSWindow *DEKeyGameWindow;
static BOOL DEGlobalTouchCommandMode;
static void DELogTouchDetail(id t,NSUInteger n){}
static void DELogSynthesizedMouse(NSUInteger p,id e,UIEventButtonMask m,SEL s){}
@interface DEGameViewHost:UIView
@property(nonatomic,strong) CALayer *gameLayer;
@property(nonatomic,strong) id originalView;
@property(nonatomic) NSInteger gameClickCount;
@property(nonatomic) CGPoint previousTouchPoint;
@property(nonatomic) UIEventButtonMask gameButtonMask;
-(void)sendGameMouse:(NSUInteger)type touch:(UITouch *)touch cancelled:(BOOL)cancelled;
@end
'''
main=r'''
static void pump(double seconds){NSDate *end=[NSDate dateWithTimeIntervalSinceNow:seconds];while(end.timeIntervalSinceNow>0)CFRunLoopRunInMode(kCFRunLoopDefaultMode,0.005,true);}
int main(void){@autoreleasepool{
setenv("AGEPAD_POINTER_STATE","1",1);
NSWindow *w=[NSWindow new];w.deVisible=YES;w.deUIKitWindow=[FakeKeyWindow new];w.contentView=[FakeContent new];w.contentView.deHost=[[UIView alloc]initWithFrame:CGRectMake(0,0,800,600)];DEKeyGameWindow=w;
FakeOwner *owner=[FakeOwner new];owner.window=w;
DEGameViewHost *host=[DEGameViewHost new];host.originalView=owner;host.gameClickCount=1;
FakeTouch *a=[FakeTouch new];a.point=CGPointMake(10,20);a.timestamp=NSProcessInfo.processInfo.systemUptime;a.tapCount=1;
[host sendGameMouse:1 touch:(UITouch *)a cancelled:NO];
[host sendGameMouse:2 touch:(UITouch *)a cancelled:NO];
pump(0.02);
FakeTouch *b=[FakeTouch new];b.point=CGPointMake(100,200);b.timestamp=NSProcessInfo.processInfo.systemUptime;b.tapCount=1;
[host sendGameMouse:1 touch:(UITouch *)b cancelled:NO];
[host sendGameMouse:6 touch:(UITouch *)b cancelled:NO];
pump(0.14);
NSMutableArray *sequence=[NSMutableArray new];for(NSEvent *e in NSApplication.sharedApplication.queue.events)[sequence addObject:@{ @"type":@(e.type),@"x":@(e.locationInWindow.x),@"event":@(e.eventNumber)}];
[NSApplication.sharedApplication.queue.events removeAllObjects];
DEPostGameKey(44,@"/",YES);pump(0.02);
NSEvent *key=NSApplication.sharedApplication.queue.events.firstObject;
[host sendGameMouse:2 touch:(UITouch *)b cancelled:NO];pump(0.14);
[NSApplication.sharedApplication.queue.events removeAllObjects];
host.gameButtonMask=UIEventButtonMaskSecondary;
[host sendGameMouse:1 touch:(UITouch *)b cancelled:NO];
[host sendGameMouse:6 touch:(UITouch *)b cancelled:NO];
[host sendGameMouse:2 touch:(UITouch *)b cancelled:NO];pump(0.14);
NSMutableArray *secondary=[NSMutableArray new];
for(NSEvent *e in NSApplication.sharedApplication.queue.events)[secondary addObject:@{@"type":@(e.type),@"button":@(e.buttonNumber)}];
NSDictionary *result=@{ @"mouse_sequence":sequence,@"hardware_secondary":secondary,@"synthetic_key_event_type":@(key.type),@"synthetic_key_code":@(key.keyCode),@"polled_slash_down":@(CGEventSourceKeyState(0,44)),@"physical_keyboard_present":@(GCKeyboard.coalescedKeyboard.keyboardInput!=nil)};
puts([[NSString alloc]initWithData:[NSJSONSerialization dataWithJSONObject:result options:NSJSONWritingPrettyPrinted error:nil] encoding:NSUTF8StringEncoding].UTF8String);
return 0;
}}
'''
(out/'InputProbe.m').write_text(preamble+protocol+'\n@implementation DEGameViewHost\n'+mouse+'\n@end\n'+key+main)
(out/'extracted-source.json').write_text(json.dumps({'source':'port/de/WindowViewCompat.m','sha256':hashlib.sha256(s.encode()).hexdigest(),'methods':['sendGameMouse','DEPostGameKey'],'note':'Exact source extraction; fixture supplies touch/window objects, actual EventCompat/EventQueueCompat/PointerEventCompat included.'},indent=2))
sdk=subprocess.check_output(['xcrun','--sdk','iphonesimulator','--show-sdk-path'],text=True).strip()
subprocess.run(['xcrun','clang','-fobjc-arc','-target','arm64-apple-ios26.0-simulator','-isysroot',sdk,'-I',str(root/'port/de'),str(out/'InputProbe.m'),'-framework','Foundation','-framework','UIKit','-framework','QuartzCore','-framework','GameController','-framework','CoreGraphics','-o',str(out/'InputProbe')],check=True)
subprocess.run(['codesign','-s','-','--force',str(out/'InputProbe')],check=True)

# Exercise the real adapter in the only permitted already-booted Simulator.
device='574671AD-6F61-4558-9528-BF946DDB760A'
boot=json.loads(subprocess.check_output(['xcrun','simctl','list','devices','booted','-j'],text=True))
assert [d['udid'] for group in boot['devices'].values() for d in group]==[device]
run=subprocess.run(['xcrun','simctl','spawn',device,str(out/'InputProbe')],capture_output=True,text=True,timeout=30)
(out/'run.stderr').write_text(run.stderr)
assert run.returncode==0,run.stderr
result=json.loads(run.stdout)
(out/'result.json').write_text(json.dumps(result,indent=2))
assert [event['type'] for event in result['mouse_sequence']]==[1,2,1,6],result
assert [event['event'] for event in result['mouse_sequence']]==[1,2,3,4],result
assert result['hardware_secondary']==[{'type':3,'button':1},{'type':7,'button':1},{'type':4,'button':1}],result
print('PASS: ordered touch delivery and hardware secondary down/drag/up in the actual adapter')
