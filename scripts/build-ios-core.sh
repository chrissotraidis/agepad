#!/bin/sh
# Compile/link the pinned core for an Apple mobile SDK. This does not run gameplay.
set -eu
cd "$(dirname "$0")/.."
backend="${2:-eagl}"
if [ "$backend" = metal ]; then
  selected_target="${1:-simulator}"
  shift 2
  exec "${AGEPAD_PYTHON:-python3.11}" scripts/build-metal.py "$selected_target" "$@"
elif [ "$backend" != eagl ]; then
  echo 'Backend must be eagl or metal' >&2
  exit 2
fi
case "${1:-simulator}" in
  simulator) sdk=iphonesimulator; target=ipadsim ;;
  device) sdk=iphoneos; target=ipaddevice ;;
  *) echo 'Usage: build-ios-core.sh [simulator|device]' >&2; exit 2 ;;
esac
scripts/verify-sources.sh
# The generator is a host program even when the game is cross-compiled.
cmake --build generated/freeaoe-macos --target resgen -j 4
host_resgen="$PWD/generated/freeaoe-macos/src/tools/resgen/resgen"
test -x "$host_resgen"
cmake -S ref/freetype-2.5.5 -B "generated/freetype-$target" -G Ninja \
  -DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_SYSROOT="$sdk" \
  -DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_OSX_DEPLOYMENT_TARGET=15.0 \
  -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF \
  -DCMAKE_C_FLAGS=-DFT_CONFIG_OPTION_SYSTEM_ZLIB \
  -DCMAKE_INSTALL_PREFIX="$PWD/generated/deps/freetype-$target"
cmake --build "generated/freetype-$target" -j 4
cmake --install "generated/freetype-$target"
cmake -S ref/sfml -B "generated/sfml-$target" -G Ninja \
  -DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_SYSROOT="$sdk" \
  -DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_OSX_DEPLOYMENT_TARGET=15.0 \
  -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF \
  -DCMAKE_INSTALL_PREFIX="$PWD/generated/deps/$target" \
  -DSFML_BUILD_AUDIO=OFF -DSFML_BUILD_NETWORK=OFF \
  -DSFML_BUILD_EXAMPLES=OFF -DSFML_BUILD_DOC=OFF
cmake --build "generated/sfml-$target" -j 4
cmake --install "generated/sfml-$target"
cmake -S worktrees/freeaoe -B "generated/freeaoe-$target" -G Ninja \
  -DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_SYSROOT="$sdk" \
  -DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_OSX_DEPLOYMENT_TARGET=15.0 \
  -DCMAKE_BUILD_TYPE=RelWithDebInfo -DBUILD_TESTS=OFF \
  -DSFML_DIR="$PWD/generated/deps/$target/lib/cmake/SFML" \
  -DSFML_STATIC_LIBRARIES=TRUE \
  -DFreeType_LIB="$PWD/generated/deps/freetype-$target/lib/libfreetype.a" \
  -DAGEPAD_HOST_RESGEN="$host_resgen"
cmake --build "generated/freeaoe-$target" -j 4
file "generated/freeaoe-$target/freeaoe.app/freeaoe"
shasum -a 256 "generated/freeaoe-$target/freeaoe.app/freeaoe"
