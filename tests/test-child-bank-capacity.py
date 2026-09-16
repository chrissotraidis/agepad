#!/usr/bin/env python3
"""Exercise the native bank allocator, including concurrent reservations."""
from pathlib import Path
import subprocess,tempfile,re
r=Path(__file__).resolve().parents[1];s=(r/'port/windows/SignedNTDLLLoader.h').read_text()
cap=int(re.search(r'AGEPAD_CHILD_BANK_CAPACITY (\d+)',s)[1]);images=int(re.search(r'AGEPAD_SIGNED_IMAGE_CAPACITY (\d+)',s)[1])
assert (r/'worktrees/madeira/build/ntdll-unix/agepad_signed_ntdll.h').read_text()==s
assert f'j < {images}; ++j' in (r/'worktrees/madeira/wine/dlls/ntdll/loader.c').read_text()
assert (cap+1)*15 <= images
start=s.index('static pthread_mutex_t agepad_child_bank_mutex');end=s.index('\nBOOL agepad_signed_owner_registered',start)
body=s[start:end]
source='''#include <pthread.h>
#include <assert.h>
#include <stdio.h>
typedef int BOOL;
#define AGEPAD_CHILD_BANK_CAPACITY '''+str(cap)+'\n'+body+'''
static int owners[AGEPAD_CHILD_BANK_CAPACITY+1];
static unsigned assigned[AGEPAD_CHILD_BANK_CAPACITY];
static void *reserve(void *arg){size_t i=(size_t)arg;for(int n=0;n<10000;n++){
 unsigned s=agepad_child_bank(&owners[i],1);assert(s && s<=AGEPAD_CHILD_BANK_CAPACITY);
 if(n)assert(assigned[i]==s);else assigned[i]=s;}return NULL;}
int main(void){pthread_t threads[AGEPAD_CHILD_BANK_CAPACITY];
 assert(!agepad_child_bank(&owners[AGEPAD_CHILD_BANK_CAPACITY],0));
 for(size_t i=0;i<AGEPAD_CHILD_BANK_CAPACITY;i++)assert(!pthread_create(&threads[i],NULL,reserve,(void*)i));
 for(int i=0;i<AGEPAD_CHILD_BANK_CAPACITY;i++)assert(!pthread_join(threads[i],NULL));
 for(int i=0;i<AGEPAD_CHILD_BANK_CAPACITY;i++)for(int j=i+1;j<AGEPAD_CHILD_BANK_CAPACITY;j++)assert(assigned[i]!=assigned[j]);
 assert(!agepad_child_bank(&owners[AGEPAD_CHILD_BANK_CAPACITY],1));
 puts("CHILD_BANK_CAPACITY_PASS: concurrent unique stable reservations; extra owner refused");}
'''
with tempfile.TemporaryDirectory(prefix='agepad-banks-') as d:
 p=Path(d);(p/'test.c').write_text(source)
 subprocess.run(['clang','-O2','-Wall','-Wextra','-Werror','-pthread',str(p/'test.c'),'-o',str(p/'test')],check=True)
 subprocess.run([str(p/'test')],check=True)
