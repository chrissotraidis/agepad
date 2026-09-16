#!/usr/bin/env python3
"""Build a bounded signed-container test of the actual source-built FEX PE.

No game conversion, Wine startup, import emulation, or JIT entitlement grant.
"""
from pathlib import Path
import argparse
import hashlib
import json
import plistlib
import re
import struct
import subprocess

args=argparse.ArgumentParser(description=__doc__)
args.add_argument('--kind',choices=['fex','ntdll'],default='fex')
args.add_argument('--source', type=Path)
args.add_argument('--output', type=Path)
args.add_argument('--container-only', action='store_true')
args.add_argument('--sdk', choices=['iphonesimulator','iphoneos'], default='iphonesimulator')
options=args.parse_args()
if options.sdk == 'iphoneos' and (not options.output or options.output.exists()):
    args.error('Device builds require a new explicit --output directory')
kind=options.kind
r=Path(__file__).resolve().parents[1]
out=r/('generated/madeira-pe-container'+('-ntdll' if kind=='ntdll' else ''))
if options.output: out=options.output.resolve()
out.mkdir(parents=True,exist_ok=True)
src=r/('generated/madeira-fex-arm64ec/Bin/libarm64ecfex.dll' if kind=='fex' else 'worktrees/madeira/wine/build-arm64ec/dlls/ntdll/arm64ec-windows/ntdll.dll')
tools=r/'worktrees/madeira/toolchains/llvm-mingw-20260421-ucrt-macos-universal/bin'
if options.source:
    assert options.container_only, '--source requires --container-only'
    src=options.source.resolve()
# Signed ntdll must include the configured direct TEB path. A plain incremental
# make can silently recompile this object without arm64ec_CFLAGS and regress it.
if kind == 'ntdll':
    symbols = subprocess.check_output([str(tools/'llvm-nm'), '--defined-only', str(src)], text=True)
    checker = re.search(r'^([0-9a-fA-F]+) t #arm64x_check_call$', symbols, re.M)
    assert checker, 'Cannot verify signed ntdll call checker'
    address = int(checker.group(1), 16)
    checker_code = subprocess.check_output([str(tools/'llvm-objdump'), '-d',
        f'--start-address={address}', f'--stop-address={address + 64}', str(src)], text=True)
    assert re.search(r'mrs\s+x16,\s*TPIDRRO_EL0', checker_code, re.I), \
        'Signed ntdll lacks direct TEB path; rebuild with arm64ec_CFLAGS=-g -O2 -DAGEPAD_SIGNED_WINE_TSD=1'
    (out/'call-checker.txt').write_text(checker_code)
b=src.read_bytes()
u16=lambda o:struct.unpack_from('<H',b,o)[0]
u32=lambda o:struct.unpack_from('<I',b,o)[0]
pe=u32(60); optional=pe+24
assert b[pe:pe+4]==b'PE\0\0' and u16(pe+4) in (0xa641,0x8664) and u16(optional)==0x20b
preferred=struct.unpack_from('<Q',b,optional+24)[0]
size,headers=u32(optional+56),u32(optional+60)
assert headers<=len(b) and headers<=size<=64*1024*1024
image=bytearray(size); image[:headers]=b[:headers]
for i in range(u16(pe+6)):
    o=optional+u16(pe+20)+40*i
    vs,va,rs,ro=struct.unpack_from('<IIII',b,o+8)
    assert va+rs<=size and ro+rs<=len(b)
    image[va:va+rs]=b[ro:ro+rs]
layout=subprocess.check_output([str(tools/'llvm-readobj'),'--sections','--coff-basereloc','--coff-load-config','--coff-exports',str(src)],text=True)
(out/'layout.txt').write_text(layout)
native_ranges=[(int(a,16),int(z,16)) for a,z in re.findall(r'(0x[0-9A-F]+) - (0x[0-9A-F]+)  ARM64EC',layout)]
assert native_ranges
split=(max(z for a,z in native_ranges)+16383)&~16383
assert split<size
relocs=re.findall(r'Type: (\w+)\n    Address: (0x[0-9A-F]+)',layout)
for reloc_kind,addr in relocs:
    if reloc_kind=='ABSOLUTE':continue
    assert reloc_kind=='DIR64' and split<=int(addr,16)<=size-8, 'Relocation touches immutable code or is unsupported'
assert re.search(r'DynamicValueRelocTable: 0x0\n',layout), 'Dynamic relocation needs separate handling'
for field in ['DynamicValueRelocTableOffset', 'DynamicValueRelocTableSection']:
    match=re.search(r'  '+field+r': (0x[0-9A-F]+|\d+)\n',layout)
    assert match and int(match.group(1),0)==0, 'Dynamic relocation needs separate handling: '+field
