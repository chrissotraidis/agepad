/* Source-owned x64 HTTPS diagnostic. No credentials or certificate bypass. */
#include <windows.h>
#include <winhttp.h>
#include <wincrypt.h>
static void say(const char *s,DWORD n) { DWORD w;WriteFile(GetStdHandle(STD_OUTPUT_HANDLE),s,n,&w,0); }
#define SAY(s) say(s,sizeof(s)-1)
static void hex(DWORD v) { char b[]="0x00000000\n";for(unsigned i=0;i<8;i++)b[9-i]="0123456789abcdef"[(v>>(4*i))&15];say(b,11); }
static void require(BOOL ok,DWORD code) { if(!ok){SAY("AGEPAD_HTTPS: ERROR ");hex(GetLastError());ExitProcess(code);} }
#ifdef AGEPAD_CHECK_REVOCATION
#define DIRECTORY_PATH L"/ISteamDirectory/GetCMListForConnect/v0001/?cellid=0&qoslevel=3"
#else
#define DIRECTORY_PATH L"/ISteamDirectory/GetCMListForConnect/v1/?cellid=0&qoslevel=3"
#endif
void mainCRTStartup(void) {
 DWORD start=GetTickCount();
 SAY("AGEPAD_HTTPS: BEGIN\n");
 HINTERNET session=WinHttpOpen(L"AgePad diagnostic/1",WINHTTP_ACCESS_TYPE_DEFAULT_PROXY,0,0,0);
 require(session!=0,20);
 require(WinHttpSetTimeouts(session,10000,10000,10000,10000),21);
#ifdef AGEPAD_AUTOPROXY
 WINHTTP_CURRENT_USER_IE_PROXY_CONFIG ie={0};
 SAY("AGEPAD_HTTPS: IE_PROXY_BEGIN\n");
 BOOL ie_ok=WinHttpGetIEProxyConfigForCurrentUser(&ie);
 SAY("AGEPAD_HTTPS: IE_PROXY_RESULT ");hex(ie_ok?0:GetLastError());
 if(ie.lpszAutoConfigUrl)GlobalFree(ie.lpszAutoConfigUrl);
 if(ie.lpszProxy)GlobalFree(ie.lpszProxy);
 if(ie.lpszProxyBypass)GlobalFree(ie.lpszProxyBypass);
 WINHTTP_AUTOPROXY_OPTIONS options={0};WINHTTP_PROXY_INFO proxy={0};
 options.dwFlags=WINHTTP_AUTOPROXY_AUTO_DETECT;
 options.dwAutoDetectFlags=WINHTTP_AUTO_DETECT_TYPE_DHCP|WINHTTP_AUTO_DETECT_TYPE_DNS_A;
 options.fAutoLogonIfChallenged=FALSE;
 DWORD proxy_start=GetTickCount();
 SAY("AGEPAD_HTTPS: AUTOPROXY_BEGIN\n");
 BOOL proxy_ok=WinHttpGetProxyForUrl(session,L"https://api.steampowered.com" DIRECTORY_PATH,&options,&proxy);
 DWORD proxy_error=proxy_ok?0:GetLastError();
 SAY("AGEPAD_HTTPS: AUTOPROXY_RESULT ");hex(proxy_error);
 SAY("AGEPAD_HTTPS: AUTOPROXY_ELAPSED_MS ");hex(GetTickCount()-proxy_start);
 if(proxy_ok)require(WinHttpSetOption(session,WINHTTP_OPTION_PROXY,&proxy,sizeof(proxy)),32);
 if(proxy.lpszProxy)GlobalFree(proxy.lpszProxy);
 if(proxy.lpszProxyBypass)GlobalFree(proxy.lpszProxyBypass);
 /* No PAC discovered is a normal direct-network result; other failures
  * remain failures. This is a diagnostic policy, not Steam's implementation. */
 if(!proxy_ok && proxy_error!=ERROR_WINHTTP_AUTODETECTION_FAILED)ExitProcess(33);
#endif
 HINTERNET connection=WinHttpConnect(session,L"api.steampowered.com",INTERNET_DEFAULT_HTTPS_PORT,0);
 require(connection!=0,22);
 HINTERNET request=WinHttpOpenRequest(connection,L"GET",DIRECTORY_PATH,0,0,WINHTTP_DEFAULT_ACCEPT_TYPES,WINHTTP_FLAG_SECURE);
 require(request!=0,23);
#ifdef AGEPAD_CHECK_REVOCATION
 DWORD feature=WINHTTP_ENABLE_SSL_REVOCATION;
 require(WinHttpSetOption(request,WINHTTP_OPTION_ENABLE_FEATURE,&feature,sizeof(feature)),31);
 SAY("AGEPAD_HTTPS: REVOCATION_ENABLED\n");
#endif
 SAY("AGEPAD_HTTPS: SEND\n");
 require(WinHttpSendRequest(request,0,0,0,0,0,0),24);SAY("AGEPAD_HTTPS: RECEIVE\n");
 require(WinHttpReceiveResponse(request,0),25);
 DWORD status=0,size=sizeof(status);
 require(WinHttpQueryHeaders(request,WINHTTP_QUERY_STATUS_CODE|WINHTTP_QUERY_FLAG_NUMBER,0,&status,&size,0),26);
 SAY("AGEPAD_HTTPS: HTTP_STATUS ");hex(status);
 if(status!=200)ExitProcess(27);
#ifdef AGEPAD_CHAIN
 PCCERT_CONTEXT cert=0;DWORD cert_size=sizeof(cert);
 require(WinHttpQueryOption(request,WINHTTP_OPTION_SERVER_CERT_CONTEXT,&cert,&cert_size),34);
 DWORD chain_errors=0;
 for(unsigned pass=0;pass<2;pass++) {
  CERT_CHAIN_PARA para={0};para.cbSize=sizeof(para);
  PCCERT_CHAIN_CONTEXT chain=0;DWORD flags=pass?0x48000001:0;
  SAY("AGEPAD_HTTPS: CHAIN_FLAGS ");hex(flags);
  require(CertGetCertificateChain(0,cert,0,cert->hCertStore,&para,flags,0,&chain),35);
  SAY("AGEPAD_HTTPS: CHAIN_ERROR ");hex(chain->TrustStatus.dwErrorStatus);
  chain_errors|=chain->TrustStatus.dwErrorStatus;
  for(DWORD ci=0;ci<chain->cChain;ci++) {
   PCERT_SIMPLE_CHAIN simple=chain->rgpChain[ci];
   for(DWORD ei=0;ei<simple->cElement;ei++) {
    PCCERT_CONTEXT element=simple->rgpElement[ei]->pCertContext;
    char name[256];DWORD count=CertGetNameStringA(element,CERT_NAME_SIMPLE_DISPLAY_TYPE,0,0,name,sizeof(name));
    SAY("AGEPAD_HTTPS: CHAIN_SUBJECT ");if(count>1&&count<=sizeof(name))say(name,count-1);SAY("\n");
    SAY("AGEPAD_HTTPS: ELEMENT_ERROR ");hex(simple->rgpElement[ei]->TrustStatus.dwErrorStatus);
   }
  }
  CertFreeCertificateChain(chain);
 }
 CertFreeCertificateContext(cert);
 if(chain_errors)ExitProcess(36);
#endif

 static char buffer[4096];DWORD read=0,total=0;
 do {require(WinHttpReadData(request,buffer,sizeof(buffer),&read),28);total+=read;if(total>1048576)ExitProcess(29);}while(read);
 SAY("AGEPAD_HTTPS: BODY_BYTES ");hex(total);if(!total)ExitProcess(30);
 WinHttpCloseHandle(request);WinHttpCloseHandle(connection);WinHttpCloseHandle(session);
 SAY("AGEPAD_HTTPS: ELAPSED_MS ");hex(GetTickCount()-start);
 SAY("AGEPAD_HTTPS: PASS\n");ExitProcess(0);
}
