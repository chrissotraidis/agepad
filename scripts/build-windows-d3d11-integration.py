#!/usr/bin/env python3
"""Build Windows x64 graphics diagnostic with pinned Wine DXBC fixtures."""
from pathlib import Path
import re, json, hashlib, subprocess, argparse
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument("--fresh-staging", action="store_true")
parser.add_argument("--procedural", action="store_true", help="Control: generate vertex positions from vertex ID")
parser.add_argument("--sampled-texture", action="store_true", help="Verify texture initialization, sampling and update through GPU readback")
args=parser.parse_args()
if args.sampled_texture and (args.procedural or args.fresh_staging):
    parser.error("sampled-texture is a separate diagnostic variant")
r=Path(__file__).resolve().parents[1];out=r/'generated/windows-d3d11-integration';out.mkdir(parents=True,exist_ok=True)
fixture=r/'worktrees/madeira/wine/dlls/d3d11/tests/d3d11.c';s=fixture.read_text()
arrays=[]
vertex_start=s.index('static const DWORD default_vs_code[]')
if args.procedural:
    anchor=s.index('void main(uint id : SV_VertexID, out output o)')
    vertex_start=s.rfind('static const DWORD vs_code[]',0,anchor)
pixel_start=s.index('static const DWORD ps_sample_code[]') if args.sampled_texture else s.index('static const DWORD ps_code[]',s.index('static void test_pipeline_statistics_query(void)'))
for name, start in [('vertex_fixture',vertex_start),('pixel_fixture',pixel_start)]:
    end=s.index('\n    };',start);words=re.findall(r'0x[0-9a-f]+',s[start:end]);arrays.append(f'static const uint32_t {name}[] = {{'+','.join(words)+'};\n')
(out/'graphics-fixtures.h').write_text('// Generated from Wine d3d11 tests; LGPL-2.1-or-later.\n'+''.join(arrays))
source=r/'port/windows/WindowsD3D11IntegrationProbe.c';variant='texture' if args.sampled_texture else 'procedural' if args.procedural else ('fresh' if args.fresh_staging else 'integration')
exe=out/f'agepad-d3d11-{variant}-x64.exe'
compiler=r/'worktrees/madeira/toolchains/llvm-mingw-20260421-ucrt-macos-universal/bin/x86_64-w64-mingw32-clang'
cmd=[str(compiler),'-O2','-nostdlib','-fno-builtin','-fno-stack-protector','-Wl,--entry,mainCRTStartup','-Wl,--subsystem,console','-I',str(out),str(source),'-lkernel32','-o',str(exe)]
if args.fresh_staging: cmd.insert(1,"-DAGEPAD_FRESH_STAGING=1")
if args.procedural: cmd.insert(1,"-DAGEPAD_PROCEDURAL=1")
if args.sampled_texture: cmd.insert(1,"-DAGEPAD_SAMPLED_TEXTURE=1")
subprocess.run(cmd,check=True)
(out/(variant+'-manifest.json')).write_text(json.dumps({'command':cmd,'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'exe_sha256':hashlib.sha256(exe.read_bytes()).hexdigest(),'fixture_source':str(fixture),'fixture_source_sha256':hashlib.sha256(fixture.read_bytes()).hexdigest()},indent=2)+'\n')
print(exe)
