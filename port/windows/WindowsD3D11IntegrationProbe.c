/* Actual x64 D3D11 -> DXMT -> Metal draw/readback, not a native Metal substitute. */
#define COBJMACROS
#include <windows.h>
#include <d3d11.h>
#include <stdint.h>
#include "graphics-fixtures.h"
void *memset(void *p, int v, size_t n) { volatile unsigned char *b=p; for(size_t i=0;i<n;++i)b[i]=(unsigned char)v; return p; }
void *memcpy(void *p, const void *q, size_t n) { volatile unsigned char *b=p; const volatile unsigned char *a=q; for(size_t i=0;i<n;++i)b[i]=a[i]; return p; }
static void emit(const char *s, DWORD n) { DWORD w; WriteFile(GetStdHandle(STD_OUTPUT_HANDLE),s,n,&w,0); }
#define SAY(s) emit(s,sizeof(s)-1)
static void hex(DWORD value) { char b[11]="0x00000000\n"; for(unsigned i=0;i<8;++i)b[9-i]="0123456789abcdef"[(value>>(i*4))&15]; emit(b,11); }
static void check(HRESULT h, DWORD code) { if(FAILED(h)) { SAY("AGEPAD_D3D11: HRESULT_FAIL ");hex(h);ExitProcess(code); } }
typedef HRESULT (WINAPI *CreateDeviceFn)(IDXGIAdapter*,D3D_DRIVER_TYPE,HMODULE,UINT,const D3D_FEATURE_LEVEL*,UINT,UINT,ID3D11Device**,D3D_FEATURE_LEVEL*,ID3D11DeviceContext**);
void mainCRTStartup(void) {
    SAY("AGEPAD_D3D11: BEGIN v1\n");
    HMODULE lib=LoadLibraryW(L"d3d11.dll");
    if(!lib) { SAY("AGEPAD_D3D11: LOAD_FAIL ");hex(GetLastError());ExitProcess(20); }
    CreateDeviceFn create=(CreateDeviceFn)GetProcAddress(lib,"D3D11CreateDevice");
    if(!create)ExitProcess(21);
    SAY("AGEPAD_D3D11: DLL_LOADED\n");
    ID3D11Device *device=0; ID3D11DeviceContext *context=0;
    D3D_FEATURE_LEVEL requested=D3D_FEATURE_LEVEL_11_0, actual;
    check(create(0,D3D_DRIVER_TYPE_HARDWARE,0,0,&requested,1,D3D11_SDK_VERSION,&device,&actual,&context),22);
    SAY("AGEPAD_D3D11: DEVICE_CREATED\n");
    D3D11_TEXTURE2D_DESC desc={0};
    desc.Width=64;desc.Height=64;desc.MipLevels=1;desc.ArraySize=1;desc.Format=DXGI_FORMAT_R8G8B8A8_UNORM;desc.SampleDesc.Count=1;desc.BindFlags=D3D11_BIND_RENDER_TARGET;
    ID3D11Texture2D *target=0,*staging=0; ID3D11RenderTargetView *rtv=0;
    check(ID3D11Device_CreateTexture2D(device,&desc,0,&target),23);
    check(ID3D11Device_CreateRenderTargetView(device,(ID3D11Resource*)target,0,&rtv),24);
    desc.BindFlags=0;desc.Usage=D3D11_USAGE_STAGING;desc.CPUAccessFlags=D3D11_CPU_ACCESS_READ;
    check(ID3D11Device_CreateTexture2D(device,&desc,0,&staging),25);
    const float blue[4]={0,0,1,1};
    ID3D11DeviceContext_ClearRenderTargetView(context,rtv,blue);
    ID3D11DeviceContext_CopyResource(context,(ID3D11Resource*)staging,(ID3D11Resource*)target);
    D3D11_MAPPED_SUBRESOURCE mapped;
    check(ID3D11DeviceContext_Map(context,(ID3D11Resource*)staging,0,D3D11_MAP_READ,0,&mapped),26);
    DWORD clear=*(DWORD*)((char*)mapped.pData+32*mapped.RowPitch+32*4);
    ID3D11DeviceContext_Unmap(context,(ID3D11Resource*)staging,0);
    if(clear!=0xffff0000) { SAY("AGEPAD_D3D11: CLEAR_MISMATCH ");hex(clear);ExitProcess(27); }
    SAY("AGEPAD_D3D11: GPU_CLEAR_READBACK_OK\n");
    ID3D11VertexShader *vs=0;ID3D11PixelShader *ps=0;ID3D11InputLayout *layout=0;
    check(ID3D11Device_CreateVertexShader(device,vertex_fixture,sizeof(vertex_fixture),0,&vs),28);
    check(ID3D11Device_CreatePixelShader(device,pixel_fixture,sizeof(pixel_fixture),0,&ps),29);
    D3D11_INPUT_ELEMENT_DESC element={"POSITION",0,DXGI_FORMAT_R32G32B32_FLOAT,0,0,D3D11_INPUT_PER_VERTEX_DATA,0};
#ifndef AGEPAD_PROCEDURAL
    check(ID3D11Device_CreateInputLayout(device,&element,1,vertex_fixture,sizeof(vertex_fixture),&layout),30);
#endif
    const float vertices[12]={-1,-1,0,-1,1,0,1,-1,0,1,1,0};
    D3D11_BUFFER_DESC bd={0};bd.ByteWidth=sizeof(vertices);bd.Usage=D3D11_USAGE_IMMUTABLE;bd.BindFlags=D3D11_BIND_VERTEX_BUFFER;
    D3D11_SUBRESOURCE_DATA data={vertices,0,0};ID3D11Buffer *vb=0;
    check(ID3D11Device_CreateBuffer(device,&bd,&data,&vb),31);
    D3D11_RASTERIZER_DESC rd={0};rd.FillMode=D3D11_FILL_SOLID;rd.CullMode=D3D11_CULL_NONE;rd.DepthClipEnable=TRUE;
    ID3D11RasterizerState *rs=0;check(ID3D11Device_CreateRasterizerState(device,&rd,&rs),32);
    D3D11_VIEWPORT vp={0,0,64,64,0,1};UINT stride=12,offset=0;
    ID3D11DeviceContext_RSSetState(context,rs);ID3D11DeviceContext_RSSetViewports(context,1,&vp);
    ID3D11DeviceContext_OMSetRenderTargets(context,1,&rtv,0);
    ID3D11DeviceContext_IASetInputLayout(context,layout);ID3D11DeviceContext_IASetPrimitiveTopology(context,D3D11_PRIMITIVE_TOPOLOGY_TRIANGLESTRIP);
    ID3D11DeviceContext_IASetVertexBuffers(context,0,1,&vb,&stride,&offset);
    ID3D11DeviceContext_VSSetShader(context,vs,0,0);ID3D11DeviceContext_PSSetShader(context,ps,0,0);
#ifdef AGEPAD_SAMPLED_TEXTURE
    /* A single asymmetric texel isolates upload/binding/sample from UV math. */
    DWORD texel=0xff332211;
    ID3D11Texture2D *sample_texture=0;ID3D11ShaderResourceView *srv=0;ID3D11SamplerState *sampler=0;
    D3D11_TEXTURE2D_DESC td={0};td.Width=1;td.Height=1;td.MipLevels=1;td.ArraySize=1;
    td.Format=DXGI_FORMAT_R8G8B8A8_UNORM;td.SampleDesc.Count=1;td.BindFlags=D3D11_BIND_SHADER_RESOURCE;
    D3D11_SUBRESOURCE_DATA initial={&texel,4,4};
    check(ID3D11Device_CreateTexture2D(device,&td,&initial,&sample_texture),36);
    D3D11_TEXTURE2D_DESC read_desc=td;read_desc.BindFlags=0;
    read_desc.Usage=D3D11_USAGE_STAGING;read_desc.CPUAccessFlags=D3D11_CPU_ACCESS_READ;
    ID3D11Texture2D *upload_readback=0;
    check(ID3D11Device_CreateTexture2D(device,&read_desc,0,&upload_readback),41);
    ID3D11DeviceContext_CopyResource(context,(ID3D11Resource*)upload_readback,(ID3D11Resource*)sample_texture);
    check(ID3D11DeviceContext_Map(context,(ID3D11Resource*)upload_readback,0,D3D11_MAP_READ,0,&mapped),42);
    DWORD uploaded=*(DWORD*)mapped.pData;
    ID3D11DeviceContext_Unmap(context,(ID3D11Resource*)upload_readback,0);
    ID3D11Texture2D_Release(upload_readback);
    SAY("AGEPAD_D3D11: TEXTURE_UPLOAD_PIXEL ");hex(uploaded);
    if(uploaded!=texel) { SAY("AGEPAD_D3D11: TEXTURE_UPLOAD_MISMATCH\n");ExitProcess(43); }
    SAY("AGEPAD_D3D11: TEXTURE_UPLOAD_READBACK_OK\n");
    check(ID3D11Device_CreateShaderResourceView(device,(ID3D11Resource*)sample_texture,0,&srv),37);
    D3D11_SAMPLER_DESC sd={0};sd.Filter=D3D11_FILTER_MIN_MAG_MIP_POINT;
    sd.AddressU=sd.AddressV=sd.AddressW=D3D11_TEXTURE_ADDRESS_CLAMP;sd.ComparisonFunc=D3D11_COMPARISON_NEVER;
    check(ID3D11Device_CreateSamplerState(device,&sd,&sampler),38);
    ID3D11DeviceContext_PSSetShaderResources(context,0,1,&srv);
    ID3D11DeviceContext_PSSetSamplers(context,0,1,&sampler);
    DWORD expected=texel;
#else
    DWORD expected=0xff00ffff;
#endif
    SAY("AGEPAD_D3D11: DRAW_SUBMIT\n");
#ifdef AGEPAD_PROCEDURAL
    ID3D11DeviceContext_Draw(context,3,0);
#else
    ID3D11DeviceContext_Draw(context,4,0);
#endif
#ifdef AGEPAD_FRESH_STAGING
    /* Diagnostic variant: isolate reuse/invalidation of the first readback. */
    ID3D11Texture2D *old_staging = staging; staging=0;
    check(ID3D11Device_CreateTexture2D(device,&desc,0,&staging),35);
#endif
    ID3D11DeviceContext_CopyResource(context,(ID3D11Resource*)staging,(ID3D11Resource*)target);
    check(ID3D11DeviceContext_Map(context,(ID3D11Resource*)staging,0,D3D11_MAP_READ,0,&mapped),33);
    BOOL good=TRUE;for(unsigned y=8;y<64;y+=16)for(unsigned x=8;x<64;x+=16)if(*(DWORD*)((char*)mapped.pData+y*mapped.RowPitch+x*4)!=expected)good=FALSE;
    if(!good) { SAY("AGEPAD_D3D11: SAMPLE_PIXELS\n"); for(unsigned y=8;y<64;y+=16)for(unsigned x=8;x<64;x+=16)hex(*(DWORD*)((char*)mapped.pData+y*mapped.RowPitch+x*4)); }
    ID3D11DeviceContext_Unmap(context,(ID3D11Resource*)staging,0);
    if(!good) { SAY("AGEPAD_D3D11: DRAW_READBACK_MISMATCH\n");ExitProcess(34); }
    SAY("AGEPAD_D3D11: GPU_DRAW_READBACK_OK\n");
#ifdef AGEPAD_SAMPLED_TEXTURE
    SAY("AGEPAD_D3D11: TEXTURE_INITIAL_SAMPLE_OK\n");
    texel=0xffa0b0c0;
    ID3D11DeviceContext_UpdateSubresource(context,(ID3D11Resource*)sample_texture,0,0,&texel,4,4);
    ID3D11DeviceContext_ClearRenderTargetView(context,rtv,blue);
    ID3D11DeviceContext_Draw(context,4,0);
    ID3D11DeviceContext_CopyResource(context,(ID3D11Resource*)staging,(ID3D11Resource*)target);
    check(ID3D11DeviceContext_Map(context,(ID3D11Resource*)staging,0,D3D11_MAP_READ,0,&mapped),39);
    good=TRUE;
    for(unsigned y=8;y<64;y+=16)for(unsigned x=8;x<64;x+=16) {
        DWORD pixel=*(DWORD*)((char*)mapped.pData+y*mapped.RowPitch+x*4);
        if(pixel!=texel) { good=FALSE;hex(pixel); }
    }
    ID3D11DeviceContext_Unmap(context,(ID3D11Resource*)staging,0);
    if(!good) { SAY("AGEPAD_D3D11: TEXTURE_UPDATE_MISMATCH\n");ExitProcess(40); }
    SAY("AGEPAD_D3D11: TEXTURE_UPDATE_SAMPLE_OK\n");
    ID3D11ShaderResourceView_Release(srv);ID3D11SamplerState_Release(sampler);ID3D11Texture2D_Release(sample_texture);
#endif

#ifdef AGEPAD_FRESH_STAGING
    ID3D11Texture2D_Release(old_staging);
#endif
    ID3D11DeviceContext_ClearState(context);ID3D11Buffer_Release(vb);ID3D11RasterizerState_Release(rs);
    if(layout) ID3D11InputLayout_Release(layout);ID3D11VertexShader_Release(vs);ID3D11PixelShader_Release(ps);
    ID3D11RenderTargetView_Release(rtv);ID3D11Texture2D_Release(target);ID3D11Texture2D_Release(staging);
    ID3D11DeviceContext_Release(context);ID3D11Device_Release(device);
    SAY("AGEPAD_D3D11: PASS v1\n");ExitProcess(0);
}
