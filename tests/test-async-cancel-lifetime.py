#!/usr/bin/env python3
"""Exercise actual cancellation traversal with synchronous/reentrant completion."""
from pathlib import Path
import subprocess, tempfile, argparse
root=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('--source',type=Path,default=root/'worktrees/madeira/wine/server/async.c');a=p.parse_args()
s=a.source.read_text()
def function(start,end):return s[s.index(start):s.index(end,s.index(start))]
complete=function('static void async_complete_cancel(', '\n/* store the result')
cancel=function('static int cancel_process_async(', '\nstatic int cancel_blocking(')
pre=r'''
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include "wine/list.h"
typedef unsigned long client_ptr_t;
typedef unsigned obj_handle_t;
#define SYNCHRONIZE 1
struct object {unsigned refcount,kind;};
struct thread {int unused;};
struct process {struct list asyncs;};
struct async_cancel {struct object obj; struct object *sync; unsigned count;};
struct async {struct object obj;struct list process_entry;int terminated,is_system,canceled;void *fd;struct thread *thread;struct {client_ptr_t iosb;}data;struct async_cancel *async_cancel;int immediate;};
static unsigned live_async,live_group,signals;
static struct async *sibling;
static struct async_cancel *handle_group;
static void *grab_object(void *p){struct object *o=p;assert(o->refcount);o->refcount++;return p;}
static void release_object(void *p){struct object *o=p;assert(o->refcount);if(--o->refcount)return;
 if(o->kind==1){struct async *a=p;assert(!a->async_cancel);list_remove(&a->process_entry);live_async--;}
 else{live_group--;} free(p);}
static struct async_cancel *create_async_cancel(struct process *p){(void)p;struct async_cancel *c=calloc(1,sizeof(*c));c->obj=(struct object){1,2};live_group++;return c;}
static void signal_sync(struct object *o){(void)o;signals++;}
static void *get_fd_user(void *fd){return fd;}
static unsigned alloc_handle(struct process *p,void *c,unsigned rights,unsigned flags){(void)p;(void)rights;(void)flags;assert(!handle_group);handle_group=grab_object(c);return 42;}
'''
mid=r'''
static void finish(struct async *a){a->terminated=1;async_complete_cancel(a);release_object(a);}
static void cancel_async(struct async *a){a->canceled=1;
 if(sibling){struct async *b=sibling;sibling=NULL;finish(b);}
 if(a->immediate)finish(a);
}
static struct async *add(struct process *p,struct thread *t,int immediate){struct async *a=calloc(1,sizeof(*a));a->obj=(struct object){1,1};a->thread=t;a->immediate=immediate;list_add_tail(&p->asyncs,&a->process_entry);live_async++;return a;}
'''
post=r'''
int main(void){struct process p;struct thread t={0};unsigned h=0;list_init(&p.asyncs);
 /* Final reference is released inside callback, with a completion group. */
 add(&p,&t,1);assert(cancel_process_async(&p,NULL,&t,0,&h)==1);assert(!h&&!live_async&&!live_group&&list_empty(&p.asyncs));
 /* No group for CancelIoEx-style request. */
 add(&p,&t,1);assert(cancel_process_async(&p,NULL,NULL,0,&h)==1);assert(!live_async&&!live_group);
 /* Deferred + immediate siblings: group stays alive until deferred completion. */
 struct async *later=add(&p,&t,0);add(&p,&t,1);
 assert(cancel_process_async(&p,NULL,&t,0,&h)==2);assert(h==42&&live_async==1&&live_group==1&&signals==0);
 finish(later);assert(signals==1&&!live_async&&live_group==1);release_object(handle_group);handle_group=NULL;assert(!live_group);h=0;
 /* Callback destroys another process-list member: traversal must restart. */
 add(&p,&t,1);sibling=add(&p,&t,0);assert(cancel_process_async(&p,NULL,&t,0,&h)==1);assert(!live_async&&!live_group&&!h&&list_empty(&p.asyncs));
 /* Empty selection must release the group's construction reference. */
 assert(cancel_process_async(&p,NULL,&t,0,&h)==0);assert(!live_group&&!h);
 puts("ASYNC_CANCEL_LIFETIME_PASS: immediate/deferred completion, sibling removal, empty selection; no outstanding references");
}
'''
with tempfile.TemporaryDirectory(prefix='agepad-async-') as d:
 d=Path(d);(d/'test.c').write_text(pre+complete+mid+cancel+post)
 subprocess.run(['clang','-g','-O1','-fsanitize=address,undefined','-I',str(root/'worktrees/madeira/wine/include'),str(d/'test.c'),'-o',str(d/'test')],check=True)
 subprocess.run([str(d/'test')],check=True)
