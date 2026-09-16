// Menu object model for original startup. UIKit menu presentation/action
// dispatch are not implemented here and unsupported operations still stop.
#import <Foundation/Foundation.h>
#include "UnsupportedBoundary.h"
@class NSMenu;
@interface NSMenuItem : NSObject
@property(nonatomic,copy) NSString *title;
@property(nonatomic,copy) NSString *keyEquivalent;
@property(nonatomic) NSUInteger keyEquivalentModifierMask;
@property(nonatomic) SEL action;
@property(nonatomic,weak) id target;
@property(nonatomic,strong) NSMenu *submenu;
@property(nonatomic,weak) NSMenu *menu;
@property(nonatomic) NSInteger tag,state;
@property(nonatomic,getter=isEnabled) BOOL enabled;
@property(nonatomic,getter=isHidden) BOOL hidden;
@property(nonatomic,getter=isSeparatorItem) BOOL separatorItem;
- (instancetype)initWithTitle:(NSString *)title action:(SEL)action keyEquivalent:(NSString *)key;
@end
@interface NSMenu : NSObject
@property(nonatomic,copy) NSString *title;
@property(nonatomic,weak) id delegate;
@property(nonatomic) BOOL autoenablesItems;
@property(nonatomic,strong) NSMutableArray<NSMenuItem *> *deItems;
- (instancetype)initWithTitle:(NSString *)title;
- (void)addItem:(NSMenuItem *)item;
@end
@implementation NSMenuItem
- (instancetype)initWithTitle:(NSString *)title action:(SEL)action keyEquivalent:(NSString *)key {
    if ((self=[super init])) {_title=[title copy];_action=action;_keyEquivalent=[key copy];_enabled=YES;_keyEquivalentModifierMask=1UL<<20;}
    return self;
}
+ (instancetype)separatorItem { NSMenuItem *item=[[self alloc] initWithTitle:@"" action:NULL keyEquivalent:@""];item.separatorItem=YES;return item; }
+ (BOOL)resolveInstanceMethod:(SEL)sel { fprintf(stderr,"DE_UNSUPPORTED_SELECTOR -[NSMenuItem %s]\n",sel_getName(sel));DEUnsupported("NSMenuItem"); }
@end
@implementation NSMenu
- (instancetype)initWithTitle:(NSString *)title {
    if ((self=[super init])) {_title=[title copy];_deItems=[NSMutableArray array];_autoenablesItems=YES;fprintf(stderr,"DE_MENU_MODEL_CREATED\n");}
    return self;
}
- (NSArray *)itemArray { return self.deItems.copy; }
- (NSInteger)numberOfItems { return self.deItems.count; }
- (NSInteger)indexOfItem:(NSMenuItem *)item { NSUInteger i=[self.deItems indexOfObjectIdenticalTo:item];return i==NSNotFound?-1:(NSInteger)i; }
- (NSInteger)indexOfItemWithTitle:(NSString *)title { return [self indexOfItem:[self itemWithTitle:title]]; }
- (NSMenuItem *)itemAtIndex:(NSInteger)index { return self.deItems[index]; }
- (NSMenuItem *)itemWithTag:(NSInteger)tag { for (NSMenuItem *item in self.deItems) if (item.tag==tag) return item;return nil; }
- (NSMenuItem *)itemWithTitle:(NSString *)title { for (NSMenuItem *item in self.deItems) if ([item.title isEqualToString:title]) return item;return nil; }
- (void)insertItem:(NSMenuItem *)item atIndex:(NSInteger)index {
    if (!item || item.menu) DEUnsupported("menu item already owned or nil");
    [self.deItems insertObject:item atIndex:index];item.menu=self;
}
- (void)addItem:(NSMenuItem *)item { [self insertItem:item atIndex:self.deItems.count]; }
- (NSMenuItem *)addItemWithTitle:(NSString *)title action:(SEL)action keyEquivalent:(NSString *)key {
    NSMenuItem *item=[[NSMenuItem alloc] initWithTitle:title action:action keyEquivalent:key];[self addItem:item];return item;
}
- (void)removeItem:(NSMenuItem *)item { if (item.menu==self) {[self.deItems removeObjectIdenticalTo:item];item.menu=nil;} }
- (void)removeItemAtIndex:(NSInteger)index { [self removeItem:self.deItems[index]]; }
- (void)removeAllItems { for (NSMenuItem *item in self.deItems) item.menu=nil;[self.deItems removeAllObjects]; }
- (void)setSubmenu:(NSMenu *)submenu forItem:(NSMenuItem *)item { if (item.menu!=self) DEUnsupported("submenu item not in menu");item.submenu=submenu; }
+ (BOOL)resolveInstanceMethod:(SEL)sel { fprintf(stderr,"DE_UNSUPPORTED_SELECTOR -[NSMenu %s]\n",sel_getName(sel));DEUnsupported("NSMenu"); }
@end
