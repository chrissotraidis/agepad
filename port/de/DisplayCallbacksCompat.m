// Actual UIKit screen notifications feed registered original-engine callbacks.
// This initial adapter supplies post-change events; macOS's pre-change phase
// has no direct UIScreen notification equivalent and remains unimplemented.
#import <UIKit/UIKit.h>
#include <stdint.h>
typedef void (*DEReconfigurationCallback)(uint32_t,uint32_t,void *);
extern uint32_t DEUIKitDisplayIdentifier(UIScreen *screen);

@interface DEDisplayCallbackRecord : NSObject
@property(nonatomic) DEReconfigurationCallback callback;
@property(nonatomic) void *context;
@end
@implementation DEDisplayCallbackRecord @end
static NSMutableArray<DEDisplayCallbackRecord *> *records;
static NSMutableArray *observers;

static void DEEnsureDisplayCallbacks(void) {
    static dispatch_once_t once;
    dispatch_once(&once,^{
        records=[NSMutableArray array]; observers=[NSMutableArray array];
        NSArray *events=@[
            @[UIScreenDidConnectNotification,@((1<<4)|(1<<8)|(1<<12))],
            @[UIScreenDidDisconnectNotification,@((1<<5)|(1<<9)|(1<<12))],
            @[UIScreenModeDidChangeNotification,@((1<<3)|(1<<12))],
            @[@"DEUIKitDisplayGeometryDidChange",@((1<<3)|(1<<12))]];
        for (NSArray *event in events) {
            id observer=[NSNotificationCenter.defaultCenter addObserverForName:event[0] object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) {
                if (![note.object isKindOfClass:UIScreen.class]) return;
                uint32_t display=DEUIKitDisplayIdentifier(note.object);
                NSArray *snapshot;
                @synchronized(records) { snapshot=records.copy; }
                for (DEDisplayCallbackRecord *record in snapshot) record.callback(display,[event[1] unsignedIntValue],record.context);
            }];
            [observers addObject:observer];
        }
    });
}
int32_t CGDisplayRegisterReconfigurationCallback(DEReconfigurationCallback callback,void *context) {
    if (!callback) return 1001; // kCGErrorIllegalArgument, from the Mac SDK.
    DEEnsureDisplayCallbacks();
    @synchronized(records) {
        for (DEDisplayCallbackRecord *record in records)
            if (record.callback==callback && record.context==context) return 0;
        DEDisplayCallbackRecord *record=[DEDisplayCallbackRecord new];
        record.callback=callback; record.context=context; [records addObject:record];
    }
    fprintf(stderr,"DE_DISPLAY_CALLBACK_REGISTERED UIKit screen changes\n");
    return 0;
}
int32_t CGDisplayRemoveReconfigurationCallback(DEReconfigurationCallback callback,void *context) {
    if (!callback) return 1001;
    DEEnsureDisplayCallbacks();
    @synchronized(records) {
        NSIndexSet *indices=[records indexesOfObjectsPassingTest:^BOOL(DEDisplayCallbackRecord *record,NSUInteger index,BOOL *stop) {
            return record.callback==callback && record.context==context;
        }];
        [records removeObjectsAtIndexes:indices];
    }
    return 0;
}
