#!/usr/bin/env python3
"""Run the actual allocator on macOS to test ownership after thread exit.
Windows diagnostic writes and the disabled allocation-watch hook are stubbed.
Host allocator configuration differs from the Windows/FEX build; this tests
queue/live-object semantics, not the iPad VA geometry or full process teardown.
"""
from pathlib import Path
import subprocess,tempfile
root=Path(__file__).resolve().parents[1]
source=root/'worktrees/madeira/FEX/External/rpmalloc/rpmalloc/rpmalloc.c'
body=r'''
#include <assert.h>
#include <pthread.h>
volatile int FEX_AllocWatch_Armed=0;
void FEX_AllocWatch_Event(const void*ptr,unsigned int event){(void)ptr;(void)event;}
static heap_t *retired;
static unsigned char *shared;
static size_t queued_mapped;
static size_t heap_spans(heap_t *heap) {
 size_t size=0;
 for(int type=0;type<3;type++)for(span_t *s=heap->span_partial[type];s;s=s->next)size+=s->mapped_size;
 for(int type=0;type<4;type++)for(span_t *s=heap->span_used[type];s;s=s->next)size+=s->mapped_size;
 return size;
}
static void *worker(void *unused) {
 (void)unused;rpmalloc_thread_initialize();retired=get_thread_heap();
 shared=rpmalloc(2048);assert(shared);
 for(unsigned i=0;i<2048;i++)shared[i]=(unsigned char)(i*17+3);
 void *temporary=rpmalloc(131072);assert(temporary);rpfree(temporary);
 queued_mapped=heap_spans(retired);assert(queued_mapped>0);
 rpmalloc_thread_finalize();
 assert(get_thread_heap()==global_heap_default);
 assert(heap_spans(retired)==queued_mapped); /* Finalize queues, does not unmap. */
 return NULL;
}
int main(void) {
 assert(!rpmalloc_initialize(NULL));heap_t *parent=get_thread_heap();
 pthread_t thread;assert(!pthread_create(&thread,NULL,worker,NULL));assert(!pthread_join(thread,NULL));
 assert(retired!=parent);int queued=0;for(heap_t *h=global_heap_queue;h;h=h->next)queued+=(h==retired);
 assert(queued==1);assert(heap_spans(retired)==queued_mapped);
 /* A retired heap still backs another thread's valid allocation. */
 for(unsigned i=0;i<2048;i++)assert(shared[i]==(unsigned char)(i*17+3));
 span_t *span=block_get_span((block_t*)shared);page_t *page=span_get_page_from_block(span,shared);
 assert(page->block_used>0);
 rpfree(shared);shared=NULL;
 /* Remote free is deferred; queue membership alone is never an emptiness test. */
 assert(atomic_load_explicit(&page->thread_free,memory_order_acquire)!=0);
 assert(page->block_used>0);
 assert(global_config.unmap_on_finalize==0);
 /* Test cleanup only: all user pointers released, worker joined, no concurrent allocator use. */
 rpmalloc_finalize_with_unmap();assert(!global_heap_used&&!global_heap_queue);
 rpmalloc_finalize_with_unmap(); /* Idempotent once finalized. */
 puts("PASS retired heap preserves cross-thread live allocation; remote free remains deferred");
 return 0;
}
'''
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'test.c';p.write_text('static void *GetStdHandle(unsigned long n){(void)n;return (void*)1;}\nstatic int WriteFile(void*h,const void*p,unsigned long n,unsigned long*w,void*o){(void)h;(void)p;(void)o;if(w)*w=n;return 1;}\n#include "'+str(source)+'"\n'+body);exe=Path(d)/'test'
 subprocess.run(['clang','-std=c11','-O2','-pthread','-fsanitize=address,undefined',str(p),'-o',str(exe)],check=True)
 subprocess.run([str(exe)],check=True)
