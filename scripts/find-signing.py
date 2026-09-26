#!/usr/bin/env python3
"""Find the signing setup for AgePad on a connected iPad.

Looks through the provisioning profiles Xcode has downloaded for one that is
current, covers the bundle ID, grants the increased memory limit, includes this
iPad, and whose certificate has a private key in this Mac's keychain. Prints
the profile path and the signing identity hash on two lines, or explains what
is missing (exit 1).
"""
import datetime
import hashlib
import plistlib
import subprocess
import sys
from pathlib import Path

bundle, udid = sys.argv[1], sys.argv[2]
folders = [Path.home() / 'Library/Developer/Xcode/UserData/Provisioning Profiles',
           Path.home() / 'Library/MobileDevice/Provisioning Profiles']
identities = subprocess.run(['security', 'find-identity', '-v', '-p', 'codesigning'],
                            capture_output=True, text=True).stdout
keychain = {line.split()[1] for line in identities.splitlines() if line.strip()[:2].rstrip(')').isdigit()}
memory = 'com.apple.developer.kernel.increased-memory-limit'
reasons = set()
now = datetime.datetime.now(datetime.timezone.utc)
for profile in sorted((p for folder in folders if folder.is_dir() for p in folder.glob('*.mobileprovision')),
                      key=lambda p: p.stat().st_mtime, reverse=True):
    try:
        data = plistlib.loads(subprocess.check_output(['security', 'cms', '-D', '-i', str(profile)],
                                                      stderr=subprocess.DEVNULL))
    except (subprocess.CalledProcessError, plistlib.InvalidFileException):
        continue
    team = data.get('TeamIdentifier', [''])[0]
    entitlements = data.get('Entitlements', {})
    if entitlements.get('application-identifier') != team + '.' + bundle:
        continue
    expiry = data['ExpirationDate']
    if expiry.tzinfo is None:
        expiry = expiry.replace(tzinfo=datetime.timezone.utc)
    if expiry < now:
        reasons.add('the profile for ' + bundle + ' has expired'); continue
    if not entitlements.get(memory):
        reasons.add('the profile does not include the Increased Memory Limit capability'); continue
    if udid not in data.get('ProvisionedDevices', []) and not data.get('ProvisionsAllDevices'):
        reasons.add('this iPad is not in the profile (register it, then download the profile again)'); continue
    for certificate in data.get('DeveloperCertificates', []):
        sha1 = hashlib.sha1(certificate).hexdigest().upper()
        if sha1 in keychain:
            print(profile)
            print(sha1)
            sys.exit(0)
    reasons.add("the profile's certificate is not in this Mac's keychain")
print('No usable signing setup for ' + bundle + (': ' + '; '.join(sorted(reasons)) if reasons
      else ': no provisioning profile for it was found') + '. See docs/IPAD-SETUP.md, "Signing".', file=sys.stderr)
sys.exit(1)

