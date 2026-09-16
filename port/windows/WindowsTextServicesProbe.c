#define COBJMACROS
#include <windows.h>
#include <objbase.h>
#include <msctf.h>
static void say(const char*s,DWORD n){DWORD w;WriteFile(GetStdHandle(STD_OUTPUT_HANDLE),s,n,&w,0);}
#define SAY(s) say(s,sizeof(s)-1)
static void check(HRESULT hr,DWORD code){if(FAILED(hr)){char message[]="AGEPAD_TEXT_SERVICES: HRESULT=00000000\n";const char digits[]="0123456789abcdef";for(unsigned i=0;i<8;i++)message[sizeof("AGEPAD_TEXT_SERVICES: HRESULT=")-1+i]=digits[((DWORD)hr>>(28-i*4))&15];say(message,sizeof(message)-1);ExitProcess(code);}}
void mainCRTStartup(void){
 SAY("AGEPAD_TEXT_SERVICES: BEGIN\n");
 check(CoInitializeEx(0,COINIT_APARTMENTTHREADED),10);
 ITfInputProcessorProfiles *profiles=0;
 check(CoCreateInstance(&CLSID_TF_InputProcessorProfiles,0,CLSCTX_INPROC_SERVER,&IID_ITfInputProcessorProfiles,(void**)&profiles),11);
 SAY("AGEPAD_TEXT_SERVICES: INPUT_PROFILES_CREATED\n");
 LANGID language=0;check(ITfInputProcessorProfiles_GetCurrentLanguage(profiles,&language),12);
 if(!language)ExitProcess(13);
 SAY("AGEPAD_TEXT_SERVICES: CURRENT_LANGUAGE_OK\n");
 ITfInputProcessorProfiles_Release(profiles);CoUninitialize();
 SAY("AGEPAD_TEXT_SERVICES: PASS\n");ExitProcess(0);
}
