// Diagnostic file queries: retain real results, cwd, paths, and errno.
#include <sys/stat.h>
#include <stdio.h>
#include <unistd.h>
#include <errno.h>
#include <string.h>
#include <stdatomic.h>
#include <stdlib.h>
#include <fcntl.h>
#include <stdarg.h>
#include <dirent.h>
#include <time.h>
#include <aio.h>
#include "CaseInsensitiveResourcePaths.h"
extern FILE *DEOriginalFopenExt(const char *,const char *) __asm("_fopen$DARWIN_EXTSN");
static _Atomic(FILE *) DETrackedSteamFile;
static _Thread_local int DEFileLogging;
static _Atomic unsigned DEFileTraceCount;
static void DEFileResult(const char *api,const char *path,int failed,int error) {
    if (DEFileLogging || !path) return;
    int steam=strstr(path,"libsteam_api")!=NULL;
    int resource=getenv("AGEPAD_RESOURCE_FILE_TRACE") &&
        (strstr(path,"AgeOfEmpires2Data") || strstr(path,"/VFS/") || strstr(path,"/resources/") || path[0]!='/');
    if(!steam && !resource)return;
    const char *match=getenv("AGEPAD_RESOURCE_FILE_TRACE_MATCH");
    if(!steam && match && *match && !strcasestr(path,match))return;
    const char *armPath=getenv("AGEPAD_RESOURCE_FILE_TRACE_ARM");
    if(resource && !steam && armPath && access(armPath,F_OK)!=0)return;
    unsigned sequence=atomic_fetch_add(&DEFileTraceCount,1);
    if(sequence>=100000){
        if(sequence==100000)fprintf(stderr,"DE_RESOURCE_FILE_TRACE_LIMIT records=100000\n");
        return;
    }
    DEFileLogging=1;
    struct timespec now;clock_gettime(CLOCK_MONOTONIC,&now);
    fprintf(stderr,"%s seq=%u time=%lld.%09ld api=%s path=%s failed=%d errno=%d\n",steam?"DE_STEAM_FILE":"DE_RESOURCE_FILE",sequence,(long long)now.tv_sec,now.tv_nsec,api,path,failed,failed?error:0);
    fflush(stderr);
    DEFileLogging=0;
}
static int DEOpen(const char *path,int flags,...) {
    int result;
    if(flags&O_CREAT){va_list a;va_start(a,flags);int mode=va_arg(a,int);va_end(a);result=open(path,flags,mode);}
    else result=open(path,flags);
    int saved=errno;char resolved[PATH_MAX];
    if(result<0 && !(flags&(O_CREAT|O_TRUNC)) && (flags&O_ACCMODE)==O_RDONLY && DEResolveResourceCase(path,saved,resolved)) {result=open(resolved,flags);saved=errno;}
    DEFileResult("open",path,result<0,saved);errno=saved;return result;
}
extern int DEOriginalOpenNoCancel(const char *,int,...) __asm("_open$NOCANCEL");
static int DEOpenNoCancel(const char *path,int flags,...) {
    int result;
    if(flags&O_CREAT){va_list a;va_start(a,flags);int mode=va_arg(a,int);va_end(a);result=DEOriginalOpenNoCancel(path,flags,mode);}
    else result=DEOriginalOpenNoCancel(path,flags);
    int saved=errno;char resolved[PATH_MAX];
    if(result<0 && !(flags&(O_CREAT|O_TRUNC)) && (flags&O_ACCMODE)==O_RDONLY && DEResolveResourceCase(path,saved,resolved)) {result=DEOriginalOpenNoCancel(resolved,flags);saved=errno;}
    DEFileResult("open$NOCANCEL",path,result<0,saved);errno=saved;return result;
}
static DIR *DEOpenDir(const char *path) {
    DIR *result=opendir(path);int saved=errno;
    char resolved[PATH_MAX];if(!result && DEResolveResourceCase(path,saved,resolved)){result=opendir(resolved);saved=errno;}
    DEFileResult("opendir",path,result==NULL,saved);errno=saved;return result;
}
static int DEStat(const char *path,struct stat *buffer) {
    int result=stat(path,buffer),saved=errno;
    char resolved[PATH_MAX];if(result<0 && DEResolveResourceCase(path,saved,resolved)){result=stat(resolved,buffer);saved=errno;}
    DEFileResult("stat",path,result<0,saved);errno=saved;return result;
}
static int DELstat(const char *path,struct stat *buffer) {
    int result=lstat(path,buffer),saved=errno;
    char resolved[PATH_MAX];if(result<0 && DEResolveResourceCase(path,saved,resolved)){result=lstat(resolved,buffer);saved=errno;}
    DEFileResult("lstat",path,result<0,saved);errno=saved;return result;
}
static int DEAccess(const char *path,int mode) {
    int result=access(path,mode),saved=errno;
    char resolved[PATH_MAX];if(result<0 && DEResolveResourceCase(path,saved,resolved)){result=access(resolved,mode);saved=errno;}
    DEFileResult("access",path,result<0,saved);errno=saved;return result;
}
static FILE *DEFopen(const char *path,const char *mode) {
    FILE *result=fopen(path,mode);int saved=errno;
    char resolved[PATH_MAX];if(!result && mode && (strcmp(mode,"r")==0 || strcmp(mode,"rb")==0) && DEResolveResourceCase(path,saved,resolved)){result=fopen(resolved,mode);saved=errno;}
    DEFileResult("fopen",path,result==NULL,saved);errno=saved;return result;
}
static FILE *DEFopenExt(const char *path,const char *mode) {
    FILE *result=DEOriginalFopenExt(path,mode);int saved=errno;
    char resolved[PATH_MAX];if(!result && mode && (strcmp(mode,"r")==0 || strcmp(mode,"rb")==0) && DEResolveResourceCase(path,saved,resolved)){result=DEOriginalFopenExt(resolved,mode);saved=errno;}
    DEFileResult("fopen$DARWIN_EXTSN",path,result==NULL,saved);
    if (path && strstr(path,"libsteam_api")) atomic_store(&DETrackedSteamFile,result);
    errno=saved;return result;
}
static size_t DEFread(void *buffer,size_t size,size_t count,FILE *stream) {
    size_t result=fread(buffer,size,count,stream);int saved=errno;
    if (stream==atomic_load(&DETrackedSteamFile) && !DEFileLogging) {
        DEFileLogging=1;
        fprintf(stderr,"DE_STEAM_READ size=%zu count=%zu returned=%zu error=%d eof=%d errno=%d\n",
            size,count,result,ferror(stream),feof(stream),saved);
        fflush(stderr);DEFileLogging=0;
    }
    errno=saved;return result;
}
static int DEFclose(FILE *stream) {
    FILE *expected=stream;
    atomic_compare_exchange_strong(&DETrackedSteamFile,&expected,NULL);
    return fclose(stream);
}
static void DEAIOResult(const char *api,const struct aiocb *request,int failed,int error) {
    if(!getenv("AGEPAD_RESOURCE_AIO_TRACE") || !request)return;
    char path[1024],operation[128];
    if(fcntl(request->aio_fildes,F_GETPATH,path)!=0)return;
    snprintf(operation,sizeof operation,"%s(offset=%lld,bytes=%zu)",api,(long long)request->aio_offset,request->aio_nbytes);
    DEFileResult(operation,path,failed,error);
}
static int DEAIORead(struct aiocb *request) {
    int result=aio_read(request),saved=errno;
    DEAIOResult("aio_read",request,result<0,saved);errno=saved;return result;
}
static int DEAIOError(const struct aiocb *request) {
    int result=aio_error(request),saved=errno;
    if(result!=EINPROGRESS)DEAIOResult("aio_error",request,result!=0,result);
    errno=saved;return result;
}
static ssize_t DEAIOReturn(struct aiocb *request) {
    ssize_t result=aio_return(request);int saved=errno;
    DEAIOResult("aio_return",request,result<0,saved);errno=saved;return result;
}
__attribute__((used,section("__DATA,__interpose")))
static const struct { const void *replacement; const void *original; } DEFileInterpose[]={
    {(const void *)DEAIORead,(const void *)aio_read},
    {(const void *)DEAIOError,(const void *)aio_error},
    {(const void *)DEAIOReturn,(const void *)aio_return},
    {(const void *)DEOpen,(const void *)open},
    {(const void *)DEOpenNoCancel,(const void *)DEOriginalOpenNoCancel},
    {(const void *)DEOpenDir,(const void *)opendir},
    {(const void *)DEStat,(const void *)stat},
    {(const void *)DELstat,(const void *)lstat},
    {(const void *)DEAccess,(const void *)access},
    {(const void *)DEFopen,(const void *)fopen},
    {(const void *)DEFopenExt,(const void *)DEOriginalFopenExt},
    {(const void *)DEFread,(const void *)fread},
    {(const void *)DEFclose,(const void *)fclose}
};

#include "SLDParseTrace.h"
