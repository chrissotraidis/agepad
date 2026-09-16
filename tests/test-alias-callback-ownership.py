#!/usr/bin/env python3
"""Actual alias registry: two owners, retirement with an alias call in flight."""
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
typedef unsigned NTSTATUS;
#define STATUS_SUCCESS 0
#define STATUS_INVALID_PARAMETER 1
#define STATUS_INSUFFICIENT_RESOURCES 2
#define STATUS_NOT_SUPPORTED 3
#define STATUS_PENDING 0x103
uint64_t ios_state_close_for_owner(uintptr_t t,void *p){return UINT64_MAX;}
static NTSTATUS ios_register_owned_callback(void *,unsigned,void *);
static struct {void *Peb;} teb;
#define NtCurrentTeb() (&teb)
'''
main=r'''
static int parent,child,unknown,entered,finish,parent_calls,child_calls;
static pthread_mutex_t gate=PTHREAD_MUTEX_INITIALIZER;
static pthread_cond_t changed=PTHREAD_COND_INITIALIZER;
static void parent_alias(unsigned long long pe,unsigned long long jit,unsigned long long size) {
 assert(pe==1&&jit==2&&size==3);parent_calls++;
}
static void child_alias(unsigned long long pe,unsigned long long jit,unsigned long long size) {
 assert(pe==4&&jit==5&&size==6);
 pthread_mutex_lock(&gate);child_calls++;entered=1;pthread_cond_broadcast(&changed);
 while(!finish)pthread_cond_wait(&changed,&gate);
 pthread_mutex_unlock(&gate);
}
static void *deliver(void *unused){assert(ios_deliver_alias(&child,4,5,6));return NULL;}
int main(void) {
 assert(!ios_register_owned_callback(&parent,5,parent_alias));
 assert(!ios_register_owned_callback(&child,5,child_alias));
 assert(ios_deliver_alias(&parent,1,2,3));
 assert(!ios_deliver_alias(&unknown,1,2,3));
 pthread_t thread;assert(!pthread_create(&thread,NULL,deliver,NULL));
 pthread_mutex_lock(&gate);while(!entered)pthread_cond_wait(&changed,&gate);pthread_mutex_unlock(&gate);
 assert(ios_retire_process_callbacks(&child)==1);
 assert(!ios_deliver_alias(&child,4,5,6));
 assert(ios_register_owned_callback(&child,5,child_alias)==STATUS_INVALID_PARAMETER);
 assert(ios_deliver_alias(&parent,1,2,3));
 pthread_mutex_lock(&gate);finish=1;pthread_cond_broadcast(&changed);pthread_mutex_unlock(&gate);
 assert(!pthread_join(thread,NULL));assert(ios_retire_process_callbacks(&child)==0);
 assert(parent_calls==2&&child_calls==1);
 assert(ios_deliver_alias(&parent,1,2,3));assert(parent_calls==3);
 return 0;
}
'''
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'test.c';p.write_text(pre+s+main);exe=Path(d)/'test'
 subprocess.run(['clang','-pthread','-fsanitize=address,undefined',str(p),'-o',str(exe)],check=True)
 subprocess.run([str(exe)],check=True,timeout=15)
print('PASS aliases route by owner; retirement tracks in-flight alias and preserves parent delivery')
