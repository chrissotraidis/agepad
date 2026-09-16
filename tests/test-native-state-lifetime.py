#!/usr/bin/env python3
"""Actual independent state domain: closure drains users without closing native identity."""
from pathlib import Path
import subprocess,tempfile
r=Path(__file__).resolve().parents[1]
s=(r/'worktrees/madeira/build/ntdll-unix/signal_arm64_ios.c').read_text()
a=s.index('#define IOS_MAX_WINE_THREADS 512');b=s.index('/* Return a caller-owned send right',a)
pre='#include <stdint.h>\n#include <pthread.h>\n#include <assert.h>\n#include <stdatomic.h>\n#include <sched.h>\ntypedef unsigned thread_t;\n'
main=r'''
static atomic_int ready,finish;
static void *reader(void *arg) {
 struct ios_state_lease lease __attribute__((cleanup(ios_state_lease_cleanup)))=ios_state_lease_for_teb(100);
 assert(lease.held && lease.native.slot==0);
 atomic_store(&ready,1);
 while(!atomic_load(&finish))sched_yield();
 assert(lease.native.value.teb==100);
 return 0;
}
int main(void) {
 assert(ios_thread_registry_publish(0,100,50,(void *)200));
 __atomic_store_n(&ios_thread_count,1,__ATOMIC_SEQ_CST);
 assert(!ios_state_lease_for_teb(0).held);
 pthread_t t;assert(!pthread_create(&t,0,reader,0));
 while(!atomic_load(&ready))sched_yield();
 struct ios_thread_lease owner=ios_thread_lease_for_teb(100);
 assert(owner.slot==0 && ios_state_retire(&owner)==1);
 assert(!ios_state_lease_for_teb(100).held);
 /* Native identity remains usable while frame access is closing. */
 struct ios_thread_lease native=ios_thread_lease_for_port(50);
 assert(native.slot==0);ios_thread_lease_cleanup(&native);
 assert((ios_thread_registry[0].access&IOS_THREAD_ACCESS_COUNT)==2);
 atomic_store(&finish,1);assert(!pthread_join(t,0));
 assert(ios_state_retire(&owner)==0);
 ios_thread_lease_cleanup(&owner);
 assert(ios_thread_registry[0].access==0);
 assert(!ios_thread_registry_publish(0,999,99,(void *)999));
 assert(ios_thread_registry[0].access==0);
 native=ios_thread_lease_for_port(50);assert(native.slot==0);ios_thread_lease_cleanup(&native);
 assert(ios_thread_retire_joined_teb(100));
 assert(ios_thread_lease_for_port(50).slot==-1);
 return 0;
}
'''
# Integration checks: each audited frame chain is gated by a state reference.
for suffix,teb in [('q','teb_q'),('pre','teb_out_pre')]:
 start=s.index('struct ios_state_lease state_lease_'+suffix)
 end=s.index('uint64_t state_rip_'+suffix,start)
 block=s[start:end]
 assert 'cleanup(ios_state_lease_cleanup)' in block
 assert 'ios_state_lease_for_teb('+teb+')' in block
 assert block.index('if (state_lease_'+suffix+'.held)') < block.index('+ 0x1788')
assert 'if (rspq < 6) diagnostic_lease = ios_state_lease_for_teb(teb_r);' in s
assert 'if (diagnostic_lease.held)' in s
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'test.c';p.write_text(pre+s[a:b]+main);exe=Path(d)/'test'
 subprocess.run(['clang','-pthread','-fsanitize=address,undefined',str(p),'-o',str(exe)],check=True)
 subprocess.run([str(exe)],check=True,timeout=15)
print('PASS state closure waits for reader; native identity remains open; state closure blocks replacement')
