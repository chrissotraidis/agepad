#include <windows.h>
static void say(const char*s,DWORD n){DWORD w;WriteFile(GetStdHandle(STD_OUTPUT_HANDLE),s,n,&w,0);}
#define SAY(s) say(s,sizeof(s)-1)
void mainCRTStartup(void){
 WCHAR path[MAX_PATH];DWORD n=GetModuleFileNameW(0,path,MAX_PATH);if(!n||n>=MAX_PATH)ExitProcess(10);
 DWORD end=n;while(end&&path[end-1]!=L'\\')--end;
 const WCHAR name[]=L"agepad-arch-child-x86.exe";
 if(end+sizeof(name)/sizeof(WCHAR)>MAX_PATH)ExitProcess(11);
 for(DWORD i=0;i<sizeof(name)/sizeof(WCHAR);i++)path[end+i]=name[i];
 STARTUPINFOW si={0};PROCESS_INFORMATION pi={0};si.cb=sizeof(si);
 if(CreateProcessW(path,0,0,0,FALSE,0,0,0,&si,&pi)){SAY("AGEPAD_ARCH_CHILD: UNEXPECTED_SUCCESS\n");ExitProcess(12);}
 DWORD error=GetLastError();if(error!=ERROR_BAD_EXE_FORMAT){SAY("AGEPAD_ARCH_CHILD: WRONG_ERROR\n");ExitProcess(13);}
 if(pi.hProcess||pi.hThread)ExitProcess(14);
 SAY("AGEPAD_ARCH_CHILD: BAD_EXE_FORMAT_PARENT_ALIVE_PASS\n");ExitProcess(0);
}
