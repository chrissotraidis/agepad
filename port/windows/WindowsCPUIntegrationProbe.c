/* Source-owned x64 Windows integration test. No CRT and no gameplay claims. */
#include <windows.h>
#include <stdint.h>
static void emit(const char *s, DWORD n) { DWORD written; WriteFile(GetStdHandle(STD_OUTPUT_HANDLE), s, n, &written, 0); }
#define SAY(s) emit(s, sizeof(s)-1)
__declspec(noinline) static uint64_t step(uint64_t x, unsigned i) {
    return (i & 1) ? x * 6364136223846793005ULL + 1442695040888963407ULL : (x ^ (x >> 13)) + i;
}
void mainCRTStartup(void) {
    volatile uint64_t value = 0x123456789abcdef0ULL;
    LARGE_INTEGER start, end, frequency;
    if (!QueryPerformanceFrequency(&frequency) || frequency.QuadPart <= 0 || !QueryPerformanceCounter(&start)) ExitProcess(10);
    for (unsigned i = 0; i < 1000000; ++i) value = step(value, i);
    if (value != EXPECTED_CHECKSUM) { SAY("AGEPAD_CPU_INTEGRATION: CHECKSUM_FAIL\n"); ExitProcess(11); }
    if (!QueryPerformanceCounter(&end) || end.QuadPart < start.QuadPart) ExitProcess(12);
    SAY("AGEPAD_CPU_INTEGRATION: MILLION_BRANCH_CHECKSUM_OK\n");
    /* CREATE_NEW prevents overwriting anything from a prior or user run. */
    HANDLE file = CreateFileW(L"agepad-cpu-integration-v1.tmp", GENERIC_READ | GENERIC_WRITE, 0, 0, CREATE_NEW, FILE_ATTRIBUTE_TEMPORARY, 0);
    if (file == INVALID_HANDLE_VALUE) ExitProcess(13);
    uint64_t readback = 0, expected = value;
    DWORD n = 0;
    BOOL good = WriteFile(file, &expected, sizeof(expected), &n, 0) && n == sizeof(expected);
    good = good && SetFilePointer(file, 0, 0, FILE_BEGIN) == 0;
    good = good && ReadFile(file, &readback, sizeof(readback), &n, 0) && n == sizeof(readback) && readback == expected;
    CloseHandle(file);
    good = DeleteFileW(L"agepad-cpu-integration-v1.tmp") && good;
    if (!good) ExitProcess(14);
    SAY("AGEPAD_CPU_INTEGRATION: FILE_ROUNDTRIP_OK\n");
    SAY("AGEPAD_CPU_INTEGRATION: PASS v1\n");
    ExitProcess(0);
}
