/* Windows window + real DXGI presentation diagnostic. No gameplay/FPS claim. */
#define COBJMACROS
#include <windows.h>
#include <d3d11.h>
void *memset(void *p,int v,size_t n){volatile unsigned char*b=p;for(size_t i=0;i<n;i++)b[i]=(unsigned char)v;return p;}
static void say(const char*s,DWORD n){DWORD w;WriteFile(GetStdHandle(STD_OUTPUT_HANDLE),s,n,&w,0);}
#define SAY(s) say(s,sizeof(s)-1)
static void fail(DWORD code,DWORD value){char b[11]="0x00000000\n";for(unsigned i=0;i<8;i++)b[9-i]="0123456789abcdef"[(value>>(i*4))&15];SAY("AGEPAD_PRESENT: FAIL ");say(b,11);ExitProcess(code);}
static LRESULT CALLBACK proc(HWND w,UINT m,WPARAM a,LPARAM b){return DefWindowProcW(w,m,a,b);}
typedef HRESULT(WINAPI*CreateFn)(IDXGIAdapter*,D3D_DRIVER_TYPE,HMODULE,UINT,const D3D_FEATURE_LEVEL*,UINT,UINT,const DXGI_SWAP_CHAIN_DESC*,IDXGISwapChain**,ID3D11Device**,D3D_FEATURE_LEVEL*,ID3D11DeviceContext**);
void mainCRTStartup(void){
 SAY("AGEPAD_PRESENT: BEGIN v1\n");
 WNDCLASSW wc={0};wc.lpfnWndProc=proc;wc.hInstance=GetModuleHandleW(0);wc.lpszClassName=L"AgePadPresentationProbe";
 if(!RegisterClassW(&wc))fail(40,GetLastError());
 SAY("AGEPAD_PRESENT: CLASS_OK\n");
 HWND window=CreateWindowExW(0,wc.lpszClassName,L"AgePad Windows presentation test",WS_OVERLAPPEDWINDOW|WS_VISIBLE,0,0,640,480,0,0,wc.hInstance,0);
 if(!window)fail(41,GetLastError());
 SAY("AGEPAD_PRESENT: WINDOW_OK\n");
 HMODULE lib=LoadLibraryW(L"d3d11.dll");if(!lib)fail(42,GetLastError());
 CreateFn create=(CreateFn)GetProcAddress(lib,"D3D11CreateDeviceAndSwapChain");if(!create)fail(43,GetLastError());
 DXGI_SWAP_CHAIN_DESC desc={0};desc.BufferDesc.Width=640;desc.BufferDesc.Height=480;desc.BufferDesc.Format=DXGI_FORMAT_R8G8B8A8_UNORM;desc.SampleDesc.Count=1;desc.BufferUsage=DXGI_USAGE_RENDER_TARGET_OUTPUT;desc.BufferCount=2;desc.OutputWindow=window;desc.Windowed=TRUE;desc.SwapEffect=DXGI_SWAP_EFFECT_DISCARD;
 IDXGISwapChain*swap=0;ID3D11Device*device=0;ID3D11DeviceContext*context=0;D3D_FEATURE_LEVEL level=D3D_FEATURE_LEVEL_11_0,actual;
 HRESULT hr=create(0,D3D_DRIVER_TYPE_HARDWARE,0,0,&level,1,D3D11_SDK_VERSION,&desc,&swap,&device,&actual,&context);if(FAILED(hr))fail(44,hr);
 SAY("AGEPAD_PRESENT: SWAPCHAIN_OK\n");
 static const GUID texture_iid={0x6f15aaf2,0xd208,0x4e89,{0x9a,0xb4,0x48,0x95,0x35,0xd3,0x4f,0x9c}};
 ID3D11Texture2D*back=0;hr=IDXGISwapChain_GetBuffer(swap,0,&texture_iid,(void**)&back);if(FAILED(hr))fail(45,hr);
 ID3D11RenderTargetView*rtv=0;hr=ID3D11Device_CreateRenderTargetView(device,(ID3D11Resource*)back,0,&rtv);if(FAILED(hr))fail(46,hr);
 for(unsigned frame=0;frame<120;frame++){
  MSG msg;while(PeekMessageW(&msg,0,0,0,PM_REMOVE)){TranslateMessage(&msg);DispatchMessageW(&msg);}
  const float color[4]={(frame%60)/59.0f,0.25f,1.0f-(frame%60)/59.0f,1};
  ID3D11DeviceContext_ClearRenderTargetView(context,rtv,color);
  hr=IDXGISwapChain_Present(swap,1,0);if(hr!=S_OK)fail(47,hr);
 }
 SAY("AGEPAD_PRESENT: PRESENT_120_RETURNED_OK\n");
 Sleep(15000); /* Bounded screenshot window; API success still needs visual evidence. */
 ID3D11RenderTargetView_Release(rtv);ID3D11Texture2D_Release(back);IDXGISwapChain_Release(swap);ID3D11DeviceContext_Release(context);ID3D11Device_Release(device);DestroyWindow(window);
 SAY("AGEPAD_PRESENT: PASS_API v1\n");ExitProcess(0);
}
