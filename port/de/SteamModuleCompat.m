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
#include <dirent.h>
#include <limits.h>
#include <TargetConditionals.h>
#include "CaseInsensitiveResourcePaths.h"
#if !TARGET_OS_SIMULATOR
#include "DeviceDataTree.h"
#endif
// Physical iPad: the game lowercases data paths, but the imported tree keeps
// the original names on a case-sensitive volume. Retry only failed lookups
// inside the configured data root with the one real on-disk spelling. The
// Simulator uses its separately injected RuntimeFileTrace resolver instead.
static BOOL DEDeviceCaseRetry(const char *path,int error,char resolved[PATH_MAX]) {
#if TARGET_OS_SIMULATOR
    return NO;
#else
    return getenv("AGEPAD_DEVICE_DATA_ROOT") && DEResolveResourceCase(path,error,resolved);
#endif
}
static _Thread_local int DESteamModuleLoading;
static NSString *DEAdjacentSteamPath(void) {
    return [[[NSBundle mainBundle].bundlePath stringByDeletingLastPathComponent]
            stringByAppendingPathComponent:@"Frameworks/libsteam_api.dylib"];
}
static NSString *DEDeviceOriginalSteamPath(void) {
    // The owned Mac module is shipped wrapped (a 16-byte AgePad header before
    // the untouched bytes) so signing tools, which sign every Mach-O they find,
    // leave it alone; the game hashes these bytes itself. It is unwrapped once
    // into Caches. Older builds carry it unwrapped as OriginalSteamModule.data.
    static NSString *path;
    static dispatch_once_t once;
    dispatch_once(&once,^{
        NSString *bundle=[NSBundle mainBundle].bundlePath;
        NSString *plain=[bundle stringByAppendingPathComponent:@"OriginalSteamModule.data"];
        NSData *wrapped=[NSData dataWithContentsOfFile:[bundle stringByAppendingPathComponent:@"OriginalSteamModule.wrapped"]
                                               options:NSDataReadingMappedIfSafe error:nil];
        if (wrapped.length<=16 || memcmp(wrapped.bytes,"AGEPAD-MODULE-1\n",16)) { path=plain;return; }
        NSData *body=[wrapped subdataWithRange:NSMakeRange(16,wrapped.length-16)];
        NSString *cache=[[NSSearchPathForDirectoriesInDomains(NSCachesDirectory,NSUserDomainMask,YES) firstObject]
            stringByAppendingPathComponent:@"OriginalSteamModule.data"];
        if (![[NSData dataWithContentsOfFile:cache] isEqualToData:body]) [body writeToFile:cache atomically:YES];
        path=cache;
    });
    return path;
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
// SHA-256 over every section's bytes of a thin arm64 Mach-O: the module's code
// and data, unaffected by re-signing (a sideloading tool signs the app again).
static NSString *DESteamModuleSectionsDigest(NSString *path) {
    NSData *file=[NSData dataWithContentsOfFile:path options:NSDataReadingMappedIfSafe error:nil];
    const uint8_t *d=file.bytes;size_t n=file.length;
    if (n<32 || *(const uint32_t *)d!=0xfeedfacf) return nil;
    uint32_t count=*(const uint32_t *)(d+16);size_t offset=32;
    CC_SHA256_CTX context;CC_SHA256_Init(&context);
    for (uint32_t i=0;i<count && offset+8<=n;i++) {
        uint32_t cmd=*(const uint32_t *)(d+offset),size=*(const uint32_t *)(d+offset+4);
        if (cmd==0x19 && offset+72<=n) {
            uint32_t sections=*(const uint32_t *)(d+offset+64);
            for (uint32_t s=0;s<sections && offset+72+80*(s+1)<=n;s++) {
                const uint8_t *section=d+offset+72+80*s;
                uint64_t length=*(const uint64_t *)(section+40);uint32_t start=*(const uint32_t *)(section+48);
                if (start && start+length<=n) CC_SHA256_Update(&context,d+start,(CC_LONG)length);
            }
        }
        if (!size) return nil;
        offset+=size;
    }
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];CC_SHA256_Final(digest,&context);
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
            ([DESteamModuleDigest(translated) isEqualToString:translatedDigest] ||
             (device && config[@"device_translated_sections_sha256"] &&
              [DESteamModuleSectionsDigest(translated) isEqualToString:config[@"device_translated_sections_sha256"]]));
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
    static char module[4096];
    static dispatch_once_t once;
    dispatch_once(&once,^{ strlcpy(module,DEDeviceOriginalSteamPath().fileSystemRepresentation,sizeof(module)); });
    int count=snprintf(original,size,"%s",module);
    return count>0 && (size_t)count<size;
}
// Startup profile counters (read by the launcher's watchdog): stat calls,
// failed first attempts, case-retry resolutions, and time inside each stage.
static _Atomic unsigned long long DEStatCalls,DEStatMisses,DEStatRetried,DEStatNanos,DEStatRetryNanos,DEStatTreeAnswers;
unsigned long long DEFileStatCounter(int which) {
    switch (which) {
        case 0: return DEStatCalls; case 1: return DEStatMisses; case 2: return DEStatRetried;
        case 3: return DEStatNanos; case 4: return DEStatRetryNanos; case 5: return DEStatTreeAnswers; default: return 0;
    }
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
    if (strstr(path,"FeralCrashReport") || strstr(path,"Saved Application State")) return;
    if (atomic_fetch_add(&count,1)>=1500) return;
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
#if !TARGET_OS_SIMULATOR
    {
        int treeError=0,tree=DETreeStat(path,buffer,&treeError);
        if (tree!=-2) { atomic_fetch_add(&DEStatTreeAnswers,1);if (tree<0) errno=treeError;return tree; }
    }
#endif
    uint64_t begin=clock_gettime_nsec_np(CLOCK_UPTIME_RAW);
    int result=stat(path,buffer),saved=errno;
    uint64_t afterFirst=clock_gettime_nsec_np(CLOCK_UPTIME_RAW);
    atomic_fetch_add(&DEStatCalls,1);atomic_fetch_add(&DEStatNanos,afterFirst-begin);
    char resolved[PATH_MAX];
    if (result<0) {
        atomic_fetch_add(&DEStatMisses,1);
        if (DEDeviceCaseRetry(path,saved,resolved)) {result=stat(resolved,buffer);saved=errno;atomic_fetch_add(&DEStatRetried,1);}
        atomic_fetch_add(&DEStatRetryNanos,clock_gettime_nsec_np(CLOCK_UPTIME_RAW)-afterFirst);
    }
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
#if !TARGET_OS_SIMULATOR
    if ((flags&O_ACCMODE)!=O_RDONLY || (flags&(O_CREAT|O_TRUNC))) DETreeNoteWrite(path);
    else {
        DETreeEntry *entry=NULL;
        int kind=DETreeLookup(path,&entry);
        if (kind==DETreeAbsent) { errno=ENOENT;return -1; }
        if (kind==DETreePresent) return open(entry->canonical,flags);
    }
#endif
    int result=(flags&O_CREAT)?open(path,flags,mode):open(path,flags),saved=errno;
    char resolved[PATH_MAX];
    if (result<0 && (flags&O_ACCMODE)==O_RDONLY && !(flags&O_CREAT) && DEDeviceCaseRetry(path,saved,resolved)) {
        result=open(resolved,flags);saved=errno;
    }
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
#if !TARGET_OS_SIMULATOR
    if (!DESteamModuleReadMode(mode)) DETreeNoteWrite(path);
    else {
        DETreeEntry *entry=NULL;
        int kind=DETreeLookup(path,&entry);
        if (kind==DETreeAbsent) { errno=ENOENT;return NULL; }
        if (kind==DETreePresent) return function(entry->canonical,mode);
    }
#endif
    FILE *result=function(path,mode);
    int saved=errno;
    char resolved[PATH_MAX];
    if (!result && DESteamModuleReadMode(mode) && DEDeviceCaseRetry(path,saved,resolved)) {
        result=function(resolved,mode);saved=errno;
    }
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
#if !TARGET_OS_SIMULATOR
static int DEDeviceLstat(const char *path,struct stat *buffer) {
    int treeError=0,tree=DETreeStat(path,buffer,&treeError);
    if (tree!=-2) { if (tree<0) errno=treeError;return tree; }
    int result=lstat(path,buffer),saved=errno;char resolved[PATH_MAX];
    if (result<0 && DEDeviceCaseRetry(path,saved,resolved)) {result=lstat(resolved,buffer);saved=errno;}
    DEDevicePathMiss("lstat",path,result,saved,(uintptr_t)__builtin_return_address(0));
    errno=saved;return result;
}
static int DEDeviceAccess(const char *path,int mode) {
    if (!(mode&(W_OK|X_OK))) { // existence/read checks; the tree is readable
        DETreeEntry *entry=NULL;
        int kind=DETreeLookup(path,&entry);
        if (kind==DETreeAbsent) { errno=ENOENT;return -1; }
        if (kind==DETreePresent) return 0;
    }
    int result=access(path,mode),saved=errno;char resolved[PATH_MAX];
    if (result<0 && DEDeviceCaseRetry(path,saved,resolved)) {result=access(resolved,mode);saved=errno;}
    DEDevicePathMiss("access",path,result,saved,(uintptr_t)__builtin_return_address(0));
    errno=saved;return result;
}
static DIR *DEDeviceOpendir(const char *path) {
    DETreeEntry *entry=NULL;
    int kind=DETreeLookup(path,&entry);
    if (kind==DETreeAbsent) { errno=ENOENT;return NULL; }
    if (kind==DETreePresent) return opendir(entry->canonical);
    DIR *result=opendir(path);int saved=errno;char resolved[PATH_MAX];
    if (!result && DEDeviceCaseRetry(path,saved,resolved)) {result=opendir(resolved);saved=errno;}
    DEDevicePathMiss("opendir",path,result?0:-1,saved,(uintptr_t)__builtin_return_address(0));
    errno=saved;return result;
}
__attribute__((used,section("__DATA,__interpose")))
static const struct { const void *replacement; const void *original; } DEDeviceCaseInterpose[]={
    {(const void *)DEDeviceLstat,(const void *)lstat},
    {(const void *)DEDeviceAccess,(const void *)access},
    {(const void *)DEDeviceOpendir,(const void *)opendir}
};
#endif
