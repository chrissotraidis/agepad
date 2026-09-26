#!/bin/zsh
# Test helper: sign an injected AgePad .ipa the way a sideloading tool would
# (every Mach-O and the app, with a profile and its entitlements), then install.
# Usage: scripts/sign-agepad-ipa.sh IN.ipa UDID [BUNDLE_ID]
set -eu
IN=$1 UDID=$2 BUNDLE=${3:-local.agepad.device-de-probe}
ROOT=${0:A:h:h}
T=$(mktemp -d); cd $T
unzip -q $IN
A=$(print -r -- Payload/*.app)
S=$(python3 $ROOT/scripts/find-signing.py $BUNDLE $UDID)
P=$(print -r -- "$S" | head -1); ID=$(print -r -- "$S" | tail -1)
cp "$P" $A/embedded.mobileprovision
security cms -D -i "$P" > profile.plist
/usr/libexec/PlistBuddy -x -c 'Print :Entitlements' profile.plist > entitlements.plist
EXE=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' $A/Info.plist)
find $A -type f ! -path '*/_CodeSignature/*' ! -name "$EXE" -print0 | while IFS= read -r -d '' f; do
  if file -b "$f" | grep -q Mach-O; then codesign --force --sign $ID "$f" 2>/dev/null; fi
done
codesign --force --sign $ID --entitlements entitlements.plist $A 2>/dev/null
codesign --verify --deep --strict $A
xcrun devicectl device install app --device $UDID $A | grep -E 'installationURL|rror'
