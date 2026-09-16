#!/usr/bin/env python3
"""Actual registry helpers: concurrent saturation and bounded lookup, ASan/UBSan.
Child-startup rejection wiring is inspected, not an end-to-end guest test.
"""
from pathlib import Path
import subprocess, tempfile
root=Path(__file__).resolve().parents[1]
s=(root/'worktrees/madeira/build/ntdll-unix/server_ios.c').read_text()
registry=s[s.index('#define IOS_MAX_PROC_SOCKETS'):s.index('/* ─── ml586')]
a=s.index('static BOOL ios_register_proc_socket(')
register=s[a:s.index('\n#endif',a)]
preamble=r'''
#include <assert.h>
#include <pthread.h>
#include <stdio.h>
#include <stddef.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/socket.h>
#include <errno.h>
typedef int BOOL;
#define TRUE 1
#define FALSE 0
#define FDT_MASTER 1
#define wine_log_write(...) ((void)0)
static int fd_socket=777, process_exiting;
static _Thread_local void *owner;
void *ios_jit_current_peb(void) {return owner;}
static void ios_fdt_reg(int fd,int kind,void *peb) {(void)fd;(void)kind;(void)peb;}
'''
prefix=s[s.index('size_t server_init_process_child('):s.index('    /* Do NOT set up signal mask',s.index('size_t server_init_process_child('))]
prefix_preamble=r'''
typedef int obj_handle_t;
typedef unsigned DWORD;
struct ntdll_thread_data {int unused;};
static struct ntdll_thread_data dummy;
static struct ntdll_thread_data *ntdll_get_thread_data(void) {return &dummy;}
'''
prefix += '    return 17; /* Harness: stop before protocol handshake. */\n}\n'
main=r'''
static int ids[128], results[128];
static void *worker(void *arg) {
 int i=*(int*)arg;owner=&ids[i];
 results[i]=ios_register_proc_socket(owner,1000+i);
 if(results[i]) {assert(ios_current_fd_socket()==1000+i);assert(!*ios_process_exiting_ptr());}
 else assert(ios_proc_socket_index()==-1);
 return NULL;
}
int main(void) {
 pthread_t threads[128];
 for(int round=0;round<8;round++) {
  memset(ios_proc_sockets,0,sizeof(ios_proc_sockets));ios_proc_socket_count=0;
  assert(!ios_register_proc_socket(NULL,99));assert(ios_proc_socket_count==0);
  for(int i=0;i<128;i++){ids[i]=i;assert(!pthread_create(&threads[i],NULL,worker,&ids[i]));}
  int accepted=0;
  for(int i=0;i<128;i++){assert(!pthread_join(threads[i],NULL));accepted+=results[i];}
  assert(accepted==64);assert(ios_proc_socket_count==64);
  for(int i=0;i<128;i++) {
   owner=&ids[i];assert((ios_proc_socket_index()>=0)==results[i]);
   if(results[i])assert(ios_current_fd_socket()==1000+i);
  }
  owner=&accepted;assert(!ios_register_proc_socket(owner,42));assert(ios_proc_socket_count==64);
  /* Defensive lookup bound even if a legacy/invalid count is encountered. */
  int parent[2],child[2];assert(!socketpair(AF_UNIX,SOCK_STREAM,0,parent));
  assert(!socketpair(AF_UNIX,SOCK_STREAM,0,child));
  fd_socket=parent[0];
  assert(server_init_process_child(child[0])==(size_t)-1);
  assert(fcntl(child[0],F_GETFD)==-1 && errno==EBADF);
  char byte='x',got=0;assert(write(parent[0],&byte,1)==1);assert(read(parent[1],&got,1)==1 && got==byte);
  assert(read(child[1],&got,1)==0); /* Rejected child's peer sees EOF. */
  close(parent[0]);close(parent[1]);close(child[1]);fd_socket=777;
  ios_proc_socket_count=100000;assert(ios_proc_socket_index()==-1);
  owner=NULL;assert(ios_current_fd_socket()==777);
 }
 puts("PASS: concurrent capacity rejection, published owner lookup, defensive bound");
}
'''
# Check actual startup wiring in addition to executing the registry itself.
child=s[s.index('size_t server_init_process_child('):]
reject=child[child.index('if (!ios_register_proc_socket'):child.index('/* Do NOT set up signal mask')]
assert 'close( child_fd_socket );' in reject and 'return (size_t)-1;' in reject
assert 'process_exit_wrapper(' not in reject and 'close( fd_socket )' not in reject
loader=(root/'worktrees/madeira/build/ntdll-unix/loader_ios.c').read_text()
a=loader.index('if (child_startup_size == (size_t)-1)')
reject=loader[a:loader.index('startup_info_size = child_startup_size;',a)]
for token in ['peb = parent_peb;', 'main_argc = parent_argc;', 'main_argv = parent_argv;', 'return;']:
 assert token in reject
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'probe.c'; p.write_text(preamble+registry+register+prefix_preamble+prefix+main)
 exe=Path(d)/'probe'
 subprocess.run(['clang','-std=c11','-pthread','-fsanitize=address,undefined','-g',str(p),'-o',str(exe)],check=True)
 subprocess.run([str(exe)],check=True)
