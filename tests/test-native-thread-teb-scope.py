#!/usr/bin/env python3
"""Extract actual TEB lookup: reference spans signal diagnostic reads."""
from pathlib import Path
import subprocess, tempfile
r=Path(__file__).resolve().parents[1]
s=(r/'worktrees/madeira/build/ntdll-unix/signal_arm64_ios.c').read_text()
a=s.index('#define IOS_MAX_WINE_THREADS 512');b=s.index('/* Return a caller-owned send right',a)
pre='#include <stdint.h>\n#include <pthread.h>\n#include <assert.h>\ntypedef unsigned thread_t;\n'
main=r''' 
static void diagnostic(void) {
 struct ios_thread_lease lease __attribute__((cleanup(ios_thread_lease_cleanup)))=ios_thread_lease_for_teb(101);
 assert(lease.slot==1 && lease.value.mach_thread==51);
 assert(ios_thread_registry_retire(1)==1);
 assert(ios_thread_lease_for_teb(101).slot==-1);
 assert(lease.value.trampoline==(void *)201);
}
int main(void) {
 assert(ios_thread_registry_publish(0,100,50,(void *)200));
 assert(ios_thread_registry_publish(1,101,51,(void *)201));
 __atomic_store_n(&ios_thread_count,2,__ATOMIC_SEQ_CST);
 assert(ios_thread_lease_for_teb(0).slot==-1);
 assert(ios_thread_lease_for_teb(999).slot==-1);
 __atomic_store_n(&ios_thread_registry[1].access,IOS_THREAD_ACCESS_WRITING,__ATOMIC_SEQ_CST);
 assert(ios_thread_lease_for_teb(101).slot==-1);
 __atomic_store_n(&ios_thread_registry[1].access,0,__ATOMIC_SEQ_CST);
 diagnostic(); assert(ios_thread_registry_retire(1)==0);
 /* A later native thread may legitimately reuse a freed TEB address. */
 assert(ios_thread_registry_publish(2,101,52,(void *)202));
 __atomic_store_n(&ios_thread_count,3,__ATOMIC_SEQ_CST);
 struct ios_thread_lease current=ios_thread_lease_for_teb(101);
 assert(current.slot==2&&current.value.mach_thread==52);
 ios_thread_lease_cleanup(&current);

 assert(ios_thread_registry[0].access==0);
 return 0;
}
'''
assert 'if (rspq < 6 && ios_teb_is_registered(teb_r))' not in s
assert 'if (rspq < 6) diagnostic_lease = ios_state_lease_for_teb(teb_r);' in s
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'test.c';p.write_text(pre+s[a:b]+main);exe=Path(d)/'test'
 subprocess.run(['clang','-pthread','-fsanitize=address,undefined',str(p),'-o',str(exe)],check=True)
 subprocess.run([str(exe)],check=True,timeout=15)
print('PASS exact TEB lease; missing/busy/closed rejection; diagnostic scope drains reference')
