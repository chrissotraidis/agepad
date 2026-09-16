#!/usr/bin/env python3
"""Exercise actual native exit wrapper with a TEB key that clears immediately."""
from pathlib import Path
import subprocess,tempfile
root=Path(__file__).resolve().parents[1]
s=(root/'worktrees/madeira/build/ntdll-unix/thread_ios.c').read_text()
a=s.index('static DECLSPEC_NORETURN void pthread_exit_wrapper( int status )');b=s.index('\n\n/***********************************************************************',a);body=s[a:b]
pre=r'''
#include <stdint.h>
#include <stdio.h>
#include <assert.h>
#include <setjmp.h>
#include <stdarg.h>
#include <stdlib.h>
#define DECLSPEC_NORETURN __attribute__((noreturn))
typedef uintptr_t ULONG_PTR;
typedef unsigned pthread_key_t;
struct TEB {struct {void *UniqueThread;} ClientId;void *Peb;unsigned char pad[0x1800];};typedef struct TEB TEB;
static TEB *live;
static TEB* NtCurrentTeb(void){return live;}
static struct {int alert_fd,wait_fd[2],reply_fd,request_fd;} data;
#define ntdll_get_thread_data() (&data)
#define UIntToPtr(n) ((void*)(uintptr_t)(n))
static jmp_buf jump;static int closed,dead,cleared;
static int close(int fd){(void)fd;closed++;return 0;}
#define dprintf fake_dprintf
static int fake_dprintf(int fd,const char *fmt,...){(void)fd;(void)fmt;return 0;}
pthread_key_t ios_teb_tls_key=1;
static int pthread_setspecific(pthread_key_t k,const void *v){assert(k==1&&!v);live=NULL;cleared++;return 0;}
static DECLSPEC_NORETURN void pthread_exit(void *value){assert((uintptr_t)value==7);longjmp(jump,1);}
void ios_thread_died(unsigned tid){assert(tid==42);dead++;}
unsigned int (*ios_hold_release_lookup(void *peb))(void *,unsigned long long *,unsigned int *,unsigned int *){(void)peb;return NULL;}
'''
post=r'''
int main(){
 TEB teb={0};teb.ClientId.UniqueThread=(void*)42;live=&teb;
 if(!setjmp(jump))pthread_exit_wrapper(7);
 assert(closed==5&&dead==1&&cleared==1&&!live);
 if(!setjmp(jump))pthread_exit_wrapper(7);
 assert(closed==5&&dead==1&&cleared==1);
 puts("PASS: TEB survives key clearing; no-TEB exit closes nothing");
}
'''
with tempfile.TemporaryDirectory(prefix='agepad-exit-teb-') as d:
 c=Path(d)/'test.c';exe=Path(d)/'test'
 c.write_text(pre+body+post)
 subprocess.run(['xcrun','clang','-std=c11','-fsanitize=address,undefined',str(c),'-o',str(exe)],check=True)
 subprocess.run([str(exe)],check=True,timeout=10)

 # Negative control restores the post-clear implicit lookup.
 bad=body.replace('uint64_t held_lock = *(volatile uint64_t *)((char *)teb + 0x16f8);', 'uint64_t held_lock = *(volatile uint64_t *)((char *)NtCurrentTeb() + 0x16f8);')
 assert bad!=body
 c.write_text(pre+bad+post)
 subprocess.run(['xcrun','clang','-std=c11','-fsanitize=address,undefined',str(c),'-o',str(exe)],check=True)
 result=subprocess.run([str(exe)],capture_output=True,timeout=10)
 assert result.returncode!=0 and b'AddressSanitizer' in result.stderr
 print('PASS: negative control rejects post-clear TEB dereference')
