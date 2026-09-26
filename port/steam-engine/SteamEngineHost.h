// Valve's Steam client engine (steamclient.dylib), hosted in-process: the job
// steam_osx does on a Mac. Shared by the Mac probe and the iPad app.
// Every Steam answer comes from Valve's engine; nothing is synthesized here.
#pragma once
#include <mach/mach.h>
#include <stdbool.h>
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
// Loads the engine interface from an already-opened steamclient image, creates
// the global user and starts the engine's frame pump. Returns false and fills
// error (for logs) if any interface does not match what this code expects.
bool AgePadEngineStart(void *steamClientImage,char *error,unsigned long errorSize);
// Sign-in, through IClientUser methods found by their own names at run time.
void AgePadEngineSetLoginToken(const char *token,const char *accountName);
int AgePadEngineLogOn(uint64_t steamID);
int AgePadEngineLogOnOffline(void);
void AgePadEngineLogOff(void);
bool AgePadEngineLoggedOn(void);
bool AgePadEngineConnected(void);
int AgePadEngineLogonState(void);
uint64_t AgePadEngineSteamID(void);
// Steam's own ownership answer for the signed-in account (known once the
// engine has loaded the account's licenses after logon).
bool AgePadEngineOwnsApp(uint32_t appID);
// Steam's own answer to "could this account log on offline now" (raw value).
int AgePadEngineCanLogOnOffline(void);
// Tells Valve's ipcserver that this process runs Steam (operation 13), as
// steam_osx does, so a game's libsteam_api loads steamclient from clientPath
// and connects to this engine. lookUp is the bootstrap_look_up to use.
kern_return_t AgePadEngineRegister(const char *clientPath,
    kern_return_t (*lookUp)(mach_port_t,const char *,mach_port_t *));
#ifdef __cplusplus
}
#endif
