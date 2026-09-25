// Tap-to-play launch settings (physical iPad). A launch from the Home Screen
// has no Mac-supplied environment, so the compatibility settings come from:
//   <app>/AgePadLaunch.env                 play settings, baked in at build time
//   Documents/AgePadSteamHost.env          written once by "agepad-ipad.sh pair":
//                                          Mac helper address(es) and pairing key
// The original game starts only when the pairing file exists; otherwise the
// setup screen explains what to do. Values passed by a Mac launch always win
// (setenv never overwrites), and only AGEPAD_* keys are accepted. Included by
// every image whose constructors read settings; the first one to run applies it.
#pragma once
#include <TargetConditionals.h>
#if !TARGET_OS_SIMULATOR
#include <mach-o/dyld.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
static int DEApplyLaunchEnvFile(const char *path) {
    FILE *file=fopen(path,"r");
    if (!file) return 0;
    char line[1024];int applied=0;
    while (fgets(line,sizeof line,file)) {
        line[strcspn(line,"\r\n")]=0;
        char *equals=strchr(line,'=');
        if (!equals || strncmp(line,"AGEPAD_",7)) continue;
        *equals=0;
        if (!getenv(line)) { setenv(line,equals+1,0);applied++; }
    }
    fclose(file);
    return applied;
}
__attribute__((constructor(101))) static void DEApplyLaunchConfig(void) {
    if (getenv("AGEPAD_LAUNCH_CONFIG_APPLIED")) return;
    setenv("AGEPAD_LAUNCH_CONFIG_APPLIED","1",1);
    const char *home=getenv("HOME");
    char path[PATH_MAX];
    int paired=0;
    if (home) {
        snprintf(path,sizeof path,"%s/Documents/AgePadSteamHost.env",home);
        paired=DEApplyLaunchEnvFile(path)>0 || getenv("AGEPAD_STEAM_TUNNEL_HOST")!=NULL;
    }
    if (!paired && !getenv("AGEPAD_DEVICE_RUN_ORIGINAL")) return; // setup screen only
    char executable[PATH_MAX];uint32_t size=sizeof executable;
    if (_NSGetExecutablePath(executable,&size)==0) {
        char *slash=strrchr(executable,'/');
        if (slash) { *slash=0;snprintf(path,sizeof path,"%s/AgePadLaunch.env",executable);DEApplyLaunchEnvFile(path); }
    }
    if (paired) setenv("AGEPAD_DEVICE_RUN_ORIGINAL","1",0);
}
#endif
