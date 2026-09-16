#!/usr/bin/env python3
"""Execute the real bounded chunk-reuse helper against poisoned allocations."""
from pathlib import Path
import subprocess,tempfile
r=Path(__file__).resolve().parents[1]
s=(r/'worktrees/madeira/build/ntdll-unix/virtual_ios.c').read_text()
a=s.index('static struct { void *base; SIZE_T size; BOOL released; void *owner; BOOL reusable; }')
struct=s[a:s.index('\n',a)]
a=s.index('static void *agepad_jit_reuse_chunk(');b=s.index('\n/* Called with virtual_mutex',a)
helper=s[a:b]
code='''#include <assert.h>
#include <string.h>
#include <stdint.h>
#include <stdlib.h>
typedef size_t SIZE_T; typedef int BOOL;
#define TRUE 1
#define FALSE 0
'''+struct+'\nstatic unsigned int agepad_jit_count;\n'+helper+'''
int main(void) {
 unsigned char buffers[5][64]; memset(buffers,0xa5,sizeof buffers);
 void *owner=(void*)1;
 for(unsigned i=0;i<5;i++) {
  agepad_jit_chunks[i].base=buffers[i]; agepad_jit_chunks[i].size=64;
  agepad_jit_chunks[i].owner=owner; agepad_jit_chunks[i].released=1;
  agepad_jit_chunks[i].reusable=1;
 }
 agepad_jit_count=5;
 agepad_jit_chunks[0].owner=(void*)2; /* other process */
 agepad_jit_chunks[1].released=0; /* still allocated */
 agepad_jit_chunks[2].reusable=0; /* partial release */
 agepad_jit_chunks[3].size=32; /* no splitting/coalescing */
 assert(agepad_jit_reuse_chunk(owner,64)==buffers[4]);
 for(unsigned i=0;i<64;i++) assert(buffers[4][i]==0);
 for(unsigned i=0;i<4;i++) for(unsigned j=0;j<64;j++) assert(buffers[i][j]==0xa5);
 assert(!agepad_jit_chunks[4].released && !agepad_jit_chunks[4].reusable);
 assert(agepad_jit_reuse_chunk(owner,64)==NULL); /* cannot allocate twice */
 assert(agepad_jit_reuse_chunk((void*)3,64)==NULL);
 return 0;
}
'''
with tempfile.TemporaryDirectory() as d:
 p=Path(d);(p/'test.c').write_text(code)
 subprocess.run(['clang','-std=c11','-fsanitize=address,undefined','-g',str(p/'test.c'),'-o',str(p/'test')],check=True)
 subprocess.run([str(p/'test')],check=True)
 # Removing owner isolation must be caught by the same execution test.
 (p/'bad.c').write_text(code.replace('agepad_jit_chunks[i].owner != owner || ',''))
 subprocess.run(['clang','-std=c11',str(p/'bad.c'),'-o',str(p/'bad')],check=True)
 result=subprocess.run([str(p/'bad')],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
 assert result.returncode != 0
print('JIT chunk reuse helper: zeroing, owner/size/lifetime guards and negative control pass')
