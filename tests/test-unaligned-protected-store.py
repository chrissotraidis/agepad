#!/usr/bin/env python3
"""Actual store emulator against Mach mappings; no signal-delivery/SMC claim."""
from pathlib import Path
import subprocess,tempfile
root=Path(__file__).resolve().parents[1]
s=(root/'worktrees/madeira/build/ntdll-unix/signal_arm64_ios.c').read_text()
a=s.index('static int ios_unaligned_store_writable(');b=s.index('\n#endif',a);code=s[a:b]
assert 'if (emulated < 0)' in s and 'rec.ExceptionInformation[0] = EXCEPTION_WRITE_FAULT;' in s
pre=r'''
#include <mach/mach.h>
#include <mach/mach_vm.h>
#include <stdint.h>
#include <stddef.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <assert.h>
#include <sys/mman.h>
#include <unistd.h>

#define ucontext_t agepad_test_context
typedef struct { struct { __uint128_t __v[32]; } __ns; } mock_mc;
typedef struct {mock_mc *uc_mcontext; uint64_t regs[32],pc;} ucontext_t;
#define PC_sig(c) ((c)->pc)
#define REGn_sig(r,c) ((c)->regs[r])
static uint64_t ios_get_reg(ucontext_t *c,int r){return r==31?0:c->regs[r];}
'''
post=r'''
int main(void){
 size_t page=getpagesize();
 unsigned char *p=mmap(0,page*3,PROT_READ|PROT_WRITE,MAP_PRIVATE|MAP_ANON,-1,0);
 assert(p!=MAP_FAILED);memset(p,0x55,page*3);
 mock_mc mc={0};ucontext_t c={.uc_mcontext=&mc,.pc=0x1000};c.regs[0]=0x123456789abcdef0ULL;
 assert(ios_emulate_unaligned_guest_access(&c,0xf9000000,(uintptr_t)(p+3))==1);
 assert(!memcmp(p+3,&c.regs[0],8));assert(c.pc==0x1000);
 assert(!mprotect(p+page,page,PROT_READ));
 assert(!ios_unaligned_store_writable((uintptr_t)(p+page),8));
 assert(!ios_unaligned_store_writable((uintptr_t)(p+page-4),8));
 assert(ios_emulate_unaligned_guest_access(&c,0xf9000000,(uintptr_t)(p+page+3))==-1);
 assert(ios_emulate_unaligned_guest_access(&c,0xf9000000,(uintptr_t)(p+page-4))==-1);
 assert(ios_emulate_unaligned_guest_access(&c,0xa9000400,(uintptr_t)(p+page-8))==-1);
 for(int i=1;i<=8;i++)assert(p[page-i]==0x55);
 assert(c.pc==0x1000);
 assert(!mprotect(p+page,page,PROT_READ|PROT_EXEC));
 assert(ios_emulate_unaligned_guest_access(&c,0xf9000000,(uintptr_t)(p+page+3))==-1);
 assert(!mprotect(p+page,page,PROT_READ|PROT_WRITE));
 assert(ios_unaligned_store_writable((uintptr_t)(p+page-4),8));
 assert(ios_emulate_unaligned_guest_access(&c,0xa9000400,(uintptr_t)(p+page-8))==1);
 /* Exact observed unsigned Q store plus unscaled form; loads/writeback refused. */
 mc.__ns.__v[1]=((__uint128_t)0x1122334455667788ULL<<64)|0x99aabbccddeeff00ULL;
 assert(ios_emulate_unaligned_guest_access(&c,0x3d800001,(uintptr_t)(p+35))==1);
 assert(!memcmp(p+35,&mc.__ns.__v[1],16));
 assert(ios_emulate_unaligned_guest_access(&c,0x3c9f0001,(uintptr_t)(p+67))==1);
 assert(!memcmp(p+67,&mc.__ns.__v[1],16));
 assert(ios_emulate_unaligned_guest_access(&c,0x3c9f0401,(uintptr_t)(p+99))==0);
 assert(ios_emulate_unaligned_guest_access(&c,0x3dc00001,(uintptr_t)(p+99))==0);
 assert(!mprotect(p+page,page,PROT_READ));memset(p+page-8,0x55,8);
 assert(ios_emulate_unaligned_guest_access(&c,0x3d800001,(uintptr_t)(p+page-8))==-1);
 for(int i=1;i<=8;i++)assert(p[page-i]==0x55);
 assert(c.pc==0x1000);
 assert(!munmap(p+page,page));
 assert(!ios_unaligned_store_writable((uintptr_t)(p+page-4),8));
 assert(!ios_unaligned_store_writable(UINTPTR_MAX-3,8));
 munmap(p,page);munmap(p+2*page,page);
}
'''
with tempfile.TemporaryDirectory() as d:
 d=Path(d)
 for name,c,ok in [('fixed',code,True),('old-SIMD-rejection',code.replace('const void *value = &ctx->uc_mcontext->__ns.__v[rt];','return 0; const void *value = &ctx->uc_mcontext->__ns.__v[rt];'),False),('old-readable-only',code.replace('if (!ios_unaligned_store_writable(addr, nbytes)) return -1;',''),False)]:
  (d/'test.c').write_text(pre+c+post)
  subprocess.run(['clang','-fsanitize=address,undefined',str(d/'test.c'),'-o',str(d/'test')],check=True)
  r=subprocess.run([str(d/'test')],capture_output=True)
  assert (r.returncode==0)==ok,(name,r.stderr)
print('PASS: actual writable stores, R/RX refusal, cross-boundary scalar/pair refusal without partial write, holes/overflow; scalar and SIMD negative controls fail.')
