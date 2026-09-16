#!/usr/bin/env python3
"""Inject reserve/commit failures into the actual CallRetStack implementation."""
from pathlib import Path
import subprocess,tempfile
root=Path(__file__).resolve().parents[1]
s=(root/'worktrees/madeira/FEX/Source/Windows/Common/CallRetStack.h').read_text()
fragment=s[s.index('namespace FEX::Windows::CallRetStack {'):]
preamble=r'''
#include <cstdint>
#include <cstdlib>
#include <cstddef>
#include <cassert>
#define FEX_IOS_HOST 1
#define MEM_RESERVE 1
#define MEM_COMMIT 2
#define MEM_RELEASE 4
#define PAGE_NOACCESS 0
#define PAGE_READWRITE 1
#define MemExtendedParameterAddressRequirements 1
struct MEM_ADDRESS_REQUIREMENTS {void *LowestStartingAddress, *HighestEndingAddress;};
struct MEM_EXTENDED_PARAMETER {int Type;void *Pointer;};
uintptr_t ios_fex_band_base=1,ios_fex_band_end=2;
static int failure, reserves, commits, releases, scrubs, names;
static void *allocation;
void *VirtualAlloc2(void*,void*,size_t n,int,int,void*,int) {
 ++reserves;if(failure==1)return nullptr;return allocation=malloc(n);
}
void *VirtualAlloc(void *p,size_t,int,int) {++commits;return failure==2?nullptr:p;}
bool VirtualFree(void *p,size_t,int) {assert(p==allocation);++releases;free(p);allocation=nullptr;return true;}
namespace LogMan::Msg {template<class... T>void EFmt(const char*,T...){} template<class... T>void DFmt(const char*,T...){} }
namespace FEXCore {
namespace Utils {constexpr size_t FEX_PAGE_SIZE=4096;}
namespace X86State {constexpr int REG_RSP=4;}
namespace Core {
struct CPUState {uint64_t rip=0,gregs[16]{},callret_sp=0,callret_sp_base=0,flags=0;};
struct CpuStateFrame {CPUState State;};
struct InternalThreadState {
 static constexpr size_t CALLRET_STACK_SIZE=8*1024*1024;
 static constexpr size_t CALLRET_LIVE_OFFSET=CALLRET_STACK_SIZE/8,CALLRET_LIVE_SIZE=CALLRET_STACK_SIZE/4;
 void *CallRetStackBase=nullptr;
 CpuStateFrame frame;CpuStateFrame *CurrentFrame=&frame;
};
}
namespace Allocator {
enum class THPControl {Disable};
void VirtualName(const char*,const void*,size_t){++names;}
void VirtualTHPControl(const void*,size_t,THPControl){}
size_t ZeroScrub(void *p,size_t n){assert(p==(char*)allocation+4096);assert(n==8*1024*1024);++scrubs;return 0;}
}
}
'''
main=r'''
int main(){
 using namespace FEX::Windows::CallRetStack;
 for(int mode=1;mode<=2;++mode){
  failure=mode;reserves=commits=releases=scrubs=names=0;
  FEXCore::Core::InternalThreadState t;
  t.frame.State.callret_sp=123;t.frame.State.callret_sp_base=456;
  assert(!InitializeThread(&t));assert(!t.CallRetStackBase);
  assert(!t.frame.State.callret_sp && !t.frame.State.callret_sp_base);
  assert(reserves==1 && commits==(mode==2) && releases==(mode==2));assert(scrubs==0);
  if(mode==1)assert(names==0);
  DestroyThread(&t);assert(releases==(mode==2));
  uint64_t sp=99;assert(!HandleAccessViolation(&t,0,sp));assert(sp==99);
 }
 failure=0;reserves=commits=releases=scrubs=0;
 FEXCore::Core::InternalThreadState t;
 assert(InitializeThread(&t));assert(reserves==1 && commits==1 && scrubs==1);
 assert(t.frame.State.callret_sp==GetInfoThread(&t).DefaultLocation);
 DestroyThread(&t);assert(releases==1 && !allocation);
}
'''
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'test.cpp';exe=Path(d)/'test';p.write_text(preamble+fragment+main)
 subprocess.run(['clang++','-std=c++20','-Wall','-Wextra','-Werror','-fsanitize=address,undefined',str(p),'-o',str(exe)],check=True)
 subprocess.run([str(exe)],check=True)
print('PASS: actual CallRetStack reserve failure, commit failure, successful init and safe failed-init destruction; ASan/UBSan. Not guest end-to-end qualification.')
