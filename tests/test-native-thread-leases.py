#!/usr/bin/env python3
"""Actual lease helpers: retirement/replacement cannot bypass an active reader."""
from pathlib import Path
import subprocess,tempfile
r=Path(__file__).resolve().parents[1]
s=(r/'worktrees/madeira/build/ntdll-unix/signal_arm64_ios.c').read_text();a=s.index('#define IOS_MAX_WINE_THREADS 512');b=s.index('/* Exact-match registry probe',a)
start=s.index('/* Return a caller-owned send right');end=s.index('/* A rejected snapshot',start)
s=s[:start]+s[end:]
b=s.index('/* Exact-match registry probe',a)
pre='#include <stdint.h>\n#include <pthread.h>\n#include <assert.h>\ntypedef unsigned thread_t;\n'
main=r'''
static pthread_mutex_t gate=PTHREAD_MUTEX_INITIALIZER;
static pthread_cond_t changed=PTHREAD_COND_INITIALIZER;
static int acquired,finish;
static void *reader(void *unused) {
 struct ios_thread_entry v;assert(ios_thread_registry_acquire(0,&v));
 pthread_mutex_lock(&gate);acquired=1;pthread_cond_broadcast(&changed);
 while(!finish)pthread_cond_wait(&changed,&gate);
 pthread_mutex_unlock(&gate);
 assert(v.teb==16&&v.mach_thread==1&&v.trampoline==(void *)24);
 ios_thread_registry_release(0);return NULL;
}
int main(void) {
 struct ios_thread_entry v;
 assert(!ios_thread_registry_acquire(0,&v));
 assert(ios_thread_registry[0].access==0);
 assert(ios_thread_registry_publish(0,16,1,(void *)24));
 pthread_t t;assert(!pthread_create(&t,NULL,reader,NULL));
 pthread_mutex_lock(&gate);while(!acquired)pthread_cond_wait(&changed,&gate);pthread_mutex_unlock(&gate);
 assert(!ios_thread_registry_publish(0,32,2,(void *)40));
 assert(ios_thread_registry_retire(0)==1);
 assert(!ios_thread_registry_acquire(0,&v));
 assert(!ios_thread_registry_publish(0,32,2,(void *)40));
 pthread_mutex_lock(&gate);finish=1;pthread_cond_broadcast(&changed);pthread_mutex_unlock(&gate);
 assert(!pthread_join(t,NULL));assert(ios_thread_registry_retire(0)==0);
 assert(!ios_thread_registry_publish(0,32,2,(void *)40));
 assert(ios_thread_registry_retire(-1)==UINT64_MAX);
 /* Retirement during publication is unknown, and completion preserves closure. */
 __atomic_store_n(&ios_thread_registry[1].access,IOS_THREAD_ACCESS_WRITING,__ATOMIC_SEQ_CST);
 assert(ios_thread_registry_retire(1)==UINT64_MAX);
 __atomic_fetch_and(&ios_thread_registry[1].access,~IOS_THREAD_ACCESS_WRITING,__ATOMIC_SEQ_CST);
 assert(ios_thread_registry[1].access==IOS_THREAD_ACCESS_CLOSED);
 assert(!ios_thread_registry_acquire(1,&v));
 return 0;
}
'''
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'test.c';p.write_text(pre+s[a:b]+main);exe=Path(d)/'test'
 subprocess.run(['clang','-pthread','-fsanitize=address,undefined',str(p),'-o',str(exe)],check=True)
 subprocess.run([str(exe)],check=True,timeout=15)
print('PASS leased identity blocks replacement; retirement rejects new readers and remains pending until release')
