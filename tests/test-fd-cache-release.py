#!/usr/bin/env python3
"""Compile the real cleanup body against host descriptors; no Simulator restart."""
from pathlib import Path
import argparse,subprocess,tempfile
r=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--source',type=Path,default=r/'worktrees/madeira/build/ntdll-unix/server_ios.c')
s=parser.parse_args().source.read_text()
a=s.index('union fd_cache_entry\n');b=s.index('\nC_ASSERT',a);entry=s[a:b]
a=s.index('void ios_fd_cache_release( void *peb )\n{');b=s.index('\n#define fd_cache ',a);release=s[a:b]
harness=r'''
#include <assert.h>
#include <errno.h>
#include <fcntl.h>
#include <pthread.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/mman.h>
#include <unistd.h>
typedef int64_t LONG64;
enum server_fd_type { FD_TYPE_FILE, FD_TYPE_INVALID=31 };
'''+entry+r'''
#define FD_CACHE_BLOCK_SIZE (65536 / sizeof(union fd_cache_entry))
#define FD_CACHE_ENTRIES 128
#define IOS_MAX_FD_CACHES 64
struct ios_fd_cache { union fd_cache_entry *blocks[FD_CACHE_ENTRIES]; union fd_cache_entry initial_block[FD_CACHE_BLOCK_SIZE]; };
static struct {void *peb;struct ios_fd_cache *cache;int in_use;} ios_fd_caches[IOS_MAX_FD_CACHES];
static int ios_fd_cache_count;
static pthread_mutex_t ios_fd_cache_alloc_lock=PTHREAD_MUTEX_INITIALIZER;
static __attribute__((unused)) LONG64 interlocked_xchg64(LONG64*p,LONG64 n){return __atomic_exchange_n(p,n,__ATOMIC_SEQ_CST);}
static void ios_fdt_note_close(int fd,const char*why,void*peb){(void)fd;(void)why;(void)peb;}
static void*unmapped;static size_t unmapped_size;static int unmap_count;
static __attribute__((unused)) int checked_munmap(void*p,size_t n){int rc=munmap(p,n);assert(rc==0);unmapped=p;unmapped_size=n;unmap_count++;return rc;}
#define munmap checked_munmap
'''+release+r'''
#undef munmap
static void expect_closed(int fd){errno=0;assert(fcntl(fd,F_GETFD)==-1 && errno==EBADF);}
int main(void){
 int p[2];assert(pipe(p)==0);assert(p[1]==p[0]+1);
 struct ios_fd_cache*c=calloc(1,sizeof(*c));assert(c);
 c->blocks[0]=c->initial_block;
 c->blocks[0][0].s.fd=p[0]+1;
 /* Error entries must never be interpreted as live descriptors. */
 c->blocks[0][1].s.fd=p[1]+1;c->blocks[0][1].s.type=FD_TYPE_INVALID;
 /* fd zero is valid and must be closed too, only in this test subprocess. */
 assert(dup2(p[0],0)==0);c->blocks[0][2].s.fd=1;
 union fd_cache_entry*extra=mmap(0,65536,PROT_READ|PROT_WRITE,MAP_PRIVATE|MAP_ANON,-1,0);assert(extra!=MAP_FAILED);
 c->blocks[1]=extra;
 ios_fd_caches[0].peb=(void*)1;ios_fd_caches[0].cache=c;ios_fd_caches[0].in_use=1;ios_fd_cache_count=1;
 ios_fd_cache_release((void*)1);
 expect_closed(p[0]);expect_closed(0);assert(fcntl(p[1],F_GETFD)>=0);
 assert(unmapped==extra && unmapped_size==65536 && unmap_count==1);
 ios_fd_cache_release((void*)1);assert(fcntl(p[1],F_GETFD)>=0);close(p[1]);
 puts("FD_CACHE_RELEASE_PASS: encoded fd, adjacent descriptor, error entry, fd zero, mmap block, repeat release");
}
'''
with tempfile.TemporaryDirectory(prefix='agepad-fd-cache-') as d:
 p=Path(d);(p/'test.c').write_text(harness)
 subprocess.run(['clang','-Wall','-Wextra','-Werror',str(p/'test.c'),'-o',str(p/'test')],check=True)
 subprocess.run([str(p/'test')],check=True)
