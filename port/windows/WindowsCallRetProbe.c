/* Source-owned translated recursion test; not a gameplay benchmark. */
#include <windows.h>
static volatile LONG corrupt;
__declspec(noinline) static unsigned long long descend(unsigned n) {
 volatile unsigned tag=n ^ 0xa5917bc3u;
 unsigned long long value=n?descend(n-1)+n:0;
 if(tag!=(n ^ 0xa5917bc3u))InterlockedIncrement(&corrupt);
 return value;
}
static void say(const char *s,DWORD n) {DWORD written;WriteFile(GetStdHandle(STD_OUTPUT_HANDLE),s,n,&written,0);}
#define SAY(s) say(s,sizeof(s)-1)
void mainCRTStartup(void) {
 const unsigned depths[]={1024,98304,98304};
 SAY("AGEPAD_CALLRET: BEGIN\n");
 for(unsigned i=0;i<3;i++) {
  unsigned n=depths[i];
  unsigned long long expected=(unsigned long long)n*(n+1)/2;
  if(descend(n)!=expected || corrupt) {SAY("AGEPAD_CALLRET: FAIL\n");ExitProcess(41);}
  SAY("AGEPAD_CALLRET: DEPTH_CHECK_OK\n");
 }
 SAY("AGEPAD_CALLRET: PASS\n");ExitProcess(0);
}
