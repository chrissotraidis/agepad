#!/usr/bin/env python3
"""Build the original Mac-engine default-output bridge for iOS or its Simulator."""
import argparse
from pathlib import Path
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('output', type=Path)
parser.add_argument('--sdk', choices=('iphonesimulator', 'iphoneos'), default='iphonesimulator')
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
sdk = subprocess.check_output(['xcrun', '--sdk', args.sdk, '--show-sdk-path'], text=True).strip()
target = 'arm64-apple-ios15.0' + ('-simulator' if args.sdk == 'iphonesimulator' else '')
args.output.parent.mkdir(parents=True, exist_ok=True)
subprocess.run(['xcrun', 'clang', '-fobjc-arc', '-dynamiclib', '-target', target,
    '-isysroot', sdk, str(root/'port/de/AudioOutputCompat.m'),
    '-framework', 'AudioToolbox', '-framework', 'AVFoundation', '-o', str(args.output)], check=True)
subprocess.run(['codesign', '--force', '--sign', '-', str(args.output)], check=True)
