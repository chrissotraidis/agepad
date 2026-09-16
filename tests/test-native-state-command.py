#!/usr/bin/env python3
"""Execute actual command dispatcher; distinguish disabled, invalid, pending, drained."""
from pathlib import Path
import subprocess,tempfile
r=Path(__file__).resolve().parents[1]
s=(r/'worktrees/madeira/build/ntdll-unix/virtual_ios.c').read_text()
a=s.index('struct ios_register_hold_release_args\n');b=s.index('/* Internal kind5',a)
pre=r'''
#include <stdint.h>
#include <assert.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>
#define dprintf(...) ((void)0)
typedef unsigned NTSTATUS;
#define STATUS_SUCCESS 0
#define STATUS_INVALID_PARAMETER 0xc000000dU
#define STATUS_NOT_SUPPORTED 0xc00000bbU
#define STATUS_PENDING 0x103U
static struct {void *Peb;} teb;
static int no_teb,calls;
#define NtCurrentTeb() (no_teb ? NULL : &teb)
static uint64_t pending;
uint64_t ios_state_close_for_owner(uintptr_t t,void *p){assert(t==100&&p==(void *)123);calls++;return pending;}
static unsigned ios_retire_process_callbacks(void *p){return 0;}
static NTSTATUS ios_register_owned_callback(void *p,unsigned v,void *c){assert(0);return 0;}
'''
main=r'''
int main(void){
 struct ios_register_hold_release_args p={sizeof(p),6,(void *)123,(void *)100};
 teb.Peb=(void *)123;
 unsetenv("AGEPAD_RETIRE_FEX_STATE");
 assert(unixcall_ios_register_hold_release(&p)==STATUS_NOT_SUPPORTED && !calls);
 setenv("AGEPAD_RETIRE_FEX_STATE","0",1);
 assert(unixcall_ios_register_hold_release(&p)==STATUS_NOT_SUPPORTED && !calls);
 setenv("AGEPAD_RETIRE_FEX_STATE","1",1);
 p.size--;assert(unixcall_ios_register_hold_release(&p)==STATUS_INVALID_PARAMETER);p.size++;
 p.version=5;assert(unixcall_ios_register_hold_release(&p)==STATUS_INVALID_PARAMETER);p.version=6;
 no_teb=1;assert(unixcall_ios_register_hold_release(&p)==STATUS_INVALID_PARAMETER);no_teb=0;
 p.peb=(void *)124;assert(unixcall_ios_register_hold_release(&p)==STATUS_INVALID_PARAMETER);p.peb=(void *)123;
 p.callback=0;assert(unixcall_ios_register_hold_release(&p)==STATUS_INVALID_PARAMETER);p.callback=(void *)100;
 assert(!calls);
 pending=UINT64_MAX;assert(unixcall_ios_register_hold_release(&p)==STATUS_INVALID_PARAMETER);
 pending=1;assert(unixcall_ios_register_hold_release(&p)==STATUS_PENDING);
 pending=0;assert(unixcall_ios_register_hold_release(&p)==STATUS_SUCCESS);
 assert(calls==3);return 0;
}
'''
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'test.c';p.write_text(pre+s[a:b]+main);exe=Path(d)/'test'
 subprocess.run(['clang','-pthread','-fsanitize=address,undefined',str(p),'-o',str(exe)],check=True)
 subprocess.run([str(exe)],check=True,timeout=15)
print('PASS explicit disabled/invalid/pending/drained command results; invalid callers never close state')
