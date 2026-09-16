#!/usr/bin/env python3
"""Read-only inventory of a supplied Mac app; private output must stay ignored."""
import argparse
import collections
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import struct
import subprocess


def command(*args):
    p = subprocess.run(args, capture_output=True, text=True)
    return {"returncode": p.returncode, "stdout": p.stdout, "stderr": p.stderr}


def digest(path):
    h = hashlib.sha256()
    with path.open("rb") as f:
        for block in iter(lambda: f.read(8 * 1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def main():
    a = argparse.ArgumentParser()
    a.add_argument("input", type=Path)
    a.add_argument("output", type=Path)
    args = a.parse_args()
    root = args.input.resolve()
    apps = list(root.glob("*.app"))
    if len(apps) != 1:
        raise SystemExit("Expected exactly one app in the supplied directory")
    app = apps[0]
    info = plistlib.loads((app / "Contents/Info.plist").read_bytes())
    out = args.output.resolve()
    # Never write generated analysis back into the supplied input.
    if root == out or root in out.parents:
        raise SystemExit("Output must be outside input")
    out.mkdir(parents=True, exist_ok=True)
    summary = {"input": str(root), "bundle": {k: info.get(k) for k in
        ("CFBundleIdentifier", "CFBundleExecutable", "CFBundleVersion",
         "CFBundleShortVersionString", "LSMinimumSystemVersion")},
        "files": [], "binaries": [], "shaders": []}
    for path in sorted(root.rglob("*")):
        if path.is_symlink():
            summary["files"].append({"path": str(path.relative_to(root)),
                                     "symlink": os.readlink(str(path))})
            continue
        if not path.is_file():
            continue
        rel = str(path.relative_to(root))
        stat = path.stat()
        with path.open("rb") as f:
            magic = f.read(4)
        record = {"path": rel, "size": stat.st_size, "sha256": digest(path)}
        summary["files"].append(record)
        if path.suffix == ".metallib":
            summary["shaders"].append(record)
        if magic not in (b"\xcf\xfa\xed\xfe", b"\xce\xfa\xed\xfe", b"\xca\xfe\xba\xbe"):
            continue
        b = dict(record)
        b["file"] = command("file", str(path))
        b["build"] = command("xcrun", "vtool", "-show-build", str(path))
        b["dependencies"] = command("otool", "-L", str(path))
        b["load_commands"] = command("otool", "-l", str(path))
        symbols = command("nm", "-m", "-u", str(path))
        groups = collections.defaultdict(list)
        for line in symbols["stdout"].splitlines():
            match = re.search(r"external (.*?) \(from (.*?)\)", line)
            if match:
                groups[match.group(2)].append(match.group(1))
        b["undefined_symbols"] = dict(groups)
        b["undefined_count"] = sum(map(len, groups.values()))
        summary["binaries"].append(b)
        print("Audited", rel, b["undefined_count"], "imports", flush=True)
    summary["signature_verification"] = command("codesign", "--verify", "--deep", "--strict", str(app))
    summary["total_bytes"] = sum(x.get("size", 0) for x in summary["files"])
    summary["file_count"] = len(summary["files"])
    (out / "audit.json").write_text(json.dumps(summary, indent=2) + "\n")
    print(json.dumps({"files": summary["file_count"], "bytes": summary["total_bytes"],
        "binaries": len(summary["binaries"]), "shaders": len(summary["shaders"]),
        "signature_returncode": summary["signature_verification"]["returncode"]}, indent=2))


if __name__ == "__main__":
    main()
