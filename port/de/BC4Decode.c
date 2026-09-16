#include "BC4Decode.h"
#include <stdint.h>
#include <string.h>
#define BCDEC_STATIC
#define BCDEC_BC4BC5_PRECISE
#define BCDEC_IMPLEMENTATION
#include "third_party/bcdec/bcdec.h"
bool DEDecodeBC4R8(const void *source,size_t sourceBytes,size_t sourceStride,
                  void *destination,size_t destinationBytes,size_t destinationStride,
                  size_t width,size_t height) {
    if (!source || !destination || !width || !height || width>SIZE_MAX-3 || height>SIZE_MAX-3) return false;
    size_t columns=(width+3)/4,rows=(height+3)/4;
    if (columns>SIZE_MAX/8 || sourceStride<columns*8 || destinationStride<width) return false;
    if (rows-1>(SIZE_MAX-columns*8)/sourceStride || height-1>(SIZE_MAX-width)/destinationStride) return false;
    if (sourceBytes<(rows-1)*sourceStride+columns*8 || destinationBytes<(height-1)*destinationStride+width) return false;
    for (size_t by=0;by<rows;by++) for(size_t bx=0;bx<columns;bx++) {
        // bcdec loads a uint64_t; copy into aligned storage before decoding.
        uint64_t block;uint8_t pixels[16];
        memcpy(&block,(const uint8_t *)source+by*sourceStride+bx*8,8);
        bcdec_bc4(&block,pixels,4,0);
        size_t count=width-bx*4;if(count>4)count=4;
        for(size_t y=0;y<4 && by*4+y<height;y++)
            memcpy((uint8_t *)destination+(by*4+y)*destinationStride+bx*4,pixels+y*4,count);
    }
    return true;
}
