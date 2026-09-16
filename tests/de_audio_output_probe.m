#import <AudioToolbox/AudioToolbox.h>
#include <stdio.h>
#include <string.h>
int main(int argc,char **argv) {
    int bridged=argc>1 && strcmp(argv[1],"bridged")==0;
    AudioComponentDescription mac={kAudioUnitType_Output,0x64656620,kAudioUnitManufacturer_Apple,0,0};
    AudioComponent output=AudioComponentFindNext(NULL,&mac);
    AudioComponentDescription mixer={kAudioUnitType_Mixer,kAudioUnitSubType_MultiChannelMixer,kAudioUnitManufacturer_Apple,0,0};
    AudioComponent mix=AudioComponentFindNext(NULL,&mixer);
    AudioComponentDescription missing={kAudioUnitType_Output,0x7a7a7a7a,kAudioUnitManufacturer_Apple,0,0};
    AudioComponent invalid=AudioComponentFindNext(NULL,&missing);
    AudioComponentDescription observed={0};
    OSStatus status=output?AudioComponentGetDescription(output,&observed):0;
    int pass=(!!output==bridged) && mix && !invalid && !status &&
             (!bridged || observed.componentSubType==kAudioUnitSubType_RemoteIO);
    printf("bridge=%d output=%p mixer=%p unsupported=%p actual_subtype=%08x pass=%d\n",bridged,output,mix,invalid,(unsigned)observed.componentSubType,pass);
    return !pass;
}
