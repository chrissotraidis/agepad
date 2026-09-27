#!/usr/bin/env python3
"""Two-finger tap and touch-gesture behaviour of the real game-view touch code,
run in the AgePad iPad Simulator with scripted touch timelines.

The Simulator can't produce two independent finger touches, so this compiles
the actual touch handlers from port/de/WindowViewCompat.m (touchesBegan..Ended,
the two-finger recogniser, deferred presses, click synthesis) with fake touches
and records the mouse events the game would receive. Real fingers, the Apple
Pencil and multi-finger feel still need the iPad."""
from pathlib import Path
import json, subprocess, sys
root = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root / 'scripts'))
import de_device
out = root / 'generated/de-two-finger-regression'
out.mkdir(parents=True, exist_ok=True)
s = (root / 'port/de/WindowViewCompat.m').read_text()
protocol = s[s.index('@protocol DEGameMouseEvent'):s.index('@interface DEGameViewHost')]
interface = s[s.index('@interface DEGameViewHost'):s.index('static void DEPostGameKey(unsigned short macKey, NSString *characters, BOOL pressed);')]
handlers = s[s.index('- (void)sendGameMouse:'):s.index('- (void)layoutSubviews')]
window_line = next(l for l in s.splitlines() if l.startswith('static const NSTimeInterval DETwoFingerWindow'))
preamble = r'''
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/message.h>
#include "EventCompat.m"
#include "EventQueueCompat.m"
#include "PointerEventCompat.m"
static CGPoint testPointer;
CGPoint DEUIKitPointerPosition(void){return testPointer;}
void DEUIKitSetPointerPosition(CGPoint p){testPointer=p;}
void DEUIKitPinPointer(CGPoint p,NSTimeInterval s){testPointer=p;}
@interface NSApplication:NSObject
@property(nonatomic,strong) DEEventQueue *queue;
+(instancetype)sharedApplication;
-(void)postEvent:(id)e atStart:(BOOL)start;
@end
@implementation NSApplication
+(instancetype)sharedApplication{static NSApplication *a; if(!a){a=[self new];a.queue=[DEEventQueue new];}return a;}
-(void)postEvent:(id)e atStart:(BOOL)start{[self.queue post:e atStart:start];}
@end
@interface FakeContent:NSObject
@property(nonatomic,strong) UIView *deHost;
@end
@implementation FakeContent @end
@interface NSWindow:NSObject
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
@property(nonatomic) UITouchType type;
@property(nonatomic) UITouchPhase phase;
@property(nonatomic,weak) UIView *view;
-(CGPoint)locationInView:(UIView *)view;
@end
@implementation FakeTouch
-(CGPoint)locationInView:(UIView *)view{return self.point;}
@end
@interface FakeEvent:NSObject
@property(nonatomic,strong) NSSet *allTouches;
@property(nonatomic) NSTimeInterval timestamp;
@property(nonatomic) UIEventButtonMask buttonMask;
@end
@implementation FakeEvent @end
static BOOL DEGlobalTouchCommandMode,DEPencilOrderArmed,DEMenuOpen;
TWO_FINGER_WINDOW
static BOOL DEPencilMatchActive(void){return YES;}
static void DERefreshTouchCommandButtons(void){}
static BOOL DEInputVerbose(NSUInteger t){return NO;}
static void DELogTouchDetail(id t,NSUInteger n){}
static void DELogButtonMask(id e,NSUInteger t,UIEventButtonMask m){}
static void DELogSynthesizedMouse(NSUInteger p,id e,UIEventButtonMask m,SEL s){}
'''
main = r'''
static void pump(double seconds){NSDate *end=[NSDate dateWithTimeIntervalSinceNow:seconds];while(end.timeIntervalSinceNow>0)CFRunLoopRunInMode(kCFRunLoopDefaultMode,0.005,true);}
static DEGameViewHost *host;static UIButton *button;
static FakeTouch *touch(CGPoint p,UIView *view){FakeTouch *t=[FakeTouch new];t.point=p;t.tapCount=1;t.type=UITouchTypeDirect;t.view=view;t.phase=UITouchPhaseBegan;t.timestamp=NSProcessInfo.processInfo.systemUptime;return t;}
static FakeEvent *event(NSArray *all){FakeEvent *e=[FakeEvent new];e.allTouches=[NSSet setWithArray:all];e.timestamp=NSProcessInfo.processInfo.systemUptime;return e;}
static void began(FakeTouch *t,NSArray *all){t.phase=UITouchPhaseBegan;t.timestamp=NSProcessInfo.processInfo.systemUptime;[host touchesBegan:[NSSet setWithObject:t] withEvent:(UIEvent *)event(all)];}
static void moved(FakeTouch *t,CGPoint p,NSArray *all){t.point=p;t.phase=UITouchPhaseMoved;t.timestamp=NSProcessInfo.processInfo.systemUptime;[host touchesMoved:[NSSet setWithObject:t] withEvent:(UIEvent *)event(all)];}
static void ended(FakeTouch *t,NSArray *all){t.phase=UITouchPhaseEnded;t.timestamp=NSProcessInfo.processInfo.systemUptime;[host touchesEnded:[NSSet setWithObject:t] withEvent:(UIEvent *)event(all)];}
static NSArray *drain(void){pump(0.45);NSMutableArray *types=[NSMutableArray new];
  for(NSEvent *e in NSApplication.sharedApplication.queue.events)if(e.type!=5)[types addObject:@(e.type)];
  [NSApplication.sharedApplication.queue.events removeAllObjects];host.gameTouch=nil;return types;}
int main(void){@autoreleasepool{
setenv("AGEPAD_POINTER_STATE","1",1);setenv("AGEPAD_TOUCH_DEFER_PRESS","1",1);
NSWindow *w=[NSWindow new];w.contentView=[FakeContent new];w.contentView.deHost=[[UIView alloc]initWithFrame:CGRectMake(0,0,1366,1024)];
FakeOwner *owner=[FakeOwner new];owner.window=w;
host=[[DEGameViewHost alloc]initWithFrame:CGRectMake(0,0,1366,1024)];host.originalView=owner;host.gameClickCount=1;
button=[[UIButton alloc]initWithFrame:CGRectMake(1280,500,76,44)];[host addSubview:button];
NSMutableDictionary *r=[NSMutableDictionary new];
CGPoint p=CGPointMake(600,400),q=CGPointMake(700,420);
// One finger tap on the map: a left click.
{FakeTouch *a=touch(p,host);began(a,@[a]);pump(0.08);ended(a,@[a]);r[@"one_finger_tap"]=drain();}
// Two fingers 80 ms apart, lifted together: a right click only.
{FakeTouch *a=touch(p,host),*b=touch(q,host);began(a,@[a]);pump(0.08);began(b,@[a,b]);pump(0.1);ended(a,@[a,b]);ended(b,@[a,b]);r[@"two_finger_tap"]=drain();}
// Second finger 300 ms after the first (slow tap).
{FakeTouch *a=touch(p,host),*b=touch(q,host);began(a,@[a]);pump(0.30);began(b,@[a,b]);pump(0.1);ended(a,@[a,b]);ended(b,@[a,b]);r[@"slow_two_finger_tap"]=drain();}
// Fingers lifted 150 ms apart.
{FakeTouch *a=touch(p,host),*b=touch(q,host);began(a,@[a]);pump(0.05);began(b,@[a,b]);pump(0.1);ended(a,@[a,b]);pump(0.15);ended(b,@[a,b]);r[@"uneven_lift"]=drain();}
// A finger holding a side button while another taps the map: a left click.
{FakeTouch *z=touch(CGPointMake(1300,520),button),*a=touch(p,host);began(a,@[z,a]);pump(0.08);ended(a,@[z,a]);r[@"tap_while_holding_button"]=drain();}
// Two fingers that move apart (a pinch): no click.
{FakeTouch *a=touch(p,host),*b=touch(q,host);began(a,@[a]);pump(0.05);began(b,@[a,b]);pump(0.05);moved(b,CGPointMake(800,480),@[a,b]);pump(0.05);ended(a,@[a,b]);ended(b,@[a,b]);r[@"pinch"]=drain();}
// Three fingers: no click.
{FakeTouch *a=touch(p,host),*b=touch(q,host),*c=touch(CGPointMake(650,500),host);began(a,@[a]);pump(0.05);began(b,@[a,b]);began(c,@[a,b,c]);pump(0.1);ended(a,@[a,b,c]);ended(b,@[a,b,c]);ended(c,@[a,b,c]);r[@"three_fingers"]=drain();}
// One finger drag: a left-button drag (selection box).
{FakeTouch *a=touch(p,host);began(a,@[a]);pump(0.05);moved(a,CGPointMake(650,450),@[a]);pump(0.05);moved(a,CGPointMake(700,500),@[a]);pump(0.05);ended(a,@[a]);r[@"one_finger_drag"]=drain();}
// Apple Pencil sticky orders: tap selects and arms, later taps order until a
// hold (>=0.45 s) disarms; HUD taps never order; a drag-box selects and arms.
setenv("AGEPAD_PENCIL_STICKY_ORDER","1",1);DEPencilOrderArmed=NO;
#define PTAP(name,pt,hold) {FakeTouch *a=touch(pt,host);a.type=UITouchTypePencil;began(a,@[a]);pump(hold);ended(a,@[a]);r[@name]=drain();}
PTAP("pencil_1_select",p,0.08) PTAP("pencil_2_order",q,0.08) PTAP("pencil_3_order_again",p,0.08)
PTAP("pencil_4_hold_deselect",q,0.5) PTAP("pencil_5_select_again",p,0.08)
PTAP("pencil_6_hud_tap",CGPointMake(600,900),0.08) PTAP("pencil_7_after_hud",p,0.08)
{FakeTouch *a=touch(p,host);a.type=UITouchTypePencil;began(a,@[a]);pump(0.05);moved(a,CGPointMake(700,500),@[a]);pump(0.05);ended(a,@[a]);r[@"pencil_8_box"]=drain();}
PTAP("pencil_9_order_after_box",q,0.08)
puts([[NSString alloc]initWithData:[NSJSONSerialization dataWithJSONObject:r options:NSJSONWritingSortedKeys error:nil] encoding:NSUTF8StringEncoding].UTF8String);
return 0;}}
'''
(out/'TwoFingerProbe.m').write_text(preamble.replace('TWO_FINGER_WINDOW', window_line)+protocol+interface+'\n@implementation DEGameViewHost\n'+handlers+'\n@end\n'+main)
sdk=subprocess.check_output(['xcrun','--sdk','iphonesimulator','--show-sdk-path'],text=True).strip()
subprocess.run(['xcrun','clang','-fobjc-arc','-Wno-deprecated-declarations','-target','arm64-apple-ios26.0-simulator','-isysroot',sdk,'-I',str(root/'port/de'),str(out/'TwoFingerProbe.m'),
                '-framework','Foundation','-framework','UIKit','-framework','QuartzCore','-framework','GameController','-framework','CoreGraphics','-o',str(out/'TwoFingerProbe')],check=True)
