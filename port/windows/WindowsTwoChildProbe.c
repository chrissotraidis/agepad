#include <windows.h>
volatile DWORD process_value=0x13579bdf;
void *memset(void*p,int c,size_t n){volatile unsigned char*b=p;for(size_t i=0;i<n;i++)b[i]=(unsigned char)c;return p;}
static void emit(const char*s,DWORD n){DWORD w;WriteFile(GetStdHandle(STD_OUTPUT_HANDLE),s,n,&w,0);}
#define SAY(s) emit(s,sizeof(s)-1)
static const WCHAR *ready_names[]={L"AgePadTwoChildReady1",L"AgePadTwoChildReady2"};
static const WCHAR go_name[]=L"AgePadTwoChildGo";
void mainCRTStartup(void){
 const WCHAR*args=GetCommandLineW();unsigned child=0;
 for(unsigned i=0;args[i];i++)if(args[i]=='-'&&args[i+1]=='-'&&args[i+2]=='c'&&args[i+3]=='h'&&args[i+4]=='i'&&args[i+5]=='l'&&args[i+6]=='d'){
  if(args[i+7]=='1')child=1;else if(args[i+7]=='2')child=2;
 }
 if(child){
  if(process_value!=0x13579bdf)ExitProcess(71);
  process_value=0x2468ace0+child;
  HANDLE ready=OpenEventW(EVENT_MODIFY_STATE,FALSE,ready_names[child-1]);
  HANDLE go=OpenEventW(SYNCHRONIZE,FALSE,go_name);
  if(!ready||!go||!SetEvent(ready))ExitProcess(72);
  if(WaitForSingleObject(go,30000)!=WAIT_OBJECT_0)ExitProcess(75);
  CloseHandle(ready);CloseHandle(go);
  if(process_value!=0x2468ace0+child)ExitProcess(76);
  ExitProcess(73+child-1);
 }
 SAY("AGEPAD_TWO_CHILD: PARENT_BEGIN\n");
 HANDLE ready[2],go=CreateEventW(0,TRUE,FALSE,go_name);
 for(unsigned i=0;i<2;i++)ready[i]=CreateEventW(0,TRUE,FALSE,ready_names[i]);
 if(!go||!ready[0]||!ready[1])ExitProcess(50);
 static WCHAR exe[1024],command[1100];DWORD n=GetModuleFileNameW(0,exe,1024);
 if(!n||n>=1024)ExitProcess(51);
 PROCESS_INFORMATION pi[2]={{0}};
 for(unsigned k=0;k<2;k++){
  command[0]='"';for(DWORD i=0;i<n;i++)command[i+1]=exe[i];
  const WCHAR suffix[]=L"\" --child1";for(unsigned i=0;i<sizeof(suffix)/sizeof(WCHAR);i++)command[n+1+i]=suffix[i];
  command[n+10]='1'+k;
  STARTUPINFOW startup={0};startup.cb=sizeof(startup);
  if(!CreateProcessW(exe,command,0,0,FALSE,0,0,0,&startup,&pi[k])){SAY("AGEPAD_TWO_CHILD: CREATE_FAIL\n");ExitProcess(52);}
 }
 if(WaitForMultipleObjects(2,ready,TRUE,30000)!=WAIT_OBJECT_0){SAY("AGEPAD_TWO_CHILD: READY_FAIL\n");ExitProcess(53);}
 SAY("AGEPAD_TWO_CHILD: BOTH_READY\n");
 if(!SetEvent(go))ExitProcess(54);
 for(unsigned k=0;k<2;k++){
  DWORD code=0;
  if(WaitForSingleObject(pi[k].hProcess,30000)!=WAIT_OBJECT_0||!GetExitCodeProcess(pi[k].hProcess,&code)||code!=73+k){SAY("AGEPAD_TWO_CHILD: EXIT_FAIL\n");ExitProcess(55);}
  CloseHandle(pi[k].hThread);CloseHandle(pi[k].hProcess);CloseHandle(ready[k]);
 }
 CloseHandle(go);
 if(process_value!=0x13579bdf)ExitProcess(56);
 SAY("AGEPAD_TWO_CHILD: TWO_EXITS_PARENT_UNCHANGED\n");ExitProcess(0);
}
