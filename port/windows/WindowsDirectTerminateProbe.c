#include <windows.h>
static void say(const char*s,DWORD n){DWORD w;WriteFile(GetStdHandle(STD_OUTPUT_HANDLE),s,n,&w,0);}
#define SAY(s) say(s,sizeof(s)-1)
static DWORD WINAPI worker(void *ready){SetEvent(ready);Sleep(INFINITE);return 99;}
void mainCRTStartup(void){
 WCHAR marker[4];
 if(GetEnvironmentVariableW(L"AGEPAD_DIRECT_TERMINATE_CHILD",marker,4)){
  HANDLE ready=CreateEventW(0,TRUE,FALSE,0);if(!ready)ExitProcess(10);
  HANDLE thread=CreateThread(0,0,worker,ready,0,0);if(!thread||WaitForSingleObject(ready,10000)!=WAIT_OBJECT_0)ExitProcess(11);
  SAY("AGEPAD_DIRECT_TERMINATE: CHILD_SELF_TERMINATING\n");
  TerminateProcess(GetCurrentProcess(),47);ExitProcess(12);
 }
 WCHAR exe[MAX_PATH];DWORD n=GetModuleFileNameW(0,exe,MAX_PATH);if(!n||n>=MAX_PATH)ExitProcess(20);
 if(!SetEnvironmentVariableW(L"AGEPAD_DIRECT_TERMINATE_CHILD",L"1"))ExitProcess(21);
 STARTUPINFOW si={0};PROCESS_INFORMATION pi={0};si.cb=sizeof(si);
 if(!CreateProcessW(exe,0,0,0,FALSE,0,0,0,&si,&pi))ExitProcess(22);
 SetEnvironmentVariableW(L"AGEPAD_DIRECT_TERMINATE_CHILD",0);
 if(WaitForSingleObject(pi.hProcess,15000)!=WAIT_OBJECT_0)ExitProcess(23);
 DWORD code=0;if(!GetExitCodeProcess(pi.hProcess,&code)||code!=47)ExitProcess(24);
 CloseHandle(pi.hThread);CloseHandle(pi.hProcess);
 SAY("AGEPAD_DIRECT_TERMINATE: CHILD_47_PARENT_ALIVE_PASS\n");ExitProcess(0);
}
