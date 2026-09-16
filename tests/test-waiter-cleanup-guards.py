#!/usr/bin/env python3
"""Execute actual FEX bridge guards; destructive helper is stubbed."""
from pathlib import Path
import subprocess,tempfile
root=Path(__file__).resolve().parents[1]
s=(root/'worktrees/madeira/FEX/Source/Windows/ARM64EC/Module.cpp').read_text()
a=s.index('extern "C" uint32_t BTCpu64IosCleanupTerminatedWaiter(');s=s[a:s.index('\n}\n',a)+3]
pre=r'''
#include <cassert>
#include <cstdint>
#include <map>
#define FEX_IOS_HOST 1
struct alignas(16) TEB {unsigned char bytes[0x1800];};
static TEB teb,other;static TEB *current=&teb;static bool CTX=true,has_area=true,on_stack=false;
static void *state=(void*)0x1234;static int destroyed=0;
TEB *IOSLoadTEB(){return current;}
struct ThreadCPUArea {
 void *Area;ThreadCPUArea(TEB*) : Area(has_area?(void*)1:nullptr) {}
 void *ThreadState()const{return state;}
};
bool IsEmulatorStackAddress(ThreadCPUArea,uintptr_t){return on_stack;}
static struct {bool busy=false;bool try_lock(){return !busy;}void unlock(){}} ThreadCreationMutex;
static std::map<uint64_t,void*> Threads;
static unsigned DestroyRegisteredThreadState(ThreadCPUArea,uint64_t tid,bool self){assert(tid==12&&self);destroyed++;return 0;}
'''
main=r'''
int main(){
 *reinterpret_cast<uint64_t*>(teb.bytes+0x48)=12;Threads[12]=state;
 assert(BTCpu64IosCleanupTerminatedWaiter(nullptr)==0x229);
 assert(BTCpu64IosCleanupTerminatedWaiter(&other)==1);
 CTX=false;assert(BTCpu64IosCleanupTerminatedWaiter(&teb)==1);CTX=true;
 has_area=false;assert(BTCpu64IosCleanupTerminatedWaiter(&teb)==2);has_area=true;
 void *saved=state;state=nullptr;assert(BTCpu64IosCleanupTerminatedWaiter(&teb)==2);state=saved;
 on_stack=true;assert(BTCpu64IosCleanupTerminatedWaiter(&teb)==3);on_stack=false;
 for(unsigned offset:{0x16f0u,0x16f8u,0x1700u}){teb.bytes[offset]=1;assert(BTCpu64IosCleanupTerminatedWaiter(&teb)==4);teb.bytes[offset]=0;}
 ThreadCreationMutex.busy=true;assert(BTCpu64IosCleanupTerminatedWaiter(&teb)==5);ThreadCreationMutex.busy=false;
 Threads.clear();assert(BTCpu64IosCleanupTerminatedWaiter(&teb)==6);
 Threads[12]=(void*)0x2345;assert(BTCpu64IosCleanupTerminatedWaiter(&teb)==6);
 assert(!destroyed);Threads[12]=state;assert(!BTCpu64IosCleanupTerminatedWaiter(&teb));assert(destroyed==1);
}
'''
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'test.cpp';p.write_text(pre+s+main);exe=Path(d)/'test'
 subprocess.run(['clang++','-std=c++20','-fsanitize=address,undefined',str(p),'-o',str(exe)],check=True)
 subprocess.run([str(exe)],check=True)
print('PASS bridge rejection guards; destructive helper is mocked')
