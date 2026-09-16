#include <windows.h>
typedef LONG (WINAPI *allocate_fn)(HANDLE,PVOID*,ULONG_PTR,PSIZE_T,ULONG,ULONG);
static void say(const char*s,DWORD n){DWORD w;WriteFile(GetStdHandle(STD_OUTPUT_HANDLE),s,n,&w,0);}
#define SAY(s) say(s,sizeof(s)-1)
static void hex(ULONG_PTR n){char b[19]="0x0000000000000000\n";for(int i=0;i<16;i++)b[17-i]="0123456789abcdef"[(n>>(i*4))&15];say(b,19);}
void mainCRTStartup(void){
 allocate_fn alloc=(allocate_fn)GetProcAddress(GetModuleHandleW(L"ntdll.dll"),"NtAllocateVirtualMemory");
 if(!alloc)ExitProcess(10);
 PVOID base=0;SIZE_T size=0x6000;
 LONG status=alloc(GetCurrentProcess(),&base,0x7fffffff,&size,MEM_COMMIT|MEM_RESERVE,PAGE_READWRITE);
 SAY("AGEPAD_LOW_ADDRESS: STATUS ");hex((ULONG)status);
 if(status){ExitProcess(11);}
 SAY("AGEPAD_LOW_ADDRESS: BASE ");hex((ULONG_PTR)base);
 if(!base||(ULONG_PTR)base>=0x80000000ull||size>0x80000000ull-(ULONG_PTR)base)ExitProcess(12);
 volatile unsigned char *bytes=base;
 for(SIZE_T i=0;i<size;i++)bytes[i]=(unsigned char)(i^0x5a);
 for(SIZE_T i=0;i<size;i++)if(bytes[i]!=(unsigned char)(i^0x5a))ExitProcess(13);
 if(!VirtualFree(base,0,MEM_RELEASE))ExitProcess(14);
 SAY("AGEPAD_LOW_ADDRESS: BELOW_2GB_READ_WRITE_FREE_PASS\n");ExitProcess(0);
}
