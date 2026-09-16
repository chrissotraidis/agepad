#!/usr/bin/env python3
"""Check trace startup snapshot and absence of environment reads in callbacks."""
from pathlib import Path
import subprocess,tempfile
r=Path(__file__).resolve().parents[1]/'worktrees/madeira'
s=(r/'wine/server/thread.c').read_text()
a=s.index('void agepad_server_init_trace(void)');b=s.index('\n}',a)+2;init=s[a:b]
for name in ['thread','async','completion']:
 text=(r/f'wine/server/{name}.c').read_text().replace(init,'')
 assert 'getenv("AGEPAD_STARTUP_TRACE")' not in text
assert 'getenv("AGEPAD_STARTUP_TRACE")' not in (r/'build/wineserver/mach_ios.c').read_text()
main=(r/'build/wineserver/main_ios.c').read_text();assert main.index('agepad_server_init_trace();')<main.index('main_loop();')
pre='''#include <assert.h>
#include <string.h>
static const char *value; static int calls,forbidden;
static char *getenv(const char *key){assert(!forbidden);assert(!strcmp(key,"AGEPAD_STARTUP_TRACE") || !strcmp(key,"AGEPAD_SIGNED_NTDLL"));calls++;return (char*)value;}
int agepad_server_startup_trace;
int agepad_server_signed_ntdll;
'''
post='''
int main(void){
 const char *values[]={0,"","0","1","1extra","true"};
 int expected[]={0,0,0,1,1,0};
 for(int i=0;i<6;i++){
  value=values[i];forbidden=0;agepad_server_init_trace();assert(calls==2*(i+1));assert(agepad_server_signed_ntdll==(value!=0));
  forbidden=1;value="changed";
  for(int j=0;j<100;j++)assert(agepad_server_startup_trace==expected[i]);
 }
}
'''
with tempfile.TemporaryDirectory() as d:
 d=Path(d);(d/'t.c').write_text(pre+init+post)
 subprocess.run(['clang','-fsanitize=address,undefined',str(d/'t.c'),'-o',str(d/'t')],check=True)
 subprocess.run([str(d/'t')],check=True)
print('PASS: startup parsing preserved; callback trace reads use snapshot, no trace getenv calls. Not a general libc signal-safety proof.')
