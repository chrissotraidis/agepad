#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <objc/runtime.h>
#include <dlfcn.h>
#include <stdio.h>

int main(int argc,char **argv) {
    @autoreleasepool {
        if (argc != 2 && argc != 3) return 64;
        fprintf(stderr,"DE_HOST_LOAD_BEGIN\n");
        void *handle=dlopen(argv[1],RTLD_NOW|RTLD_LOCAL);
        const char *error=handle?NULL:dlerror();
        NSMutableDictionary *result=[@{@"loaded":@(handle!=NULL),@"error":error?@(error):@"",
            @"game_main_called":@NO,@"platform":@"macOS"} mutableCopy];
        if (handle) {
            unsigned int count=0;
            const char **classes=objc_copyClassNamesForImage(argv[1],&count);
            result[@"class_count"]=@(count);
            NSMutableArray *inventory=[NSMutableArray array];
            for (unsigned int i=0;i<count;i++) {
                Class cls=objc_getClass(classes[i]);
                NSMutableArray *ancestors=[NSMutableArray array];
                for (Class parent=class_getSuperclass(cls);parent;parent=class_getSuperclass(parent))
                    [ancestors addObject:@(class_getName(parent))];
                NSMutableArray *methods=[NSMutableArray array];
                unsigned int methodCount=0;
                Method *list=class_copyMethodList(cls,&methodCount);
                for (unsigned int j=0;j<methodCount;j++)
                    [methods addObject:@{@"selector":@(sel_getName(method_getName(list[j]))),
                        @"encoding":@(method_getTypeEncoding(list[j]))}];
                free(list);
                [inventory addObject:@{@"class":@(classes[i]),@"ancestors":ancestors,
                    @"instance_size":@(class_getInstanceSize(cls)),@"methods":methods}];
            }
            result[@"classes"]=inventory;
            free(classes);
            result[@"original_application_class"]=@(NSClassFromString(@"CFeralNSApplication")!=Nil);
            if (argc==3) {
                NSApplication *application=[NSClassFromString(@"CFeralNSApplication") sharedApplication];
                [application setActivationPolicy:NSApplicationActivationPolicyProhibited];
                NSNib *nib=[[NSNib alloc] initWithNibData:[NSData dataWithContentsOfFile:@(argv[2])] bundle:nil];
                NSArray *objects=nil;
                BOOL instantiated=[nib instantiateWithOwner:application topLevelObjects:&objects];
                NSMutableArray *types=[NSMutableArray array];
                for (id object in objects) [types addObject:NSStringFromClass([object class])];
                result[@"nib"]=@{@"instantiated":@(instantiated),@"top_level_classes":types,
                    @"delegate_class":application.delegate?NSStringFromClass([(id)application.delegate class]):@"",
                    @"delegate_is_application":@((id)application.delegate==application),
                    @"main_menu_count":@(application.mainMenu.numberOfItems)};
            }
        }
        NSData *data=[NSJSONSerialization dataWithJSONObject:result options:NSJSONWritingPrettyPrinted error:NULL];
        fwrite(data.bytes,1,data.length,stdout);fputc('\n',stdout);fflush(stdout);
        // No dlclose: unloading Objective-C images is unsupported.
        return handle?0:1;
    }
}
