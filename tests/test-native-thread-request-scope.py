#!/usr/bin/env python3
"""Actual lease lookup/cleanup: exact owner and C scope-exit behavior."""
from pathlib import Path
import subprocess,tempfile
r=Path(__file__).resolve().parents[1]
s=(r/'worktrees/madeira/build/ntdll-unix/signal_arm64_ios.c').read_text();a=s.index('#define IOS_MAX_WINE_THREADS 512');b=s.index('/* Exact-match registry probe',a)
start=s.index('/* Return a caller-owned send right');end=s.index('/* A rejected snapshot',start)
s=s[:start]+s[end:]
b=s.index('/* Exact-match registry probe',a)
pre='#include <stdint.h>\n#include <pthread.h>\n#include <assert.h>\ntypedef unsigned thread_t;\n'
main=r'''
static void request(unsigned mode) {
 for(int once=0;once<1;once++) {
  struct ios_thread_lease lease __attribute__((cleanup(ios_thread_lease_cleanup)))=ios_thread_lease_for_port(50+mode);
  assert(lease.slot==(int)mode);
  assert(ios_thread_registry_retire(mode)==1);
  assert(ios_thread_lease_for_port(50+mode).slot==-1);
  if(mode==0)return;
  if(mode==1)continue;
  if(mode==2)goto reply;
reply:;
  assert(ios_thread_registry_retire(mode)==1);
 }
}
int main(void) {
 for(unsigned i=0;i<4;i++)assert(ios_thread_registry_publish(i,100+i,50+i,(void *)(uintptr_t)(200+i)));
 __atomic_store_n(&ios_thread_count,4,__ATOMIC_SEQ_CST);
 assert(ios_thread_lease_for_port(999).slot==-1); /* never slot0 */
 assert(ios_thread_lease_for_port(0).slot==-1);
 for(unsigned i=0;i<4;i++){request(i);assert(ios_thread_registry_retire(i)==0);}
 return 0;
}
'''
# Integration uses one request-level cleanup guard, and no unleased re-lookups.
f=s[s.index('static void *ios_mach_exception_thread('):s.index('static void ios_install_task_exception_port(')]
assert f.count('cleanup(ios_thread_lease_cleanup)')==1 and 'ios_lookup_thread(' not in f
assert f.index('ios_thread_lease_for_port(thread)')<f.index('thread_teb = request_lease.value.teb')<f.index('agepad_mach_reply:;')
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'test.c';p.write_text(pre+s[a:b]+main);exe=Path(d)/'test'
 subprocess.run(['clang','-pthread','-fsanitize=address,undefined',str(p),'-o',str(exe)],check=True)
 subprocess.run([str(exe)],check=True,timeout=15)
print('PASS exact request identity and lease cleanup on return/continue/goto/normal exit')
