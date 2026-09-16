#include "WindowViewCompat.m"
#include "MenuCompat.m"
#include "ColorCompat.m"
#include "EventCompat.m"
#include "EventQueueCompat.m"
int main(void) { @autoreleasepool {
    NSView *root=[[NSView alloc] initWithFrame:CGRectMake(0,0,120,80)];NSView *child=[[NSView alloc] initWithFrame:CGRectMake(2,3,20,10)];
    [root addSubview:child];BOOL hierarchy=child.superview==root && child.deHost.superview==root.deHost;
    CAMetalLayer *metal=[CAMetalLayer layer];[child setLayer:metal];child.frame=CGRectMake(2,3,40,30);
    BOOL layer=child.layer==metal && metal.superlayer==child.deHost.layer && CGSizeEqualToSize(metal.bounds.size,CGSizeMake(40,30));
    [child removeFromSuperview];hierarchy=hierarchy && child.superview==nil && child.deHost.superview==nil && root.deSubviews.count==0;
    NSMenu *menu=[[NSMenu alloc] initWithTitle:@"test"];NSMenuItem *item=[menu addItemWithTitle:@"Play" action:NULL keyEquivalent:@""];item.tag=7;
    BOOL owned=[menu itemWithTag:7]==item && [menu indexOfItem:item]==0 && item.menu==menu;
    [menu removeItem:item];owned=owned && item.menu==nil && [menu indexOfItem:item]==-1;
    DEDiagnosticNSColor *color=[DEDiagnosticNSColor colorWithDeviceRed:.25 green:.5 blue:.75 alpha:.5];
    const CGFloat *components=CGColorGetComponents(color.CGColor);BOOL pixels=CGColorGetNumberOfComponents(color.CGColor)==4 && fabs(components[0]-.25)<1e-6 && fabs(components[3]-.5)<1e-6;
    NSEvent *event=[NSEvent otherEventWithType:15 location:CGPointMake(2,3) modifierFlags:0 timestamp:1 windowNumber:2 context:nil subtype:12345 data1:10 data2:20];DEEventQueue *queue=[DEEventQueue new];[queue post:(id)event atStart:NO];
    NSEvent *received=[queue next:1UL<<15 until:NSDate.distantPast mode:NSDefaultRunLoopMode dequeue:YES];BOOL delivered=received==event && received.data2==20 && received.subtype==12345;
    printf("{\"view_hierarchy\":%s,\"real_metal_layer_identity_and_geometry\":%s,\"menu_ownership\":%s,\"color_components\":%s,\"application_event_queue\":%s}\n",hierarchy?"true":"false",layer?"true":"false",owned?"true":"false",pixels?"true":"false",delivered?"true":"false");return hierarchy&&layer&&owned&&pixels&&delivered?0:1;
} }
