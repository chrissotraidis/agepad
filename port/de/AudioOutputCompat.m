// Map the original Mac engine's unavailable default output to UIKit audio.
// All other component searches and error results retain system behavior.
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>
#include <stdio.h>

static AudioComponent DEFindAudioComponent(AudioComponent previous,
                                           const AudioComponentDescription *description) {
    AudioComponent result=AudioComponentFindNext(previous,description);
    if(getenv("AGEPAD_AUDIO_COMPONENT_TRACE") && description) {
        static _Atomic unsigned traces;
        if(traces++<24)fprintf(stderr,"DE_AUDIO_COMPONENT_QUERY type=%08x subtype=%08x manufacturer=%08x previous=%d found=%d\n",
            (unsigned)description->componentType,(unsigned)description->componentSubType,
            (unsigned)description->componentManufacturer,previous!=NULL,result!=NULL);
    }
    if(result || previous || !description ||
       description->componentType!=kAudioUnitType_Output ||
       description->componentSubType!=0x64656620 || // macOS 'def '
       description->componentManufacturer!=kAudioUnitManufacturer_Apple)return result;
    @autoreleasepool {
        AVAudioSession *session=AVAudioSession.sharedInstance;
        NSError *error=nil;
        if(![session setCategory:AVAudioSessionCategoryPlayback
                   withOptions:AVAudioSessionCategoryOptionMixWithOthers error:&error] ||
           ![session setActive:YES error:&error]) {
            fprintf(stderr,"DE_AUDIO_OUTPUT_SESSION_FAILED %s\n",error.description.UTF8String);
            return NULL;
        }
        AudioComponentDescription mobile=*description;
        mobile.componentSubType=kAudioUnitSubType_RemoteIO;
        result=AudioComponentFindNext(NULL,&mobile);
        fprintf(stderr,"DE_AUDIO_OUTPUT_REMOTE_IO component=%p sample_rate=%g route=%s\n",
                result,session.sampleRate,session.currentRoute.outputs.description.UTF8String);
    }
    return result;
}
__attribute__((used)) static struct { const void *replacement; const void *original; }
DEAudioOutputInterpose __attribute__((section("__DATA,__interpose"))) = {
    (const void *)DEFindAudioComponent,(const void *)AudioComponentFindNext
};
