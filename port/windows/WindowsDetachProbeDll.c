/* Source-owned x64 DLL: prove actual translated callbacks during process detach. */
#include <windows.h>
static volatile LONG tls_attached, dll_attached;
static void emit(const char *s,DWORD n){DWORD written;WriteFile(GetStdHandle(STD_OUTPUT_HANDLE),s,n,&written,0);}
#define SAY(s) emit(s,sizeof(s)-1)
static BOOL calculation(void){volatile DWORD v=7;for(unsigned i=0;i<64;i++)v=v*1664525u+1013904223u;return v==0x8b03e047u;}
static void NTAPI tls_callback(void *module,DWORD reason,void *reserved){
 (void)module;(void)reserved;
 if(reason==DLL_PROCESS_ATTACH)tls_attached=1;
 if(reason==DLL_PROCESS_DETACH){
  if(tls_attached&&dll_attached&&calculation())SAY("AGEPAD_DETACH: TLS_DETACH_OK\n");
  else SAY("AGEPAD_DETACH: TLS_DETACH_FAIL\n");
 }
}
__attribute__((section(".tls"))) char tls_data[1]={0};
static DWORD tls_index;
static const PIMAGE_TLS_CALLBACK tls_callbacks[]={tls_callback,0};
__attribute__((used,section(".rdata$T"))) const IMAGE_TLS_DIRECTORY64 _tls_used={
 (ULONGLONG)tls_data,(ULONGLONG)(tls_data+1),(ULONGLONG)&tls_index,(ULONGLONG)tls_callbacks,0,0
};
__declspec(dllexport) DWORD WINAPI CheckAttach(void){return tls_attached&&dll_attached?1:0;}
BOOL WINAPI DllMain(HINSTANCE instance,DWORD reason,LPVOID reserved){
 (void)instance;(void)reserved;
 if(reason==DLL_PROCESS_ATTACH)dll_attached=1;
 if(reason==DLL_PROCESS_DETACH){
  if(tls_attached&&dll_attached&&calculation())SAY("AGEPAD_DETACH: DLL_DETACH_OK\n");
  else SAY("AGEPAD_DETACH: DLL_DETACH_FAIL\n");
 }
 return TRUE;
}
