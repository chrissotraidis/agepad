#include "AppPresence.h"
#include <unistd.h>
// Carbon Process Manager questions from the Steam engine client. AgePad is
// its only process; it is the front process while it is the active app.
typedef struct { UInt32 highLongOfPSN,lowLongOfPSN; } AgePadPSN;
enum { AgePadCurrentProcess=2,AgePadProcNotFound=-600 };
OSErr GetCurrentProcess(AgePadPSN *psn) { psn->highLongOfPSN=0;psn->lowLongOfPSN=AgePadCurrentProcess;return 0; }
OSErr GetFrontProcess(AgePadPSN *psn) {
    if (!atomic_load(&AgePadAppActive)) return AgePadProcNotFound;
    return GetCurrentProcess(psn);
}
OSStatus GetProcessPID(const AgePadPSN *psn,pid_t *pid) {
    if (psn->highLongOfPSN!=0 || psn->lowLongOfPSN!=AgePadCurrentProcess) return AgePadProcNotFound;
    *pid=getpid();return 0;
}
