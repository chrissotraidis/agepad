#!/usr/bin/env python3
"""Execute actual JIT service entry through env gate with section assertions."""
from pathlib import Path
import subprocess,tempfile
r=Path(__file__).resolve().parents[1]
s=(r/'worktrees/madeira/build/ntdll-unix/virtual_ios.c').read_text();a=s.index('static NTSTATUS agepad_jit_service(void *opaque)');b=s.index('    if (!agepad_jit_protect)',a);entry=s[a:b]
pre=r'''
#include <assert.h>
#include <stddef.h>
typedef int NTSTATUS;typedef int sigset_t;
#define STATUS_SUCCESS 0
#define STATUS_NOT_SUPPORTED 1
#undef TARGET_OS_SIMULATOR
#define TARGET_OS_SIMULATOR 1
struct agepad_jit_args {unsigned version;unsigned long result;};
struct file_view;
static struct {void *Peb;} teb;
#define NtCurrentTeb() (&teb)
static int virtual_mutex,blocked,enabled;
static void server_enter_uninterrupted_section(int*m,sigset_t*s){assert(!blocked);blocked=1;}
static void server_leave_uninterrupted_section(int*m,sigset_t*s){assert(blocked);blocked=0;}
static char *getenv(const char*n){assert(blocked);return enabled?"1":0;}
'''
post=r'''
done: server_leave_uninterrupted_section(&virtual_mutex,&sigset);return status;}
int main(void){struct agepad_jit_args a={1,99};
assert(agepad_jit_service(0)==1 && !blocked);
a.version=2;assert(agepad_jit_service(&a)==1 && !blocked && a.result==99);
a.version=1;assert(agepad_jit_service(&a)==1 && !blocked && a.result==99);
enabled=1;assert(agepad_jit_service(&a)==0 && !blocked && a.result==0);
}
'''
with tempfile.TemporaryDirectory() as d:
 d=Path(d);(d/'t.c').write_text(pre+entry+post)
 subprocess.run(['clang','-fsanitize=address,undefined',str(d/'t.c'),'-o',str(d/'t')],check=True);subprocess.run([str(d/'t')],check=True)
print('PASS: actual JIT env gate inside uninterrupted section; rejection/result semantics preserved. Mock section; native APC integration pending.')
