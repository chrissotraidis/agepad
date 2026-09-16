#!/usr/bin/env python3
"""Summarize a saved vmmap snapshot; gaps are geometry, not allocatability."""
import argparse
import json
import re
from pathlib import Path


def census(snapshot, low, high, alignment):
    regions = set()
    for line in snapshot.splitlines():
        match = re.search(r'\b([0-9a-fA-F]{8,16})-([0-9a-fA-F]{8,16})\b', line)
        if match:
            start, end = (int(value, 16) for value in match.groups())
            if start < high and end > low:
                regions.add((max(start, low), min(end, high)))
    if not regions:
        raise ValueError('No regions found in selected band; verify snapshot format and bounds')
    merged = []
    for start, end in sorted(regions):
        if merged and start <= merged[-1][1]:
            merged[-1][1] = max(end, merged[-1][1])
        else:
            merged.append([start, end])
    gaps, position = [], low
    for start, end in merged:
        if start > position:
            gaps.append((position, start))
        position = end
    if position < high:
        gaps.append((position, high))
    return {
        'band_bytes': high - low,
        'mapped_union_bytes': sum(end - start for start, end in merged),
        'gap_bytes': sum(end - start for start, end in gaps),
        'largest_gap_bytes': max((end - start for start, end in gaps), default=0),
        'alignment_bytes': alignment,
        'aligned_slots': sum(max(0, (end - ((start + alignment - 1) & ~(alignment - 1))) // alignment)
                             for start, end in gaps),
        'scope': 'Snapshot region union includes no-access reservations; gaps do not prove mappability. Not a resident-memory or allocation-time census.',
    }


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('snapshot', type=Path)
    parser.add_argument('--low', type=lambda value: int(value, 0), default=0x7c00000000)
    parser.add_argument('--high', type=lambda value: int(value, 0), default=0x8000000000)
    parser.add_argument('--alignment', type=lambda value: int(value, 0), default=0x1000000)
    args = parser.parse_args()
    if args.low >= args.high or args.alignment <= 0 or args.alignment & (args.alignment - 1):
        parser.error('Require low < high and positive power-of-two alignment')
    print(json.dumps(census(args.snapshot.read_text(), args.low, args.high, args.alignment), indent=2))
