#ifndef DE_BC_DECODE_H
#define DE_BC_DECODE_H
#include <stdbool.h>
#include <stddef.h>
typedef enum {
    DEBC1, DEBC2, DEBC3, DEBC4U, DEBC4S, DEBC5U, DEBC5S,
    DEBC6U, DEBC6S, DEBC7
} DEBCFormat;
// CPU reference/staging decoder. Output is RGBA float32, with missing channels
// zero and missing alpha one. Color values remain in the source transfer space:
// callers must preserve sRGB texture sampling semantics separately.
// Strides and sizes are bytes. Edge blocks are cropped. Inputs may be unaligned.
// Buffers must not overlap. Invalid bounds cause no destination writes.
bool DEDecodeBCFloat(DEBCFormat format, const void *source, size_t sourceBytes,
                     size_t sourceStride, void *destination, size_t destinationBytes,
                     size_t destinationStride, size_t width, size_t height);
#endif
