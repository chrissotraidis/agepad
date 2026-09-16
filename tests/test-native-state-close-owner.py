#!/usr/bin/env python3
"""Actual native state-close boundary: owner validation, pending/drained outcomes."""
from pathlib import Path
import subprocess,tempfile
r=Path(__file__).resolve().parents[1]
s=(r/'worktrees/madeira/build/ntdll-unix/signal_arm64_ios.c').read_text()
a=s.index('#define IOS_MAX_WINE_THREADS 512');b=s.index('/* Return a caller-owned send right',a)
c=s.index('/* Native bridge primitive:');e=s.index('/* Diagnostic scans',c)
pre='#include <stdint.h>\n#include <pthread.h>\n#include <assert.h>\ntypedef unsigned thread_t;\ntypedef struct {void *Peb;} TEB;\n'
main=r'''
int main(void) {
 TEB target={.Peb=(void *)123}; uintptr_t address=(uintptr_t)&target;
 assert(ios_thread_registry_publish(0,address,50,(void *)200));
 __atomic_store_n(&ios_thread_count,1,__ATOMIC_SEQ_CST);
 assert(ios_state_close_for_owner(0,(void *)123)==UINT64_MAX);
 assert(ios_state_close_for_owner(999,(void *)123)==UINT64_MAX);
 assert(ios_state_close_for_owner(address,0)==UINT64_MAX);
 assert(ios_state_close_for_owner(address,(void *)124)==UINT64_MAX);
 assert(ios_thread_registry[0].state_access==0 && ios_thread_registry[0].access==0);
 struct ios_state_lease reader=ios_state_lease_for_teb(address);assert(reader.held);
 assert(ios_state_close_for_owner(address,(void *)123)==1);
 assert(!ios_state_lease_for_teb(address).held);
 assert((ios_thread_registry[0].access&IOS_THREAD_ACCESS_COUNT)==1);
 ios_state_lease_cleanup(&reader);
 assert(ios_state_close_for_owner(address,(void *)123)==0);
 assert(ios_state_close_for_owner(address,(void *)123)==0);
 struct ios_thread_lease native=ios_thread_lease_for_port(50);assert(native.slot==0);
 ios_thread_lease_cleanup(&native);
 assert(ios_thread_registry[0].access==0);
 return 0;
}
'''
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'test.c';p.write_text(pre+s[a:b]+s[c:e]+main);exe=Path(d)/'test'
 subprocess.run(['clang','-pthread','-fsanitize=address,undefined',str(p),'-o',str(exe)],check=True)
 subprocess.run([str(exe)],check=True,timeout=15)
print('PASS invalid owner leaves state open; pending/drained explicit; native references released')
