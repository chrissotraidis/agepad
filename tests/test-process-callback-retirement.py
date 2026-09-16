#!/usr/bin/env python3
"""Actual exit guard: unknown/pending callbacks cannot reach resource release."""
from pathlib import Path
import subprocess,tempfile
root=Path(__file__).resolve().parents[1]
s=(root/'worktrees/madeira/build/ntdll-unix/server_ios.c').read_text()
a=s.index('    const char *retire = getenv("AGEPAD_RETIRE_FEX_CALLBACKS")')
b=s.index('    /* Close THIS pseudo-process',a)
body=s[a:b]
pre=r'''
#include <assert.h>
#include <pthread.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
typedef struct {void *Peb;} TEB;
static TEB teb;static int missing,released;static unsigned count,calls;
static TEB *NtCurrentTeb(void){return missing?NULL:&teb;}
unsigned ios_retire_process_callbacks(void *peb){assert(peb==&teb);calls++;return count;}
'''
main=r'''
static void check(unsigned n,int absent,int expect_release,int expected_calls) {
 count=n;missing=absent;released=0;calls=0;
 pthread_t thread;assert(!pthread_create(&thread,NULL,run,NULL));assert(!pthread_join(thread,NULL));
 assert(released==expect_release);assert(calls==(unsigned)expected_calls);
}
int main(void) {
 teb.Peb=&teb;setenv("AGEPAD_RETIRE_FEX_CALLBACKS","1",1);
 check(1,0,0,1);check(~0u,0,0,1);check(0,1,0,0);check(0,0,1,1);
 setenv("AGEPAD_RETIRE_FEX_CALLBACKS","0",1);check(1,0,1,0);
 return 0;
}
'''
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'test.c';p.write_text(pre+'static void *run(void *unused) {\n'+body+'\nreleased=1;return NULL;\n}\n'+main);exe=Path(d)/'test'
 subprocess.run(['clang','-pthread','-fsanitize=address,undefined',str(p),'-o',str(exe)],check=True)
 subprocess.run([str(exe)],check=True,timeout=15)
print('PASS final-exit guard retains resources for pending/unknown callbacks')