subprocess.run(['codesign','-s','-','--force',str(out/'TwoFingerProbe')],check=True,capture_output=True)
device=de_device.device_udid()
boot=json.loads(subprocess.check_output(['xcrun','simctl','list','devices','booted','-j'],text=True))
if device not in [d['udid'] for g in boot['devices'].values() for d in g]:
    print('COMPILED; run skipped: boot the AgePad Simulator (%s) to run it.' % device); sys.exit(0)
run=subprocess.run(['xcrun','simctl','spawn',device,str(out/'TwoFingerProbe')],capture_output=True,text=True,timeout=60)
assert run.returncode==0,run.stderr[-2000:]
r=json.loads(run.stdout.strip().splitlines()[-1])
(out/'result.json').write_text(json.dumps(r,indent=1))
LEFT,RIGHT=[1,2],[3,4]
expect={'one_finger_tap':LEFT,'two_finger_tap':RIGHT,'slow_two_finger_tap':RIGHT,'uneven_lift':RIGHT,
        'tap_while_holding_button':LEFT,'pinch':[],'three_fingers':[],
        'pencil_1_select':LEFT,'pencil_2_order':RIGHT,'pencil_3_order_again':RIGHT,'pencil_4_hold_deselect':LEFT,
        'pencil_5_select_again':LEFT,'pencil_6_hud_tap':LEFT,'pencil_7_after_hud':LEFT,'pencil_9_order_after_box':RIGHT}
bad={k:r[k] for k,v in expect.items() if r[k]!=v}
if r['one_finger_drag'][:1]!=[1] or r['one_finger_drag'][-1:]!=[2] or 6 not in r['one_finger_drag']: bad['one_finger_drag']=r['one_finger_drag']
if r['pencil_8_box'][:1]!=[1] or r['pencil_8_box'][-1:]!=[2] or 6 not in r['pencil_8_box']: bad['pencil_8_box']=r['pencil_8_box']
print(json.dumps(r))
assert not bad,'unexpected: %s' % bad
print('PASS: two-finger taps right-click only (pinch, 3 fingers, side-button hold do not); Pencil tap selects, repeat taps order, hold/HUD disarm, box arms')
