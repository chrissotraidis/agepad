#!/usr/bin/env python3
"""Check attribution under interleaved threads and incomplete trace records."""
import importlib.util
from pathlib import Path

p = Path(__file__).resolve().parents[1] / 'scripts/analyze-madeira-startup-trace.py'
spec = importlib.util.spec_from_file_location('trace_parser', p)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
lines = ['D 24 Value: 0xa6e2000000404ab1', 'D 294 Value: 0xa6e200000047c697']
for i in range(10):
    lines += [f'D 24 Value: 0x{i:x}', f'D 294 Value: 0x{100+i:x}']
lines += ['D 24 Value: 0xa6e20000003f4730', 'D 24 Value: 0x1',
          'D 24 Value: 0xa6e2000000306715', 'D 24 Value: 0x2']
result = module.analyze(lines)
assert len(result['records']) == 2
assert result['records'][0]['registers']['r15'] == '0x9'
assert result['records'][1]['registers']['rax'] == '0x64'
assert len(result['incomplete']) == 2
assert result['incomplete'][0]['values'] == [1]
assert result['incomplete'][1]['values'] == [2]
print('Interleaving and incomplete record attribution pass.')

lines = ['D 24 Value: 0xa6e3000002d4bea5', 'D 80 Value: 0xa6e2000001452015']
for i in range(12):
    lines.append(f'D 24 Value: 0x{200+i:x}')
    if i < 10: lines.append(f'D 80 Value: 0x{i:x}')
lines += ['D 24 Value: 0xa6e3000002d4bea5'] + ['D 24 Value: 0x1'] * 11
result = module.analyze(lines)
assert len(result['records']) == 2
new = next(r for r in result['records'] if r['thread'] == '0x24')
old = next(r for r in result['records'] if r['thread'] == '0x80')
assert new['registers']['r8'] == hex(210) and new['registers']['r9'] == hex(211)
assert len(old['registers']) == 10 and len(result['incomplete']) == 1
assert len(result['incomplete'][0]['values']) == 11
print('Mixed trace formats and extended-register truncation pass.')
