#!/usr/bin/env python3
"""Actual TID lookup holds its lease until it acquires a caller-owned Mach right."""
from pathlib import Path
import subprocess,tempfile
r=Path(__file__).resolve().parents[1]
s=(r/'worktrees/madeira/build/ntdll-unix/signal_arm64_ios.c').read_text();a=s.index('#define IOS_MAX_WINE_THREADS 512');b=s.index('/* A rejected snapshot',a)
pre=r'''
#include <stdint.h>
#include <pthread.h>
#include <assert.h>
typedef unsigned thread_t;typedef unsigned DWORD;typedef uintptr_t ULONG_PTR;
typedef struct {struct {void *UniqueThread;} ClientId; void *Peb;} TEB;
#define MACH_PORT_NULL 0
#define MACH_PORT_RIGHT_SEND 1
#define KERN_SUCCESS 0
static int mach_task_self(void){return 1;}
static int mach_port_mod_refs(int task,thread_t port,int right,int delta);
'''
main=r'''
static int fail,rights,calls;
static int mach_port_mod_refs(int task,thread_t port,int right,int delta) {
 assert(task==1&&port==50&&right==MACH_PORT_RIGHT_SEND&&delta==1);
 assert((ios_thread_registry[0].access&IOS_THREAD_ACCESS_COUNT)==1);
 calls++;if(fail)return 5;rights++;return 0;
}
int main(void) {
 TEB teb;teb.ClientId.UniqueThread=(void *)73;
 assert(ios_thread_registry_publish(0,(uintptr_t)&teb,50,(void *)24));
 __atomic_store_n(&ios_thread_count,1,__ATOMIC_SEQ_CST);
 assert(!ios_mach_thread_for_tid(0)&&!ios_mach_thread_for_tid(74)&&!calls);
 fail=1;assert(!ios_mach_thread_for_tid(73)&&calls==1&&rights==0);
 assert(ios_thread_registry[0].access==0);
 fail=0;assert(ios_mach_thread_for_tid(73)==50&&rights==1);
 assert(ios_thread_registry[0].access==0);
 assert(ios_thread_registry_retire(0)==0);
 assert(!ios_mach_thread_for_tid(73)&&rights==1); /* old caller owns its own right */
 return 0;
}
'''
consumer=(r/'worktrees/madeira/build/ntdll-unix/thread_ios.c').read_text()
f=consumer[consumer.index('NTSTATUS WINAPI NtTerminateThread('):consumer.index('NTSTATUS WINAPI NtQueueApcThreadEx2(')]
assert f.index('thread_get_state( vt')<f.index('mach_port_deallocate(mach_task_self(), vt)')<f.index('SERVER_START_REQ( terminate_thread )')
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'test.c';p.write_text(pre+s[a:b]+main);exe=Path(d)/'test'
 subprocess.run(['clang','-pthread','-fsanitize=address,undefined',str(p),'-o',str(exe)],check=True)
 subprocess.run([str(exe)],check=True,timeout=15)
print('PASS TID lookup holds lease through right acquisition; failures release lease; consumer deallocation ordered')
