// Read public Mac framework string constants for matching notification/key names.
#import <Foundation/Foundation.h>
#include <dlfcn.h>
#include <stdio.h>
int main(int argc,char **argv) {
    @autoreleasepool {
        if (argc!=2) return 64;
        NSDictionary *manifest=[NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:@(argv[1])] options:0 error:NULL];
        NSMutableDictionary *values=[NSMutableDictionary dictionary];
        for (NSDictionary *library in manifest[@"libraries"]) {
            void *handle=dlopen([library[@"path"] UTF8String],RTLD_NOW|RTLD_LOCAL);
            if (!handle) continue;
            for (NSDictionary *entry in library[@"symbols"]) {
                NSString *symbol=entry[@"symbol"];
                if (![entry[@"action"] hasPrefix:@"NULL diagnostic data"] ||
                    [symbol isEqual:@"_NSApp"] || [symbol hasPrefix:@"__swift_FORCE_LOAD"]) continue;
                // Only known string-variable naming families; a manifest from an
                // older probe may have misclassified a function ending Attribute.
                if (![symbol hasPrefix:@"_NS"] && ![symbol hasPrefix:@"_k"] &&
                    !([symbol hasPrefix:@"_MTLDevice"] && [symbol hasSuffix:@"Notification"])) continue;
                fprintf(stderr,"DE_CONSTANT_READ %s\n",symbol.UTF8String); fflush(stderr);
                void *address=dlsym(handle,[[symbol substringFromIndex:1] UTF8String]);
                if (address) {
                    id value=*(__unsafe_unretained id *)address;
                    if ([value isKindOfClass:NSString.class]) values[symbol]=value;
                }
            }
        }
        NSData *json=[NSJSONSerialization dataWithJSONObject:values options:NSJSONWritingPrettyPrinted error:NULL];
        fwrite(json.bytes,1,json.length,stdout); fputc('\n',stdout);
    }
}
