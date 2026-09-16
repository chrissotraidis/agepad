#!/bin/sh
set -eu
uname -sm
sw_vers
git --version
xcodebuild -version
xcodebuild -showsdks
xcrun clang --version
cmake --version
ninja --version
python3 --version
xcrun simctl list devices booted
df -h .
