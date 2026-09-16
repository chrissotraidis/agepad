#!/usr/bin/env python3
"""Exercise actual class-init synchronization with cross-process callbacks."""
from pathlib import Path
import subprocess,tempfile
root=Path(__file__).resolve().parents[1]
s=(root/'worktrees/madeira/build/win32u-unix/class_ios.c').read_text()
a=s.index('void register_builtin_classes(void)');b=s.index('\n/***********************************************************************',a)
body=s[a:b]
pre=r'''
#include <pthread.h>
#include <stdint.h>
#include <stdio.h>
#include <assert.h>
#include <unistd.h>
#include <stdatomic.h>
typedef unsigned DWORD;
#define ARRAYSIZE(a) (sizeof(a)/sizeof((a)[0]))
#define HandleToULong(x) ((DWORD)(uintptr_t)(x))
static _Thread_local struct { struct { void *UniqueProcess; } ClientId; void *Peb; } teb;
#define NtCurrentTeb() (&teb)
static atomic_int entered, release_a, b_done, counts[4];
static void register_builtins(void) {
 unsigned id=(unsigned)(uintptr_t)teb.ClientId.UniqueProcess;
 atomic_fetch_add(&counts[id],1);
 if(id==1) { atomic_store(&entered,1); while(!atomic_load(&release_a)) usleep(1000); }
 if(id==2) atomic_store(&b_done,1);
}
'''
post=r'''
static void *run(void *arg) {
 uintptr_t id=(uintptr_t)arg;teb.ClientId.UniqueProcess=(void*)id;teb.Peb=(void*)(id*4096);
 register_builtin_classes();return NULL;
}
int main(void) {
 pthread_t a,b,other_a;pthread_create(&a,NULL,run,(void*)1);
 while(!atomic_load(&entered))usleep(1000);
 pthread_create(&other_a,NULL,run,(void*)1);
 pthread_create(&b,NULL,run,(void*)2);
 for(int i=0;i<1000 && !atomic_load(&b_done);i++)usleep(1000);
 int independent=atomic_load(&b_done);
 atomic_store(&release_a,1);
 pthread_join(a,NULL);pthread_join(other_a,NULL);pthread_join(b,NULL);
 assert(independent && "process B must finish while A's guest callback waits");
 assert(counts[1]==1 && counts[2]==1);
 run((void*)2);assert(counts[2]==1);
 teb.Peb=(void*)0x9000;register_builtin_classes();assert(counts[2]==2);
 puts("PASS: independent processes, concurrent once, repeat calls, and distinct PEB identity");
}
'''
with tempfile.TemporaryDirectory(prefix='agepad-builtin-once-') as d:
 c=Path(d)/'test.c';exe=Path(d)/'test';c.write_text(pre+body+post)
 subprocess.run(['xcrun','clang','-std=c11','-Wall','-Wextra','-fsanitize=address,undefined','-pthread',str(c),'-o',str(exe)],check=True)
 subprocess.run([str(exe)],check=True,timeout=10)

 # Negative control recreates global serialization across the guest callback.
 bad=body.replace("    pthread_mutex_unlock( &builtin_lock );\n\n    if (once) pthread_once( once, register_builtins );", "    if (once) pthread_once( once, register_builtins );\n    pthread_mutex_unlock( &builtin_lock );\n    if (once) {}")
 assert bad != body
 c.write_text(pre+bad+post)
 subprocess.run(['xcrun','clang','-std=c11','-pthread',str(c),'-o',str(exe)],check=True)
 result=subprocess.run([str(exe)],stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=10)
 assert result.returncode != 0 and b'process B must finish' in result.stderr
 print('PASS: negative control rejects global callback serialization')
