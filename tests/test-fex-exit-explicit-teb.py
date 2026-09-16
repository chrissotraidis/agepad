#!/usr/bin/env python3
"""Extract cleanup callback; exercise native entry with no implicit guest TEB."""
from pathlib import Path
import subprocess,tempfile
root=Path(__file__).resolve().parents[1]
s=(root/'worktrees/madeira/FEX/Source/Windows/ARM64EC/Module.cpp').read_text()
a=s.index('extern "C" uint32_t BTCpu64IosReleaseThreadHolds(');b=s.index('\n#ifdef FEX_IOS_HOST',a);body=s[a:b]
pre=r'''
#include <cstdint>
#include <cassert>
#include <cstdio>
#include <cstdlib>
#include <cstring>
struct alignas(16) TEB { unsigned char bytes[0x1800]; }; using _TEB=TEB;
struct Frontend { bool InLockedRWXRead; } frontend;
struct ThreadCPUArea { TEB* teb; explicit ThreadCPUArea(TEB* t):teb(t){}
 Frontend* ThreadState(){assert(teb);return &frontend;} };
static Frontend* GetFrontendThreadData(Frontend* p){return p;}
static bool* IosInLockedRWXReadSlot(){std::puts("IMPLICIT_TEB_USED");std::exit(23);}
static ThreadCPUArea GetCPUArea(){std::puts("IMPLICIT_TEB_USED");std::exit(23);}
static TEB* current;
static int shared,exclusive,creation;
struct Mutex {uint64_t IosStampAddress(){return reinterpret_cast<uint64_t>(this);}
 void unlock(){++exclusive;}
 void unlock_shared(){++shared;auto& depth=*reinterpret_cast<uint32_t*>(current->bytes+0x16f0);
 assert(depth);if(!--depth)*reinterpret_cast<uint64_t*>(current->bytes+0x16f8)=0;}
} mutex;
struct Context {Mutex& GetCodeInvalidationMutex(){return mutex;}} ctx;
static Context* CTX=&ctx;
struct CreationMutex {void unlock(){++creation;}} ThreadCreationMutex;
'''
post=r'''
int main(){
 TEB teb{};current=&teb;uint64_t stamp;uint32_t depth,flags;
 auto& stored_stamp=*reinterpret_cast<uint64_t*>(teb.bytes+0x16f8);
 auto& stored_depth=*reinterpret_cast<uint32_t*>(teb.bytes+0x16f0);
 auto& rwx=*reinterpret_cast<bool*>(teb.bytes+0x1700);
 auto run=[&]{return BTCpu64IosReleaseThreadHolds(&teb,&stamp,&depth,&flags);};
 assert(BTCpu64IosReleaseThreadHolds(nullptr,nullptr,nullptr,nullptr)==16);
 assert(run()==0 && !stamp && !depth && !flags);
 stored_stamp=mutex.IosStampAddress();stored_depth=3;
 assert(run()==1 && shared==3 && !stored_stamp && !stored_depth);
 stored_stamp=123;stored_depth=2;
 assert(run()==4 && shared==3 && stored_stamp==123 && stored_depth==2);
 CTX=nullptr;assert(run()==8 && shared==3);CTX=&ctx;
 stored_stamp=0;stored_depth=0;rwx=true;frontend.InLockedRWXRead=true;
 assert(run()==2 && exclusive==1 && creation==1 && !rwx && !frontend.InLockedRWXRead);
 assert(run()==0 && shared==3 && exclusive==1);
 puts("PASS: explicit TEB, exact shared depth, foreign stamp refusal, no context, exclusive pair, repeated cleanup");
}
'''
with tempfile.TemporaryDirectory(prefix='agepad-explicit-teb-') as d:
 c=Path(d)/'test.cpp';exe=Path(d)/'test'
 def build(body):
  c.write_text(pre+body+post)
  subprocess.run(['xcrun','clang++','-std=c++20','-fsanitize=address,undefined',str(c),'-o',str(exe)],check=True)
 build(body);subprocess.run([str(exe)],check=True,timeout=10)
 bad=body.replace('reinterpret_cast<bool*>(reinterpret_cast<uintptr_t>(Teb) + 0x1700)','IosInLockedRWXReadSlot()')
 assert bad!=body;build(bad)
 r=subprocess.run([str(exe)],capture_output=True,timeout=10)
 assert r.returncode==23 and b'IMPLICIT_TEB_USED' in r.stdout
 print('PASS: negative control detects implicit TEB access')

 bad=body.replace('ThreadCPUArea(Teb).ThreadState()', 'GetCPUArea().ThreadState()')
 assert bad!=body;build(bad)
 r=subprocess.run([str(exe)],capture_output=True,timeout=10)
 assert r.returncode==23 and b'IMPLICIT_TEB_USED' in r.stdout
 print('PASS: negative control detects implicit CPU-area access')
