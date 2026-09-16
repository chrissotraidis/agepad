#ifndef DE_BC4_DECODE_H
#define DE_BC4_DECODE_H
#include <stddef.h>
#include <stdbool.h>
// Decode BC4 UNORM blocks to R8 UNORM. Strides are bytes; source stride is per
// block row. Nonmultiples of four crop the decoded edge blocks. The caller owns
// nonoverlapping source/destination storage. No writes occur on invalid bounds.
// R8 quantizes interpolated values; this is not a bit-exact float sampler match.
bool DEDecodeBC4R8(const void *source,size_t sourceBytes,size_t sourceStride,
                  void *destination,size_t destinationBytes,size_t destinationStride,
                  size_t width,size_t height);
#endif
