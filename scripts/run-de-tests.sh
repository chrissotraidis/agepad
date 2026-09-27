#!/bin/zsh
# Run AgePad's game-side tests: the Mac-runnable ones run; the iPadOS ones are
# compiled for the Simulator (and the touch test runs if the AgePad Simulator
# is the only one booted). Usage: scripts/run-de-tests.sh
set -u
ROOT=${0:A:h:h}; cd $ROOT
T=$(mktemp -d); FAILED=0
pass() { print -P "  %F{green}✓%f $1"; }
fail() { print -P "  %F{red}✗%f $1"; FAILED=1; }
mac() { # name, extra sources/flags
  local name=$1; shift
  if xcrun clang -fobjc-arc -I port/de "$@" -o $T/$name 2>$T/$name.err && $T/$name >$T/$name.out 2>&1; then pass "$name: $(tail -1 $T/$name.out)"
  else fail "$name (see $T/$name.err, $T/$name.out)"; fi
}
mac hardware-key-mapping tests/de_hardware_key_mapping_test.m -framework Foundation -framework GameController
mac resource-case tests/de_resource_case_test.m -framework Foundation
mac sld-frame-trace tests/de_sld_frame_trace_test.m -framework Foundation
mac bc-decode tests/de_bc_decode_test.c port/de/BCDecode.c
SDK=$(xcrun --sdk iphonesimulator --show-sdk-path)
for name in pointer_ownership ordered_delivery; do
  xcrun clang -fobjc-arc -target arm64-apple-ios17.0-simulator -isysroot $SDK -I port/de tests/de_${name}_test.m \
    -framework Foundation -framework UIKit -framework QuartzCore -framework CoreGraphics -o $T/$name 2>$T/$name.err \
    && pass "$name: compiles for iPadOS" || fail "$name (see $T/$name.err)"
done
OUT=$(python3 tests/test_de_touch_ordering.py 2>&1) && pass "touch-ordering: $(print -r -- $OUT | tail -1)" || fail "touch-ordering: $(print -r -- $OUT | tail -3)"
OUT=$(python3 tests/test_agepad_kit_roundtrip.py 2>&1) && pass "release round trip: $(print -r -- $OUT | tail -1)" || fail "release round trip: $(print -r -- $OUT | tail -3)"
OUT=$(python3 tests/test-startup-trace-parser.py 2>&1) && pass "startup-trace-parser" || fail "startup-trace-parser"
(( FAILED )) && { print 'Some tests failed.'; exit 1; }
print 'All game-side tests passed.'
