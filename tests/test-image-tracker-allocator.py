#!/usr/bin/env python3
"""Check real tracker map declarations route nodes through FEX's allocator."""
from pathlib import Path
import re,subprocess,tempfile
r=Path(__file__).resolve().parents[1];f=r/'worktrees/madeira/FEX'
s=(f/'Source/Windows/Common/ImageTracker.h').read_text()
decl=re.search(r'^\s*(.*) MappedImages;',s,re.M).group(1)
assert 'fextl::map<fextl::string, AOTImageInfo> AOTImages;' in s
code='''#include <FEXCore/fextl/map.h>
#include <cassert>
#include <cstdlib>
#include <cstdint>
static bool held;
static unsigned allocations, frees;
void* operator new(size_t n) { assert(!held); if(void* p=std::malloc(n)) return p; throw std::bad_alloc(); }
void operator delete(void* p) noexcept { std::free(p); }
namespace FEXCore::Allocator {
void* aligned_alloc(size_t a,size_t n) { void* p=nullptr; ++allocations; if(a<sizeof(void*)) a=sizeof(void*); assert(!::posix_memalign(&p,a,n)); return p; }
void aligned_free(void* p) { ++frees; std::free(p); }
}
struct MappedImageInfo { uint64_t value; };
int main() {
 held=true;
 {
 MAP_DECL images;
 for(uint64_t n=0;n<256;++n) images.emplace(n,MappedImageInfo{n*3});
 assert(images.size()==256 && images.at(73).value==219);
 for(uint64_t n=0;n<128;++n) images.erase(n);
 assert(images.begin()->first==128);
 }
 held=false;
 assert(allocations==256 && frees==256);
}
'''.replace('MAP_DECL',decl)
with tempfile.TemporaryDirectory() as d:
 p=Path(d)
 for name,body in [('good',code),('bad',code.replace(decl,'std::map<uint64_t, MappedImageInfo>'))]:
  (p/(name+'.cpp')).write_text(body)
  subprocess.run(['clang++','-std=c++20','-fsanitize=address,undefined','-I'+str(f/'FEXCore/include'),'-I'+str(f/'External/fmt/include'),str(p/(name+'.cpp')),'-o',str(p/name)],check=True)
  result=subprocess.run([str(p/name)],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
  assert (result.returncode==0)==(name=='good'),(name,result.returncode)
print('Tracker node allocation/deallocation bypass default new; original std::map negative control fails')
