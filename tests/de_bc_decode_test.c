#include "../port/de/BCDecode.h"
#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

int main(void) {
    uint8_t source[128] = {0}, destination[2048], before[2048];
    float pixels[64];
    // BC1 endpoint 0 is pure red in RGB565, with all indices zero.
    source[1] = 0xf8;
    assert(DEDecodeBCFloat(DEBC1, source, 8, 8, pixels, sizeof pixels, 64, 4, 4));
    for (int i = 0; i < 16; ++i)
        assert(pixels[4*i] == 1 && pixels[4*i+1] == 0 && pixels[4*i+2] == 0 && pixels[4*i+3] == 1);
    // Signed BC5 independently preserves red -1 and green +1.
    memset(source, 0, sizeof source); source[0] = 128; source[8] = 127;
    assert(DEDecodeBCFloat(DEBC5S, source, 16, 16, pixels, sizeof pixels, 64, 4, 4));
    for (int i = 0; i < 16; ++i)
        assert(pixels[4*i] == -1 && pixels[4*i+1] == 1 && pixels[4*i+2] == 0 && pixels[4*i+3] == 1);
    uint32_t state = 0x98135;
    unsigned cases = 0;
    for (unsigned f = DEBC1; f <= DEBC7; ++f) for (unsigned n = 0; n < 1000; ++n) {
        for (unsigned i = 0; i < sizeof source; ++i) {
            state ^= state << 13; state ^= state >> 17; state ^= state << 5; source[i] = state;
        }
        memset(destination, 0xcd, sizeof destination);
        // Unaligned buffers, padded block rows, 5x7 crop across four blocks.
        assert(DEDecodeBCFloat(f, source+1, 127, 40, destination+1, 2047, 96, 5, 7));
        assert(destination[0] == 0xcd);
        for (unsigned y = 0; y < 7; ++y) for (unsigned x = 80; x < 96; ++x)
            assert(destination[1+y*96+x] == 0xcd);
        for (unsigned i = 1+7*96; i < sizeof destination; ++i) assert(destination[i] == 0xcd);
        memcpy(before, destination, sizeof before);
        assert(!DEDecodeBCFloat(f, source, 1, 40, destination, 2048, 96, 5, 7));
        assert(!DEDecodeBCFloat(f, source, 128, 40, destination, 10, 96, 5, 7));
        assert(!DEDecodeBCFloat(f, source, 128, 40, destination, 2048, 96, SIZE_MAX, 7));
        assert(memcmp(before, destination, sizeof before) == 0);
        ++cases;
    }
    assert(!DEDecodeBCFloat(DEBC1, destination, 2048, 8, destination+1, 2047, 64, 4, 4));
    printf("PASS known BC1/BC5S pixels; %u all-format unaligned/crop/guard cases; invalid bounds and overlap rejection\n", cases);
    return 0;
}
