/* Finite clock regression: a frozen clock must fail, not hang its own test. */
#include <windows.h>
static void say(const char *s, DWORD n) { DWORD w; WriteFile(GetStdHandle(STD_OUTPUT_HANDLE), s, n, &w, 0); }
#define SAY(s) say(s, sizeof(s)-1)
static ULONGLONG shared_time(unsigned offset)
{
    volatile DWORD *p = (volatile DWORD *)(ULONG_PTR)(0x7ffe0000u + offset);
    DWORD hi, lo;
    unsigned attempts=0;
    do { if (++attempts>1024) ExitProcess(94); hi=p[1]; lo=p[0]; } while (hi!=p[2]);
    return ((ULONGLONG)hi<<32)|lo;
}
void mainCRTStartup(void)
{
    LARGE_INTEGER q0,q1,freq;
    ULONGLONG t0,t1,u0,u1,i0,i1,s0,s1;
    DWORD d0,d1;
    SAY("AGEPAD_CLOCK: BEGIN\n");
    if (!QueryPerformanceFrequency(&freq) || freq.QuadPart<=0 || !QueryPerformanceCounter(&q0)) ExitProcess(90);
    t0=GetTickCount64(); d0=GetTickCount(); u0=shared_time(0x320); i0=shared_time(8); s0=shared_time(0x14);
    for (unsigned n=0;n<8;++n) Sleep(50);
    t1=GetTickCount64(); d1=GetTickCount(); u1=shared_time(0x320); i1=shared_time(8); s1=shared_time(0x14);
    if (!QueryPerformanceCounter(&q1) || q1.QuadPart<=q0.QuadPart) ExitProcess(91);
    if (t1<=t0 || (DWORD)(d1-d0)<100 || u1<=u0 || i1<=i0 || s1<=s0) {
        SAY("AGEPAD_CLOCK: FROZEN_OR_NONMONOTONIC\n"); ExitProcess(92);
    }
    if (t1-t0<100 || u1-u0<100 || i1-i0<1000000 || s1-s0<1000000) ExitProcess(93);
    SAY("AGEPAD_CLOCK: API_AND_SHARED_TIME_ADVANCE\n");
    SAY("AGEPAD_CLOCK: PASS\n"); ExitProcess(0);
}
