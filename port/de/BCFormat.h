#pragma once
#import <Metal/Metal.h>
#include "BCDecode.h"
// Logical compressed format -> actual writable and sampled texture formats.
// A mapping is not a declaration of complete Metal BC feature support.
static inline BOOL DEBCFormatInfo(MTLPixelFormat logical, DEBCFormat *decoder,
                                 MTLPixelFormat *storage, MTLPixelFormat *sample) {
 DEBCFormat d;MTLPixelFormat w;BOOL srgb=NO;
 switch(logical) {
  case MTLPixelFormatBC1_RGBA_sRGB:srgb=YES;__attribute__((fallthrough));
  case MTLPixelFormatBC1_RGBA:d=DEBC1;w=MTLPixelFormatRGBA8Unorm;break;
  case MTLPixelFormatBC2_RGBA_sRGB:srgb=YES;__attribute__((fallthrough));
  case MTLPixelFormatBC2_RGBA:d=DEBC2;w=MTLPixelFormatRGBA8Unorm;break;
  case MTLPixelFormatBC3_RGBA_sRGB:srgb=YES;__attribute__((fallthrough));
  case MTLPixelFormatBC3_RGBA:d=DEBC3;w=MTLPixelFormatRGBA8Unorm;break;
  case MTLPixelFormatBC4_RUnorm:d=DEBC4U;w=MTLPixelFormatR16Float;break;
  case MTLPixelFormatBC4_RSnorm:d=DEBC4S;w=MTLPixelFormatR16Float;break;
  case MTLPixelFormatBC5_RGUnorm:d=DEBC5U;w=MTLPixelFormatRG16Float;break;
  case MTLPixelFormatBC5_RGSnorm:d=DEBC5S;w=MTLPixelFormatRG16Float;break;
  case MTLPixelFormatBC6H_RGBUfloat:d=DEBC6U;w=MTLPixelFormatRGBA16Float;break;
  case MTLPixelFormatBC6H_RGBFloat:d=DEBC6S;w=MTLPixelFormatRGBA16Float;break;
  case MTLPixelFormatBC7_RGBAUnorm_sRGB:srgb=YES;__attribute__((fallthrough));
  case MTLPixelFormatBC7_RGBAUnorm:d=DEBC7;w=MTLPixelFormatRGBA8Unorm;break;
  default:return NO;
 }
 if(decoder)*decoder=d;if(storage)*storage=w;if(sample)*sample=srgb?MTLPixelFormatRGBA8Unorm_sRGB:w;
 return YES;
}
