#!/usr/bin/env python3
"""Decode opt-in executed CEF register traces, keeping interleaved guest threads separate."""
import argparse
import json
import re
from pathlib import Path

REGISTERS = ('rax', 'rcx', 'rdx', 'rbx', 'rsp', 'rbp', 'rsi', 'rdi', 'r14', 'r15')
REGISTER_FORMATS = {0xA6E2: REGISTERS, 0xA6E3: REGISTERS + ('r8', 'r9')}
VALUE = re.compile(r'^D ([0-9A-Fa-f]+) Value: 0x([0-9A-Fa-f]+)$')


def analyze(lines):
    pending, complete, incomplete = {}, [], []
    for number, line in enumerate(lines, 1):
        match = VALUE.match(line.strip())
        if not match:
            continue
        tid, value = int(match[1], 16), int(match[2], 16)
        if value >> 48 in REGISTER_FORMATS:
            if tid in pending:
                incomplete.append(pending.pop(tid))
            pending[tid] = {'thread': hex(tid), 'line': number,
                            'rva': hex(value & 0xFFFFFFFFFFFF), 'format': value >> 48, 'values': []}
        elif tid in pending:
            record = pending[tid]
            record['values'].append(value)
            registers = REGISTER_FORMATS[record['format']]
            if len(record['values']) == len(registers):
                record['registers'] = dict(zip(registers, map(hex, record.pop('values'))))
                complete.append(pending.pop(tid))
    incomplete.extend(pending.values())
    return {'scope': 'Executed debug Print records; diagnostic timing, not gameplay acceptance. Missing records do not prove a site was not executed.',
            'records': complete, 'incomplete': incomplete}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('log', type=Path)
    args = parser.parse_args()
    print(json.dumps(analyze(args.log.read_text(errors='replace').splitlines()), indent=2))
