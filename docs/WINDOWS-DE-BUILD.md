# Madeira Simulator build checkpoint

Run from the agepad repository with `/opt/homebrew/bin/python3.11`. This is a resumable engineering build, not a one-command consumer installer. Windows PE modules are still upstream inputs, so full reproducibility gate W0 remains open.

## Source and tool inputs

- Recursive Madeira checkout: `worktrees/madeira`, commit recorded in WINDOWS-DE-STATUS.md. Apply `port/windows/patches/madeira.patch` there, `fex.patch` inside FEX, and `dxmt.patch` inside research/dxmt. These are local experiment patches, not upstream contributions.
- FreeType VER-2-13-3: `worktrees/madeira/research/freetype`, commit `42608f77f20749dd6ddc9e0536788eaad70ea4b5`.
- LLVM 15.0.7 official release source: `worktrees/madeira/toolchains/llvm-project-15.0.7.src`. Host tblgen in `generated/madeira-llvm-host`; Simulator libraries in `generated/madeira-llvm-sim`. The small AddLLVM Apple-linker patch is recorded separately.
- LLVM-MinGW 20260421 UCRT macOS universal compiler. Official archive SHA256: `bd85a3975723815cef28dbbd2ca2cb0c926f6b348a12a0453f39f7af273cb3f7`. Installed below Madeira/toolchains.
- Homebrew bison 3.8.2; LLVM 20 llvm-objcopy for Wine-server archive symbol renaming; Xcode's Simulator SDK and Metal tools.
- GMP 6.3.0, Nettle 3.10.1 and GnuTLS 3.8.9 are built by upstream's parameterized crypto script. Verify its SHA256SUMS before extraction/build. Current outputs are in toolchains/gnutls-iphonesimulator.
- Official Microsoft VC_redist.x64.exe: `https://aka.ms/vs/17/release/vc_redist.x64.exe`. Burn's second embedded CAB contains the runtime payload CAB. Extracted twelve x64 DLLs are staged unchanged in app/Madeira/x86_64-vcruntime. Local download and extracted-file hashes are in generated/madeira-downloads/vcruntime-manifest.json. This is not an Authenticode verification claim.

## Build order

