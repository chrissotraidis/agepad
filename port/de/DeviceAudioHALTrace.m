// Physical iPad diagnostic (AGEPAD_AUDIO_HAL_TRACE). A leak sampler found
// Apple's in-process BTAudioHALPlugin reconnecting in a tight XPC loop and
// leaking a process-name string each time (~20k/s). The HAL is started by the
// engine's macOS AudioObject* calls. Log which properties it uses; calls are
// forwarded unchanged.
#include <TargetConditionals.h>
#if !TARGET_OS_SIMULATOR
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#include <CoreAudio/CoreAudioTypes.h>
#include <CoreAudio/AudioHardwareBase.h>
#include <stdatomic.h>
#include <stdio.h>
#include <unistd.h>
typedef OSStatus (*DEAudioListenerProc)(AudioObjectID,UInt32,const AudioObjectPropertyAddress *,void *);
extern OSStatus AudioObjectGetPropertyData(AudioObjectID,const AudioObjectPropertyAddress *,UInt32,const void *,UInt32 *,void *);
extern OSStatus AudioObjectGetPropertyDataSize(AudioObjectID,const AudioObjectPropertyAddress *,UInt32,const void *,UInt32 *);
extern OSStatus AudioObjectSetPropertyData(AudioObjectID,const AudioObjectPropertyAddress *,UInt32,const void *,UInt32,const void *);
extern Boolean AudioObjectHasProperty(AudioObjectID,const AudioObjectPropertyAddress *);
extern OSStatus AudioObjectAddPropertyListener(AudioObjectID,const AudioObjectPropertyAddress *,DEAudioListenerProc,void *);
extern OSStatus AudioObjectRemovePropertyListener(AudioObjectID,const AudioObjectPropertyAddress *,DEAudioListenerProc,void *);
// AGEPAD_AUDIO_HAL_LOCAL: answer the engine's device queries without starting
// the in-process HAL. On iPad the engine asks only for change listeners, the
// default output device, its UID and the device list (traced). Audio itself is
// played through RemoteIO (AudioOutputCompat), so the single output device
// reported here names that route. Unknown queries fail visibly, not silently.
enum { DELocalOutputDevice=2 };
// macOS AudioHardware.h values (absent from the iPadOS SDK headers).
enum {
    kAudioObjectSystemObject=1,
    kAudioHardwarePropertyDevices='dev#',
    kAudioHardwarePropertyDefaultInputDevice='dIn ',
    kAudioHardwarePropertyDefaultOutputDevice='dOut',
    kAudioHardwarePropertyDefaultSystemOutputDevice='sOut',
    kAudioDevicePropertyStreamFormat='sfmt',
    kAudioDevicePropertyBufferFrameSizeRange='fsz#',
    kAudioDevicePropertyStreamConfiguration='slay',
};
// Values of the current iPad route, read from the shared audio session.
static void DERouteFormat(double *rate,UInt32 *channels,UInt32 *frames) {
    AVAudioSession *session=AVAudioSession.sharedInstance;
    *rate=session.sampleRate>0?session.sampleRate:48000;
    *channels=session.outputNumberOfChannels>0?(UInt32)session.outputNumberOfChannels:2;
    if (*channels>2) *channels=2;
    double duration=session.IOBufferDuration>0?session.IOBufferDuration:0.01;
    *frames=(UInt32)lround(duration * *rate);
}
#define DE_ANSWER(type,value) do { if (data) { if (*size<sizeof(type)) return kAudioHardwareBadPropertySizeError; *(type *)data=(value); } *size=sizeof(type);return noErr; } while (0)
static BOOL DEAudioLocal(void) { static int on=-1;if (on<0) on=getenv("AGEPAD_AUDIO_HAL_LOCAL")!=NULL;return on; }
static OSStatus DELocalGet(AudioObjectID o,const AudioObjectPropertyAddress *a,UInt32 *size,void *data) {
    if (!a || !size) return kAudioHardwareIllegalOperationError;
    UInt32 s=a->mSelector;
    if (o==kAudioObjectSystemObject && (s==kAudioHardwarePropertyDefaultOutputDevice || s==kAudioHardwarePropertyDefaultSystemOutputDevice)) {
        if (data) { if (*size<sizeof(AudioObjectID)) return kAudioHardwareBadPropertySizeError; *(AudioObjectID *)data=DELocalOutputDevice; }
        *size=sizeof(AudioObjectID);return noErr;
    }
    if (o==kAudioObjectSystemObject && s==kAudioHardwarePropertyDefaultInputDevice) {
        if (data) { if (*size<sizeof(AudioObjectID)) return kAudioHardwareBadPropertySizeError; *(AudioObjectID *)data=kAudioObjectUnknown; }
        *size=sizeof(AudioObjectID);return noErr;
    }
    if (o==kAudioObjectSystemObject && s==kAudioHardwarePropertyDevices) {
        if (data) { if (*size<sizeof(AudioObjectID)) return kAudioHardwareBadPropertySizeError; *(AudioObjectID *)data=DELocalOutputDevice; }
        *size=sizeof(AudioObjectID);return noErr;
    }
    if (o==DELocalOutputDevice && (s==kAudioDevicePropertyDeviceUID || s==kAudioObjectPropertyName)) {
        if (data) { if (*size<sizeof(CFStringRef)) return kAudioHardwareBadPropertySizeError; *(CFStringRef *)data=CFSTR("AgePadRemoteIO"); }
        *size=sizeof(CFStringRef);return noErr;
    }
    if (o==DELocalOutputDevice) {
        double rate;UInt32 channels,frames;DERouteFormat(&rate,&channels,&frames);
        if (s==kAudioDevicePropertyStreamFormat) {
            AudioStreamBasicDescription f={0};
            f.mSampleRate=rate;f.mFormatID=kAudioFormatLinearPCM;
            f.mFormatFlags=kAudioFormatFlagIsFloat|kAudioFormatFlagIsPacked;
            f.mChannelsPerFrame=channels;f.mBitsPerChannel=32;f.mFramesPerPacket=1;
            f.mBytesPerFrame=f.mBytesPerPacket=4*channels;
            DE_ANSWER(AudioStreamBasicDescription,f);
        }
        if (s==kAudioDevicePropertyBufferFrameSizeRange) DE_ANSWER(AudioValueRange,((AudioValueRange){frames,frames}));
        if (s==kAudioDevicePropertyPreferredChannelsForStereo) {
            if (data) { if (*size<2*sizeof(UInt32)) return kAudioHardwareBadPropertySizeError; ((UInt32 *)data)[0]=1;((UInt32 *)data)[1]=channels>1?2:1; }
            *size=2*sizeof(UInt32);return noErr;
        }
        if (s==kAudioDevicePropertyPreferredChannelLayout) {
            AudioChannelLayout layout={0};layout.mChannelLayoutTag=channels>1?kAudioChannelLayoutTag_Stereo:kAudioChannelLayoutTag_Mono;
            DE_ANSWER(AudioChannelLayout,layout);
        }
        if (s==kAudioDevicePropertyStreamConfiguration) {
            // One interleaved buffer carrying the route's channels.
            AudioBufferList list={0};list.mNumberBuffers=1;list.mBuffers[0].mNumberChannels=channels;
            DE_ANSWER(AudioBufferList,list);
        }
    }
    return kAudioHardwareUnknownPropertyError;
}
static void DEAudioHALLog(const char *op,AudioObjectID object,const AudioObjectPropertyAddress *address,long status) {
    static _Atomic unsigned long long calls;
    unsigned long long n=++calls;
    if (!getenv("AGEPAD_AUDIO_HAL_TRACE") || (n>60 && n%5000)) return;
    UInt32 s=address?address->mSelector:0,scope=address?address->mScope:0;
    char line[200];
    int length=snprintf(line,sizeof line,"DE_AUDIO_HAL op=%s calls=%llu object=%u selector=%c%c%c%c scope=%c%c%c%c element=%u status=%ld\n",op,n,(unsigned)object,
        (char)(s>>24),(char)(s>>16),(char)(s>>8),(char)s,(char)(scope>>24),(char)(scope>>16),(char)(scope>>8),(char)scope,address?(unsigned)address->mElement:0,status);
    if (length>0) write(STDERR_FILENO,line,(size_t)length);
}
static OSStatus DEGetData(AudioObjectID o,const AudioObjectPropertyAddress *a,UInt32 q,const void *qd,UInt32 *size,void *data) {
    if (DEAudioLocal()) { OSStatus s=DELocalGet(o,a,size,data);DEAudioHALLog("local-get",o,a,s);return s; }
    OSStatus s=AudioObjectGetPropertyData(o,a,q,qd,size,data);DEAudioHALLog("get",o,a,s);return s;
}
static OSStatus DEGetSize(AudioObjectID o,const AudioObjectPropertyAddress *a,UInt32 q,const void *qd,UInt32 *size) {
    if (DEAudioLocal()) { OSStatus s=DELocalGet(o,a,size,NULL);DEAudioHALLog("local-size",o,a,s);return s; }
    OSStatus s=AudioObjectGetPropertyDataSize(o,a,q,qd,size);DEAudioHALLog("size",o,a,s);return s;
}
static OSStatus DESetData(AudioObjectID o,const AudioObjectPropertyAddress *a,UInt32 q,const void *qd,UInt32 size,const void *data) {
    if (DEAudioLocal()) { DEAudioHALLog("local-set-refused",o,a,kAudioHardwareIllegalOperationError);return kAudioHardwareIllegalOperationError; }
    OSStatus s=AudioObjectSetPropertyData(o,a,q,qd,size,data);DEAudioHALLog("set",o,a,s);return s;
}
static Boolean DEHas(AudioObjectID o,const AudioObjectPropertyAddress *a) {
    if (DEAudioLocal()) { UInt32 size=0;Boolean b=DELocalGet(o,a,&size,NULL)==noErr;DEAudioHALLog("local-has",o,a,b);return b; }
    Boolean b=AudioObjectHasProperty(o,a);DEAudioHALLog("has",o,a,b);return b;
}
static OSStatus DEAddListener(AudioObjectID o,const AudioObjectPropertyAddress *a,DEAudioListenerProc proc,void *context) {
    // The single local route never changes identity; accept without the HAL.
    if (DEAudioLocal()) { DEAudioHALLog("local-listen",o,a,noErr);return noErr; }
    OSStatus s=AudioObjectAddPropertyListener(o,a,proc,context);DEAudioHALLog("listen",o,a,s);return s;
}
static OSStatus DERemoveListener(AudioObjectID o,const AudioObjectPropertyAddress *a,DEAudioListenerProc proc,void *context) {
    if (DEAudioLocal()) { DEAudioHALLog("local-unlisten",o,a,noErr);return noErr; }
    return AudioObjectRemovePropertyListener(o,a,proc,context);
}
__attribute__((used, section("__DATA,__interpose")))
static const struct { const void *replacement; const void *original; } DEAudioHALInterpose[] = {
    {(const void *)DEGetData,(const void *)AudioObjectGetPropertyData},
    {(const void *)DEGetSize,(const void *)AudioObjectGetPropertyDataSize},
    {(const void *)DESetData,(const void *)AudioObjectSetPropertyData},
    {(const void *)DEHas,(const void *)AudioObjectHasProperty},
    {(const void *)DEAddListener,(const void *)AudioObjectAddPropertyListener},
    {(const void *)DERemoveListener,(const void *)AudioObjectRemovePropertyListener},
};
#endif
