/* Source-owned Windows probe: census the constrained FEX band during thread churn.
 * VirtualQuery describes guest-visible mappings, not resident device memory. */
#include <windows.h>
#include <stdint.h>
#ifndef AGEPAD_WORKER_COUNT
#define AGEPAD_WORKER_COUNT 4
#endif
#if AGEPAD_WORKER_COUNT < 1 || AGEPAD_WORKER_COUNT > 32
#error Unsupported probe worker count
#endif
static volatile LONG entered;
static void say(const char *s) {DWORD n=0,w;while(s[n])n++;WriteFile(GetStdHandle(STD_OUTPUT_HANDLE),s,n,&w,0);}
static void number(uint64_t n) {char b[32];unsigned i=sizeof(b)-1;b[i]=0;do{b[--i]=(char)('0'+n%10);n/=10;}while(n);say(b+i);}
static void fail(UINT code) {say("AGEPAD_PROCESS_CHURN: FAIL code=");number(code);say("\n");ExitProcess(code);}
static HANDLE release_workers;
static DWORD WINAPI worker(void *unused) {
 (void)unused;InterlockedIncrement(&entered);
 return WaitForSingleObject(release_workers,30000)==WAIT_OBJECT_0?73:74;
}
void *memset(void *p,int c,size_t n) {volatile unsigned char *b=p;for(size_t i=0;i<n;i++)b[i]=(unsigned char)c;return p;}

static void census(unsigned completed) {
 const uintptr_t end=0x8000000000ull;uintptr_t pos=0x7c00000000ull;
 uint64_t reserved=0,committed=0,free_bytes=0,regions=0,largest_free=0;
 while(pos<end) {
  MEMORY_BASIC_INFORMATION m;uintptr_t base,next;uint64_t size;
  if(VirtualQuery((void*)pos,&m,sizeof(m))!=sizeof(m))fail(61);
  base=(uintptr_t)m.BaseAddress;
  if(!m.RegionSize || base>pos || m.RegionSize>UINTPTR_MAX-base)fail(62);
  next=base+m.RegionSize;if(next<=pos)fail(63);if(next>end)next=end;size=next-pos;
  if(m.State==MEM_FREE){free_bytes+=size;if(size>largest_free)largest_free=size;}
  else if(m.State==MEM_RESERVE)reserved+=size;
  else if(m.State==MEM_COMMIT)committed+=size;
  else fail(64);
  pos=next;regions++;if(regions>1000000)fail(65);
 }
 say("AGEPAD_PROCESS_CHURN: CENSUS completed=");number(completed);
 say(" reserve=");number(reserved);say(" commit=");number(committed);
 say(" free=");number(free_bytes);say(" largest_free=");number(largest_free);
 say(" regions=");number(regions);say("\n");
}

void mainCRTStartup(void) {
 const WCHAR *args=GetCommandLineW();unsigned mode=0;
 for(unsigned i=0;args[i];i++) {
  if(args[i]=='-' && args[i+1]=='-' && args[i+2]=='j') {mode=1;break;}
  if(args[i]=='-' && args[i+1]=='-' && args[i+2]=='l') {mode=2;break;}
 }
 say("AGEPAD_PROCESS_CHURN: CONFIG workers=");number(AGEPAD_WORKER_COUNT);say("\n");
 if(mode) {
#ifdef AGEPAD_DETACH_PROBE
  HMODULE dll=LoadLibraryW(L"agepad-detach.dll");
  if(!dll)fail(85);
  DWORD (WINAPI *check)(void)=(DWORD (WINAPI *)(void))GetProcAddress(dll,"CheckAttach");
  if(!check || check()!=1)fail(86);
  say("AGEPAD_DETACH: ATTACH_CONFIRMED\n");
  /* Intentionally retained until ExitProcess invokes its detach callbacks. */
#endif
  HANDLE workers[AGEPAD_WORKER_COUNT];release_workers=CreateEventW(0,TRUE,FALSE,0);if(!release_workers)fail(70);
  for(unsigned i=0;i<AGEPAD_WORKER_COUNT;i++) {workers[i]=CreateThread(0,0,worker,0,0,0);if(!workers[i])fail(71);}
  ULONGLONG start=GetTickCount64();
  while(InterlockedCompareExchange(&entered,0,0)!=AGEPAD_WORKER_COUNT) {if(GetTickCount64()-start>15000)fail(72);Sleep(1);}
  say(mode==1?"AGEPAD_PROCESS_CHURN: JOIN_CHILD_READY\n":"AGEPAD_PROCESS_CHURN: LIVE_CHILD_READY\n");
  census(0);
  if(mode==1) {
   if(!SetEvent(release_workers))fail(73);
   for(unsigned i=0;i<AGEPAD_WORKER_COUNT;i++) {DWORD code=0;
    if(WaitForSingleObject(workers[i],15000)!=WAIT_OBJECT_0 || !GetExitCodeThread(workers[i],&code) || code!=73)fail(74);
    CloseHandle(workers[i]);
   }
   CloseHandle(release_workers);say("AGEPAD_PROCESS_CHURN: WORKERS_JOINED\n");census(AGEPAD_WORKER_COUNT);
  }
  say("AGEPAD_PROCESS_CHURN: CHILD_EXIT mode=");number(mode);say("\n");
  ExitProcess(80+mode);
 }
 say("AGEPAD_PROCESS_CHURN: PARENT_BEGIN\n");census(0);
 static WCHAR exe[1024],command[1100];DWORD n=GetModuleFileNameW(0,exe,1024);
 if(!n||n>=1024)fail(75);
 for(unsigned k=1;k<=2;k++) {
  command[0]='"';for(DWORD i=0;i<n;i++)command[i+1]=exe[i];
  const WCHAR *suffix=k==1?L"\" --join":L"\" --live";
  unsigned j=0;do {command[n+1+j]=suffix[j];}while(suffix[j++]);
  STARTUPINFOW startup={0};PROCESS_INFORMATION pi={0};startup.cb=sizeof(startup);
  if(!CreateProcessW(exe,command,0,0,FALSE,0,0,0,&startup,&pi))fail(76);
  DWORD code=0;
  if(WaitForSingleObject(pi.hProcess,30000)!=WAIT_OBJECT_0)fail(77);
  if(!GetExitCodeProcess(pi.hProcess,&code)||code!=80+k)fail(78);
  CloseHandle(pi.hThread);CloseHandle(pi.hProcess);
  say("AGEPAD_PROCESS_CHURN: PARENT_OBSERVED_EXIT mode=");number(k);say("\n");census(k);
#ifdef AGEPAD_LATE_ALIAS_PROBE
  say("AGEPAD_LATE_LOAD: BEGIN mode=");number(k);say("\n");
  const WCHAR *late_name=k==1?L"agepad-late-one.dll":L"agepad-late-two.dll";
  if(GetModuleHandleW(late_name))fail(87);
  HMODULE late=LoadLibraryW(late_name);if(!late)fail(88);
  DWORD (WINAPI *calculate)(DWORD)=(DWORD (WINAPI *)(DWORD))GetProcAddress(late,"Calculate");
  if(!calculate||calculate(7)!=0x8b03e047u)fail(89);
  say("AGEPAD_LATE_LOAD: EXECUTED mode=");number(k);say(" module=");number((uintptr_t)late);say("\n");
  /* Retain until parent shutdown; do not mix unload/reload into this test. */
#endif
 }
 say("AGEPAD_PROCESS_CHURN: PASS process exit statuses; reclamation remains a measured question\n");ExitProcess(0);
}