1. Configure Wine's host build with the LLVM-MinGW and modern bison bin directories on PATH: `../configure --enable-win64 --disable-tests --without-x --without-wayland --without-gstreamer --without-ffmpeg`, from wine/build-macos. Build `make -j6 include/all tools/widl/all tools/winebuild/all` for headers and host generators.
2. Configure FEX in generated/madeira-fex-sim: CMake iOS, ARM64, iphonesimulator, deployment 17.0, Release, `TUNE_CPU=apple-m1`, `CMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY`; testing, FEXCONFIG, LTO, jemalloc-glibc, FEX allocator, offline telemetry and ccache disabled. Build **FEXCore FEXCore_Base**, not the shared Linux-oriented target. Ensure upstream's `python3` resolves to Python 3.11. FEX/build-ios symlinks to this Simulator build.
3. Run `scripts/build-madeira-wineserver.py --sdk iphonesimulator`. It compiles all 46 inputs, then renames twelve archive-local symbols. Copy generated/madeira-wineserver-iphonesimulator/libwineserver.a into app/Madeira.
4. Run `AGEPAD_SDK=iphonesimulator bash worktrees/madeira/build/gnutls-ios/build.sh`. Copy libgnutls, libnettle, libhogweed and libgmp archives into app/Madeira. Build FreeType as static iOS ARM64 Simulator, deployment17, with optional compression/PNG/HarfBuzz/Brotli dependencies off; expected archive path build/freetype-ios/build/libfreetype.a.
5. Run the win32u-unix and ntdll-unix build.sh scripts with `AGEPAD_SDK=iphonesimulator`. Both copy their results into app/Madeira. The latter explicitly enables the GnuTLS-backed implementations; empty conditional compilation must not count as TLS success.
6. Build host llvm-tblgen, then configure Simulator LLVM with that absolute `LLVM_TABLEGEN` path, no architecture targets/tests/tools/examples/benchmarks/zlib/zstd/terminfo, and `CMAKE_MACOSX_BUNDLE=OFF`. Build `LLVMPasses LLVMBitWriter` with six jobs. Saved CMake caches and logs identify exact configuration.
7. Compile air_msad, air_samplepos and air_tessellation helper shaders with Xcode Metal using `--target=air64-apple-ios18.0-simulator -std=metal3.1`. Generate headers using `xxd -i -n NAME`. Run Madeira/build/dxmt-ios/build.sh. This patch is explicitly a Simulator configuration. Merge libdxmt_unix.a and generated/madeira-llvm-sim/lib/*.a using `xcrun --sdk iphonesimulator libtool -static` into app/Madeira/libdxmt_combined.a.
8. Build the Xcode project with scheme Madeira, SDK iphonesimulator, arch arm64, derivedDataPath generated/madeira-baseline, `CODE_SIGNING_ALLOWED=NO ENABLE_DEBUG_DYLIB=NO`. Its separate bundle ID is local.agepad.windows-runtime. MetalFX is linked only for iphoneos; unsupported Simulator scaler/shared-texture functions explicitly fail or report unsupported.

## Bounded probes

`scripts/build-madeira-cpu-probe.py` creates generated/madeira-cpu-probe/AgePadCPUProbe.app. Default launch executes the bounded FEX x64 arithmetic program. `--dualmap` tests the separate memory alias; adding `--debugger-rwx` uses ordinary executable mmap. The latter requires an explicitly controlled debugger experiment; these are not product options.

`scripts/build-madeira-shader-probe.py` extracts a known vertex fixture from the pinned Wine D3D11 tests, links source-built DXMT/LLVM and creates generated/madeira-shader-probe/AgePadShaderProbe.app. It tests library loading, pipeline creation and an offscreen draw with pixel readback. Its fragment shader is native test MSL. This does not exercise Windows D3D11 APIs or imply game rendering.

Before any launch, inspect `xcrun simctl list devices booted -j`; only `574671AD-6F61-4558-9528-BF946DDB760A` may be booted. Install each separate diagnostic with simctl. Simulator launch stdout/stderr paths under /tmp refer to the Simulator data/tmp directory. Probe result.txt and shader output live in each app's Documents directory; resolve the current container using simctl get_app_container, not a stale UUID.

Continuous CPU qualification: after applying the complete fex.patch (including AgePadJITScope.h), rebuild FEXCore/FEXCore_Base and the CPU probe, then run `scripts/run-madeira-cpu-probes.py`. This restarts only the separate CPU diagnostic, runs three fresh-result cases, and leaves its final result visible. The scope hooks default to null; the CPU harness explicitly registers its callbacks before creating threads. Other applications retain their existing behavior.

## Windows core DLL build

Apply `port/windows/patches/wine.patch` inside the pinned Wine checkout, then run `bash scripts/build-madeira-windows-core.sh`. This builds the ARM64EC translator in generated/madeira-fex-arm64ec, builds required Wine host tools, builds plain ARM64 ntdll in wine/build-macos, configures/builds ARM64EC ntdll in wine/build-arm64ec, and writes the structural audit to generated/madeira-windows-core/audit.json. It does not install DLLs or modify bundled originals. The Wine ARM64EC configure step's missing host GnuTLS warning does not validate or invalidate the separate source-built iOS TLS handlers; no TLS runtime test occurred here.

The new ARM64 ntdll contains the source's additional thread-state export and shifts nine private ordinals. Audit consumers before packaging it; do not equate identical named-export coverage with full ABI compatibility. Remaining Windows core/GUI/graphics DLLs still need source rebuild and runtime qualification.

## Signed PE container experiments (windows-005)

Prerequisite: the source-built Windows core DLLs above. These commands build only separate diagnostics and preserve the installed classic game and main runtime:

```sh
/opt/homebrew/bin/python3.11 scripts/build-madeira-pe-container-probe.py
/opt/homebrew/bin/python3.11 scripts/build-madeira-pe-container-probe.py --kind ntdll
/opt/homebrew/bin/python3.11 scripts/run-madeira-pe-container-probes.py
/opt/homebrew/bin/python3.11 scripts/audit-madeira-container-layouts.py
```

The runner refuses to proceed unless only the designated Simulator is already booted. It installs the two diagnostic apps, deletes prior results, launches fresh processes and captures output. It does not boot devices. It leaves the ntdll diagnostic visible.

The builder reconstructs PE RVA layout, derives ARM64EC native ranges and native export redirections from CHPE metadata, splits on a 16 KiB boundary, and rejects relocations requiring immutable-prefix writes. It rejects nonzero dynamic relocation pointer, offset or section fields. Raw machine 0x8664 is allowed because the hybrid source-built FEX file uses that machine value; native code is identified using CHPE metadata. It signs the resulting Mach-O dylib and UIKit app, verifies signatures, and compares the immutable prefix byte-for-byte against the PE image. Runtime checks verify protections and spacing before applying DIR64 relocations to writable data only.

Outputs: `generated/madeira-pe-container`, `generated/madeira-pe-container-ntdll`, `generated/madeira-pe-container-runs`, and `generated/madeira-container-audit`. The static audit examines bundled DLL layouts; it does not modify them, reproduce them from source or qualify runtime behavior. No game binaries are transformed by this experiment. See the status document for loader integration boundaries.

## Actual Wine startup experiment (windows-006)

The Madeira patch now includes `build/ntdll-unix/agepad_signed_ntdll.h` (canonical local source `port/windows/SignedNTDLLLoader.h`), loader integration and a Simulator-only opt-in launch path. Apply the updated Wine patch for the ntdll TSD lookup. Build the PE ntdll with explicit `arm64ec_CFLAGS="-g -O2 -DAGEPAD_SIGNED_NTDLL_TSD=1"`; the updated Windows-core script supplies it. **CPPFLAGS from configure do not reach the PE compiler rule.** When changing compiler flags on existing objects, force a relevant rebuild; make does not track flag changes alone.

Rebuild native ntdll with `AGEPAD_SDK=iphonesimulator`, then the complete app with the existing xcodebuild command, then rebuild the ntdll signed container. Run:

```sh
/opt/homebrew/bin/python3.11 scripts/run-madeira-signed-startup.py --label unique-experiment-name
```

The runner stages a separate app ID, includes the signed ntdll container, verifies the app signature, checks the one-Simulator constraint, installs and launches with `AGEPAD_SIGNED_STARTUP=1`. It captures up to 15 seconds of process observation and logs; **it does not declare success from survival or a substring**. Inspect the runtime log and process snapshot. The current experimental build enters Wine's loader but fails during the subsequent FEX path. The current source-built PE differs from windows-004/005; preserve checkpoint hashes when comparing results.

## Signed dependency build and startup (windows-007)

Current flag name is `AGEPAD_SIGNED_WINE_TSD=1` (supersedes the ntdll-only flag from windows-006). The Windows-core script now builds host wmc and the ARM64EC ucrtbase/kernel32/kernelbase DLLs as well as ntdll and FEX. Apply the current Madeira, Wine and FEX patches; these are local experiments, not upstream contributions. The FEX import-library custom command now depends on its `.def` file, so added imports regenerate the archive.

The container builder supports `--container-only --source PATH --output DIRECTORY`. Build four dependency containers into `generated/madeira-containers/{xtajit64,ucrtbase,kernel32,kernelbase}` from their corresponding rebuilt DLLs, plus the ordinary `--kind ntdll` container. For example:

```sh
/opt/homebrew/bin/python3.11 scripts/build-madeira-pe-container-probe.py --container-only --source generated/madeira-fex-arm64ec/Bin/libarm64ecfex.dll --output generated/madeira-containers/xtajit64
/opt/homebrew/bin/python3.11 scripts/build-madeira-pe-container-probe.py --container-only --source worktrees/madeira/wine/build-arm64ec/dlls/ucrtbase/arm64ec-windows/ucrtbase.dll --output generated/madeira-containers/ucrtbase
```

Use the matching name/path for kernel32 and kernelbase. Each container receives a distinct install name; the startup runner stages them as `NAME.dll.dylib`. Rebuild native ntdll and the full app after loader changes. The runner now requires all five current containers and checks both PE-source and dylib hashes. An observation is not a success test: the latest integrated run fails in ThreadInit, with no completed Windows guest execution.

## Call-checker assembly flag (windows-008)

The Windows-core script now supplies `CMAKE_ASM_FLAGS=-DAGEPAD_CHECKCALL_DELEGATION=1`. CMAKE_C_FLAGS and CMAKE_CXX_FLAGS do not affect Module.S. This flag enables the local fallback to Wine's saved checker for targets outside the ntdll workaround. It does not enable every upstream FEX_IOS_HOST assembly branch. The corrected run reaches the generated-code entry boundary and fails on RW/non-executable memory; it does not run a Windows guest successfully.


### Integrated Windows CPU diagnostic (windows-009)

The updated Madeira patch registers a versioned FEX native JIT service in virtual_ios.c, gated by TARGET_OS_SIMULATOR and the signed experiment environment. The updated FEX patch enables the service only after a successful ABI probe, routes executable allocations to it, and installs nested write scopes in the compiler. No new compiler flag is needed beyond the existing FEX_IOS_HOST C/C++ flags and the narrowly scoped assembly delegation flag.

After rebuilding native ntdll, Windows FEX, its signed container and the full app using the preceding instructions:

```sh
/opt/homebrew/bin/python3.11 scripts/build-windows-cpu-integration.py
/opt/homebrew/bin/python3.11 scripts/run-madeira-signed-startup.py --label cpu-new-run --exe generated/windows-cpu-integration/agepad-cpu-integration-x64.exe
```

Use a fresh label. `--exe` stages the source-built diagnostic in the separate app and records its hash. The Simulator-only startup hook forwards its simple filename; omitting the option retains the bundled hello diagnostic. Verify the exact checksum/file/PASS markers, guest exit 0, clean thread completion and artifact hashes. App-shell survival is not a guest execution assertion. Build manifest includes the compiler command and independently computed million-iteration checksum. The CPU pass does not qualify the physical-device JIT path or Windows graphics.


### Windows DXMT integration (windows-010)

Apply current Madeira, Wine and DXMT patches. Keep the Windows-core build and native Simulator prerequisites above. This recipe isolates Meson 1.7.2, builds the Windows graphics DLLs and required Wine modules, and creates their signed containers:

```sh
/opt/homebrew/bin/python3.11 scripts/build-madeira-windows-graphics.py
/opt/homebrew/bin/python3.11 scripts/build-windows-d3d11-integration.py
```

After rebuilding native ntdll, native DXMT, its combined LLVM archive and the full app:

```sh
/opt/homebrew/bin/python3.11 scripts/run-madeira-signed-startup.py --label graphics-new-run --graphics --exe generated/windows-d3d11-integration/agepad-d3d11-integration-x64.exe
```

`--graphics` stages matching source PE headers alongside the signed containers, adds nine graphics dependencies, and enables MADEIRA_WIN32U. The runner removes its generated staging app before copying the current baseline; it preserves app data and the separate classic candidate. It still does not infer a pass from process survival.

For the diagnostic comparison that holds the first staging texture alive while allocating a second:

```sh
/opt/homebrew/bin/python3.11 scripts/build-windows-d3d11-integration.py --fresh-staging
/opt/homebrew/bin/python3.11 scripts/run-madeira-signed-startup.py --label graphics-fresh-new-run --graphics --exe generated/windows-d3d11-integration/agepad-d3d11-fresh-x64.exe
```

Current measured result is clear/readback success and draw/readback failure, exit 34. A success requires the ordinary vertex-buffer draw's expected pixels and clean completion, not just device creation, pipeline compilation or a clear. No device/game/FPS acceptance follows from this diagnostic.


### windows-011 argument-buffer correction

The DXMT patch now allocates iOS argument-ring blocks through Metal shared buffers instead of wrapping malloc memory. Rebuild Windows DXMT with the existing graphics build script and regenerate d3d11/dxgi/winemetal signed containers. The native diagnostic additions require rebuilding dxmt-ios, combining its archive with Simulator LLVM and rebuilding Madeira. The graphics fixture builder supports an optional `--procedural` control; ordinary acceptance uses no variant flags. Current ordinary manifest is `integration-manifest.json` (historical `manifest.json` may be stale). Preserved windows-011 per-run manifests are authoritative for their logs.

Two fresh `--graphics --exe generated/windows-d3d11-integration/agepad-d3d11-integration-x64.exe` runs passed all expected readback markers and Wine exit 0. The runner itself only observes startup; inspect guest results. No Simulator or physical-device FPS inference follows from these tests.

### Shared Windows time (windows-064)

Shared time is enabled by default in `run-madeira-signed-startup.py` from windows-065; explicit `--usd-time` remains accepted. The inherited native clock publisher is opt-in; without it the shared TickCount/InterruptTime/SystemTime remain zero even though QPC can advance. Build `scripts/build-windows-clock-probe.py`, run `generated/windows-clock-probe/agepad-clock-x64.exe` with that flag, and require API_AND_SHARED_TIME_ADVANCE plus PASS/root0. Use `--no-usd-time` for the deliberate negative control (root92). The earlier windows-064 negative-control run predates this default change.


## Experimental unlocked full flush (067)

`--unlocked-jit-flush` enables a pending Simulator qualification experiment. Default is off. It releases the metadata mutex during the existing full cache flush, retaining signal masking until executable protection is restored. Native and app builds plus instrumented lock-order tests pass; actual generated-code concurrency and performance are not yet qualified. The installed clock-enabled Steam candidate does not contain this change.


Checkpoint068 supersedes the installation note above: the opt-in unlocked flush is installed for `windows-steam-unlocked-flush`, after real two-child and four-thread256-code-revision diagnostics passed. Default remains off. Performance and full Steam compatibility remain unqualified.


## Direct assembly TEB candidate (070)

`--direct-asm-teb` selects a published per-bank TSD offset at FEX assembly transitions; defaultfalse retains x18 fallback. Translator and all8 banks rebuilt, but this candidate is not installed or runtime-qualified yet. Current Steam run is still `windows-steam-unlocked-flush`.


Checkpoint071 supersedes candidate070 installation status: direct assembly TEB is now installed in `windows-steam-direct-asm` after five actual Windows diagnostics passed. Shared clock and unlocked flush retained; real RpcSs running confirmed in Steam run. Neither default opt-in flags nor game/device acceptance changed.


## Cache-hit flush candidate (074)

`--cache-hit-explicit-flush` is off by default. Built but not installed; retains nested conservative scopes for compilation and all queued-work callback types. Scope-header tests pass; real Windows invalidation and performance remain unqualified. Current installed Steam label remains `windows-steam-direct-asm`.


## Shared-host memory candidate (076)

`--shared-process-memory` enables scoped real Mach memory transfer for registered signed guests in this host. Defaultfalse; debugger-port lookup unchanged. Server and app built; remote code test advances past access-denied but still executes stale code with cache-hit flag on or off. Current diagnostic `windows-shared-memory-cross-baseline`; Steam is stopped. Do not treat this as complete remote-memory/invalidation qualification.


## Pending work dispatcher check (078)

`--dispatch-pending-work` adds an acquire queue check before dispatcher cache hits and uses the existing compile path to drain pending work. Defaultfalse. Strict remote-code test passes enabled, fails disabled on same build, and passes combined with cache-hit flushing. Current Steam launch `windows-steam-pending-work` includes this and scoped shared-memory transfer. No game/device/performance qualification.


Checkpoint079 builds a follow-up that confines callback flush scopes to actual tracker work. Not installed or runtime-qualified; current live Steam remains078 `windows-steam-pending-work`. All generated containers/banks contain079 for the next intentional candidate test.


Checkpoint080 builds source x64 Wine `msctf.dll`; `--msctf-dll PATH` validates and stages it for the next launch, with a hash manifest. Not installed or COM-qualified yet. Current Steam PID/run unchanged.


Checkpoint081 qualifies actual msctf InputProcessorProfiles creation/current-language call and strict cross-process code revision with active-only callback scopes. Current Steam launch is `windows-steam-text-services`, including `--msctf-dll worktrees/madeira/wine/build-x86_64/dlls/msctf/x86_64-windows/msctf.dll`. No UI/game acceptance.


windows-084: private child capacity is now16; native/PE signed image table256. Rebuild native ntdll, ARM64EC ntdll container, all staged banks and app together. --child-banks accepts1..16; banks remain quarantined for the run. The two-child regression passes with16 staged, but high-bank execution requires actual integration qualification.

windows-086: --explicit-invalidation-flush is a default-off experiment for the three flush/dirty callbacks. Build/scope-test only at this checkpoint; actual Windows runtime qualification pending. Does not remove conservative compilation or memory-protection scopes.

windows-087: explicit invalidation flush passes strict cross-process, four-thread256-revision, and two-child Windows probes. Integrated into windows-steam-explicit-invalidation for measurement; no performance/device acceptance yet.

windows-089: --explicit-compile-flush is a default-off normal compilation experiment requiring --cache-hit-explicit-flush. Build/scope-test only; actual Windows qualification pending. Current Steam does not have this flag.

windows-090: explicit compilation plus invalidation flush passes five actual Windows CPU/concurrent/cross-process/children/D3D11 probes. Steam integration windows-steam-explicit-compile begins with unchanged256MiB pool and16 banks. Performance/device/game acceptance pending.

windows-093: signed native runtime rejects i386 child creation with STATUS_INVALID_IMAGE_WIN_32 before creating a child. Real Windows parent observes error193 and survives; x64 child regression passes. No32-bit support or helper success is claimed.


`--explicit-memory-flush` (default off) sets AGEPAD_EXPLICIT_MEMORY_FLUSH=1. Successful memory allocation/protection/free notifications keep their write scope but rely on checked delinker instruction flushes. Metadata updates and invalidation locks remain. Missing explicit-flush hooks retain conservative fallback. This is a Simulator experiment, not physical-device qualification.
