#!/usr/bin/env python3
"""Test actual NtDeviceIoControlFile guard dispatch, not mapped-memory safety."""
from pathlib import Path
import subprocess, tempfile
root=Path(__file__).resolve().parents[1]
s=(root/'worktrees/madeira/wine/dlls/ntdll/signal_arm64ec.c').read_text()
a=s.index('NTSTATUS SYSCALL_API NtDeviceIoControlFile(')
b=s.index('\n/* ml392', a)
body=s[a:b]
pre=r'''#include <stdint.h>
#include <assert.h>
#include <stddef.h>
typedef void *HANDLE; typedef void *PIO_APC_ROUTINE;
typedef struct {uintptr_t status,info;} IO_STATUS_BLOCK;
typedef uintptr_t ULONG_PTR; typedef unsigned long ULONG; typedef int NTSTATUS;
#define SYSCALL_API
#define STATUS_ACCESS_VIOLATION ((int)0xc0000005)
#define ERR(...) ((void)0)
static unsigned calls;
static NTSTATUS syscall_NtDeviceIoControlFile(HANDLE h,HANDLE e,PIO_APC_ROUTINE a,void *c,IO_STATUS_BLOCK *i,ULONG code,void *in,ULONG n,void *out,ULONG m) {calls++; return 259;}
'''
post=r'''
static int run(uintptr_t p) {return NtDeviceIoControlFile(0,0,0,0,(void*)p,0x120338,0,32,0,0);}
int main(void) {
 assert(run(0)==STATUS_ACCESS_VIOLATION);
 assert(run(0x7200000103ULL)==STATUS_ACCESS_VIOLATION);
 assert(calls==0);
 assert(run(0x708742c660ULL)==259);
 assert(run(0x7b1c0019e428ULL)==259);
 assert(run(0x793c02e4f408ULL)==259);
 assert(calls==3);
}
'''
with tempfile.TemporaryDirectory() as d:
 d=Path(d)
 for name,code,ok in [('fixed',body,True),('old-ceiling',body.replace('if (!io || ((ULONG_PTR)io & (sizeof(void *) - 1)))','if (!io || ((ULONG_PTR)io & (sizeof(void *) - 1)) || (ULONG_PTR)io >= 0x8000000000ull)'),False)]:
  (d/'test.c').write_text(pre+code+post)
  subprocess.run(['clang','-fsanitize=address,undefined',str(d/'test.c'),'-o',str(d/'test')],check=True)
  r=subprocess.run([str(d/'test')],capture_output=True)
  assert (r.returncode==0)==ok,(name,r.stderr)
print('PASS: high addresses forwarded, null/misaligned rejected; old ceiling negative control fails. No memory-access or integration claim.')
