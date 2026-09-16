// Exact-module compatibility experiment, not a replacement Steam implementation.
// File reads/validation still see the untouched supplied module. The verified
// representation differs only in Mach-O packaging; its original sections match.
#import <Foundation/Foundation.h>
#include <CommonCrypto/CommonDigest.h>
#include <dlfcn.h>
#include <errno.h>
#include <string.h>
#include <signal.h>
#include "MachDiscovery.h"
static _Thread_local int DESteamModuleLoading;
static NSString *DESteamModuleDigest(NSString *path) {
    NSData *data=[NSData dataWithContentsOfFile:path];
    if (!data || data.length>UINT32_MAX) return nil;
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(data.bytes,(CC_LONG)data.length,digest);
    NSMutableString *text=[NSMutableString stringWithCapacity:64];
    for (unsigned i=0;i<sizeof(digest);i++) [text appendFormat:@"%02x",digest[i]];
    return text;
}
static void *DESteamModuleDlopen(const char *path,int flags) {
    if (DESteamModuleLoading || !path || !strstr(path,"libsteam_api.dylib") ||
        !getenv("AGEPAD_MAC_STEAM_MODULE")) return dlopen(path,flags);
    DESteamModuleLoading=1;
    void *result;
    @autoreleasepool {
        NSString *bundle=NSBundle.mainBundle.bundlePath;
        NSString *expected=[[bundle stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"Frameworks/libsteam_api.dylib"];
        NSString *requested=[NSString stringWithUTF8String:path];
        NSString *translated=[bundle stringByAppendingPathComponent:@"Frameworks/SteamModuleSimulator.dylib"];
        NSData *configData=[NSData dataWithContentsOfFile:[bundle stringByAppendingPathComponent:@"SteamModuleCompat.json"]];
        NSDictionary *config=configData?[NSJSONSerialization JSONObjectWithData:configData options:0 error:NULL]:nil;
        BOOL verified=[requested isEqualToString:expected] &&
            [DESteamModuleDigest(expected) isEqualToString:config[@"original_sha256"]] &&
            [DESteamModuleDigest(translated) isEqualToString:config[@"translated_sha256"]];
        if (verified) {
            if (getenv("AGEPAD_MAC_STEAM_DISCOVERY")) {
                NSData *data=[NSJSONSerialization dataWithJSONObject:DESteamMachDiscovery() options:0 error:NULL];
                fprintf(stderr,"DE_STEAM_DISCOVERY %s\n",[[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] UTF8String]);
                fflush(stderr);
            }
            if (getenv("AGEPAD_MAC_STEAM_PAUSE")) {
                fprintf(stderr,"DE_STEAM_DIAGNOSTIC_PAUSE pid=%d\n",getpid());fflush(stderr);
                raise(SIGSTOP);
            }
            result=dlopen(translated.fileSystemRepresentation,flags);
            int saved=errno;
            fprintf(stderr,"DE_STEAM_MODULE verified=1 loaded=%d\n",result!=NULL);
            fflush(stderr);errno=saved;
        } else {
            fprintf(stderr,"DE_STEAM_MODULE verified=0 using original loader\n");
            result=dlopen(path,flags);
        }
    }
    DESteamModuleLoading=0;
    return result;
}
// Interposition can affect caller-relative loads. This experiment maps only the
// exact absolute module path; broader loader compatibility remains unqualified.
__attribute__((used,section("__DATA,__interpose")))
static const struct { const void *replacement; const void *original; } DESteamModuleInterpose={
    (const void *)DESteamModuleDlopen,(const void *)dlopen
};
