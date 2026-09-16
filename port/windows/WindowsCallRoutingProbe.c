/* x64 -> native MSVCRT variadic call and native MSVCRT -> x64 callback. */
#include <windows.h>
static volatile unsigned comparisons;
static int __cdecl compare_ints(const void *a,const void *b) {
 int av=*(const int*)a,bv=*(const int*)b;comparisons++;
 return (av>bv)-(av<bv);
}
static void emit(const char *s,DWORD n){DWORD written;WriteFile(GetStdHandle(STD_OUTPUT_HANDLE),s,n,&written,0);}
#define SAY(s) emit(s,sizeof(s)-1)
void mainCRTStartup(void){
 HMODULE crt=LoadLibraryW(L"msvcrt.dll");
 if(!crt)ExitProcess(60);
 int (__cdecl *format)(char*,size_t,const char*,...)=(void*)GetProcAddress(crt,"_snprintf");
 void (__cdecl *sort)(void*,size_t,size_t,int (__cdecl *)(const void*,const void*))=(void*)GetProcAddress(crt,"qsort");
 if(!format||!sort)ExitProcess(61);
 char buffer[512];
 int n=format(buffer,sizeof(buffer),"%d|%s|%.2f|%d|%s|%.2f",7,"seven",2.5,-9,"nine",-1.25);
 const char expected[]="7|seven|2.50|-9|nine|-1.25";
 if(n!=sizeof(expected)-1)ExitProcess(62);
 for(unsigned i=0;i<sizeof(expected);i++)if(buffer[i]!=expected[i])ExitProcess(63);
 SAY("AGEPAD_CALL_ROUTING: MIXED_VARIADIC_OK\n");
 int values[]={9,-2,7,0,-2,5,1};const int sorted[]={-2,-2,0,1,5,7,9};
 sort(values,7,sizeof(int),compare_ints);
 if(!comparisons)ExitProcess(64);
 for(unsigned i=0;i<7;i++)if(values[i]!=sorted[i])ExitProcess(65);
 SAY("AGEPAD_CALL_ROUTING: NATIVE_TO_X64_CALLBACK_OK\n");
 SAY("AGEPAD_CALL_ROUTING: PASS\n");ExitProcess(0);
}
