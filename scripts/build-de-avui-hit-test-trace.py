#!/usr/bin/env python3
"""Build the opt-in read-only AVUI hit-test observer."""
import hashlib
import json
import subprocess
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[1]
output = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else root / "generated/mac-de-simulator-375/AVUIHitTestTrace.dylib"
output.parent.mkdir(parents=True, exist_ok=True)
sdk = subprocess.check_output(
    ["xcrun", "--sdk", "iphonesimulator", "--show-sdk-path"], text=True
).strip()
command = [
    "xcrun", "clang", "-target", "arm64-apple-ios26.0-simulator", "-isysroot", sdk,
    "-dynamiclib", "-O2", "-fno-omit-frame-pointer",
    str(root / "port/de/AVUIHitTestTrace.c"),
    "-Wl,-undefined,dynamic_lookup", "-o", str(output),
]
subprocess.run(command, check=True)
subprocess.run(["codesign", "--force", "--sign", "-", str(output)], check=True)
(output.with_suffix(".json")).write_text(json.dumps({
    "source": str(root / "port/de/AVUIHitTestTrace.c"),
    "source_sha256": hashlib.sha256((root / "port/de/AVUIHitTestTrace.c").read_bytes()).hexdigest(),
    "output": str(output),
    "output_sha256": hashlib.sha256(output.read_bytes()).hexdigest(),
    "command": command,
}, indent=2) + "\n")
print(output)
