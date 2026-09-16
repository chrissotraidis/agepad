// Read-only system-library export survey. Input contains paths and symbol names.
#import <Foundation/Foundation.h>
#include <dlfcn.h>
#include <stdio.h>
int main(int argc,char **argv) {
    if (argc!=2) return 64;
    @autoreleasepool {
        NSData *input=[NSData dataWithContentsOfFile:@(argv[1])];
        NSArray *libraries=input?[NSJSONSerialization JSONObjectWithData:input options:0 error:NULL]:nil;
        if (![libraries isKindOfClass:NSArray.class]) return 65;
        NSMutableArray *results=[NSMutableArray array];
        for (NSDictionary *entry in libraries) {
            NSString *path=entry[@"path"];
            if (![path hasPrefix:@"/System/Library/"] && ![path hasPrefix:@"/usr/lib/"]) return 66;
            void *library=dlopen(path.fileSystemRepresentation,RTLD_NOW|RTLD_LOCAL|RTLD_FIRST);
            NSMutableArray *missing=[NSMutableArray array];
            for (NSString *symbol in entry[@"symbols"]) {
                NSString *runtime=[symbol hasPrefix:@"_"]?[symbol substringFromIndex:1]:symbol;
                if (!library || !dlsym(library,runtime.UTF8String)) [missing addObject:symbol];
            }
            [results addObject:@{@"path":path,@"loaded":@(library!=NULL),@"missing_symbols":missing}];
        }
        NSData *data=[NSJSONSerialization dataWithJSONObject:results options:NSJSONWritingPrettyPrinted error:NULL];
        fwrite(data.bytes,1,data.length,stdout);fputc('\n',stdout);
    }
    return 0;
}
