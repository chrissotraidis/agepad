// BC1–BC5 upload decoder. Color expansion follows the MIT bcdec implementation;
// its retained copyright and license are in third_party/bcdec/bcdec.h.
// Formats use DEBCFormat values 0..6. Caller validates buffer/texture bounds.
#include <metal_stdlib>
using namespace metal;
struct BasicParams { uint stride,width,height,x,y,format; };
inline uint basic_u16(device const uchar *p) { return uint(p[0])|(uint(p[1])<<8); }
inline ulong basic_u64(device const uchar *p) { ulong v=0;for(uint i=0;i<8;i++)v|=ulong(p[i])<<(8*i);return v; }
inline float4 basic_color(device const uchar *p,uint pixel,bool opaque) {
 uint a=basic_u16(p),b=basic_u16(p+2);
 uint3 a3=uint3(a>>11,(a>>5)&63,a&31),b3=uint3(b>>11,(b>>5)&63,b&31);
 uint index=uint((basic_u64(p)>>32)>>(2*pixel))&3;
 uint3 q;
 if(index<2) {uint3 v=index?b3:a3;q=(v*uint3(527,259,527)+uint3(23,33,23))>>6;}
 else if(a>b||opaque) {uint3 v=index==2?2*a3+b3:a3+2*b3;q=(v*uint3(351,2763,351)+uint3(61,1039,61))>>uint3(7,11,7);}
 else if(index==2)q=((a3+b3)*uint3(1053,4145,1053)+uint3(125,1019,125))>>uint3(8,11,8);
 else return float4(0);
 return float4(float3(q)/255.0f,1);
}
inline float basic_channel(device const uchar *p,uint pixel,bool signedValue,bool integerAlpha) {
 float a=signedValue?max(float(as_type<char>(p[0]))/127.0f,-1.0f):float(p[0])/255.0f;
 float b=signedValue?max(float(as_type<char>(p[1]))/127.0f,-1.0f):float(p[1])/255.0f;
 uint index=uint(basic_u64(p)>>(16+3*pixel))&7;
 if(index==0)return a;if(index==1)return b;
 if(integerAlpha) {
  uint aa=p[0],bb=p[1],v;
  if(aa>bb)v=((8-index)*aa+(index-1)*bb)/7;
  else if(index<6)v=((6-index)*aa+(index-1)*bb)/5;
  else v=index==6?0:255;
  return float(v)/255.0f;
 }
 if(a>b)return ((8-index)*a+(index-1)*b)/7.0f;
 if(index<6)return ((6-index)*a+(index-1)*b)/5.0f;
 return index==6?(signedValue?-1.0f:0.0f):1.0f;
}
kernel void decode_bc_basic(device const uchar *source[[buffer(0)]],constant BasicParams &p[[buffer(1)]],texture2d<float,access::write> target[[texture(0)]],uint2 block[[thread_position_in_grid]]) {
 uint2 base=block*4;if(base.x>=p.width||base.y>=p.height||p.format>6)return;
 uint bytes=(p.format==0||p.format==3||p.format==4)?8:16;
 device const uchar *b=source+ulong(block.y)*p.stride+ulong(block.x)*bytes;
 for(uint y=0;y<4;y++)for(uint x=0;x<4;x++) {
  uint2 q=base+uint2(x,y);if(q.x>=p.width||q.y>=p.height)continue;
  uint pixel=y*4+x;float4 value;
  if(p.format<=2) {
   value=basic_color(b+(p.format?8:0),pixel,p.format!=0);
   if(p.format==1)value.a=float((basic_u64(b)>>(4*pixel))&15)/15.0f;
   if(p.format==2)value.a=basic_channel(b,pixel,false,true);
  } else {
   bool sign=p.format==4||p.format==6;
   value=float4(basic_channel(b,pixel,sign,false),0,0,1);
   if(p.format>=5)value.g=basic_channel(b+8,pixel,sign,false);
  }
  target.write(value,q+uint2(p.x,p.y));
 }
}
