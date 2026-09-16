#include <winsock2.h>
#include <windows.h>
#include <iphlpapi.h>
static void say(const char *s) { DWORD n=0,len=0;while(s[len])len++;WriteFile(GetStdHandle(STD_OUTPUT_HANDLE),s,len,&n,0); }
static void number(ULONG x) { char b[11]; unsigned n=0; do {b[n++]=(char)('0'+x%10);x/=10;}while(x);while(n){char c=b[--n];DWORD w;WriteFile(GetStdHandle(STD_OUTPUT_HANDLE),&c,1,&w,0);} }
void mainCRTStartup(void) {
 ULONG size=0,err,count=0;
 IP_ADAPTER_ADDRESSES *buf,*a;
 say("AGEPAD_ADAPTERS: BEGIN\n");
 err=GetAdaptersAddresses(AF_UNSPEC,0,0,0,&size);
 say("AGEPAD_ADAPTERS: SIZE_STATUS=");number(err);say(" BYTES=");number(size);say("\n");
 if(err!=ERROR_BUFFER_OVERFLOW||!size||size>16*1024*1024)ExitProcess(11);
 buf=HeapAlloc(GetProcessHeap(),HEAP_ZERO_MEMORY,size);if(!buf)ExitProcess(12);
 err=GetAdaptersAddresses(AF_UNSPEC,0,0,buf,&size);
 say("AGEPAD_ADAPTERS: ENUM_STATUS=");number(err);say("\n");
 if(err)ExitProcess(13);
 for(a=buf;a && count<256;a=a->Next) {
  if((ULONG_PTR)a<(ULONG_PTR)buf||(ULONG_PTR)a+sizeof(*a)>(ULONG_PTR)buf+size)ExitProcess(14);
  count++;
 }
 if(a||!count)ExitProcess(15);
 HeapFree(GetProcessHeap(),0,buf);
 say("AGEPAD_ADAPTERS: ENUMERATION_PASS COUNT=");number(count);say("\n");ExitProcess(0);
}
