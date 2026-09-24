// Exact-module compatibility experiment, not a replacement Steam implementation.
// Simulator file reads/validation see the untouched supplied module. On iPad,
// only the exact adjacent metadata query is mapped to an inert bundled copy.
// The loadable representation differs only in Mach-O packaging; its original
// sections match.
#import <Foundation/Foundation.h>
#include <CommonCrypto/CommonDigest.h>
#include <dlfcn.h>
#include <errno.h>
#include <string.h>
#include <signal.h>
#include <sys/stat.h>
#include "MachDiscovery.h"
static _Thread_local int DESteamModuleLoading;
static NSString *DEAdjacentSteamPath(void) {
    return [[[NSBundle mainBundle].bundlePath stringByDeletingLastPathComponent]
            stringByAppendingPathComponent:@"Frameworks/libsteam_api.dylib"];
}
static NSString *DEDeviceOriginalSteamPath(void) {
    return [[NSBundle mainBundle].bundlePath stringByAppendingPathComponent:@"OriginalSteamModule.data"];
}
static NSDictionary *DESteamModuleConfig(void) {
    NSData *data=[NSData dataWithContentsOfFile:[[NSBundle mainBundle].bundlePath
        stringByAppendingPathComponent:@"SteamModuleCompat.json"]];
    return data?[NSJSONSerialization JSONObjectWithData:data options:0 error:NULL]:nil;
}
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
        (!getenv("AGEPAD_MAC_STEAM_MODULE") && !getenv("AGEPAD_DEVICE_STEAM_MODULE"))) return dlopen(path,flags);
    DESteamModuleLoading=1;
    void *result;
    @autoreleasepool {
        NSString *bundle=NSBundle.mainBundle.bundlePath;
        NSString *expected=DEAdjacentSteamPath();
        NSString *requested=[NSString stringWithUTF8String:path];
        NSString *translated=[bundle stringByAppendingPathComponent:@"Frameworks/SteamModuleSimulator.dylib"];
        NSDictionary *config=DESteamModuleConfig();
        BOOL device=getenv("AGEPAD_DEVICE_STEAM_MODULE")!=NULL;
        NSString *original=device?DEDeviceOriginalSteamPath():expected;
        NSString *translatedDigest=device?config[@"device_translated_sha256"]:config[@"translated_sha256"];
        BOOL verified=[requested isEqualToString:expected] &&
            [DESteamModuleDigest(original) isEqualToString:config[@"original_sha256"]] &&
            [DESteamModuleDigest(translated) isEqualToString:translatedDigest];
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
            fprintf(stderr,"DE_STEAM_MODULE verified=1 device=%d loaded=%d\n",device,result!=NULL);
            fflush(stderr);errno=saved;
        } else {
            fprintf(stderr,"DE_STEAM_MODULE verified=0 using original loader\n");
            result=dlopen(path,flags);
        }
    }
    DESteamModuleLoading=0;
    return result;
}
// iPad app bundles cannot carry a sibling Frameworks directory. Preserve the
// owned Mac module as inert data and answer only the game's exact adjacent-file
// metadata query with that file's real metadata. This is a diagnostic, not a
// complete filesystem mapping. Loading is separately gated by both hashes.
static int DESteamModuleStat(const char *path,struct stat *buffer) {
    static const char suffix[]="/Frameworks/libsteam_api.dylib";
    if (getenv("AGEPAD_DEVICE_STEAM_MODULE") && path) {
        size_t length=strlen(path),suffixLength=sizeof(suffix)-1;
        if (length>suffixLength && strcmp(path+length-suffixLength,suffix)==0 &&
            strstr(path,"/Bundle/Application/")) {
            char original[4096];
            int count=snprintf(original,sizeof(original),"%.*s/AgePadDeviceProbe.app/OriginalSteamModule.data",
                (int)(length-suffixLength),path);
            if (count>0 && (size_t)count<sizeof(original)) {
                int result=stat(original,buffer);
                int saved=errno;
                uintptr_t caller=(uintptr_t)__builtin_return_address(0);
                uintptr_t base=(uintptr_t)_dyld_get_image_header(0);
                fprintf(stderr,"DE_STEAM_MODULE_STAT mapped=1 result=%d size=%lld caller_offset=0x%llx path=%s\n",
                    result,result?0:(long long)buffer->st_size,
                    (unsigned long long)(caller>=base?caller-base:0),path);
                errno=saved;
                return result;
            }
        }
    }
    return stat(path,buffer);
}
// Interposition can affect caller-relative loads. This experiment maps only the
// exact absolute module path; broader loader compatibility remains unqualified.
__attribute__((used,section("__DATA,__interpose")))
static const struct { const void *replacement; const void *original; } DESteamModuleInterpose[]={
    {(const void *)DESteamModuleDlopen,(const void *)dlopen},
    {(const void *)DESteamModuleStat,(const void *)stat}
};
