#!/usr/bin/env python3
"""Map raw exit-stack words to logged code sections; candidates are not frames."""
import argparse
import json
import re
from pathlib import Path

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('log', type=Path)
a = p.parse_args()
lines = a.log.read_text(errors='replace').splitlines()
sections = []
results = []
for line in lines:
    match = re.search(r'\[iOS-xins\] tracker=\S+ (\S+) sec=0x([0-9a-fA-F]+)-0x([0-9a-fA-F]+)', line)
    if match:
        name, lo, hi = match.groups()
        section = (name, int(lo, 16), int(hi, 16))
        if section not in sections:
            sections.append(section)
    match = re.search(r'\[term-raw\] tid=(\w+) rsp=(\w+) offset=(\w+) words=([0-9a-fA-F,]+)', line)
    if not match:
        continue
    tid, rsp, offset, words = match.groups()
    for index, word in enumerate(words.split(',')):
        value = int(word, 16)
        hits = [{'module': name, 'section_base': hex(lo), 'section_offset': hex(value-lo)}
                for name, lo, hi in sections if lo <= value < hi]
        if hits:
            results.append({'thread': tid, 'stack': '0x'+rsp,
                            'offset': int(offset, 16)+8*index,
                            'value': hex(value), 'matches': hits})
print(json.dumps({'scope': 'Raw stack values intersecting previously logged executable sections. Not validated return addresses, call frames, or proof of causation; logs can omit sections.',
                  'candidates': results}, indent=2))
