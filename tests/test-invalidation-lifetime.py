#!/usr/bin/env python3
"""Exercise the actual FEX holder's destructor with a reentrant callback."""
from pathlib import Path
import subprocess,tempfile
r=Path(__file__).resolve().parents[1]
s=(r/'worktrees/madeira/FEX/Source/Windows/ARM64EC/Module.cpp').read_text()
a=s.index('std::atomic<bool> InvalidationNotificationsActive');b=s.index('\n#else',a)
body=s[a:b]
source='''#include <atomic>
#include <optional>
#include <cassert>
#include <cstdio>
static void reentrant_notification();
namespace FEX::Windows { struct InvalidationTracker {
 ~InvalidationTracker(){reentrant_notification();}
}; }
'''+body+'''
static unsigned allowed,withdrawn;
static void reentrant_notification(){
 if(CanNotifyInvalidationTracker())++allowed;else ++withdrawn;
}
int main(){
 auto*holder=new InvalidationTrackerStorage;
 holder->emplace();reentrant_notification();assert(allowed==1 && withdrawn==0);
 delete holder;
 assert(allowed==1 && withdrawn==1 && !CanNotifyInvalidationTracker());
 puts("INVALIDATION_LIFETIME_PASS: access withdrawn before reentrant member destructor");
}
'''
with tempfile.TemporaryDirectory(prefix='agepad-lifetime-') as d:
 p=Path(d);(p/'probe.cpp').write_text(source)
 subprocess.run(['clang++','-std=c++20','-Wall','-Wextra','-Werror',str(p/'probe.cpp'),'-o',str(p/'probe')],check=True)
 subprocess.run([str(p/'probe')],check=True)
