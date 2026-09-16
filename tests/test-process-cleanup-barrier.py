#!/usr/bin/env python3
"""Run actual native wait policy with a deterministic clock/pending callback."""
from pathlib import Path
import subprocess,tempfile
root=Path(__file__).resolve().parents[1]
s=(root/'worktrees/madeira/build/ntdll-unix/process_ios.c').read_text()
a=s.index('static BOOL ios_wait_for_fex_cleanup(');b=s.index('\n#endif',a);func=s[a:b]
pre=r'''
#include <assert.h>
#include <stddef.h>
#include <time.h>
typedef int BOOL;
#define TRUE 1
#define FALSE 0
#define dprintf(...) ((void)0)
typedef struct {void *Peb;} TEB;
static int seconds,sleeps,clock_error,mode,queries;
static int fake_clock(int clock,struct timespec *out){if(clock_error)return -1;out->tv_sec=seconds++;out->tv_nsec=0;return 0;}
static int fake_sleep(const struct timespec *duration,void *unused){assert(duration->tv_nsec==1000000);sleeps++;return 0;}
unsigned int ios_pending_thread_cleanup(void *teb,void *peb){assert(teb&&peb);queries++;if(mode==0)return 0;if(mode==1)return queries<4?2:0;return ~0u;}
#define clock_gettime fake_clock
#define nanosleep fake_sleep
'''
main=r'''
int main(){
 TEB teb={&teb};assert(!ios_wait_for_fex_cleanup(NULL));assert(!queries);
 mode=0;assert(ios_wait_for_fex_cleanup(&teb));assert(queries==1&&!sleeps);
 seconds=queries=sleeps=0;mode=1;assert(ios_wait_for_fex_cleanup(&teb));assert(queries==4&&sleeps==3);
 seconds=queries=sleeps=0;mode=2;assert(!ios_wait_for_fex_cleanup(&teb));assert(queries==10&&sleeps==9);
 seconds=queries=sleeps=0;clock_error=1;assert(!ios_wait_for_fex_cleanup(&teb));assert(!queries);
}
'''
# Caller must not proceed to PE detach on failed wait. Quarantine itself is not executed here.
a=s.index('!ios_wait_for_fex_cleanup(NtCurrentTeb())');b=s.index('/* The server has terminated',a)
assert 'pthread_exit(NULL);' in s[a:b]
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'test.c';p.write_text(pre+func+main);exe=Path(d)/'test'
 subprocess.run(['clang','-fsanitize=address,undefined',str(p),'-o',str(exe)],check=True)
 subprocess.run([str(exe)],check=True)
print('PASS drain/unknown/deadline/clock failure policy; quarantine is source checked')
