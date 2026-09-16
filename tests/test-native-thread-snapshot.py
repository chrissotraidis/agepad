#!/usr/bin/env python3
"""Actual native snapshot/publication under concurrent replacement; no lifetime claim."""
from pathlib import Path
import subprocess,tempfile
r=Path(__file__).resolve().parents[1]
s=(r/'worktrees/madeira/build/ntdll-unix/signal_arm64_ios.c').read_text()
a=s.index('#define IOS_MAX_WINE_THREADS 512');b=s.index('/* ml398',a)
start=s.index('/* Return a caller-owned send right');end=s.index('/* A rejected snapshot',start)
s=s[:start]+s[end:]
b=s.index('/* ml398',a)
pre='''#include <stdint.h>
#include <stddef.h>
#include <pthread.h>
#include <assert.h>
typedef unsigned thread_t;
#define ERR(...) ((void)0)
'''
main=r'''
static int done;
static void *writer(void *unused) {
 for(unsigned n=1;n<=200000;n++) {
  pthread_mutex_lock(&ios_thread_publish_mutex);
  ios_thread_registry_publish(0,(uintptr_t)n*16,n,(void *)((uintptr_t)n*16+8));
  pthread_mutex_unlock(&ios_thread_publish_mutex);
 }
 __atomic_store_n(&done,1,__ATOMIC_RELEASE);return NULL;
}
int main(void) {
 uintptr_t teb=99;thread_t port=99;void *tr=(void *)99;
 assert(!ios_thread_registry_snapshot(-1,&teb,&port,&tr));
 assert(!ios_thread_registry_snapshot(0,&teb,&port,&tr));
 assert(!ios_thread_is_registered(0));
 assert(teb==99&&port==99&&tr==(void *)99);
 ios_thread_registry_publish(0,16,1,(void *)24);
 __atomic_store_n(&ios_thread_count,1,__ATOMIC_SEQ_CST);
 assert(ios_thread_is_registered(1)&&ios_teb_is_registered(16));
 assert(ios_lookup_thread(1,&teb,&tr)&&teb==16&&tr==(void *)24);
 assert(ios_thread_registry_snapshot(0,&teb,&port,&tr)&&teb==16&&port==1&&tr==(void *)24);
 __atomic_store_n(&ios_thread_registry[0].sequence,3,__ATOMIC_SEQ_CST);
 assert(!ios_thread_registry_snapshot(0,&teb,&port,&tr));
 __atomic_store_n(&ios_thread_registry[0].sequence,4,__ATOMIC_SEQ_CST);
 pthread_t t;assert(!pthread_create(&t,NULL,writer,NULL));
 do {
  if(ios_thread_registry_snapshot(0,&teb,&port,&tr)) {
   assert(teb==(uintptr_t)port*16);assert((uintptr_t)tr==teb+8);
   uintptr_t looked;void *lt;
   if(ios_lookup_thread(port,&looked,&lt))assert((uintptr_t)lt==looked+8);
  }
 }while(!__atomic_load_n(&done,__ATOMIC_ACQUIRE));
 assert(!pthread_join(t,NULL));
 assert(ios_thread_registry_snapshot(0,&teb,&port,&tr)&&port==200000);
 return 0;
}
'''
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'test.c';p.write_text(pre+s[a:b]+main);exe=Path(d)/'test'
 subprocess.run(['clang','-pthread','-fsanitize=address,undefined',str(p),'-o',str(exe)],check=True)
 subprocess.run([str(exe)],check=True,timeout=15)
print('PASS coherent nonblocking snapshots during 200000 replacements; incomplete publication rejects')
