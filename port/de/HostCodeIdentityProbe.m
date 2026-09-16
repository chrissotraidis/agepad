// Read-only native validation of the actual Simulator process, not a substitute
// for any check performed by the game. Reports genuine Security-framework results.
#import <Foundation/Foundation.h>
#import <Security/Security.h>
#include <stdio.h>
int main(int argc,char **argv) {
    @autoreleasepool {
        if (argc!=2) return 64;
        pid_t pid=(pid_t)strtol(argv[1],NULL,10);
        NSDictionary *attributes=@{(__bridge NSString *)kSecGuestAttributePid:@(pid)};
        SecCodeRef code=NULL;
        OSStatus status=SecCodeCopyGuestWithAttributes(NULL,(__bridge CFDictionaryRef)attributes,kSecCSDefaultFlags,&code);
        NSMutableDictionary *result=[@{@"pid":@(pid),@"guest_lookup_status":@(status),@"platform":@"macOS host"} mutableCopy];
        if (status==errSecSuccess && code) {
            result[@"dynamic_validation_status"]=@(SecCodeCheckValidity(code,kSecCSDefaultFlags,NULL));
            SecStaticCodeRef staticCode=NULL;
            OSStatus copied=SecCodeCopyStaticCode(code,kSecCSDefaultFlags,&staticCode);
            result[@"copy_static_status"]=@(copied);
            if (copied==errSecSuccess && staticCode) {
                result[@"static_validation_status"]=@(SecStaticCodeCheckValidity(staticCode,kSecCSDefaultFlags,NULL));
                CFRelease(staticCode);
            }
            CFRelease(code);
        }
        NSData *data=[NSJSONSerialization dataWithJSONObject:result options:NSJSONWritingPrettyPrinted error:NULL];
        fwrite(data.bytes,1,data.length,stdout);fputc('\n',stdout);
    }
}
