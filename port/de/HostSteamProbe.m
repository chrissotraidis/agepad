#import <Foundation/Foundation.h>
#include <dlfcn.h>
#include <stdbool.h>
#include <stdio.h>
#include <TargetConditionals.h>
int main(int argc,char **argv) {
    @autoreleasepool {
        if (argc!=3) return 64;
        NSMutableDictionary *result=[@{@"platform":TARGET_OS_SIMULATOR?@"iOS Simulator":@"macOS",@"claim":@"Real Steam SDK control only"} mutableCopy];
        if (![NSFileManager.defaultManager changeCurrentDirectoryPath:@(argv[2])]) return 65;
        void *handle=dlopen(argv[1],RTLD_NOW|RTLD_GLOBAL);
        result[@"library_loaded"]=@(handle!=NULL);
        if (!handle) result[@"error"]=@(dlerror());
        if (handle) {
            bool (*initialize)(void)=dlsym(handle,"SteamAPI_Init");
            void (*shutdown)(void)=dlsym(handle,"SteamAPI_Shutdown");
            if (initialize && shutdown) {
                bool ok=initialize(); result[@"initialized"]=@(ok);
                if (ok) shutdown();
            }
        }
        NSData *json=[NSJSONSerialization dataWithJSONObject:result options:NSJSONWritingPrettyPrinted error:NULL];
        fwrite(json.bytes,1,json.length,stdout); fputc('\n',stdout);
    }
}
