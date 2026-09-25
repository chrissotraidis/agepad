// Exact-module compatibility experiment, not a replacement Steam implementation.
// Simulator file reads/validation see the untouched supplied module. On iPad,
// only the exact adjacent metadata query is mapped to an inert bundled copy.
// The loadable representation differs only in Mach-O packaging; its original
// sections match.
#import <Foundation/Foundation.h>
#include <CommonCrypto/CommonDigest.h>
#include <dlfcn.h>
#include <errno.h>
#include <fcntl.h>
#include <stdarg.h>
#include <stdatomic.h>
#include <stdio.h>
#include <string.h>
#include <signal.h>
#include <sys/stat.h>
#include <unistd.h>
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
// metadata query and read-only opens with that file's real metadata and bytes.
// The game hashes those bytes itself before it calls dlopen; nothing here
// changes that check. This is a diagnostic, not a complete filesystem mapping.
// Loading is separately gated by both hashes.
static BOOL DESteamModuleMappedPath(const char *path,char *original,size_t size) {
    static const char suffix[]="/Frameworks/libsteam_api.dylib";
    if (!path || !getenv("AGEPAD_DEVICE_STEAM_MODULE")) return NO;
    size_t length=strlen(path),suffixLength=sizeof(suffix)-1;
    if (length<=suffixLength || strcmp(path+length-suffixLength,suffix)!=0 ||
        !strstr(path,"/Bundle/Application/")) return NO;
    int count=snprintf(original,size,"%.*s/AgePadDeviceProbe.app/OriginalSteamModule.data",
        (int)(length-suffixLength),path);
    return count>0 && (size_t)count<size;
}
static uintptr_t DESteamModuleCallerOffset(uintptr_t caller) {
    uintptr_t base=(uintptr_t)_dyld_get_image_header(0);
    return caller>=base?caller-base:0;
}
// Log-only: report the first failed lookups so the next missing input is
// measured rather than guessed. Results and errno are returned unchanged.
static void DEDevicePathMiss(const char *operation,const char *path,int result,int error,uintptr_t caller) {
    static _Atomic unsigned count;
    if (result==0 || !path || !getenv("AGEPAD_DEVICE_PATH_MISS_TRACE")) return;
    if (strncmp(path,"/System/",8)==0 || strncmp(path,"/usr/",5)==0) return;
    if (atomic_fetch_add(&count,1)>=120) return;
    char line[1200];
    int length=snprintf(line,sizeof(line),"DE_DEVICE_PATH_MISS op=%s errno=%d caller_offset=0x%llx path=%s\n",
        operation,error,(unsigned long long)DESteamModuleCallerOffset(caller),path);
    if (length>0) write(STDERR_FILENO,line,(size_t)length<sizeof(line)?(size_t)length:sizeof(line)-1);
}
static int DESteamModuleStat(const char *path,struct stat *buffer) {
    char original[4096];
    if (DESteamModuleMappedPath(path,original,sizeof(original))) {
        int result=stat(original,buffer);
        int saved=errno;
        fprintf(stderr,"DE_STEAM_MODULE_STAT mapped=1 result=%d size=%lld caller_offset=0x%llx path=%s\n",
            result,result?0:(long long)buffer->st_size,
            (unsigned long long)DESteamModuleCallerOffset((uintptr_t)__builtin_return_address(0)),path);
        errno=saved;
        return result;
    }
    int result=stat(path,buffer),saved=errno;
    DEDevicePathMiss("stat",path,result,saved,(uintptr_t)__builtin_return_address(0));
    errno=saved;
    return result;
}
static int DESteamModuleOpen(const char *path,int flags,...) {
    int mode=0;
    if (flags&O_CREAT) {
        va_list arguments;
        va_start(arguments,flags);
        mode=va_arg(arguments,int);
        va_end(arguments);
    }
    char original[4096];
    if ((flags&O_ACCMODE)==O_RDONLY && !(flags&(O_CREAT|O_TRUNC)) &&
        DESteamModuleMappedPath(path,original,sizeof(original))) {
        int result=open(original,flags);
        int saved=errno;
        fprintf(stderr,"DE_STEAM_MODULE_OPEN mapped=1 result=%d errno=%d caller_offset=0x%llx\n",
            result,result<0?saved:0,
            (unsigned long long)DESteamModuleCallerOffset((uintptr_t)__builtin_return_address(0)));
        errno=saved;
        return result;
    }
    int result=(flags&O_CREAT)?open(path,flags,mode):open(path,flags),saved=errno;
    DEDevicePathMiss("open",path,result<0?-1:0,saved,(uintptr_t)__builtin_return_address(0));
    errno=saved;
    return result;
}
static BOOL DESteamModuleReadMode(const char *mode) {
    return mode && mode[0]=='r' && !strchr(mode,'+');
}
// The game imports both fopen spellings; name each exactly.
extern FILE *DEFopenPlain(const char *,const char *) __asm("_fopen");
extern FILE *DEFopenExtension(const char *,const char *) __asm("_fopen$DARWIN_EXTSN");
static FILE *DESteamModuleFopenWith(FILE *(*function)(const char *,const char *),
                                    const char *path,const char *mode,uintptr_t caller) {
    char original[4096];
    if (DESteamModuleReadMode(mode) && DESteamModuleMappedPath(path,original,sizeof(original))) {
        FILE *result=function(original,mode);
        int saved=errno;
        fprintf(stderr,"DE_STEAM_MODULE_FOPEN mapped=1 result=%d errno=%d caller_offset=0x%llx\n",
            result!=NULL,result?0:saved,(unsigned long long)DESteamModuleCallerOffset(caller));
        errno=saved;
        return result;
    }
    FILE *result=function(path,mode);
    int saved=errno;
    DEDevicePathMiss("fopen",path,result?0:-1,saved,caller);
    errno=saved;
    return result;
}
static FILE *DESteamModuleFopen(const char *path,const char *mode) {
    return DESteamModuleFopenWith(DEFopenPlain,path,mode,(uintptr_t)__builtin_return_address(0));
}
static FILE *DESteamModuleFopenExtension(const char *path,const char *mode) {
    return DESteamModuleFopenWith(DEFopenExtension,path,mode,(uintptr_t)__builtin_return_address(0));
}
// Interposition can affect caller-relative loads. This experiment maps only the
// exact absolute module path; broader loader compatibility remains unqualified.
__attribute__((used,section("__DATA,__interpose")))
static const struct { const void *replacement; const void *original; } DESteamModuleInterpose[]={
    {(const void *)DESteamModuleDlopen,(const void *)dlopen},
    {(const void *)DESteamModuleStat,(const void *)stat},
    {(const void *)DESteamModuleOpen,(const void *)open},
    {(const void *)DESteamModuleFopen,(const void *)DEFopenPlain},
    {(const void *)DESteamModuleFopenExtension,(const void *)DEFopenExtension}
};
