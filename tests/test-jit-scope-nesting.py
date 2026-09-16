#!/usr/bin/env python3
"""Check actual scope header hooks for lookup/compile/callback nesting."""
from pathlib import Path
import subprocess,tempfile
root=Path(__file__).resolve().parents[1]
source=r'''#include <cassert>
#include <vector>
#include <FEXCore/Utils/AgePadJITScope.h>
static std::vector<int> events;
static void enter(){events.push_back(1);}
static void conservative(){events.push_back(2);}
static void explicit_leave(){events.push_back(3);}
void (*agepad_jit_write_enter)(void)=enter;
void (*agepad_jit_write_leave)(void)=conservative;
void (*agepad_jit_write_leave_explicit)(void)=explicit_leave;
bool agepad_cache_hit_explicit_flush=false;
int main(){
 {AgePadJITWriteScope disabled(false,false);} assert(events.empty());
 {AgePadJITWriteScope lookup(true);} assert((events==std::vector<int>{1,3}));events.clear();
 {AgePadJITWriteScope lookup(true);{AgePadJITWriteScope compilation(false,true);}}
 assert((events==std::vector<int>{1,1,2,3}));events.clear();
 {AgePadJITWriteScope lookup(true);{AgePadJITWriteScope callback(false,true);{AgePadJITWriteScope delink(true);}}}
 assert((events==std::vector<int>{1,1,1,3,2,3}));events.clear();
 {AgePadJITWriteScope callback(true);{AgePadJITWriteScope delink(true);}}
 assert((events==std::vector<int>{1,1,3,3}));events.clear();
 {AgePadJITWriteScope callback(true);{AgePadJITWriteScope reentrant_compile(false);}}
 assert((events==std::vector<int>{1,1,2,3}));events.clear();
 agepad_jit_write_leave_explicit=nullptr;
 {AgePadJITWriteScope lookup(true);} assert((events==std::vector<int>{1,2}));events.clear();
 agepad_jit_write_enter=nullptr;
 {AgePadJITWriteScope no_hooks;} assert(events.empty());
}
'''
with tempfile.TemporaryDirectory(prefix='agepad-scope-') as temporary:
 d=Path(temporary);(d/'test.cpp').write_text(source)
 subprocess.run(['clang++','-std=c++20','-fsanitize=address,undefined','-I',str(root/'worktrees/madeira/FEX/FEXCore/include'),str(d/'test.cpp'),'-o',str(d/'test')],check=True)
 subprocess.run([str(d/'test')],check=True)
 print('JIT_SCOPE_NESTING_PASS: disabled, lookup, compile, callback/delink nesting, conservative fallback, absent hooks')
