#!/bin/bash
# Rebuild the Windows translator and both ntdll architectures. Does not install.
set -euo pipefail
AGEPAD_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MADEIRA_SRC="$AGEPAD_ROOT/worktrees/madeira"
MINGW_BIN="$MADEIRA_SRC/toolchains/llvm-mingw-20260421-ucrt-macos-universal/bin"
export PATH="$AGEPAD_ROOT/generated/madeira-host-bin:$MINGW_BIN:/opt/homebrew/opt/bison/bin:$PATH"
LOG_DIR="$AGEPAD_ROOT/generated/madeira-windows-core"
mkdir -p "$LOG_DIR" "$MADEIRA_SRC/wine/build-macos" "$MADEIRA_SRC/wine/build-arm64ec"
test -x "$MINGW_BIN/arm64ec-w64-mingw32-clang"

cmake -S "$MADEIRA_SRC/FEX" -B "$AGEPAD_ROOT/generated/madeira-fex-arm64ec" -G Ninja \
  -DCMAKE_TOOLCHAIN_FILE="$MADEIRA_SRC/FEX/Data/CMake/toolchain_mingw.cmake" \
  -DMINGW_TRIPLE=arm64ec-w64-mingw32 -DCMAKE_BUILD_TYPE=Release \
  -DFEX_IOS_HOST_BUILD=ON -DCMAKE_C_FLAGS=-DFEX_IOS_HOST=1 -DCMAKE_CXX_FLAGS=-DFEX_IOS_HOST=1 \
  -DCMAKE_ASM_FLAGS=-DAGEPAD_CHECKCALL_DELEGATION=1 \
  -DBUILD_TESTING=OFF -DBUILD_FEXCONFIG=OFF -DENABLE_LTO=OFF -DENABLE_CCACHE=OFF \
  -DENABLE_OFFLINE_TELEMETRY=OFF -DTUNE_CPU=apple-m1 -DCMAKE_DISABLE_FIND_PACKAGE_fmt=TRUE \
  > "$LOG_DIR/fex-configure.log" 2>&1
cmake --build "$AGEPAD_ROOT/generated/madeira-fex-arm64ec" --target arm64ecfex -j6 \
  > "$LOG_DIR/fex-build.log" 2>&1

cd "$MADEIRA_SRC/wine/build-macos"
if [ ! -f Makefile ]; then
  ../configure --enable-win64 --disable-tests --without-x --without-wayland \
    --without-gstreamer --without-ffmpeg > "$LOG_DIR/wine-host-configure.log" 2>&1
fi
make -j6 include/all tools/widl/all tools/winebuild/all tools/wrc/all tools/wmc/all tools/winegcc/all \
  > "$LOG_DIR/host-tools-build.log" 2>&1
make -j6 dlls/ntdll/aarch64-windows/ntdll.dll > "$LOG_DIR/ntdll-arm64-build.log" 2>&1

cd "$MADEIRA_SRC/wine/build-arm64ec"
CPPFLAGS=-DWINE_IOS=1 ../configure --enable-archs=arm64ec --disable-tests \
  --without-x --without-wayland --without-gstreamer --without-ffmpeg \
  --with-wine-tools=../build-macos > "$LOG_DIR/wine-ec-configure.log" 2>&1
make -j6 arm64ec_CFLAGS="-g -O2 -DAGEPAD_SIGNED_WINE_TSD=1" dlls/ntdll/arm64ec-windows/ntdll.dll \
  dlls/ucrtbase/arm64ec-windows/ucrtbase.dll dlls/kernel32/arm64ec-windows/kernel32.dll \
  dlls/kernelbase/arm64ec-windows/kernelbase.dll > "$LOG_DIR/ntdll-ec-build.log" 2>&1

/opt/homebrew/bin/python3.11 "$AGEPAD_ROOT/scripts/audit-madeira-pe-core.py"
