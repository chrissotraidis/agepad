#import <Foundation/Foundation.h>
#include <TargetConditionals.h>
#include <assert.h>
#include "../port/de/RuntimeFileTrace.m"

int main(void) { @autoreleasepool {
    char root[PATH_MAX],directory[PATH_MAX],file[PATH_MAX],request[PATH_MAX],resolved[PATH_MAX];
    snprintf(root,sizeof(root),"%sagepad-case-XXXXXX",NSTemporaryDirectory().UTF8String);
    assert(mkdtemp(root));snprintf(directory,sizeof(directory),"%s/Graphics",root);assert(mkdir(directory,0700)==0);
    snprintf(file,sizeof(file),"%s/Villager_idleA.SLD",directory);
    FILE *out=fopen(file,"wb");assert(out);assert(fwrite("real-frame",1,10,out)==10);fclose(out);
    snprintf(request,sizeof(request),"%s/graphics/villager_idlea.sld",root);
    int direct=open(request,O_RDONLY);int directError=errno;
    if(direct>=0)close(direct);
    printf("underlying_case_mismatch_open=%d errno=%d\n",direct,directError);
    setenv("AGEPAD_CASE_INSENSITIVE_RESOURCE_ROOT",root,1);
    assert(DEResolveResourceCase(request,ENOENT,resolved));assert(strcmp(resolved,file)==0);
    int fd=DEOpen(request,O_RDONLY);assert(fd>=0);char payload[11]={0};assert(read(fd,payload,10)==10);close(fd);assert(strcmp(payload,"real-frame")==0);
    struct stat st;assert(DEStat(request,&st)==0 && st.st_size==10);assert(DELstat(request,&st)==0);assert(DEAccess(request,R_OK)==0);
    FILE *f=DEFopen(request,"rb");assert(f);fclose(f);f=DEFopenExt(request,"rb");assert(f);fclose(f);
    char requestedDirectory[PATH_MAX];snprintf(requestedDirectory,sizeof(requestedDirectory),"%s/graphics",root);
    DIR *d=DEOpenDir(requestedDirectory);assert(d);closedir(d);
    assert(!DEResolveResourceCase(request,EACCES,resolved));
    assert(!DEResolveResourceCase("/outside-agepad-resources/missing",ENOENT,resolved));
    char escape[PATH_MAX];snprintf(escape,sizeof(escape),"%s/../outside",root);assert(!DEResolveResourceCase(escape,ENOENT,resolved));
    char missing[PATH_MAX];snprintf(missing,sizeof(missing),"%s/missing.sld",root);assert(DEOpen(missing,O_RDONLY)==-1 && errno==ENOENT);
    if(direct<0) {assert(DEFopen(request,"r+")==NULL);assert(DEOpen(request,O_RDWR)==-1);}
    puts("PASS: case-mismatched resource reads resolve real bytes; stat/lstat/access/opendir/fopen agree; missing, denied, outside and write paths retain their behavior");
    unlink(file);rmdir(directory);rmdir(root);
} }
