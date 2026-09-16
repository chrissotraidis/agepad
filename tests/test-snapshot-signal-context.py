#!/usr/bin/env python3
"""Exercise actual server signal-context merge after a completed Mach snapshot.
Uses small flag-addressed register groups in place of architecture register unions.
Does not establish native suspension, full context API, or game correctness.
"""
from pathlib import Path
import subprocess,tempfile
root=Path(__file__).resolve().parents[1]
s=(root/'worktrees/madeira/wine/server/thread.c').read_text()
a=s.index('static void ios_context_begin_signal(');b=s.index('\n#endif',a);helper=s[a:b]
a=s.index('        if ((ctx = current->context))',s.index('DECL_HANDLER(select)'));b=s.index('        current->suspend_cookie =',a);merge=s[a:b].replace("))) return;", "))) return 0;") # adapt void-handler allocation failure to harness result
# Ensure the executed bookkeeping is wired to snapshot capture and both set paths.
assert 'thread->context->ios_mach_snapshot = 1;\n            thread->context->status = STATUS_SUCCESS;' in s
for index in ['CTX_NATIVE','CTX_WOW']:assert f'thread->context->ios_modified_flags[{index}] |=' in s
pre=r'''
#include <assert.h>
#include <string.h>
#include <stdio.h>
#define WINE_IOS 1
#define STATUS_SUCCESS 0
#define STATUS_PENDING 259
#define CTX_NATIVE 0
#define CTX_WOW 1
struct context_data {unsigned flags,machine;unsigned values[4];};
struct context {unsigned status;struct context_data regs[2];int ios_mach_snapshot;unsigned ios_modified_flags[2];};
struct process {unsigned machine;};
struct thread {struct context *context;struct process *process;};
static unsigned system_flags=8;
static struct context* create_thread_context(struct thread *t){assert(0);return 0;}
static void copy_context(struct context_data *d,const struct context_data *s,unsigned flags){for(int i=0;i<4;i++)if(flags&(1u<<i))d->values[i]=s->values[i];d->flags|=flags;}
'''
wrapper='''
static int publish(struct thread *current,const struct context_data *native_context,const struct context_data *wow_context){struct context *ctx;
'''+merge+'''
return 1;
invalid_param:return 0;
}
'''
post=r'''
int main(void){
 struct context_data fresh={7,1,{100,200,300,400}},wow={7,2,{500,600,700,800}};
 struct context c={0};struct process process={2};struct thread t={&c,&process};
 c.status=0;c.ios_mach_snapshot=1;c.regs[0]=(struct context_data){15,1,{1,2,3,4}};
 assert(publish(&t,&fresh,0));assert(c.status==0&&!c.ios_mach_snapshot);
 assert(c.regs[0].values[0]==100&&c.regs[0].values[1]==200&&c.regs[0].flags==7);
 /* A snapshot edit survives; untouched snapshot PC-like groups do not. */
 c=(struct context){0};c.ios_mach_snapshot=1;c.regs[0]=(struct context_data){15,1,{10,20,30,40}};c.ios_modified_flags[0]=2;
 assert(publish(&t,&fresh,0));assert(c.regs[0].values[0]==100&&c.regs[0].values[1]==20&&c.regs[0].values[2]==300);
 /* WOW edits take precedence using the original pending-context filtering. */
 c=(struct context){0};c.ios_mach_snapshot=1;c.regs[0]=(struct context_data){15,1,{10,20,30,40}};c.regs[1]=(struct context_data){15,2,{50,60,70,80}};c.ios_modified_flags[0]=1;c.ios_modified_flags[1]=2;
 assert(publish(&t,&fresh,&wow));assert(c.regs[0].values[0]==10&&c.regs[0].values[1]==200);assert(c.regs[1].values[0]==500&&c.regs[1].values[1]==60);
 /* Ordinary pending edits remain intact, not treated as stale snapshots. */
 c=(struct context){0};c.status=259;c.regs[0]=(struct context_data){1,1,{42,0,0,0}};
 assert(publish(&t,&fresh,0));assert(c.regs[0].values[0]==42&&c.regs[0].values[1]==200);
 /* Ordinary completed contexts and snapshot errors remain rejected. */
 c=(struct context){0};assert(!publish(&t,&fresh,0));c.ios_mach_snapshot=1;c.status=99;assert(!publish(&t,&fresh,0));assert(c.status==99);
 puts("PASS snapshot-to-signal publication, explicit edits, WOW precedence, pending and rejection cases");
}
'''
with tempfile.TemporaryDirectory(prefix='agepad-context-') as d:
 p=Path(d)/'test.c';exe=Path(d)/'test'
 for label,h in [('fixed',helper),('old-rejection',helper.replace('context->status = STATUS_PENDING;','/* original rejection */')),('stale-registers',helper.replace('context->regs[CTX_NATIVE].flags &= context->ios_modified_flags[CTX_NATIVE];','/* keep stale snapshot flags */'))]:
  p.write_text(pre+h+wrapper+post)
  subprocess.run(['xcrun','clang','-fsanitize=address,undefined',str(p),'-o',str(exe)],check=True)
  r=subprocess.run([str(exe)],capture_output=True,text=True,timeout=10)
  if label=='fixed':assert r.returncode==0,r.stderr;print(r.stdout.strip())
  else:assert r.returncode!=0;print('PASS negative control:',label)
