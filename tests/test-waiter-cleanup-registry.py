#!/usr/bin/env python3
"""Actual native callback registry: versions coexist, owners isolate, capacity rejects."""
from pathlib import Path
import subprocess,tempfile
root=Path(__file__).resolve().parents[1]
s=(root/'worktrees/madeira/build/ntdll-unix/virtual_ios.c').read_text()
s=s[s.index('#define IOS_HOLD_RELEASE_MAX 32'):s.index('\nNTSTATUS unixcall_ios_push_jit_aliases')]
pre=r'''
#include <assert.h>
#include <pthread.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>
#define dprintf(...) ((void)0)
typedef struct { void *Peb; } TEB;
static TEB current_teb;
static TEB *NtCurrentTeb(void) { return &current_teb; }
typedef unsigned NTSTATUS;
#define STATUS_SUCCESS 0
#define STATUS_INVALID_PARAMETER 1
#define STATUS_INSUFFICIENT_RESOURCES 2
static NTSTATUS ios_register_owned_callback(void *, unsigned, void *);
'''
main=r'''
static unsigned hold(void *a,unsigned long long *b,unsigned *c,unsigned *d){return 16;}
static unsigned clean(void *teb){return teb?71:0x229;}
static unsigned pending(void *teb){return teb?3:0x230;}
int main(void) {
 unsigned long long stamp=0;unsigned depth=0,flags=0,result=0;
 int owners[33];struct ios_register_hold_release_args p={sizeof(p),1,&owners[0],hold};
 assert(unixcall_ios_register_hold_release(NULL)==STATUS_INVALID_PARAMETER);
 assert(!unixcall_ios_register_hold_release(&p));
 assert(ios_release_exit_holds(owners,owners,&stamp,&depth,&flags,&result) && result==16);
 assert(ios_cleanup_terminated_waiter(&owners[0],&owners[0])==9);
 p.version=2;p.callback=clean;assert(!unixcall_ios_register_hold_release(&p));
 assert(ios_hold_release_n==1);assert(ios_release_exit_holds(owners,owners,&stamp,&depth,&flags,&result) && result==16);
 assert(ios_cleanup_terminated_waiter(&owners[0],&owners[0])==71);
 assert(ios_cleanup_terminated_waiter(&owners[0],&owners[1])==9);
 p.version=3;p.callback=pending;assert(!unixcall_ios_register_hold_release(&p));
 assert(ios_pending_thread_cleanup(owners,owners)==3);
 assert(ios_pending_thread_cleanup(owners,&owners[1])==~0u);
 assert(ios_cleanup_terminated_waiter(owners,owners)==71);
 assert(ios_release_exit_holds(owners,owners,&stamp,&depth,&flags,&result) && result==16);
 p.callback=clean;
 p.version=5;assert(unixcall_ios_register_hold_release(&p)==STATUS_INVALID_PARAMETER);
 p.version=2;p.size--;assert(unixcall_ios_register_hold_release(&p)==STATUS_INVALID_PARAMETER);p.size++;
 for(int i=1;i<32;i++){p.peb=&owners[i];assert(!unixcall_ios_register_hold_release(&p));}
 p.peb=&owners[32];assert(unixcall_ios_register_hold_release(&p)==STATUS_INSUFFICIENT_RESOURCES);
 assert(ios_hold_release_n==32);assert(ios_cleanup_terminated_waiter(owners,&owners[32])==9);
 return 0;
}
'''
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'test.c';p.write_text(pre+s+main);exe=Path(d)/'test'
 subprocess.run(['clang','-pthread','-fsanitize=address,undefined',str(p),'-o',str(exe)],check=True)
 subprocess.run([str(exe)],check=True)
print('PASS callback version/owner isolation and bounded capacity')
