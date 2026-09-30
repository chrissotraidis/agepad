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
gestures = (root / 'port/de/NativeTouchGestures.m').read_text()
window_line = next(l for l in s.splitlines() if l.startswith('static const NSTimeInterval DETwoFingerWindow'))
window_line += '\n' + '\n'.join(l for l in s.splitlines() if l.startswith(('static void DESetMaybeSelected', 'static BOOL DEMaybeSelected')))
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
static int escapeDowns;
static void DEPostGameKey(unsigned short key,NSString *characters,BOOL pressed){if(key==53 && pressed)escapeDowns++;}
'''
main = r'''
static void pump(double seconds){NSDate *end=[NSDate dateWithTimeIntervalSinceNow:seconds];while(end.timeIntervalSinceNow>0)CFRunLoopRunInMode(kCFRunLoopDefaultMode,0.005,true);}
static DEGameViewHost *host;static UIButton *button;
static FakeTouch *touch(CGPoint p,UIView *view){FakeTouch *t=[FakeTouch new];t.point=p;t.tapCount=1;t.type=UITouchTypeDirect;t.view=view;t.phase=UITouchPhaseBegan;t.timestamp=NSProcessInfo.processInfo.systemUptime;return t;}
static FakeEvent *event(NSArray *all){FakeEvent *e=[FakeEvent new];e.allTouches=[NSSet setWithArray:all];e.timestamp=NSProcessInfo.processInfo.systemUptime;return e;}
static void began(FakeTouch *t,NSArray *all){t.phase=UITouchPhaseBegan;t.timestamp=NSProcessInfo.processInfo.systemUptime;[host touchesBegan:[NSSet setWithObject:t] withEvent:(UIEvent *)event(all)];}
static void moved(FakeTouch *t,CGPoint p,NSArray *all){t.point=p;t.phase=UITouchPhaseMoved;t.timestamp=NSProcessInfo.processInfo.systemUptime;[host touchesMoved:[NSSet setWithObject:t] withEvent:(UIEvent *)event(all)];}
static void ended(FakeTouch *t,NSArray *all){t.phase=UITouchPhaseEnded;t.timestamp=NSProcessInfo.processInfo.systemUptime;[host touchesEnded:[NSSet setWithObject:t] withEvent:(UIEvent *)event(all)];}
// Replays the queued right-button drag through DE's measured click-drag
// scrolling (see NativeTouchGestures.m) and returns how far the map content
// moved, in view points, as the game would scroll it.
static CGPoint simulateScroll(void){BOOL down=NO;CGPoint a=CGPointZero,cur=CGPointZero,moved=CGPointZero;double t=0;
  for(NSEvent *e in NSApplication.sharedApplication.queue.events){
    if(down){double dt=e.timestamp-t;CGFloat ox=cur.x-a.x,oy=-(cur.y-a.y),r=hypot(ox,1.78*oy);
      if(r>68){CGFloat x=r-68,v=3.84*x+0.0622*x*x;moved.x-=v*dt*ox/r;moved.y-=v*dt*1.78*oy/r;}}
    if(e.type==3){down=YES;a=cur=e.locationInWindow;}
    else if(e.type==7)cur=e.locationInWindow;
    else if(e.type==4)down=NO;
    t=e.timestamp;}
  return moved;}
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
// Finger taps and two-finger orders don't switch the Pencil to orders: the
// next Pencil tap on a unit selects it.
{FakeTouch *a=touch(p,host);began(a,@[a]);pump(0.08);ended(a,@[a]);drain();}
PTAP("pencil_after_finger_tap",q,0.08)
{FakeTouch *a=touch(p,host),*b=touch(q,host);began(a,@[a]);pump(0.08);began(b,@[a,b]);pump(0.1);ended(a,@[a,b]);ended(b,@[a,b]);drain();}
DEPencilOrderArmed=NO;PTAP("pencil_select_before_two_finger",p,0.08)
{FakeTouch *a=touch(p,host),*b=touch(q,host);began(a,@[a]);pump(0.08);began(b,@[a,b]);pump(0.1);ended(a,@[a,b]);ended(b,@[a,b]);drain();}
PTAP("pencil_after_two_finger_order",q,0.08)
r[@"maybe_selected"]=@(DEMaybeSelected());
// Pencil double-tap: one Escape per gesture even when reported twice, and
// none when nothing is selected (Escape then opened the game menu).
escapeDowns=0;DESetMaybeSelected(YES);[host pencilDeselect:"a"];[host pencilDeselect:"b"];pump(0.35);
[host pencilDeselect:"c"];pump(0.1);r[@"double_tap_escapes"]=@(escapeDowns);
// Two/three-finger map drag: one right-button press held at least 0.35 s,
// and, replayed through DE's measured scrolling, the map moves as far as the
// fingers did; a drag under 16 points sends nothing.
drain();
{[host nativeMapScrollPhase:0 point:p];for(int i=1;i<=6;i++){[host nativeMapScrollPhase:1 point:CGPointMake(p.x+i*10,p.y+i*4)];pump(0.01);}
 [host nativeMapScrollPhase:2 point:CGPointMake(p.x+60,p.y+24)];pump(0.1);
 BOOL early=NO;for(NSEvent *e in NSApplication.sharedApplication.queue.events)if(e.type==4)early=YES;r[@"drag_released_early"]=@(early);
 pump(0.8);CGPoint m=simulateScroll();r[@"map_drag_moved"]=@[@(round(m.x)),@(round(m.y))];r[@"map_drag"]=drain();}
