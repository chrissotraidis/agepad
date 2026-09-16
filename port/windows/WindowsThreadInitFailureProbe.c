/* Source-owned test for a diagnostic FEX build that fails its second callret reserve. */
#include <windows.h>
static volatile LONG entered;
static DWORD WINAPI worker(void *unused) { (void)unused; InterlockedIncrement(&entered); return 73; }
static void say(const char *s,DWORD n) { DWORD written; WriteFile(GetStdHandle(STD_OUTPUT_HANDLE),s,n,&written,0); }
#define SAY(s) say(s,sizeof(s)-1)
static void fail(UINT code) { SAY("AGEPAD_THREAD_INIT: FAIL\n"); ExitProcess(code); }
void mainCRTStartup(void) {
 DWORD status=0; HANDLE thread;
 SAY("AGEPAD_THREAD_INIT: BEGIN\n");
 thread=CreateThread(0,0,worker,0,0,0);
 if(!thread) fail(51);
 if(WaitForSingleObject(thread,15000)!=WAIT_OBJECT_0) fail(52);
 if(!GetExitCodeThread(thread,&status) || status!=0xc0000017u || entered!=0) fail(53);
 CloseHandle(thread);
 SAY("AGEPAD_THREAD_INIT: FAILED_THREAD_REJECTED\n");
 thread=CreateThread(0,0,worker,0,0,0);
 if(!thread) fail(54);
 if(WaitForSingleObject(thread,15000)!=WAIT_OBJECT_0) fail(55);
 if(!GetExitCodeThread(thread,&status) || status!=73 || entered!=1) fail(56);
 CloseHandle(thread);
 SAY("AGEPAD_THREAD_INIT: PARENT_AND_NEXT_THREAD_SURVIVED\n");
 SAY("AGEPAD_THREAD_INIT: PASS\n"); ExitProcess(0);
}
