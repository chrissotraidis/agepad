#!/usr/bin/env python3
"""Execute the actual native enumerator with independent guest identities."""
from pathlib import Path
import subprocess,tempfile
root=Path(__file__).resolve().parents[1]
source=(root/'worktrees/madeira/build/crypto-unix/crypt32_unixlib_ios.c').read_text()
fragment=source[source.index('struct root_enum_cursor'):source.index('\nconst unixlib_entry_t')]
preamble=r'''
#include <assert.h>
#include <stdlib.h>
#include <string.h>
#include <stddef.h>
#include <pthread.h>
typedef int BOOL;
typedef unsigned NTSTATUS;
#define TRUE 1
#define STATUS_SUCCESS 0
#define STATUS_UNSUCCESSFUL 0xc0000001u
#define STATUS_NO_MEMORY 0xc0000017u
#define STATUS_NO_MORE_ENTRIES 0x8000001au
struct list { struct list *next,*prev; };
#define LIST_ENTRY(p,t,m) ((t*)((char*)(p)-offsetof(t,m)))
static struct list root_cert_list={&root_cert_list,&root_cert_list};
static struct list *list_head(struct list *h) {return h->next==h?NULL:h->next;}
static struct list *list_next(struct list *h,struct list *p) {return p->next==h?NULL:p->next;}
struct root_cert {struct list entry;size_t size;unsigned char data[4];};
struct enum_root_certs_params {void *buffer;unsigned size;unsigned *needed;};
static _Thread_local struct {void *Peb;} teb;
#define NtCurrentTeb() (&teb)
static int loads, empty_load;
static void load_root_certs(void) {
 static struct root_cert certs[2];
 loads++;
 if(empty_load)return;
 for(int i=0;i<2;i++) {
  certs[i].size=4;memset(certs[i].data,'A'+i,4);
  struct list *e=&certs[i].entry;e->prev=root_cert_list.prev;e->next=&root_cert_list;
  e->prev->next=e;root_cert_list.prev=e;
 }
}
'''
main=r'''
static void check(unsigned expected,unsigned size,NTSTATUS status) {
 unsigned needed=0;char data[4]={0};struct enum_root_certs_params p={data,size,&needed};
 assert(enum_root_certs(&p)==status);
 if(status==STATUS_SUCCESS) {assert(needed==4);if(size>=4) for(int i=0;i<4;i++)assert(data[i]==expected);}
}
static void *run(void *owner) {teb.Peb=owner;check('A',4,0);check('B',4,0);check(0,4,STATUS_NO_MORE_ENTRIES);return NULL;}
int main(void) {
 int owners[6];teb.Peb=&owners[0];
 empty_load=1;check(0,4,STATUS_UNSUCCESSFUL);assert(root_enum_cursors==NULL);
 empty_load=0;check('A',1,0);check('A',4,0);
 teb.Peb=&owners[1];check('A',4,0);
 teb.Peb=&owners[0];check('B',4,0);check(0,4,STATUS_NO_MORE_ENTRIES);
 teb.Peb=&owners[1];check('B',4,0);check(0,4,STATUS_NO_MORE_ENTRIES);
 pthread_t threads[4];for(int i=0;i<4;i++)assert(!pthread_create(&threads[i],0,run,&owners[i+2]));
 for(int i=0;i<4;i++)pthread_join(threads[i],0);
 assert(loads==2);assert(list_head(&root_cert_list));
 return 0;
}
'''
with tempfile.TemporaryDirectory() as directory:
 c=Path(directory)/'enum.c';exe=Path(directory)/'enum';c.write_text(preamble+fragment+main)
 subprocess.run(['clang','-std=c11','-pthread','-fsanitize=address,undefined',str(c),'-o',str(exe)],check=True)
 subprocess.run([str(exe)],check=True)
print('PASS: actual enumerator preserves roots, independent cursors, short-buffer retry and concurrent guests')
