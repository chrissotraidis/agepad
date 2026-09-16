// Opt-in diagnostic for the supplied v1.1.2 ARM64 engine's SLDFile parser.
// Replaces one data vtable slot; never changes the parser's code or result.
#include <mach/mach.h>
#include <mach-o/dyld.h>
#include <stdint.h>
#include <pthread.h>
#include <errno.h>
// The frame accessor is a separate observation from parsing: a parsed asset
// may never be requested by the renderer, or may return an empty frame layer.
static void *(*DEOriginalSLDFrame)(void *,uint32_t,uint32_t);
static pthread_mutex_t DESLDNamesLock=PTHREAD_MUTEX_INITIALIZER;
static struct { void *object; char path[512]; } DESLDNames[4096];
static unsigned DESLDNameCount;
static _Atomic unsigned DESLDFrameCount;
static void DESLDRemember(void *object,const char *path) {
    pthread_mutex_lock(&DESLDNamesLock);
    unsigned i=0;for(;i<DESLDNameCount;i++)if(DESLDNames[i].object==object)break;
    if(i<4096){DESLDNames[i].object=object;snprintf(DESLDNames[i].path,512,"%s",path);if(i==DESLDNameCount)DESLDNameCount++;}
    pthread_mutex_unlock(&DESLDNamesLock);
}
static void *DESLDFrame(void *object,uint32_t frame,uint32_t layer) {
    void *result=DEOriginalSLDFrame(object,frame,layer);
    int saved=errno;
    const char *arm=getenv("AGEPAD_SLD_FRAME_TRACE_ARM");
    if(arm && access(arm,F_OK)!=0){errno=saved;return result;}
    unsigned sequence=atomic_fetch_add(&DESLDFrameCount,1);
    if(sequence<4096) {
        char path[512]="<unobserved parse>";
        pthread_mutex_lock(&DESLDNamesLock);
        for(unsigned i=0;i<DESLDNameCount;i++)if(DESLDNames[i].object==object){memcpy(path,DESLDNames[i].path,sizeof(path));break;}
        pthread_mutex_unlock(&DESLDNamesLock);
        uint32_t frames=0;uint16_t header[6]={0};vm_size_t copied=0;
        vm_read_overwrite(mach_task_self(),(vm_address_t)object+0x28,sizeof(frames),(vm_address_t)&frames,&copied);
        if(result)vm_read_overwrite(mach_task_self(),(vm_address_t)result,sizeof(header),(vm_address_t)header,&copied);
        fprintf(stderr,"DE_SLD_FRAME seq=%u object=%p frame=%u layer=%u frames=%u present=%d bounds=%u,%u,%u,%u path=%s\n",sequence,object,frame,layer,frames,result!=NULL,header[2],header[3],header[4],header[5],path);
    }
    errno=saved;return result;
}
static int (*DEOriginalSLDParse)(void *,const char *);
static _Atomic unsigned DESLDParseCount;
static int DESLDParse(void *object,const char *path) {
    unsigned sequence=atomic_fetch_add(&DESLDParseCount,1);
    char name[512]={0};uintptr_t bounds[2]={0};vm_size_t copied=0;
    if(sequence<4096) {
        if(path)vm_read_overwrite(mach_task_self(),(vm_address_t)path,sizeof(name)-1,(vm_address_t)name,&copied);
        vm_read_overwrite(mach_task_self(),(vm_address_t)object+0x10,sizeof(bounds),(vm_address_t)bounds,&copied);
    }
    int result=DEOriginalSLDParse(object,path);
    if(getenv("AGEPAD_SLD_FRAME_TRACE") && sequence<4096)DESLDRemember(object,name);
    if(sequence<4096)fprintf(stderr,"DE_SLD_PARSE seq=%u bytes=%llu result=%d path=%s\n",sequence,
        (unsigned long long)(bounds[1]>=bounds[0]?bounds[1]-bounds[0]:0),result,name);
    return result;
}
__attribute__((constructor))static void DEInstallSLDParseTrace(void) {
    if(!getenv("AGEPAD_SLD_PARSE_TRACE") && !getenv("AGEPAD_SLD_FRAME_TRACE"))return;
    uintptr_t base=0;
    for(uint32_t i=0;i<_dyld_image_count();i++) {
        const char *name=_dyld_get_image_name(i);
        const char *last=name?strrchr(name,'/'):NULL;
        if(last && (strcmp(last+1,"DEOriginalGame")==0 || strcmp(last+1,"Age Of Empires II")==0)) {base=(uintptr_t)_dyld_get_image_header(i);break;}
    }
    if(!base){fprintf(stderr,"DE_SLD_PARSE_TRACE skipped=not_game\n");return;}
    // Verified file text and vtable slot of this exact original game build.
    uintptr_t *slot=(uintptr_t *)(base+0x4d34be8);
    uintptr_t expected=base+0x2d554ec,value=0;uint32_t code=0;vm_size_t copied=0;
    if(vm_read_overwrite(mach_task_self(),(vm_address_t)slot,sizeof(value),(vm_address_t)&value,&copied)!=KERN_SUCCESS || value!=expected ||
       vm_read_overwrite(mach_task_self(),expected,sizeof(code),(vm_address_t)&code,&copied)!=KERN_SUCCESS || code!=0xd10583ff) {
        fprintf(stderr,"DE_SLD_PARSE_TRACE skipped=ABI_mismatch\n");return;
    }
    vm_address_t page=(vm_address_t)slot & ~((vm_address_t)vm_page_size-1);
    kern_return_t status=vm_protect(mach_task_self(),page,vm_page_size,FALSE,VM_PROT_READ|VM_PROT_WRITE|VM_PROT_COPY);
    if(status!=KERN_SUCCESS){fprintf(stderr,"DE_SLD_PARSE_TRACE skipped=protection status=%d\n",status);return;}
    DEOriginalSLDParse=(void *)expected;
    *slot=(uintptr_t)DESLDParse;
    if(getenv("AGEPAD_SLD_FRAME_TRACE")) {
        // Verified three-register pointer-returning accessor in this build:
        // object, uint32 frame, uint32 layer; no modification of its result.
        uintptr_t *frameSlot=(uintptr_t *)(base+0x4d34bb8);
        uintptr_t frameExpected=base+0x2d54f1c,frameValue=0;uint32_t frameCode=0;
        if(vm_read_overwrite(mach_task_self(),(vm_address_t)frameSlot,sizeof(frameValue),(vm_address_t)&frameValue,&copied)==KERN_SUCCESS && frameValue==frameExpected &&
           vm_read_overwrite(mach_task_self(),frameExpected,sizeof(frameCode),(vm_address_t)&frameCode,&copied)==KERN_SUCCESS && frameCode==0xd2800008) {
            DEOriginalSLDFrame=(void *)frameExpected;*frameSlot=(uintptr_t)DESLDFrame;
            fprintf(stderr,"DE_SLD_FRAME_TRACE installed=1\n");
        }else fprintf(stderr,"DE_SLD_FRAME_TRACE skipped=ABI_mismatch\n");
    }
    status=vm_protect(mach_task_self(),page,vm_page_size,FALSE,VM_PROT_READ);
    fprintf(stderr,"DE_SLD_PARSE_TRACE installed=1 restore_status=%d\n",status);
}
