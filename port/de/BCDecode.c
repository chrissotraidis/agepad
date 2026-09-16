#include "BCDecode.h"
#include <stdint.h>
#include <string.h>
#define BCDEC_STATIC
#define BCDEC_BC4BC5_PRECISE
#define BCDEC_IMPLEMENTATION
#include "third_party/bcdec/bcdec.h"

bool DEDecodeBCFloat(DEBCFormat format, const void *source, size_t sourceBytes,
                     size_t sourceStride, void *destination, size_t destinationBytes,
                     size_t destinationStride, size_t width, size_t height) {
    if ((unsigned)format > DEBC7 || !source || !destination || !width || !height ||
        width > SIZE_MAX / 16 || height > SIZE_MAX - 3) return false;
    size_t blockBytes = (format == DEBC1 || format == DEBC4U || format == DEBC4S) ? 8 : 16;
    size_t columns = (width + 3) / 4, rows = (height + 3) / 4;
    size_t inputRow = columns * blockBytes, outputRow = width * 16;
    if (sourceStride < inputRow || destinationStride < outputRow ||
        rows - 1 > (SIZE_MAX - inputRow) / sourceStride ||
        height - 1 > (SIZE_MAX - outputRow) / destinationStride) return false;
    size_t inputExtent = (rows - 1) * sourceStride + inputRow;
    size_t outputExtent = (height - 1) * destinationStride + outputRow;
    if (inputExtent > sourceBytes || outputExtent > destinationBytes) return false;
    uintptr_t a = (uintptr_t)source, b = (uintptr_t)destination;
    if (inputExtent > UINTPTR_MAX - a || outputExtent > UINTPTR_MAX - b ||
        (a < b + outputExtent && b < a + inputExtent)) return false;
    for (size_t by = 0; by < rows; ++by) for (size_t bx = 0; bx < columns; ++bx) {
        uint64_t block[2] = {0};
        uint8_t rgba[64];
        float components[48] = {0}, pixels[64];
        memcpy(block, (const uint8_t *)source + by * sourceStride + bx * blockBytes, blockBytes);
        unsigned channels = 4;
        switch (format) {
            case DEBC1: bcdec_bc1(block, rgba, 16); break;
            case DEBC2: bcdec_bc2(block, rgba, 16); break;
            case DEBC3: bcdec_bc3(block, rgba, 16); break;
            case DEBC7: bcdec_bc7(block, rgba, 16); break;
            case DEBC4U: case DEBC4S:
                channels = 1; bcdec_bc4_float(block, components, 4, format == DEBC4S); break;
            case DEBC5U: case DEBC5S:
                channels = 2; bcdec_bc5_float(block, components, 8, format == DEBC5S); break;
            case DEBC6U: case DEBC6S:
                channels = 3; bcdec_bc6h_float(block, components, 12, format == DEBC6S); break;
        }
        for (unsigned i = 0; i < 16; ++i) for (unsigned c = 0; c < 4; ++c)
            pixels[i * 4 + c] = channels == 4 ? rgba[i * 4 + c] / 255.0f :
                c < channels ? components[i * channels + c] : c == 3 ? 1.0f : 0.0f;
        size_t count = width - bx * 4;
        if (count > 4) count = 4;
        for (size_t y = 0; y < 4 && by * 4 + y < height; ++y)
            memcpy((uint8_t *)destination + (by * 4 + y) * destinationStride + bx * 64,
                   pixels + y * 16, count * 16);
    }
    return true;
}