// A fast flick: 300 x 150 points in 0.1 s, then lift. The view catches up.
{[host nativeMapScrollPhase:0 point:q];for(int i=1;i<=5;i++){[host nativeMapScrollPhase:1 point:CGPointMake(q.x-i*60,q.y-i*30)];pump(0.02);}
 [host nativeMapScrollPhase:2 point:CGPointMake(q.x-300,q.y-150)];pump(1.5);
 CGPoint m=simulateScroll();r[@"flick_moved"]=@[@(round(m.x)),@(round(m.y))];r[@"flick"]=drain();}
{[host nativeMapScrollPhase:0 point:p];[host nativeMapScrollPhase:1 point:CGPointMake(p.x+8,p.y+6)];[host nativeMapScrollPhase:2 point:CGPointMake(p.x+8,p.y+6)];r[@"tiny_drag"]=drain();}
// A second swipe right after the first continues the same press: one press,
// one release, and the map moves by both swipes.
{[host nativeMapScrollPhase:0 point:p];for(int i=1;i<=4;i++){[host nativeMapScrollPhase:1 point:CGPointMake(p.x+i*10,p.y)];pump(0.01);}
 [host nativeMapScrollPhase:2 point:CGPointMake(p.x+40,p.y)];
 pump(0.1);[host nativeMapScrollPhase:0 point:q];[host nativeMapScrollPhase:1 point:CGPointMake(q.x+20,q.y)];pump(0.1);
 for(int i=1;i<=4;i++){[host nativeMapScrollPhase:1 point:CGPointMake(q.x+20+i*10,q.y)];pump(0.01);}
 [host nativeMapScrollPhase:2 point:CGPointMake(q.x+60,q.y)];pump(0.8);
 CGPoint m=simulateScroll();r[@"repeat_drag_moved"]=@[@(round(m.x)),@(round(m.y))];r[@"repeat_drag"]=drain();}
// Zoom: whole wheel steps only; the remainder waits for more movement.
{CGFloat pending=2.6;[host sendZoomSteps:&pending point:p source:"test"];r[@"zoom_steps"]=drain();r[@"zoom_left"]=@(round(pending*10)/10);}
puts([[NSString alloc]initWithData:[NSJSONSerialization dataWithJSONObject:r options:NSJSONWritingSortedKeys error:nil] encoding:NSUTF8StringEncoding].UTF8String);
return 0;}}
'''
(out/'TwoFingerProbe.m').write_text(preamble.replace('TWO_FINGER_WINDOW', window_line)+protocol+interface+'\n@implementation DEGameViewHost\n'+handlers+'\n@end\n'+gestures+main)
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
        'pencil_5_select_again':LEFT,'pencil_6_hud_tap':LEFT,'pencil_7_after_hud':LEFT,'pencil_9_order_after_box':RIGHT,
        'pencil_after_finger_tap':LEFT,'pencil_select_before_two_finger':LEFT,'pencil_after_two_finger_order':RIGHT,'maybe_selected':True,
        'double_tap_escapes':1,'drag_released_early':False,'tiny_drag':[],'zoom_steps':[22,22],'zoom_left':0.6}
bad={k:r[k] for k,v in expect.items() if r[k]!=v}
if r['one_finger_drag'][:1]!=[1] or r['one_finger_drag'][-1:]!=[2] or 6 not in r['one_finger_drag']: bad['one_finger_drag']=r['one_finger_drag']
if r['pencil_8_box'][:1]!=[1] or r['pencil_8_box'][-1:]!=[2] or 6 not in r['pencil_8_box']: bad['pencil_8_box']=r['pencil_8_box']
def one_press(events): return [t for t in events if t in (3,4)]==[3,4] and events.count(7)>=5
def near(got,want,tolerance): return abs(got[0]-want[0])<=tolerance and abs(got[1]-want[1])<=tolerance
for name,want,tol in (('map_drag',(60,24),3),('flick',(-300,-150),4),('repeat_drag',(100,0),3)):
    if not one_press(r[name]): bad[name]=r[name]
    if not near(r[name+'_moved'],want,tol): bad[name+'_moved']=r[name+'_moved']
print(json.dumps(r))
assert not bad,'unexpected: %s' % bad
print('PASS: two-finger taps right-click only; Pencil tap selects, repeat taps order, hold/HUD disarm, only Pencil selections arm; one Escape per double-tap; map drag is a held right drag; zoom in whole steps')
