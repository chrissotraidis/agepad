#!/usr/bin/env python3
"""Execute the actual registry with a callback held across retirement."""
from pathlib import Path
import subprocess,tempfile
root=Path(__file__).resolve().parents[1]
s=(root/'worktrees/madeira/build/ntdll-unix/virtual_ios.c').read_text()
s=s[s.index('#define IOS_HOLD_RELEASE_MAX 32'):s.index('\nNTSTATUS unixcall_ios_push_jit_aliases')]
pre=r'''
#include <assert.h>
#include <stdint.h>
#include <pthread.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>
#define dprintf(...) ((void)0)
typedef struct { void *Peb; } TEB;
static TEB current_teb;
static TEB *NtCurrentTeb(void) { return &current_teb; }
typedef unsigned NTSTATUS;
#define STATUS_SUCCESS 0
#define STATUS_INVALID_PARAMETER 1
#define STATUS_INSUFFICIENT_RESOURCES 2
#define STATUS_NOT_SUPPORTED 3
#define STATUS_PENDING 0x103
uint64_t ios_state_close_for_owner(uintptr_t t,void *p){return UINT64_MAX;}
static NTSTATUS ios_register_owned_callback(void *, unsigned, void *);
'''
main=r'''
static int owner,other,unknown,entered,finish,command_returned;
static pthread_mutex_t gate=PTHREAD_MUTEX_INITIALIZER;
static pthread_cond_t changed=PTHREAD_COND_INITIALIZER;
static unsigned blocked(void *teb) {
 assert(teb==&owner);
 pthread_mutex_lock(&gate);entered=1;pthread_cond_broadcast(&changed);
 while(!finish)pthread_cond_wait(&changed,&gate);
 pthread_mutex_unlock(&gate);return 71;
}
static unsigned pending(void *teb){return 0;}
static unsigned hold(void *t,unsigned long long *s,unsigned *d,unsigned *f){return 16;}
static void *caller(void *unused) {
 assert(ios_cleanup_terminated_waiter(&owner,&owner)==71);return NULL;
}
static void *retire_command(void *unused) {
 struct ios_register_hold_release_args p={sizeof(p),4,&owner,NULL};
 assert(!unixcall_ios_register_hold_release(&p));command_returned=1;return NULL;
}
int main(void) {
 struct ios_register_hold_release_args p={sizeof(p),2,&owner,blocked};
 assert(!unixcall_ios_register_hold_release(&p));
 p.version=1;p.callback=hold;assert(!unixcall_ios_register_hold_release(&p));
 p.version=3;p.callback=pending;assert(!unixcall_ios_register_hold_release(&p));
 p.peb=&other;assert(!unixcall_ios_register_hold_release(&p));
 pthread_t thread;assert(!pthread_create(&thread,NULL,caller,NULL));
 pthread_mutex_lock(&gate);while(!entered)pthread_cond_wait(&changed,&gate);pthread_mutex_unlock(&gate);
 assert(ios_retire_process_callbacks(&unknown)==~0u);
 current_teb.Peb=&owner;
 setenv("AGEPAD_RETIRE_FEX_CALLBACKS","1",1);
 pthread_t retire_thread;assert(!pthread_create(&retire_thread,NULL,retire_command,NULL));
 assert(!pthread_join(retire_thread,NULL));assert(!command_returned);
 assert(ios_retire_process_callbacks(&owner)==1);
 assert(ios_retire_process_callbacks(&owner)==1);
 assert(ios_cleanup_terminated_waiter(&owner,&owner)==9);
 assert(ios_pending_thread_cleanup(&owner,&owner)==~0u);
 unsigned long long stamp=0;unsigned depth=0,flags=0,result=123;
 assert(!ios_release_exit_holds(&owner,&owner,&stamp,&depth,&flags,&result));
 assert(result==123);
 p.peb=&owner;assert(unixcall_ios_register_hold_release(&p)==STATUS_INVALID_PARAMETER);
 assert(ios_pending_thread_cleanup(&other,&other)==0);
 pthread_mutex_lock(&gate);finish=1;pthread_cond_broadcast(&changed);pthread_mutex_unlock(&gate);
 assert(!pthread_join(thread,NULL));
 assert(ios_retire_process_callbacks(&owner)==0);
 assert(ios_cleanup_terminated_waiter(&owner,&owner)==9);
 assert(!pthread_create(&retire_thread,NULL,retire_command,NULL));
 assert(!pthread_join(retire_thread,NULL));assert(command_returned);
 p.version=4;p.callback=NULL;p.peb=&other;
 assert(unixcall_ios_register_hold_release(&p)==STATUS_INVALID_PARAMETER);
 p.peb=&owner;p.callback=hold;
 assert(unixcall_ios_register_hold_release(&p)==STATUS_INVALID_PARAMETER);
 assert(ios_hold_release_n==2); /* retirement deliberately does not recycle */
 return 0;
}
'''
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'test.c';p.write_text(pre+s+main);exe=Path(d)/'test'
 subprocess.run(['clang','-pthread','-fsanitize=address,undefined',str(p),'-o',str(exe)],check=True)
 subprocess.run([str(exe)],check=True,timeout=15)
print('PASS in-flight callback survives retirement; new calls and re-registration reject; other owner remains active')
