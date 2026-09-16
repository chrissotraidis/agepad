/* Source-owned Windows probe: census the constrained FEX band during thread churn.
 * VirtualQuery describes guest-visible mappings, not resident device memory. */
#include <windows.h>
#include <stdint.h>
static volatile LONG entered;
static void say(const char *s) {DWORD n=0,w;while(s[n])n++;WriteFile(GetStdHandle(STD_OUTPUT_HANDLE),s,n,&w,0);}
static void number(uint64_t n) {char b[32];unsigned i=sizeof(b)-1;b[i]=0;do{b[--i]=(char)('0'+n%10);n/=10;}while(n);say(b+i);}
static void fail(UINT code) {say("AGEPAD_THREAD_CHURN: FAIL code=");number(code);say("\n");ExitProcess(code);}
static DWORD WINAPI worker(void *unused) {(void)unused;InterlockedIncrement(&entered);return 73;}
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
 say("AGEPAD_THREAD_CHURN: CENSUS completed=");number(completed);
 say(" reserve=");number(reserved);say(" commit=");number(committed);
 say(" free=");number(free_bytes);say(" largest_free=");number(largest_free);
 say(" regions=");number(regions);say("\n");
}
void mainCRTStartup(void) {
 say("AGEPAD_THREAD_CHURN: BEGIN normal-thread-exits band=16GiB\n");census(0);
 for(unsigned i=1;i<=64;i++) {
  DWORD code=0;HANDLE h=CreateThread(0,0,worker,0,0,0);
  if(!h)fail(66);if(WaitForSingleObject(h,15000)!=WAIT_OBJECT_0)fail(67);
  if(!GetExitCodeThread(h,&code)||code!=73||entered!=(LONG)i)fail(68);
  if(!CloseHandle(h))fail(69);
  if(!(i%8))census(i);
 }
 say("AGEPAD_THREAD_CHURN: PASS 64 worker exits; census is measurement, not memory plateau acceptance\n");ExitProcess(0);
}
