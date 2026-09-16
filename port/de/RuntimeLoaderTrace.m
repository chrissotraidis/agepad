// Opt-in loader diagnostics. Forward actual results; do not consume dlerror.
// Interposition changes the caller image for caller-relative operations such as
// RTLD_NEXT. Use only for diagnosis and validate findings without this wrapper.
#include <dlfcn.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
static _Thread_local int DELoaderTracing;
static void *DELoggedDlopen(const char *path,int flags) {
    void *result=dlopen(path,flags);
    int saved=errno;
    if (!DELoaderTracing && getenv("AGEPAD_MAC_LOADER_TRACE")) {
        DELoaderTracing=1;
        fprintf(stderr,"DE_DLOPEN path=%s flags=%x result=%p\n",path?path:"(main)",flags,result);
        fflush(stderr);
        DELoaderTracing=0;
    }
    errno=saved;
    return result;
}
static void *DELoggedDlsym(void *handle,const char *name) {
    void *result=dlsym(handle,name);
    int saved=errno;
    if (!DELoaderTracing && getenv("AGEPAD_MAC_LOADER_TRACE")) {
        DELoaderTracing=1;
        fprintf(stderr,"DE_DLSYM handle=%p name=%s result=%p\n",handle,name?name:"(null)",result);
        fflush(stderr);
        DELoaderTracing=0;
    }
    errno=saved;
    return result;
}
__attribute__((used,section("__DATA,__interpose")))
static const struct { const void *replacement; const void *original; } DELoaderInterpose[]={
    {(const void *)DELoggedDlopen,(const void *)dlopen},
    {(const void *)DELoggedDlsym,(const void *)dlsym}
};
