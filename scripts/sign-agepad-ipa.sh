#!/bin/zsh
# Sign an injected AgePad .ipa with your developer account's profile (which
# carries the larger memory limit, docs/IPAD-SETUP.md Step 1) and install it:
# every Mach-O and the app, the way a sideloading tool would.
# Usage: scripts/sign-agepad-ipa.sh IN.ipa UDID [BUNDLE_ID]
# BUNDLE_ID: your own app ID if it isn't local.agepad.device-de-probe (the app
# is renamed to match your profile).
set -eu
IN=$1 UDID=$2 BUNDLE=${3:-local.agepad.device-de-probe}
ROOT=${0:A:h:h}
T=$(mktemp -d); cd $T
unzip -q $IN
A=$(print -r -- Payload/*.app)
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE" $A/Info.plist
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
