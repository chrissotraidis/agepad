#!/usr/bin/env python3
"""Exercise server stream while another thread holds guest stderr's FILE lock."""
from pathlib import Path
import subprocess,tempfile
r=Path(__file__).resolve().parents[1]/'worktrees/madeira'
s=(r/'wine/server/thread.c').read_text();a=s.index('FILE *agepad_server_log_stream;');b=s.index('\nint agepad_server_startup_trace;',a);code=s[a:b]
main=(r/'build/wineserver/main_ios.c').read_text();assert main.index('agepad_server_init_log_stream()')<main.index('agepad_server_init_trace()')<main.index('main_loop()')
assert '#define stderr agepad_server_log_stream' in (r/'wine/server/object.h').read_text()
pre=r'''
#include <stdio.h>
#include <unistd.h>
#include <pthread.h>
#include <stdatomic.h>
#include <assert.h>
#include <sched.h>
static atomic_int held,done;
static void *guest(void *p){flockfile(stderr);atomic_store(&held,1);while(!atomic_load(&done))sched_yield();funlockfile(stderr);return 0;}
'''
post=r'''
int main(void){
 assert(agepad_server_init_log_stream());FILE *same=agepad_server_log_stream;
 assert(agepad_server_init_log_stream() && same==agepad_server_log_stream);
 assert(agepad_server_log_stream!=stderr);
 pthread_t t;assert(!pthread_create(&t,0,guest,0));
 while(!atomic_load(&held))sched_yield();
 fprintf(agepad_server_log_stream,"SERVER_REPLY_LOG\\n");fflush(agepad_server_log_stream);
 atomic_store(&done,1);assert(!pthread_join(t,0));fclose(agepad_server_log_stream);
}
'''
with tempfile.TemporaryDirectory() as d:
 d=Path(d)
 for name,c,ok in [('isolated',post,True),('shared-negative',post.replace('fprintf(agepad_server_log_stream,','fprintf(stderr,'),False)]:
  (d/'t.c').write_text(pre+code+c)
  subprocess.run(['clang','-fsanitize=address,undefined',str(d/'t.c'),'-o',str(d/'t')],check=True)
  try:
   result=subprocess.run([str(d/'t')],capture_output=True,timeout=3)
   assert ok and result.returncode==0 and b'SERVER_REPLY_LOG' in result.stderr,(name,result)
  except subprocess.TimeoutExpired:assert not ok,name
print('PASS: isolated server stream logs while guest holds stderr; shared-stream negative control deadlocks. No general libc lock-safety claim.')
