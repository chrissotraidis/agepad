#include <windows.h>
/* Each thread owns its code page. No concurrent writer/executor on one page. */
static HANDLE go, ready[4];
static DWORD WINAPI worker(void *arg) {
 unsigned id=(unsigned)(ULONG_PTR)arg;
 unsigned char *code=VirtualAlloc(0,4096,MEM_COMMIT|MEM_RESERVE,PAGE_READWRITE);
 if(!code)return 10;
 if(!SetEvent(ready[id])||WaitForSingleObject(go,30000)!=WAIT_OBJECT_0)return 11;
 for(unsigned round=0;round<64;round++) {
  DWORD old; unsigned expected=0x12340000+id*256+round;
  if(round&&!VirtualProtect(code,4096,PAGE_READWRITE,&old))return 12;
  code[0]=0xb8; /* mov eax, imm32; ret */
  for(unsigned j=0;j<4;j++)code[j+1]=(unsigned char)(expected>>(j*8));
  code[5]=0xc3;
  if(!VirtualProtect(code,4096,PAGE_EXECUTE_READ,&old))return 13;
  if(!FlushInstructionCache(GetCurrentProcess(),code,6))return 14;
  if(((unsigned(*)(void))code)()!=expected)return 15;
 }
 return VirtualFree(code,0,MEM_RELEASE)?0:16;
}
static void say(const char *s,DWORD n){DWORD written;WriteFile(GetStdHandle(STD_OUTPUT_HANDLE),s,n,&written,0);}
#define SAY(s) say(s,sizeof(s)-1)
void mainCRTStartup(void) {
 HANDLE threads[4];
 SAY("AGEPAD_CONCURRENT_CODE: BEGIN\n");
 go=CreateEventW(0,TRUE,FALSE,0);if(!go)ExitProcess(20);
 for(unsigned i=0;i<4;i++) {
  ready[i]=CreateEventW(0,TRUE,FALSE,0);if(!ready[i])ExitProcess(21);
  threads[i]=CreateThread(0,0,worker,(void*)(ULONG_PTR)i,0,0);if(!threads[i])ExitProcess(22);
 }
 if(WaitForMultipleObjects(4,ready,TRUE,30000)!=WAIT_OBJECT_0||!SetEvent(go))ExitProcess(23);
 if(WaitForMultipleObjects(4,threads,TRUE,120000)!=WAIT_OBJECT_0)ExitProcess(24);
 for(unsigned i=0;i<4;i++) {
  DWORD result;
  if(!GetExitCodeThread(threads[i],&result)||result){SAY("AGEPAD_CONCURRENT_CODE: WORKER_FAIL\n");ExitProcess(25);}
  CloseHandle(threads[i]);CloseHandle(ready[i]);
 }
 CloseHandle(go);
 SAY("AGEPAD_CONCURRENT_CODE: FOUR_THREADS_256_CODE_REVISIONS_PASS\n");ExitProcess(0);
}
