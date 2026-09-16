#!/bin/sh
# Build the current isolated R1 candidate. Inputs are selected only at runtime.
set -eu
cd "$(dirname "$0")/.."
scripts/verify-sources.sh
test "$(git -C worktrees/freeaoe rev-parse HEAD)" = "f5e46da59761868aa1814037f712f277c71b5bb3"
cmake -S ref/sfml -B generated/sfml-macos -G Ninja \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DCMAKE_INSTALL_PREFIX="$PWD/generated/deps/macos" \
  -DSFML_BUILD_AUDIO=OFF -DSFML_BUILD_NETWORK=OFF \
  -DSFML_BUILD_EXAMPLES=OFF -DSFML_BUILD_DOC=OFF
cmake --build generated/sfml-macos -j 4
cmake --install generated/sfml-macos
cmake -S worktrees/freeaoe -B generated/freeaoe-macos -G Ninja \
  -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DCMAKE_PREFIX_PATH="$PWD/generated/deps/macos" -DBUILD_TESTS=ON \
  -DAGEPAD_TESTS_DIR="$PWD/tests"
cmake --build generated/freeaoe-macos -j 4
file generated/freeaoe-macos/freeaoe
shasum -a 256 generated/freeaoe-macos/freeaoe
echo "R1 ARM64 host executable built. Package into a new private output with package-host-probe.py. Gameplay not inferred."
