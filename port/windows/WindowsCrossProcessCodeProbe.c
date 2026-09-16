#include <windows.h>
void *memset(void *p,int c,size_t n){volatile unsigned char*b=p;for(size_t i=0;i<n;i++)b[i]=(unsigned char)c;return p;}
static void say(const char*s,DWORD n){DWORD w;WriteFile(GetStdHandle(STD_OUTPUT_HANDLE),s,n,&w,0);}
#define SAY(s) say(s,sizeof(s)-1)
static const WCHAR readyName[]=L"AgePadCrossCodeReady",goName[]=L"AgePadCrossCodeGo",fileName[]=L"C:\\agepad-cross-code-address.bin";
void mainCRTStartup(void){
 WCHAR marker[4];
 if(GetEnvironmentVariableW(L"AGEPAD_CROSS_CODE_CHILD",marker,4)){
  unsigned char *code=VirtualAlloc(0,4096,MEM_COMMIT|MEM_RESERVE,PAGE_READWRITE);DWORD old,n;
  if(!code)ExitProcess(10);
  code[0]=0xb8;code[1]=1;code[2]=code[3]=code[4]=0;code[5]=0xc3;
  if(!VirtualProtect(code,4096,PAGE_EXECUTE_READ,&old)||!FlushInstructionCache(GetCurrentProcess(),code,6))ExitProcess(11);
  if(((unsigned(*)(void))code)()!=1)ExitProcess(12);
  HANDLE f=CreateFileW(fileName,GENERIC_WRITE,0,0,CREATE_ALWAYS,FILE_ATTRIBUTE_NORMAL,0);
  ULONG_PTR address=(ULONG_PTR)code;
  if(f==INVALID_HANDLE_VALUE||!WriteFile(f,&address,sizeof(address),&n,0)||n!=sizeof(address))ExitProcess(13);
  CloseHandle(f);
  HANDLE ready=OpenEventW(EVENT_MODIFY_STATE,FALSE,readyName),go=OpenEventW(SYNCHRONIZE,FALSE,goName);
  if(!ready||!go||!SetEvent(ready)||WaitForSingleObject(go,60000)!=WAIT_OBJECT_0)ExitProcess(14);
  /* No API/logging call between resuming and checking translated execution. */
  unsigned observed_byte=((volatile unsigned char*)code)[1];
  unsigned observed_result=((unsigned(*)(void))code)();
  if(observed_byte!=2){SAY("AGEPAD_CROSS_CODE: SOURCE_BYTES_STALE\n");ExitProcess(16);}
  SAY("AGEPAD_CROSS_CODE: SOURCE_BYTES_UPDATED\n");
  if(observed_result!=2){SAY("AGEPAD_CROSS_CODE: STALE_CODE\n");ExitProcess(15);}
  SAY("AGEPAD_CROSS_CODE: CHILD_OBSERVED_NEW_CODE\n");ExitProcess(0);
 }
 SAY("AGEPAD_CROSS_CODE: BEGIN\n");DeleteFileW(fileName);
 HANDLE ready=CreateEventW(0,TRUE,FALSE,readyName),go=CreateEventW(0,TRUE,FALSE,goName);
 if(!ready||!go)ExitProcess(20);
 WCHAR exe[1024];if(!GetModuleFileNameW(0,exe,1024))ExitProcess(21);
 STARTUPINFOW si={0};si.cb=sizeof(si);PROCESS_INFORMATION pi={0};
 if(!SetEnvironmentVariableW(L"AGEPAD_CROSS_CODE_CHILD",L"1"))ExitProcess(22);
 BOOL made=CreateProcessW(exe,0,0,0,FALSE,0,0,0,&si,&pi);
 SetEnvironmentVariableW(L"AGEPAD_CROSS_CODE_CHILD",0);
 if(!made)ExitProcess(23);
 if(WaitForSingleObject(ready,60000)!=WAIT_OBJECT_0)ExitProcess(24);
 HANDLE f=CreateFileW(fileName,GENERIC_READ,FILE_SHARE_READ,0,OPEN_EXISTING,FILE_ATTRIBUTE_NORMAL,0);
 ULONG_PTR address=0;DWORD n,old;
 if(f==INVALID_HANDLE_VALUE||!ReadFile(f,&address,sizeof(address),&n,0)||n!=sizeof(address)||!address)ExitProcess(25);
 CloseHandle(f);DeleteFileW(fileName);
 unsigned char bytes[]={0xb8,2,0,0,0,0xc3};SIZE_T written;
 if(!VirtualProtectEx(pi.hProcess,(void*)address,4096,PAGE_READWRITE,&old)){SAY("AGEPAD_CROSS_CODE: PROTECT_RW_FAIL\n");ExitProcess(26);}
 if(!WriteProcessMemory(pi.hProcess,(void*)address,bytes,sizeof(bytes),&written)||written!=sizeof(bytes)){DWORD error=GetLastError();char message[]="AGEPAD_CROSS_CODE: WRITE_ERROR=00000000\n";const char digits[]="0123456789abcdef";for(unsigned i=0;i<8;i++)message[sizeof("AGEPAD_CROSS_CODE: WRITE_ERROR=")-1+i]=digits[(error>>(28-4*i))&15];say(message,sizeof(message)-1);SAY("AGEPAD_CROSS_CODE: WRITE_FAIL\n");ExitProcess(27);}
 if(!VirtualProtectEx(pi.hProcess,(void*)address,4096,PAGE_EXECUTE_READ,&old)||!FlushInstructionCache(pi.hProcess,(void*)address,sizeof(bytes)))ExitProcess(28);
 if(!SetEvent(go)||WaitForSingleObject(pi.hProcess,60000)!=WAIT_OBJECT_0)ExitProcess(29);
 DWORD result;if(!GetExitCodeProcess(pi.hProcess,&result)||result)ExitProcess(30);
 CloseHandle(pi.hThread);CloseHandle(pi.hProcess);CloseHandle(ready);CloseHandle(go);
 SAY("AGEPAD_CROSS_CODE: REMOTE_CODE_REVISION_PASS\n");ExitProcess(0);
}
