/* Source-owned x64 code loaded only by the parent after child retirement. */
#include <windows.h>
static volatile DWORD attached;
BOOL WINAPI DllMain(HINSTANCE module,DWORD reason,LPVOID reserved) {
 (void)module;(void)reserved;if(reason==DLL_PROCESS_ATTACH)attached=1;return TRUE;
}
__declspec(dllexport) DWORD WINAPI Calculate(DWORD seed) {
 volatile DWORD value=seed;
 for(unsigned i=0;i<64;i++)value=value*1664525u+1013904223u;
 return attached?value:0;
}
