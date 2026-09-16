/* Exercise legal x64 scalar accesses at every sub-eight-byte alignment.
 * Inline assembly preserves the actual access width without C alignment UB. */
#include <windows.h>
static unsigned char buffer[64] __attribute__((aligned(16)));
static void say(const char *s, DWORD n) { DWORD w; WriteFile(GetStdHandle(STD_OUTPUT_HANDLE), s, n, &w, 0); }
#define SAY(s) say(s, sizeof(s)-1)
void mainCRTStartup(void)
{
    SAY("AGEPAD_UNALIGNED: BEGIN\n");
    for (unsigned offset = 0; offset < 8; ++offset) {
        unsigned char *p = buffer + 16 + offset;
        unsigned long long value = 0x8877665544332211ULL, result;
        for (unsigned i = 0; i < sizeof(buffer); ++i) buffer[i] = 0xa5;
        __asm__ volatile("movq %1, (%0)" :: "r"(p), "r"(value) : "memory");
        for (unsigned i = 0; i < sizeof(buffer); ++i) {
            unsigned char expected = (i >= 16+offset && i < 24+offset)
                ? (unsigned char)(value >> (8*(i-16-offset))) : 0xa5;
            if (buffer[i] != expected) ExitProcess(90);
        }
        __asm__ volatile("movq (%1), %0" : "=r"(result) : "r"(p) : "memory");
        if (result != value) ExitProcess(91);
    }
    SAY("AGEPAD_UNALIGNED: PASS\n");
    ExitProcess(0);
}
