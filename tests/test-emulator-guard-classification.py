#!/usr/bin/env python3
"""Native Mach mappings qualify guard classification, not guest stack unwinding."""
from pathlib import Path
import subprocess,tempfile
r=Path(__file__).resolve().parents[1]
s=(r/'worktrees/madeira/build/ntdll-unix/signal_arm64_ios.c').read_text();a=s.index('static int ios_emulator_guard_fault(');b=s.index('\n}\n',a)+2;body=s[a:b]
assert 'if (ios_emulator_guard_fault(fault, slimit))' in s
pre=r'''
#include <mach/mach.h>
#include <mach/mach_vm.h>
#include <stdint.h>
#include <assert.h>
#include <unistd.h>
#include <sys/mman.h>
'''
post=r'''
int main(void){
 size_t page=getpagesize();unsigned char *p=mmap(0,page*3,PROT_READ|PROT_WRITE,MAP_PRIVATE|MAP_ANON,-1,0);assert(p!=MAP_FAILED);
 uintptr_t limit=(uintptr_t)(p+page),fault=limit-0x7e4;
 assert(!ios_emulator_guard_fault(fault,limit));
 assert(!mprotect(p,page,PROT_READ));assert(!ios_emulator_guard_fault(fault,limit));
 assert(!mprotect(p,page,PROT_READ|PROT_EXEC));assert(!ios_emulator_guard_fault(fault,limit));
 assert(!mprotect(p,page,PROT_NONE));assert(ios_emulator_guard_fault(fault,limit));
 assert(!ios_emulator_guard_fault(limit,limit));
 assert(!ios_emulator_guard_fault(limit-0x4001,limit));
 assert(!ios_emulator_guard_fault(UINTPTR_MAX-1,16));
 assert(!munmap(p,page));assert(ios_emulator_guard_fault(fault,limit));
 assert(!ios_emulator_guard_fault(fault,0));munmap(p+page,page*2);
}
'''
old='static int ios_emulator_guard_fault(uintptr_t fault,uintptr_t limit){return limit && fault<limit && fault+0x4000>=limit;}'
with tempfile.TemporaryDirectory() as d:
 d=Path(d)
 for name,code,ok in [('fixed',body,True),('old-proximity',old,False)]:
  (d/'t.c').write_text(pre+code+post)
  subprocess.run(['clang','-fsanitize=address,undefined',str(d/'t.c'),'-o',str(d/'t')],check=True)
  result=subprocess.run([str(d/'t')],capture_output=True);assert (result.returncode==0)==ok,(name,result.stderr)
print('PASS: RW/R/RX neighbor excluded; no-access/hole recognized; bounds/wraparound rejected; old heuristic fails.')
