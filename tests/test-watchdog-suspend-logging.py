#!/usr/bin/env python3
"""Compile the actual watchdog capture body; forbid logging while suspended."""
from pathlib import Path
import subprocess,tempfile
r=Path(__file__).resolve().parents[1]
s=(r/'worktrees/madeira/build/ntdll-unix/server_ios.c').read_text()
a=s.index('                /* Suspend thread for consistent state reading */')
b=s.index('\n            };',a)
body=s[a:b]
pre=r'''
#include <stdint.h>
#include <assert.h>
#include <stdio.h>
#include <string.h>
#include <stdarg.h>
typedef int kern_return_t;
typedef unsigned mach_msg_type_number_t;
typedef uintptr_t vm_address_t;
typedef size_t vm_size_t;
typedef unsigned *thread_state_t;
typedef struct { uint64_t __x[29],pc,lr,sp,fp; } arm_thread_state64_t;
#define KERN_SUCCESS 0
#define ARM_THREAD_STATE64 6
#define ARM_THREAD_STATE64_COUNT 68
#define arm_thread_state64_get_pc(s) ((s).pc)
#define arm_thread_state64_get_lr(s) ((s).lr)
#define arm_thread_state64_get_sp(s) ((s).sp)
#define arm_thread_state64_get_fp(s) ((s).fp)
static int held,mode,logs,reads,resumes;
static uint64_t watchdog_teb_addr=0x1000;
static uint64_t g_wine_dispatcher_x18,g_wine_dispatcher_count,g_wine_return_x18,g_wine_return_pc,g_wine_return_count;
volatile int64_t ios_exc_x18_fixes;
volatile int ios_exc_msg_count;
static int thread_suspend(int t){(void)t;assert(!held);if(mode==1)return 1;held=1;return 0;}
static int thread_resume(int t){(void)t;assert(held);held=0;resumes++;return 0;}
static int thread_get_state(int t,int kind,thread_state_t s,mach_msg_type_number_t *n)
{(void)t;(void)kind;(void)n;assert(held);memset(s,0,sizeof(arm_thread_state64_t));return mode==2;}
static int mach_task_self(void){return 1;}
static int vm_read_overwrite(int t,uint64_t a,size_t n,vm_address_t dst,vm_size_t *out)
{(void)t;(void)a;assert(held);reads++;if(mode==3)return 1;*(uint64_t*)dst=0x2000;*out=mode==4?0:n;return 0;}
static void wine_log_write(const char *s,...){(void)s;assert(!held);logs++;}
static void sample_thread(int secs){int wine_mach_thread=7;
'''
post=r'''
}
int main(void){for(mode=0;mode<5;mode++){
 held=logs=reads=resumes=0;sample_thread(2);
 assert(!held && logs>0);
 assert(resumes==(mode==1?0:1));
 assert(reads==(mode==0?2:mode>=3?1:0));
}puts("PASS: watchdog resumes before logging on success and capture failures");}
'''
with tempfile.TemporaryDirectory(prefix='agepad-watchdog-') as d:
 c=Path(d)/'test.c';e=Path(d)/'test';c.write_text(pre+body+post)
 subprocess.run(['xcrun','clang','-Wall','-Wextra','-fsanitize=address,undefined',str(c),'-o',str(e)],check=True)
 subprocess.run([str(e)],check=True,timeout=10)
