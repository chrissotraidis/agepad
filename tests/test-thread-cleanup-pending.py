#!/usr/bin/env python3
"""Actual FEX cleanup lifetime guard/snapshot with stubbed thread identities.
Tests the gap between registry removal and completion; not a native join proof.
"""
from pathlib import Path
import subprocess,tempfile
root=Path(__file__).resolve().parents[1]
s=(root/'worktrees/madeira/FEX/Source/Windows/ARM64EC/Module.cpp').read_text()
a=s.index('static std::atomic<uint32_t> ThreadCleanupsInFlight');b=s.index('// Resource teardown',a);scope=s[a:b]
a=s.index('extern "C" uint32_t BTCpu64IosPendingThreadCleanup(');b=s.index('\nNTSTATUS ThreadTerm(',a);snapshot=s[a:b]
pre=r'''
#include <atomic>
#include <cassert>
#include <cstdint>
#include <map>
#define FEX_IOS_HOST 1
struct alignas(16) TEB {unsigned char bytes[0x1800];};
static TEB teb,other;static bool CTX=true;
static TEB *IOSLoadTEB(){return &teb;}
static struct {bool busy=false;bool try_lock(){return !busy;}void unlock(){}} ThreadCreationMutex;
static std::map<uint64_t,void*> Threads;
'''
main=r'''
int main(){
 *reinterpret_cast<uint64_t*>(teb.bytes+0x48)=12;
 assert(BTCpu64IosPendingThreadCleanup(nullptr)==0x230);
 assert(BTCpu64IosPendingThreadCleanup(&other)==UINT32_MAX);
 CTX=false;assert(BTCpu64IosPendingThreadCleanup(&teb)==UINT32_MAX);CTX=true;
 ThreadCreationMutex.busy=true;assert(BTCpu64IosPendingThreadCleanup(&teb)==UINT32_MAX);ThreadCreationMutex.busy=false;
 Threads[12]=(void*)1;assert(!BTCpu64IosPendingThreadCleanup(&teb));
 Threads[13]=(void*)2;assert(BTCpu64IosPendingThreadCleanup(&teb)==1);
 {
  ScopedThreadCleanup active;
  assert(BTCpu64IosPendingThreadCleanup(&teb)==2); // conservative overlap
  Threads.erase(13);
  assert(BTCpu64IosPendingThreadCleanup(&teb)==1); // map removal is NOT completion
  {ScopedThreadCleanup second;assert(BTCpu64IosPendingThreadCleanup(&teb)==2);}
  assert(BTCpu64IosPendingThreadCleanup(&teb)==1);
 }
 assert(!BTCpu64IosPendingThreadCleanup(&teb));
 try {ScopedThreadCleanup unwind;throw 1;}catch(int){}
 assert(!ThreadCleanupsInFlight.load());
}
'''
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'test.cpp';p.write_text(pre+scope+snapshot+main);exe=Path(d)/'test'
 subprocess.run(['clang++','-std=c++20','-fsanitize=address,undefined',str(p),'-o',str(exe)],check=True)
 subprocess.run([str(exe)],check=True)
print('PASS pending count covers registry removal through cleanup scope')
