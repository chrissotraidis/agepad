#!/usr/bin/env python3
"""Actual loader selection/ABI-error guard, with mocked unix dispatcher and wait."""
from pathlib import Path
import subprocess,tempfile
root=Path(__file__).resolve().parents[1]
s=(root/'worktrees/madeira/wine/dlls/ntdll/loader.c').read_text()
a=s.index('static void *agepad_translator_module;');b=s.index('\n#endif',a)
body=s[a:b]
pre=r'''
#include <assert.h>
#include <stddef.h>
#include <setjmp.h>
typedef unsigned UINT;typedef unsigned NTSTATUS;
typedef struct {long long QuadPart;} LARGE_INTEGER;
#define DLL_PROCESS_DETACH 0
#define FALSE 0
#define ERR(...) ((void)0)
struct ios_register_hold_release_params {unsigned size,version;void *peb,*callback;};
static struct {void *Peb;} teb;
#define NtCurrentTeb() (&teb)
static unsigned calls,waits,result;
static jmp_buf escaped;
static unsigned dispatch(struct ios_register_hold_release_params *p) {
 assert(p->size==sizeof(*p)&&p->version==4&&p->peb==teb.Peb&&!p->callback);
 calls++;return result;
}
#define WINE_UNIX_CALL(op,p) dispatch(p)
static void NtDelayExecution(int alertable,LARGE_INTEGER *pause) {
 assert(!alertable&&pause->QuadPart==-10000000);waits++;longjmp(escaped,1);
}
'''
main=r'''
int main(void) {
 int translator,foreign;teb.Peb=&teb;
 agepad_retire_translator_callbacks(&translator,0,&teb);assert(!calls);
 agepad_translator_module=&translator;
 agepad_retire_translator_callbacks(&foreign,0,&teb);
 agepad_retire_translator_callbacks(&translator,1,&teb);
 agepad_retire_translator_callbacks(&translator,0,NULL);assert(!calls);
 agepad_retire_translator_callbacks(&translator,0,&teb);assert(calls==1&&!waits);
 result=1;
 if(!setjmp(escaped)) {agepad_retire_translator_callbacks(&translator,0,&teb);assert(0);}
 assert(calls==2&&waits==1);
 return 0;
}
'''
# Check actual hook placement, not only the extracted selector.
f=s[s.index('static NTSTATUS MODULE_InitDLL'):s.index('static NTSTATUS MODULE_InitDLL')+3500]
assert f.index('call_tls_callbacks(')<f.index('agepad_retire_translator_callbacks(')<f.index('call_dll_entry_point(')
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'test.c';p.write_text(pre+body+main);exe=Path(d)/'test'
 subprocess.run(['clang','-fsanitize=address,undefined',str(p),'-o',str(exe)],check=True)
 subprocess.run([str(exe)],check=True,timeout=15)
print('PASS exact translator/termination selection and ABI-error nonreturn; TLS/entry hook ordering checked')
