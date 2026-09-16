#!/usr/bin/env python3
"""Execute actual opt-in FEX guard; pending cannot pass as NT_SUCCESS."""
from pathlib import Path
import subprocess,tempfile
r=Path(__file__).resolve().parents[1]
s=(r/'worktrees/madeira/FEX/Source/Windows/ARM64EC/Module.cpp').read_text()
a=s.index('using AgePadStateCloseCallback');b=s.index('static NTSTATUS DestroyRegisteredThreadState',a)
pre=r'''
#include <atomic>
#include <cassert>
#include <cstdint>
#include <csetjmp>
#define WINAPI
#define FEX_IOS_HOST 1
#define AGEPAD_TEST_STATE_RETIRE 1
using NTSTATUS=uint32_t;
constexpr NTSTATUS STATUS_SUCCESS=0,STATUS_PENDING=0x103,STATUS_NOT_SUPPORTED=0xc00000bb;
namespace LogMan {namespace Msg {template<typename... T> void EFmt(const char *,T...) {}}}
static std::jmp_buf escape;
static int sleeps,polls;
static bool fail;
static void Sleep(unsigned n){sleeps++;if(n==1000)std::longjmp(escape,1);}
static NTSTATUS close_state(void *t){assert(t==(void *)100);polls++;return fail?STATUS_NOT_SUPPORTED:(polls<3?STATUS_PENDING:STATUS_SUCCESS);}
static NTSTATUS other(void *){return 0;}
'''
main=r'''
int main(){
 assert(!BTCpu64IosSetStateClose(2,close_state));
 assert(!BTCpu64IosSetStateClose(1,nullptr));
 assert(BTCpu64IosSetStateClose(1,close_state)==0x261);
 assert(!BTCpu64IosSetStateClose(1,other));
 AgePadDrainNativeState((void *)100);
 assert(polls==3&&sleeps==2&&!AgePadStateRetirementBlocked.load());
 fail=true;
 if(!setjmp(escape)){AgePadDrainNativeState((void *)100);assert(false);}
 assert(AgePadStateRetirementBlocked.load());
 return 0;
}
'''
body=s[b:s.index('/* Native ARM64 alias only',b)]
assert body.index('AgePadDrainNativeState(CPUArea.OwnerTeb)')<body.index('std::scoped_lock Lock')<body.index('Threads.erase')<body.index('CTX->DestroyThread')
assert 'MainDetachStateDisposed && !AgePadStateRetirementBlocked.load()' in s
w=(r/'worktrees/madeira/wine/dlls/ntdll/signal_arm64ec.c').read_text()
x=w[w.index('static NTSTATUS WINAPI agepad_close_fex_state'):w.index('static BOOLEAN emulated_processor_features')]
assert 'params.version = 6' in x and 'params.callback = target_teb' in x and 'return WINE_UNIX_CALL' in x
assert 'GET_PTR( BTCpu64IosSetStateClose )' in w
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'test.cpp';p.write_text(pre+s[a:b]+main);exe=Path(d)/'test'
 subprocess.run(['clang++','-std=c++17','-fsanitize=address,undefined',str(p),'-o',str(exe)],check=True)
 subprocess.run([str(exe)],check=True,timeout=15)
print('PASS pending polls until exact zero; error does not return; guard precedes locks/destruction; allocator blocked')
