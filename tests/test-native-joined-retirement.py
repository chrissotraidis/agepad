#!/usr/bin/env python3
"""Actual registry retirement against a held pthread reader and TEB aliases."""
from pathlib import Path
import subprocess,tempfile
r=Path(__file__).resolve().parents[1]
s=(r/'worktrees/madeira/build/ntdll-unix/signal_arm64_ios.c').read_text()
a=s.index('#define IOS_MAX_WINE_THREADS 512');b=s.index('struct ios_thread_lease {',a)
pre='#include <stdint.h>\n#include <pthread.h>\n#include <assert.h>\n#include <stdatomic.h>\n#include <sched.h>\ntypedef unsigned thread_t;\n'
main=r'''
static atomic_int ready,finish;
static void *reader(void *unused) {
 struct ios_thread_entry value;
 assert(ios_thread_registry_acquire(1,&value));
 atomic_store(&ready,1);
 while(!atomic_load(&finish))sched_yield();
 assert(value.teb==100 && value.mach_thread==51);
 ios_thread_registry_release(1); return 0;
}
int main(void) {
 assert(ios_thread_registry_publish(0,100,50,(void *)200));
 assert(ios_thread_registry_publish(1,100,51,(void *)201));
 assert(ios_thread_registry_publish(2,102,52,(void *)202));
 __atomic_store_n(&ios_thread_count,3,__ATOMIC_SEQ_CST);
 assert(!ios_thread_retire_joined_teb(0));
 assert(!ios_thread_retire_joined_teb(999));
 pthread_t t; assert(!pthread_create(&t,0,reader,0));
 while(!atomic_load(&ready))sched_yield();
 assert(!ios_thread_retire_joined_teb(100));
 struct ios_thread_entry value;
 assert(!ios_thread_registry_acquire(0,&value));
 assert(!ios_thread_registry_acquire(1,&value));
 assert(ios_thread_registry_acquire(2,&value));ios_thread_registry_release(2);
 atomic_store(&finish,1);assert(!pthread_join(t,0));
 assert(ios_thread_retire_joined_teb(100));
 assert(!ios_thread_registry_publish(0,999,99,(void *)999));
 return 0;
}
'''
t=(r/'worktrees/madeira/build/ntdll-unix/thread_ios.c').read_text()
x=t[t.index('static DECLSPEC_NORETURN void exit_thread('):t.index('void exit_process( int status )')]
assert 'int joined = pthread_join(' in x
assert x.index('if (joined)')<x.index('ios_thread_retire_joined_teb((uintptr_t)teb)')<x.index('virtual_free_teb( teb )')
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'test.c';p.write_text(pre+s[a:b]+main);exe=Path(d)/'test'
 subprocess.run(['clang','-pthread','-fsanitize=address,undefined',str(p),'-o',str(exe)],check=True)
 subprocess.run([str(exe)],check=True,timeout=15)
print('PASS all matching identities close; held reader retains; drain permits; unrelated identity stays open')
