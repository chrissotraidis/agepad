/* Real CreateProcess and child status check; diagnostic for private DLL integration. */
#include <windows.h>
volatile DWORD process_value=0x13579bdf;
void *memset(void*p,int c,size_t n){volatile unsigned char*b=p;for(size_t i=0;i<n;i++)b[i]=(unsigned char)c;return p;}
static void emit(const char*s,DWORD n){DWORD w;WriteFile(GetStdHandle(STD_OUTPUT_HANDLE),s,n,&w,0);}
#define SAY(s) emit(s,sizeof(s)-1)
#ifdef AGEPAD_CHILD_CRT
#include <stdlib.h>
__declspec(dllimport) int __cdecl _crt_atexit(void (__cdecl *)(void));
static void __cdecl child_cleanup(void){
 DWORD value=0x43525431,written=0;
 HANDLE h=CreateFileW(L"C:\\agepad-crt-callback.txt",GENERIC_WRITE,0,0,CREATE_ALWAYS,FILE_ATTRIBUTE_NORMAL,0);
 if(h==INVALID_HANDLE_VALUE||!WriteFile(h,&value,sizeof(value),&written,0)||written!=sizeof(value))ExitProcess(74);
 CloseHandle(h);
}
#endif
void mainCRTStartup(void){
 const WCHAR*args=GetCommandLineW();
 char observed[512];unsigned observed_n=0;
 while(args[observed_n]&&observed_n<sizeof(observed)-2){observed[observed_n]=(args[observed_n]<128)?(char)args[observed_n]:'?';observed_n++;}
 observed[observed_n++]='\n';SAY("AGEPAD_CHILD: COMMAND_LINE=");emit(observed,observed_n);
 for(unsigned i=0;args[i];i++)if(args[i]=='-'&&args[i+1]=='-'&&args[i+2]=='c'){
  if(process_value!=0x13579bdf)ExitProcess(71);
  process_value=0x2468ace0;
#ifdef AGEPAD_CHILD_CRT
  if(_crt_atexit(child_cleanup))ExitProcess(75);
  exit(73);
#else
  ExitProcess(73);
#endif
 }
 SAY("AGEPAD_CHILD: PARENT_BEGIN\n");
#ifdef AGEPAD_CHILD_CRT
 if(!DeleteFileW(L"C:\\agepad-crt-callback.txt")&&GetLastError()!=ERROR_FILE_NOT_FOUND)ExitProcess(56);
#endif
 static WCHAR exe[1024],command[1100];DWORD n=GetModuleFileNameW(0,exe,1024);
 if(!n||n>=1024)ExitProcess(50);
 command[0]='"';for(DWORD i=0;i<n;i++)command[i+1]=exe[i];
 const WCHAR suffix[]=L"\" --child";for(unsigned i=0;i<sizeof(suffix)/sizeof(WCHAR);i++)command[n+1+i]=suffix[i];
 STARTUPINFOW startup={0};startup.cb=sizeof(startup);PROCESS_INFORMATION pi={0};
 DWORD creation_flags=0;
#ifdef AGEPAD_CHILD_HEADLESS
 creation_flags=CREATE_NO_WINDOW;
#endif
 if(!CreateProcessW(exe,command,0,0,FALSE,creation_flags,0,0,&startup,&pi)){SAY("AGEPAD_CHILD: CREATE_FAIL\n");ExitProcess(51);}
 SAY("AGEPAD_CHILD: CREATE_RETURNED_OK\n");
 DWORD wait=WaitForSingleObject(pi.hProcess,30000),code=0;
 if(wait!=WAIT_OBJECT_0){SAY("AGEPAD_CHILD: WAIT_FAIL_OR_TIMEOUT\n");ExitProcess(52);}
 if(!GetExitCodeProcess(pi.hProcess,&code)||code!=73){SAY("AGEPAD_CHILD: EXIT_MISMATCH\n");ExitProcess(53);}
 CloseHandle(pi.hThread);CloseHandle(pi.hProcess);
 if(process_value!=0x13579bdf){SAY("AGEPAD_CHILD: PARENT_STATE_CHANGED\n");ExitProcess(54);}
#ifdef AGEPAD_CHILD_CRT
 HANDLE callback=CreateFileW(L"C:\\agepad-crt-callback.txt",GENERIC_READ,FILE_SHARE_READ,0,OPEN_EXISTING,FILE_ATTRIBUTE_NORMAL,0);
 DWORD value=0,read=0;
 if(callback==INVALID_HANDLE_VALUE||!ReadFile(callback,&value,sizeof(value),&read,0)||read!=sizeof(value)||value!=0x43525431)ExitProcess(55);
 CloseHandle(callback);DeleteFileW(L"C:\\agepad-crt-callback.txt");
 SAY("AGEPAD_CHILD: CRT_CALLBACK_AND_EXIT_PASS\n");
#endif
 SAY("AGEPAD_CHILD: CHILD_EXIT_73_PARENT_UNCHANGED\n");ExitProcess(0);
}
