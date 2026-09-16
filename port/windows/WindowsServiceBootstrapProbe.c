/* Real Wine SCM/RpcSs bootstrap, confined to the diagnostic Wine prefix. */
#include <windows.h>
#include <winsvc.h>
void *memset(void*p,int c,size_t n){volatile unsigned char*b=p;for(size_t i=0;i<n;i++)b[i]=(unsigned char)c;return p;}
static void say(const char*s,DWORD n){DWORD w;WriteFile(GetStdHandle(STD_OUTPUT_HANDLE),s,n,&w,0);}
#define SAY(s) say(s,sizeof(s)-1)
static void fail(DWORD code){SAY("AGEPAD_SCM: FAIL\n");ExitProcess(code);}
void mainCRTStartup(void){
 WCHAR command[]=L"\"C:\\windows\\system32\\services.exe\"";
 STARTUPINFOW startup={0};PROCESS_INFORMATION pi={0};startup.cb=sizeof(startup);
 SAY("AGEPAD_SCM: BEGIN\n");
 if(!CreateProcessW(L"C:\\windows\\system32\\services.exe",command,0,0,FALSE,DETACHED_PROCESS,0,0,&startup,&pi))fail(80);
 CloseHandle(pi.hThread);
 SC_HANDLE scm=0;ULONGLONG deadline=GetTickCount64()+120000;
 do {
  scm=OpenSCManagerW(0,0,SC_MANAGER_CONNECT);
  if(scm)break;
  if(WaitForSingleObject(pi.hProcess,0)==WAIT_OBJECT_0)fail(81);
  Sleep(100);
 } while(GetTickCount64()<deadline);
 if(!scm)fail(82);
 SAY("AGEPAD_SCM: MANAGER_CONNECTED\n");
 SC_HANDLE service=OpenServiceW(scm,L"RpcSs",SERVICE_START|SERVICE_QUERY_STATUS);
 if(!service)fail(83);
 if(!StartServiceW(service,0,0)&&GetLastError()!=ERROR_SERVICE_ALREADY_RUNNING)fail(84);
 SERVICE_STATUS_PROCESS status={0};DWORD bytes=0;deadline=GetTickCount64()+120000;
 do {
  if(!QueryServiceStatusEx(service,SC_STATUS_PROCESS_INFO,(BYTE*)&status,sizeof(status),&bytes))fail(85);
  if(status.dwCurrentState==SERVICE_RUNNING)break;
  if(status.dwCurrentState==SERVICE_STOPPED)fail(86);
  Sleep(100);
 } while(GetTickCount64()<deadline);
 if(status.dwCurrentState!=SERVICE_RUNNING)fail(87);
 SAY("AGEPAD_SCM: RPCSS_RUNNING\n");
 CloseServiceHandle(service);CloseServiceHandle(scm);CloseHandle(pi.hProcess);
 SAY("AGEPAD_SCM: PASS\n");ExitProcess(0);
}