if not options.container_only:
    export_name='BTCpu64IosAddAliasMapping' if kind=='fex' else 'RtlInitUnicodeString'
    exp=next(block for block in re.findall(r'Export \{(.*?)\n\}',layout,re.S) if f'Name: {export_name}\n' in block)
    export_rva=int(re.search(r'RVA: (0x[0-9A-F]+)',exp).group(1),16)
    redirects={int(a,16):int(z,16) for a,z in re.findall(r'^    (0x[0-9A-F]+) -> (0x[0-9A-F]+)$',layout,re.M)}
    entry_rva=redirects[export_rva]
    assert any(a<=entry_rva<z for a,z in native_ranges)
    macros={'PE_DATA_SPLIT':split}
    if kind=='fex':
        symbols=subprocess.check_output([str(tools/'llvm-nm'),'--defined-only',str(src)],text=True)
        (out/'symbols.txt').write_text(symbols)
        def symbol_rva(name):
            return int(re.search(r'^([0-9a-fA-F]+) [A-Za-z] '+re.escape(name)+r'$',symbols,re.M).group(1),16)-preferred
        translate_rva=symbol_rva('IosJitTranslate'); count_rva=symbol_rva('IosAliasCount')
        assert any(a<=translate_rva<z for a,z in native_ranges) and split<=count_rva<size-4
        macros.update(PE_ADD_ALIAS_RVA=entry_rva,PE_TRANSLATE_RVA=translate_rva,PE_ALIAS_COUNT_RVA=count_rva)
    else:
        macros.update(PE_NTDLL_PROBE=1,PE_INITUNICODE_RVA=entry_rva)
else:
    macros={'PE_DATA_SPLIT':split}
(out/'pe-text.bin').write_bytes(image[:split]); (out/'pe-data.bin').write_bytes(image[split:])
(out/'pe-layout.h').write_text('\n'.join(f'#define {k} {v}ULL' for k,v in macros.items())+'\n')
(out/'container.S').write_text('.section __TEXT,__pe_text,regular,pure_instructions\n.p2align 14\n.globl _agepad_pe_base\n_agepad_pe_base:\n.incbin "'+str(out/'pe-text.bin')+'"\n.section __DATA,__pe_data\n.p2align 14\n.globl _agepad_pe_data\n_agepad_pe_data:\n.incbin "'+str(out/'pe-data.bin')+'"\n')
app=out/'AgePadPEProbe.app'; frameworks=app/'Frameworks'; frameworks.mkdir(parents=True,exist_ok=True)
sdk=subprocess.check_output(['xcrun','--sdk',options.sdk,'--show-sdk-path'],text=True).strip()
target='arm64-apple-ios18.0'+('-simulator' if options.sdk=='iphonesimulator' else '')
common=['xcrun','--sdk',options.sdk,'clang++','-target',target,'-isysroot',sdk]
dylib=frameworks/'PEContainer.dylib'
commands=[common+['-dynamiclib',str(out/'container.S'),'-Wl,-install_name,@rpath/'+(out.name+'.dll.dylib' if options.container_only else 'PEContainer.dylib'),'-o',str(dylib)],
          common+['-std=c++20','-fobjc-arc','-O2','-I',str(out),str(r/'port/windows/PEContainerProbe.mm'),str(dylib),'-framework','UIKit','-Wl,-rpath,@executable_path/Frameworks','-o',str(app/'AgePadPEProbe')]]
if options.container_only: commands=commands[:1]
with (out/'build.log').open('w') as log:
    for cmd in commands:subprocess.run(cmd,stdout=log,stderr=subprocess.STDOUT,check=True)
(app/'Info.plist').write_bytes(plistlib.dumps({'CFBundleExecutable':'AgePadPEProbe','CFBundleIdentifier':'local.agepad.'+('ntdll-container-probe' if kind=='ntdll' else 'pe-container-probe'),
    'CFBundleName':'AgePad PE Probe','CFBundlePackageType':'APPL','CFBundleVersion':'1','CFBundleShortVersionString':'0.1',
    'MinimumOSVersion':'18.0','UIDeviceFamily':[2],'UILaunchScreen':{}}))
for item in ([dylib] if options.container_only else [dylib,app]):subprocess.run(['codesign','--force','--sign','-',str(item)],check=True)
# Verify the signed container retained every byte in the immutable PE prefix.
m=dylib.read_bytes(); off=32; found=False
for _ in range(struct.unpack_from('<I',m,16)[0]):
    command,length=struct.unpack_from('<II',m,off)
    if command==0x19:
        sections=struct.unpack_from('<I',m,off+64)[0]
        for j in range(sections):
            section=off+72+80*j
            if m[section:section+16].split(b'\0')[0]==b'__pe_text':
                span=struct.unpack_from('<Q',m,section+40)[0]
                fileoff=struct.unpack_from('<I',m,section+48)[0]
                assert span==split and m[fileoff:fileoff+span]==image[:split]
                found=True
    off+=length
assert found, 'Missing immutable PE code section'
subprocess.run(['codesign','--verify','--strict',str(dylib)],check=True)
if not options.container_only: subprocess.run(['codesign','--verify','--strict',str(app)],check=True)

platform_output=subprocess.check_output(['xcrun','vtool','-show-build',str(dylib)],text=True)
expected='IOSSIMULATOR' if options.sdk=='iphonesimulator' else 'IOS'
assert re.findall(r'platform\s+(\S+)',platform_output)==[expected], platform_output
(out/'platform.txt').write_text(platform_output)
manifest={'sdk':options.sdk,'platform':expected,'signing':'ad-hoc only; not provisioned for physical device','commands':commands,'source':str(src),'source_sha256':hashlib.sha256(b).hexdigest(),'source_bytes':len(b),
          'immutable_prefix_sha256':hashlib.sha256(image[:split]).hexdigest(),'immutable_prefix_preserved':True,'image_size':size,'split':split,'native_ranges':native_ranges,'relocations':len([x for x in relocs if x[0]!='ABSOLUTE']),
          'kind':('dependency' if options.container_only else kind),'macros':macros,'dylib_sha256':hashlib.sha256(dylib.read_bytes()).hexdigest(),
          'scope':'Real PE code/data functions; imports, TLS, startup, exceptions and JIT compilation untested'}
(out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(dylib if options.container_only else app)
