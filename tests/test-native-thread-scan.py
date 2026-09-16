#!/usr/bin/env python3
"""Actual protected scan: complete capture, partial-failure cleanup, scope release."""
from pathlib import Path
import subprocess,tempfile
r=Path(__file__).resolve().parents[1]
s=(r/'worktrees/madeira/build/ntdll-unix/signal_arm64_ios.c').read_text()
a=s.index('/* Return a caller-owned send right');b=s.index('/* Diagnostic scans',a);s=s[:a]+s[b:]
a=s.index('#define IOS_MAX_WINE_THREADS 512');b=s.index('/* A rejected snapshot',a)
pre='#include <stdint.h>\n#include <pthread.h>\n#include <assert.h>\ntypedef unsigned thread_t;\n'
main=r'''
static void complete_scan(void) {
 struct ios_thread_scan scan __attribute__((cleanup(ios_thread_scan_cleanup)));
 assert(ios_thread_scan_begin(&scan)&&scan.count==2);
 assert(scan.entries[0].value.teb==100&&scan.entries[1].value.teb==101);
 assert(ios_thread_registry_retire(0)==1&&ios_thread_registry_retire(1)==1);
 return;
}
int main(void) {
 assert(ios_thread_registry_publish(0,100,50,(void *)200));
 assert(ios_thread_registry_publish(1,101,51,(void *)201));
 __atomic_store_n(&ios_thread_count,2,__ATOMIC_SEQ_CST);
 /* Simulate a writer at slot1: slot0 lease must be released on failed scan. */
 __atomic_store_n(&ios_thread_registry[1].access,IOS_THREAD_ACCESS_WRITING,__ATOMIC_SEQ_CST);
 struct ios_thread_scan failed __attribute__((cleanup(ios_thread_scan_cleanup)));
 assert(!ios_thread_scan_begin(&failed)&&failed.count==0);
 assert(ios_thread_registry[0].access==0);
 __atomic_store_n(&ios_thread_registry[1].access,0,__ATOMIC_SEQ_CST);
 complete_scan();
 assert(ios_thread_registry_retire(0)==0&&ios_thread_registry_retire(1)==0);
 assert(!ios_thread_scan_begin(&failed)&&failed.count==0);
 return 0;
}
'''
# Diagnostic consumers use the held set rather than re-reading registry values.
start=s.index('static void ios_lock_census(');end=s.index('/* ml406:',start)
assert 'ios_thread_registry_value(' not in s[start:end]
start=s.index('void ios_pump_sample(void)');end=s.index('/* ml404',start)
assert 'static thread_t pump_port' not in s[start:end] and 'static uintptr_t pump_teb' not in s[start:end]
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'test.c';p.write_text(pre+s[a:b]+main);exe=Path(d)/'test'
 subprocess.run(['clang','-pthread','-fsanitize=address,undefined',str(p),'-o',str(exe)],check=True)
 subprocess.run([str(exe)],check=True,timeout=15)
print('PASS full scan pins entries; partial capture releases prior leases; return drains all references')
