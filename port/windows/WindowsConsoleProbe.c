/* Exercise Wine's real console-host launch path, not a substituted console. */
#include <windows.h>
static HANDLE report;
static void emit(const char*s,DWORD n){DWORD written;WriteFile(report,s,n,&written,0);}
#define SAY(s) emit(s,sizeof(s)-1)
void mainCRTStartup(void){
 report=CreateFileW(L"C:\\agepad-console-result.txt",GENERIC_WRITE,FILE_SHARE_READ,0,CREATE_ALWAYS,FILE_ATTRIBUTE_NORMAL,0);
 if(report==INVALID_HANDLE_VALUE)ExitProcess(80);
 SAY("AGEPAD_CONSOLE: BEGIN\n");
 /* Parent starts with an inherited Wine console; request a fresh host. */
 if(!FreeConsole()){SAY("AGEPAD_CONSOLE: FREE_FAIL\n");ExitProcess(81);}
 if(!AllocConsole()){SAY("AGEPAD_CONSOLE: ALLOC_FAIL\n");ExitProcess(82);}
 DWORD mode=0,written=0;HANDLE output=GetStdHandle(STD_OUTPUT_HANDLE);
 if(!GetConsoleMode(output,&mode)){SAY("AGEPAD_CONSOLE: MODE_FAIL\n");ExitProcess(83);}
 const WCHAR message[]=L"AgePad real Windows console\r\n";
 DWORD length=sizeof(message)/sizeof(WCHAR)-1;
 if(!WriteConsoleW(output,message,length,&written,0)||written!=length){SAY("AGEPAD_CONSOLE: WRITE_FAIL\n");ExitProcess(84);}
 if(!FreeConsole()){SAY("AGEPAD_CONSOLE: DETACH_FAIL\n");ExitProcess(85);}
 SAY("AGEPAD_CONSOLE: ALLOC_MODE_WRITE_DETACH_PASS\n");CloseHandle(report);ExitProcess(0);
}
