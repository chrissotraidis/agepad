#!/usr/bin/env python3
"""Private load diagnostic: preserve vendor sections, abort on missing API use.

Requires the audited native client dependency graph and measured public constants.
Never substitutes Steam, ownership, registration or authentication results.
"""
import argparse
import importlib.util
import json
from pathlib import Path
import re
import subprocess as sp

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('source', type=Path)
p.add_argument('audit', type=Path)
p.add_argument('constants', type=Path)
p.add_argument('output', type=Path)
p.add_argument('--survey', type=Path, help='Actual Simulator LibrarySymbolSurvey result')
a = p.parse_args()
root = Path(__file__).resolve().parents[1]
source = a.source.resolve(strict=True)
out = a.output.resolve()
if 'ref' in out.parts or out.is_relative_to(source):
    raise SystemExit('Output must be outside source and references')
out.mkdir(parents=True, exist_ok=False)
audit = json.loads(a.audit.read_text())
constants = json.loads(a.constants.read_text())
sdk = sp.check_output(['xcrun', '--sdk', 'iphonesimulator', '--show-sdk-path'], text=True).strip()
missing = {}
survey = {Path(x['path']).name:x for x in json.loads(a.survey.read_text())} if a.survey else {}
imports = {}
names = {name: Path(name).name if Path(name).suffix=='.dylib' else Path(name).name+'.dylib' for name in audit}
if len(set(names.values())) != len(names):
    raise SystemExit('Flattened vendor names collide')
for name, record in audit.items():
    imports[name] = sp.check_output(['xcrun', 'nm', '-arch', 'arm64', '-m', '-u', str(source/name)], text=True)
    for dep in record['dependencies']:
        if dep['kind']=='system' and not dep['simulator_sdk_present']:
            key = Path(dep['path']).name
            missing.setdefault(key, set()).update(re.findall(r'external (\S+) \(from '+re.escape(key)+r'\)', imports[name]))
for key,item in survey.items():
    symbols=set(item['missing_symbols'])-{'dyld_stub_binder'}
    if symbols:
        missing.setdefault(key,set()).update(symbols)
manifest = {'claim':'Diagnostic missing API calls abort; loading is not Steam initialization.', 'boundaries':{}, 'images':{}}
for library, symbols in missing.items():
    code = ['#include "UnsupportedBoundary.h"', '#import <objc/runtime.h>']
    for i, symbol in enumerate(sorted(symbols)):
        if symbol.startswith('_OBJC_CLASS_$_'):
            code.append('DE_DIAGNOSTIC_CLASS('+symbol.split('$_')[1]+')')
        elif symbol in constants:
            code.append('NSString *const Data%d __asm__(%s) = @%s;' % (i,json.dumps(symbol),json.dumps(constants[symbol])))
        elif symbol.startswith('_k') or symbol.startswith('_NS'):
            raise SystemExit('Unmeasured data symbol: '+symbol)
        else:
            code.append('__attribute__((noreturn)) void Function%d(void) __asm__(%s);' % (i,json.dumps(symbol)))
            code.append('void Function%d(void) { DEUnsupported(%s); }' % (i,json.dumps(symbol)))
    src=out/(library+'.m'); src.write_text('\n'.join(code)+'\n')
    dst=out/('DEClientBoundary_'+library+'.dylib')
    command=['xcrun','clang','-target','arm64-apple-ios26.0-simulator','-isysroot',sdk,'-fobjc-arc','-dynamiclib',
        '-I',str(root/'port/de'),str(src),'-framework','Foundation','-Wl,-install_name,@loader_path/'+dst.name,
        '-Wl,-compatibility_version,1000.0','-o',str(dst)]
    if survey.get(library,{}).get('loaded'):
        path=survey[library]['path']
        if '.framework/' in path:
            command.append('-Wl,-reexport_framework,'+library)
        else:
            command.append('-Wl,-reexport_library,'+str((Path(sdk)/path.lstrip('/')).with_suffix('.tbd')))
    sp.run(command,check=True)
    sp.run(['codesign','--force','--sign','-',str(dst)],check=True)
    manifest['boundaries'][library]={'symbols':sorted(symbols),'data':'measured public constants only','functions':'abort','classes':'diagnostic only'}
spec=importlib.util.spec_from_file_location('prepare',root/'scripts/prepare-de-load-image.py')
adapter=importlib.util.module_from_spec(spec);spec.loader.exec_module(adapter)
for name,record in audit.items():
    mapping={}
    for dep in record['dependencies']:
        if dep['kind']=='system' and Path(dep['path']).name in missing:
            mapping[dep['path']]='@loader_path/DEClientBoundary_'+Path(dep['path']).name+'.dylib'
        if dep['kind']=='vendor':
            child=((source/name).parent/dep['path'].removeprefix('@loader_path/')).resolve()
            mapping[dep['path']]='@loader_path/'+names[str(child.relative_to(source))]
    thin=out/('original-'+names[name]);sp.run(['xcrun','lipo',str(source/name),'-thin','arm64','-output',str(thin)],check=True)
    manifest['images'][name]=adapter.prepare(thin,out/names[name],dependency_map=mapping)
(out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(out/'steamclient.dylib')
