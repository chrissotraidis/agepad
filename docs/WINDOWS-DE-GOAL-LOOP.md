# Windows DE on iPad — active execution loop

**Latest user steering, 9 September:** prioritize the existing iPad Simulator before physical hardware. Re-inspect and use ref/AoE2DE, confirmed to contain the Mac ARM64 build. Active supplied-input investigation is recorded in DE-STATUS.md (candidate270); Windows route remains available when its separate input arrives. Do not require a physical iPad to continue the Mac Simulator startup investigation.


**User-directed priority reset (windows-262): get evidence from the actual DE engine and device path.** Do not spend successive turns on optional Steam/teardown refinements while original-game and device gates remain untested.

Started 8 September 2026 at the user's explicit request. This is the active implementation direction; historical Mac D-gates remain in DE-STATUS.md. The app goal tracker refused a replacement because its earlier blocked goal is unfinished; do not falsely mark that objective complete to replace it. This file records the revised goal and execution loop while work proceeds.

## Goal

Run the purchased Windows Age of Empires II: Definitive Edition entirely on iPad using a compatibility runtime, with genuine Steam login and ownership, a completed online match against a matching untouched Windows retail client, sustained gameplay performance and usable game-styled touch controls. No streaming or publisher-backed port.

## Gates

| Gate | Required result |
|---|---|
| W0 | Pinned source/dependency audit and reproducible build with no missing private prebuilt inputs. |
| W1 | Actual Windows x64 execution and D3D11 drawing in designated iPad Simulator. |
| W2 | Repeat on a physical iPad; document signing/JIT, memory, OS and hardware. |
| W3 | Genuine local Steam login, persistent session, entitled DE installation and successful real SDK initialization. |
| W4 | Current Windows DE menus and completed AI skirmish; screenshots, logs, frame times and game speed. |
| W5 | Completed private match against untouched matching retail client, with no desync or runtime-induced disconnect. |
| W6 | Touch selection/commands/camera/hotkeys, readable classic-style UI, audio, saves and lifecycle. |
| W7 | Sustained representative device games: target 60 FPS, initial floor 30 FPS, documented resolution/workload, median/p95 frame times and memory. |

W1 is useful engineering evidence; it does not prove W2. W2 may proceed before W1 if a specific platform boundary makes device testing more informative. W5 precedes substantial W6 polish. None of these gates are passed at intake.

## Immediate priorities after the user’s zoom-out request

1. Intake the original Windows Steam DE installation as soon as supplied; launch it in the isolated designated Simulator candidate up to its legitimate Steam gate. Record original-engine behavior. Do not gate this on full Steam teardown/recycling completion.
2. In parallel with missing game input, establish the physical-device backend: finish the isolated iphoneos app link, then verify the existing StikDebug-backed dual-map JIT fallback on the connected iPad. Source audit263 found that this fallback already exists; a replacement backend is warranted only by an observed incompatibility. Never equate compiling for iphoneos or host FPS with device execution/performance.
3. Once the engine runs, measure actual skirmish frame times and game speed, then genuine retail authentication/multiplayer and touch. Keep the full objective unchanged.
4. Park teardown work at failed262 plus the tested closed-entry lookup correction. Resume only for a concrete blocker in engine/device/Steam runs. No more infrastructure-only loop as a proxy for gameplay progress.

Missing inputs verified262: WindowsDE executable and connected physicaliPad. User was asked for these plus model/signing/StikDebug setup. Device compilation can proceed without those inputs; device execution cannot.

## Loop

1. Read current evidence; pick the lowest unmet dependency with a falsifiable hypothesis.
2. Pin source and inspect the build/runtime boundary. Use the actual implementation rather than upstream claims or projected FPS.
3. Make one bounded change; build from source; capture failures and artifact identity.
4. Execute the relevant test, classify pass/fail/inconclusive, and record evidence and next hypothesis.
5. Continue autonomously while useful authorized work remains. Change route after repeated evidence against a hypothesis; never fabricate Steam, ownership, simulation or graphics success.

Primary candidate: Madeira 97e2ce26e6dc9e4a38976f3b5deb9272d64558eb with its pinned Wine/FEX/DXMT forks. Fallback experiment: UTM 5.0.5 Windows guest, explicitly separating software CPU emulation from old-firmware hardware virtualization. Preserve Mac/HD work and supplied assets. Only Simulator 574671AD-6F61-4558-9528-BF946DDB760A; check inventory before runtime. Keep private game material and build outputs ignored. No vendor contact, purchases or account changes.

## Intake observations

- Madeira cloned into ignored worktrees/madeira at the pinned commit.
- No Simulator booted at intake; no physical device detected by devicectl.
- Approximately 309 GiB free on the workspace volume.
- Build audit already identifies a reproducibility gap: upstream wineserver build.sh expects an existing libwineserver.a rather than creating every object. Resolve from source, not a downloaded opaque base archive.
- Physical iPad model/OS/connection requested asynchronously; independent build work continues.

## First execution checkpoint

See [WINDOWS-DE-STATUS.md](WINDOWS-DE-STATUS.md) for measured outcomes. Source-built FEX executes bounded x64 arithmetic; source-built DXMT translates a Windows vertex shader and completes an offscreen Simulator GPU draw. Native Wine/DXMT app builds and opens. W0/W1 remain open: Windows PE provenance/rebuild and runtime-wide JIT/Windows execution are not qualified. No game, Steam, multiplayer, device or FPS pass.

Second implementation checkpoint: native FEX now passes fresh dynamic compilation across 41 blocks and a million-iteration branch loop (windows-003). Next: bridge or replace the separate Windows ARM64EC translator execution path; host CPU success is not Windows success. Full objective and all W-gates remain unchanged.

Third implementation checkpoint (windows-004): rebuilt the actual Windows ARM64EC translator and ARM64/ARM64EC ntdll DLLs, corrected a misplaced architecture-specific diagnostic, and audited export names/ordinals and bundled static imports. Candidate unchanged; integrated Windows/game execution remains unproven.

Fourth implementation checkpoint (windows-005): actual source-built Windows FEX and ntdll functions execute from signed Mach-O containers in Simulator, preserving original native code bytes with data-only relocation. This offers a route around placing the Windows compiler itself in writable JIT memory. Next: genuine Wine loader/process integration; then isolated process data for Steam. Static layout screening found 221/230 bundled DLLs without the checked obstacles, not runtime compatibility. All acceptance gates remain open.

Fifth implementation checkpoint (windows-006): signed ntdll is integrated into actual Wine startup. Fixed a measured x18-derived thread-data pointer failure with an explicitly enabled source-level TSD lookup. Startup now reaches executable TLS allocation, locale initialization and loading FEX/dependencies, then fails in that remaining path. No guest-entry completion or game pass. Next: signed FEX/dependency integration and generated-code JIT scopes; full scope unchanged.

Sixth implementation checkpoint (windows-007): five signed source-built DLLs integrate into the real Wine loader. Corrected double relocation, early FEX TLS access, missing ARM64EC bitmap and two ntdll-call-table errors. FEX reaches ThreadInit; a kernelbase thunk dispatch failure and absent generated-code pool remain. Next: general call-checker delegation and actual JIT pool/write scopes. This is progress toward W1, not a W1 pass or reduced goal.

Seventh implementation checkpoint (windows-008): correct delegation to Wine's call checker resolves the kernelbase thunk failure. FEX completes ThreadInit and attempts to enter generated EnterEC, which fails on measured RW/non-executable memory. Next: genuine MAP_JIT allocation plus Windows-compiler write scopes and startup dispatcher coverage. No Windows guest or W1 pass yet; full objective unchanged.


Current checkpoint (windows-009): integrated source-owned x64 Windows CPU/Win32 diagnostic passes in two fresh Simulator launches via signed Wine/FEX and a versioned single-mapping MAP_JIT service. All W-gates stay open; W1's CPU portion has evidence, but its Windows D3D11 portion is next. Preserve this passing diagnostic as a regression before expanding to source-built DXMT DLLs and graphics dependencies. Full goal unchanged.


Current checkpoint (windows-010): source-built Windows DXMT and its immediate Wine dependencies load; D3D11 HARDWARE device creation and Metal clear/readback succeed. Geometry draw is submitted but sampled pixels remain the clear color, including a distinct staging allocation. CPU regression still passes. Next falsifiable dependency: vertex data/resource binding/shader output versus command/target writes. Keep full Windows drawing acceptance and the full original goal; no W-gate is closed by the clear alone.


Current checkpoint (windows-011): **W1 passes bounded acceptance**, combining windows-009 CPU/Win32 execution with two fresh ordinary Windows D3D11 vertex-buffer draw/readback passes. Fixed iOS argument-buffer backing to use Metal-owned shared storage. This does not close W0 or W2–W7. Next: actual Windows DE intake and window/presentation paths. The installed Steam copy is ARM64 Mach-O Mac DE; no Windows DE executable found in ref. Physical device remains absent. Full objective unchanged.


Current checkpoint (windows-012): actual Windows window/swap-chain creation and 120 presentation calls succeed after a measured Simulator timed-present selector failure was corrected with an explicit plain-present fallback. Inspected screenshot shows the final frame; guest exits 0. No game/device/FPS/Steam acceptance. W1 remains bounded pass; full objective and all other gates unchanged.


Current checkpoint (windows-013): acquired genuine public Windows x64 Steam client and executed its real startup in the Simulator. Corrected a missing write scope around FEX unaligned backpatching. The next launch advanced but failed after code-buffer exhaustion caused a null-PC path; allocator diagnostics remain unresolved. Both observations are terminal failures, not login passes. Next: code-cache growth/rollover and real-client retry. All device/DE/Steam-auth/multiplayer/touch/performance gates remain open.


Current checkpoint (windows-014): corrected FEX lock-state TEB lookup; actual Steam no longer takes the repeated unpublished-compile path in the observed retry, reaching networking and more threads. A bundled wininet thread-state fault is next; source rebuild started. PID 38059 was live at last observation, not a completed or passed Steam run. Preserve full scope and recheck live state before restart.


Current checkpoint (windows-015): source-built signed WinINet resolves the measured networking fault; real Steam downloads and installs its 247352 KB update. Restart reaches child creation but signed ntdll cloning is unsupported, falls back to shared parent state and faults. Next: isolated signed DLLs/PE state for child processes. Preserve the updated guest directory recorded in evidence. This is updater completion only, not W3 or full-goal acceptance.


Current checkpoint (windows-016): preserved installed Steam and verified a fresh client reaches actual system-info/CEF helper launches, both requiring child isolation. Prepared the first signed child module bank; no runtime-isolation pass. Implement the source-grounded child-process plan next, retaining full Steam/DE/device/multiplayer scope.


Current checkpoint (windows-017): actual Simulator signed ntdll storage check passes, and parent Windows CPU/Win32 regression passes afterward. This is a prerequisite only: no child process ran. Proceed with private child ntdll/PEB/import/JIT integration; full objective unchanged.


## Private child core execution; startup parameters corrupt later — windows-018

Integrated opt-in private child ntdll initialization, dispatcher/TSD publication and per-PEB registration. The first run reached child loader initialization but correctly rejected parent-owned xtajit64. Routed child core dependencies to separately named signed bank-1 copies. Native JIT allocations now record owner PEB; query/release require the caller to own the live allocation. Only registered owners are admitted under the experimental flag. This is logical ownership within one host process, not OS/security process isolation. One child bank and the 16-entry table remain limits; the runner refuses oversized selections.

Native and full app builds pass. The real CreateProcess diagnostic now executes x64 child code through its private runtime and the parent receives its exit status. It FAILS acceptance: the child takes the parent branch, fails its attempted CreateProcess and exits 51; the parent detects the mismatch and exits 53. The required exit-73/unchanged-parent success marker is absent. This is not a successful multiprocess gate.

Added bounded command-line output to the source-owned diagnostic and parent/child native startup traces. In windows-child-params, both serialization and reconstruction show the correct quoted executable plus --child, with matching lengths (curdir 376, image 88, command 100 bytes). Later GetCommandLineW returns a fragment of the Simulator filesystem path. The corruption is downstream of reconstruction. Next inspect PE init_user_process_params and RtlSetCurrentDirectory_U; the latter contains an unchecked destination copy, but causation is not yet proved. Do not bypass command-line semantics to pass the probe.

Evidence: docs/artifacts/2026-09-08/windows-018; canonical Madeira patch refreshed and reverse-checked. Only the designated Simulator was booted. Separate failed diagnostic sessions were replaced, no classic game scenario restarted. The final shell PID 44140 is alive at observation but its Windows guest and wineserver have finished with failure; the screenshot remains the diagnostic viewport. No Steam login, DE, device, multiplayer, touch or FPS acceptance advances. Full original goal remains active.


## One real Windows child completes — windows-019

PE-side tracing establishes the windows-018 corruption cause. Root RtlSetCurrentDirectory_U strips the extended prefix from Wine's absolute Unix namespace path. The child then resolves the resulting relative path against itself: the current-directory copy grows to 754 bytes for a 520-byte destination and overwrites the adjacent command line. Before-copy and before-cwd parameters are correct; after-cwd parameters are corrupt.

The signed-runtime path now retains the extended prefix for the Wine Unix namespace. A destination-capacity check rejects an oversized directory before copying or replacing the old current-directory handle. The rejection branch itself is not runtime-qualified in this checkpoint. Rebuilt ntdll and all child-bank artifacts with validated hashes/signatures; Wine patch refreshed and reverse-checked.

The real CreateProcess probe passes: root and child current-directory copies are both 386 bytes within 520-byte capacity; child sees the quoted executable plus --child, exits 73, and parent verifies its own static value stayed unchanged, then exits 0. This proves the bounded one-child execution/status/data test. It does not prove all DLL independence, concurrent children, general lifecycle safety, CEF or physical-device execution.

Evidence: docs/artifacts/2026-09-08/windows-019. The designated Simulator is the sole booted device. Final shell PID 45223 remains alive after the guest and wineserver completed; do not treat the live shell as an ongoing guest. Classic app and game inputs remain untouched. Next: synchronized bank assignment and table capacity for two children, parent/two-child acceptance, then actual Steam helpers. DE, multiplayer, touch and gameplay FPS remain unproven; full objective active.


## Two overlapping children pass; actual Steam helper starts — windows-020

Added mutex-protected stable child-PEB bank assignment, with no recycling of banks after exit. Signed mapping registration is serialized. Native and PE relocation tables both expand to 64 slots, with release/acquire publication of the immutable owner record. Existing mapping reuse is checked before rejecting capacity exhaustion. Runner --child-banks validates and stages each selected bank and checks aggregate table capacity. Banks 1 and 2 are rebuilt from current PE sources. This prototype still has a 64 MiB JIT pool and four nonrecycled bank slots; it is not a general process implementation.

The new WindowsTwoChildProbe creates two named ready events and a common release event. Each child changes its private static data, signals readiness, and waits for release. Parent observes BOTH_READY before releasing them, verifies exit codes 73 and 74, checks its own static data remains unchanged, and exits 0. Actual Simulator logs show distinct PEBs assigned banks 1 and 2, separate translator allocations, both ready, both expected exits and the parent success marker. This is bounded overlapping-child evidence, not a proof that every shared native global is safe. In particular loader_ios.c still mutates global peb/argv and server_init_process_done contains global peb/initial_cwd accesses requiring audit.

Retried the genuine installed Windows Steam snapshot with graphics, WinINet and two private banks. Installation verification completes. The real steamwebhelper.exe maps, receives bank 1 and reaches private ntdll parameter initialization and executable TLS/module registration; its command line survives current-directory setup. No login or completed CEF initialization is established. At the latest observation PID 46892 is live, 2m08s elapsed, and its log is still growing. Reinspect this exact process before replacing it; the observation window is not terminal evidence.

The same run exposes an inherited process_ios.c filter refusing steamsysinfo.exe (plus several other diagnostic/crash helpers). Earlier statements about requests do not prove those helpers ran. This filter and inherited Chromium command-line adjustments need explicit review before asserting a faithful retail startup. Do not count a refused helper as a successful helper or hide that limitation.

Evidence: docs/artifacts/2026-09-08/windows-020; Madeira and Wine patches refreshed and reverse-checked. Only the designated Simulator was booted. The classic game and private inputs remain preserved. No Steam authentication, DE gameplay, physical device, multiplayer, touch or FPS gate closes. Full goal remains active; next observe the active CEF child and fix its measured next failure, with shared-native-state and lifecycle audits still outstanding.


## Console-host architecture mismatch localized — windows-021

The real web helper starts and logs startup, then creates Wine conhost.exe. The console host is bundled only in aarch64-windows; WineProcessBridge links this otherwise missing file into system32. Its logged machine is 0xaa64. Owner-aware stack setup correctly omits ARM64EC CPU state for that machine, but the experimental signed child path supplies ARM64EC ntdll/FEX anyway. The child faults repeatedly in ntdll and ResetToConsistentState (translator RVA 0x10a28c, load from null ChpeV2CpuAreaInfo). This is an architecture mismatch, not demonstrated JIT-pool exhaustion. The earlier two-x64-child test did not cover this native-ARM64 helper.

Configured a separate Wine build-x86_64. Initial target was unavailable because Wine defaults conhost to the host architecture; explicitly configuring --enable-conhost enables the x64 target. Source-built programs/conhost/x86_64-windows/conhost.exe now passes compilation and PE32+ x64 identity. Provenance and command logs are saved. Runner --conhost-exe validates PE machine and records the binary hash before staging it in arm64ec-windows, so the primary system-directory link wins over the ARM64 fallback. Retail game/client executables are unchanged.

Native server_init_process_done now uses the booting thread's PEB for completion/entry calls rather than the mutable global. Audit correction: initial_cwd is already _Thread_local in server_ios.c; the previous checkpoint's grouping of that variable with shared globals was too broad. Other global startup state (peb, argc/argv, startup_info_size) still needs audit.

Added an explicit --retail-processes experiment flag that bypasses inherited helper-name refusals and CEF command-line rewriting. It builds but is NOT enabled in this retry, which retains prior Chromium settings to isolate the console-host change. No claim of original retail process behavior follows from this run.

Captured the prior run's logs and final screenshot before replacing its verified console-host fault loop. New label windows-steam-x64-conhost is the active observation; read its run.json and exact PID before any replacement. The runner's short observation is not acceptance. No Steam login, DE, physical iPad, multiplayer, touch or FPS result is claimed. Only the designated Simulator was used and the classic game/private inputs were preserved. Full objective remains active.


## Active retry observed; cache-flush cost measured — windows-022

Revalidated the exact x64-console-host Steam run (PID 58149). Installation verification completes, runtime log continues growing and the process remains live after roughly five minutes; no conhost launch or terminal guest result is present in this observation. The previous PID 46892 is absent. No restart was performed. A bounded wait was followed by another observation of the same PID. Do not infer failure from elapsed startup time or success from shell survival.

A two-second native sample locates most sampled Windows execution-thread stacks in agepad_jit_service -> __clear_cache -> sys_icache_invalidate. Source case 3 invalidates the entire allocated JIT region whenever the outer write scope exits. This is concrete startup overhead evidence, not a gameplay FPS measurement or a proven optimization. FEX has explicit instruction-cache flushes in dispatcher emission, block emission, linking and unaligned backpatching, but coverage of every executable write is not yet established. Audit that coverage before removing or narrowing the conservative full-region flush; no cache-coherency behavior changed in this checkpoint.

The observer now optionally snapshots the three known test-client helper logs with --helper-logs, without searching account directories. Applied to this unauthenticated run, those logs are not yet present. Evidence and sample: docs/artifacts/2026-09-08/windows-022. Next continue this exact run toward console-host/CEF startup and use measured failure evidence. Full original goal stays active; DE, Steam authentication, physical device, multiplayer, touch and sustained gameplay FPS remain unproven.


## Console regression prepared; flush audit narrows safe optimization — windows-023

The same Steam retry remains active (PID 58149 at 8m25s). Steam and webhelper logs now confirm webhelper startup, and Steam's background updater remains active. No conhost result or completed CEF/login operation is present. No restart was performed.

Built WindowsConsoleProbe from source: it releases its inherited console, requests AllocConsole, verifies console mode and WriteConsoleW count, detaches, and writes results to C:\agepad-console-result.txt. This is a real console-host integration test for the measured Steam dependency, not a substitute console. Build passes; runtime acceptance is pending because the active Steam run is preserved. Use the x64 source-built conhost and signed graphics dependencies when this diagnostic can run.

Recorded WINDOWS-JIT-FLUSH-AUDIT.md. Explicit block/link/backpatch flushes exist, but dispatcher publication uses a different inline path, and pre-lookup CompileBlock work can invalidate/delink code. Therefore simply skipping the full flush or moving write permission after a cache hit is not established safe. No JIT cache-coherency behavior changed. Next audit dirty-range coverage while observing the actual console-host launch. Evidence: docs/artifacts/2026-09-08/windows-023. Full objective remains active and unfulfilled.


## Real console-host test passes; CEF null check terminates Steam — windows-024

Revalidated PID 58149 as absent. Its final log shows an unhandled 0x80000003 breakpoint in libcef.dll, not a console-host fault; no conhost creation occurred in that run. The breakpoint maps from loaded libcef base 0x70ec5c0000 to RVA 0x59c14b8. Disassembly shows a pointer loaded from RCX, tested for null, then an explicit INT3/UD2 sequence on the null branch. Guest RDI is zero in the fault capture. This identifies the failed condition, not the origin of the null pointer. The disassembler's distant nearest export label is not the function name. No assertion or game/client instruction was bypassed.

Ran the prepared WindowsConsoleProbe with source-built x64 conhost and signed graphics/core child bank. It logs ALLOC_MODE_WRITE_DETACH_PASS: real console allocation, mode query, full WriteConsoleW count and detach pass; parent exits 0. The child image is machine 0x8664 and receives private bank 1. Full console-host thread shutdown is not independently proved; retain that lifecycle limitation. The parent diagnostic's completed result was captured before replacement.

Started windows-steam-retail-processes with --retail-processes, three validated child banks, graphics/WinINet and the x64 console host. This disables inherited helper refusals and Chromium argument rewriting, testing whether the prior forced process/features configuration contributed to the null check. No causation is assumed. Initial PID 60049 is live; inspect the exact run before any later replacement. Prototype bank/JIT-capacity limits remain and may surface with the real process tree. No login or DE acceptance follows from launch.

Evidence: docs/artifacts/2026-09-08/windows-024. Only the designated Simulator was used. Classic game/private inputs remain preserved. DE, physical iPad execution, multiplayer, touch and sustained gameplay FPS remain unproven; full objective active.


## Original process tree advances; opt-in linker flush builds — windows-025

Observed the original-arguments Steam run (PID 60049). steamsysinfo.exe now starts rather than being refused, creates an x64 headless conhost in bank 2, and Steam starts CEF in bank 3. The headless console later calls NtTerminateProcess with status zero and faults during shutdown; the initial fault is a null call target in ntdll arm64x_check_call. Guest RIP resolves to conhost do_global_dtors (crt_init.h), so the earlier allocation/write/detach pass did not qualify full CRT shutdown. No null-call or destructor bypass was added. CEF is independently still progressing and reaches its Chromium version log; the run remains live at 7m24s and must be rechecked by exact PID.

Implemented --explicit-link-flush, off by default. Only ExitFunctionLink opts into the audited-scope hook: its direct/indirect instruction patches call NtFlushInstructionCache on four bytes, now checking status. Native operation 6 advertises the optional capability; operation 7 ends an explicitly-flushed scope. Any normal nested scope sets a thread-local conservative-flush requirement, so nested compilation retains the whole-region flush at outer exit. Ordinary scopes and dispatcher/backpatch paths remain conservative. Write permissions are restored on both paths. Counters distinguish full flushes from explicit-only completions. Native/FEX/app builds and all three rebuilt banks pass; Madeira/FEX patches reverse-check. This is BUILD evidence only. No runtime speed or cache-correctness acceptance is claimed yet; run CPU/branch, overlapping-child and graphics regressions before using it for Steam timing.

Evidence: docs/artifacts/2026-09-08/windows-025. Current running Steam still uses the previous build without this optimization. Existing game/private inputs and single-Simulator constraint preserved. Full DE/iPad/multiplayer/touch/FPS objective remains active.


## Shutdown caller localized against exact binary; CRT regression built — windows-026

Revalidated the existing Steam run, PID 60049, live at 19m39s with a growing runtime log. No restart occurred. CEF reports WSALookupServiceBegin failure 8 and runtime logs show missing msctf.dll / failed service-manager access, but neither is established as a terminal startup cause. Login is still unproved. The prior status turn is a verified wait, not a new execution milestone.

The first conhost shutdown fault records native LR 0x12c45c40c. Subtracting that child's FEX base 0x12c338000 yields RVA 0x12440c. Verified the installed xtajit64.dll SHA256 against the launch manifest (939e6e00cd30f5af5405aeabeec7981d3705ae6b7f78365e67d9de223229e01a); this matters because newer offline builds have different addresses. Its symbols and disassembly place LR in InvalidationTracker::InvalidateIntervalInternal. Before the call checker, code loads the context's virtual target from vtable offset 0xf0; the checker receives a null target. Source maps this to CTX.GetCodeInvalidationMutex(). The recorded guest RIP in conhost do_global_dtors is not an authoritative native caller stack. This strengthens a reentrant invalidation/context-lifetime hypothesis during FEX cleanup; it does not prove that a later UCRT callback is the cause. No teardown ordering change or null-call bypass has been applied.

Added --crt to the source-owned child diagnostic builder (mutually exclusive with --two). The child registers _crt_atexit, writes a sentinel from its cleanup callback, and invokes actual ucrtbase exit(73). Parent removes stale output, checks exit 73, verifies the callback sentinel and its unchanged private data, then exits 0. Build and PE import inspection pass. This tests explicit CRT callback/exit interaction; it does not yet reproduce the full conhost CRT startup or qualify arbitrary DLL unload. Runtime acceptance remains pending while actual Steam continues. The optional linker-flush optimization also remains runtime-unqualified and disabled in this live run.

Evidence: docs/artifacts/2026-09-08/windows-026. Next run the CRT diagnostic against baseline, then isolate callback lifetime using the exact native caller evidence; qualify the optional flush optimization separately. No additional Simulator or app replacement was used. Full DE, physical iPad, retail multiplayer, touch and sustained gameplay FPS objective stays active and unfulfilled.


## CRT/headless lifecycle regressions pass; linker optimization passes bounded gates — windows-027

The prior turn made progress by symbolizing the exact shutdown caller and preparing the CRT probe. Rechecked Steam PID 60049 live at 20m39s, then deliberately interrupted it to run focused regressions for its captured conhost failure. This was a controlled experiment replacement, not a timeout or spontaneous terminal result. Checkpoint 026 preserves its observed fault; no Steam login was achieved.

windows-crt-child-baseline passes with optimization off: _crt_atexit callback sentinel verified, child exit 73, unchanged parent data and parent exit 0. Added --crt-headless, which uses CREATE_NO_WINDOW. Wine maps that flag to its headless console allocation and launches the source-built x64 conhost with --headless. In windows-crt-headless-baseline, child exit 73, conhost's own exit 0 and parent exit 0 are all logged; no first-SEGV marker is present. Conhost reaches the same recorded do_global_dtors RIP and FEX allocation quarantine sequence seen in Steam, then completes. Therefore neither ordinary CRT exit nor this bounded headless lifecycle alone reproduces the Steam shutdown failure. Do not implement a global teardown bypass based on the prior hypothesis. Steam-specific state, lifetime ordering and concurrency remain candidates; no causal fix is established.

Opt-in explicit-link-flush passes the CPU million-branch checksum/file-roundtrip probe, overlapping-two-child rendezvous/status/private-data probe, and D3D11 clear plus vertex-buffer draw/readback probe. All guests exit 0. The CPU run explicitly logs full=15, explicit_only=1, proving that the optimized path was exercised. Other printed counters are sampled at powers of two, not exhaustive totals. These are bounded correctness regressions, not proof of every instruction-write path or any gameplay FPS improvement. The option remains off by default.

After capturing completed regressions, started windows-steam-link-flush with original retail process requests/arguments, graphics, WinINet, three private child banks and the source-built x64 console host. Inspect its run.json and exact PID before replacement; launch alone is not acceptance. Compare actual startup milestones and sampled cache-flush costs before claiming a speedup. Bank capacity, JIT pool capacity, shared native state and physical-device execution remain unqualified.

Evidence: docs/artifacts/2026-09-08/windows-027. Every runner checks that the designated AgePad G5 Simulator is the only booted device. The separate classic game candidate/private inputs remain preserved. Full DE/iPad/retail multiplayer/touch/sustained-FPS objective is active and unfulfilled.


## Descriptor cleanup off-by-one fixed; Steam retry still active — windows-028

Previous turn made progress through five runtime regressions and a genuine Steam retry. The exact optimized Steam PID 64575 is live at 4m39s. It reaches installation verification, actual webhelper startup and Chromium version/process-singleton logs. Conhost now exits zero, so the previous destructor failure is not universal; no causation from the optimization is claimed. Last sampled counters full=20794/explicit_only=11974 show real conservative-flush avoidance. A two-second native sample still shows 1120 top-of-stack sys_icache_invalidate samples; thread totals include waiting threads and must not be treated as a gameplay-FPS metric. No login yet.

The same runtime exposes a concrete cleanup bug: conhost's fd-cache-release closes fd 167, recorded as sysinfo thread 0040's reply read pipe. Source add_fd_to_cache stores fd+1; get/remove decode with -1, but ios_fd_cache_release incorrectly closes the encoded number. Corrected cleanup to atomically consume the entry, skip FD_TYPE_INVALID error entries and decode fd+1 (including valid fd zero). Noninitial cache blocks are mmap allocations; cleanup now munmaps them instead of calling free. This corrects actual neighboring-descriptor closure; it does not qualify the separate concurrent cache-release/publication lifetime model.

Added tests/test-fd-cache-release.py, which extracts the actual union and cleanup function and compiles them against host pipes and mappings. It validates closure of the intended fd, survival of the adjacent descriptor, ignored cached errors, valid fd zero, successful munmap of the extra block, and idempotent repeat release. Test passes; a negative control restoring the off-by-one fails the expected descriptor assertion. Initial harness attempts caught a signed-loop warning (fixed with unsigned j) and used an unreliable macOS mincore expectation (replaced by recording the actual successful munmap call). An old-source negative-control attempt only hit unused-helper compile warnings; it was not counted. Final arithmetic negative control reaches the assertion and is retained.

Native and app builds pass; Madeira patch refreshed and reverse-check passes. Running Steam still uses the previous installed app without this descriptor fix. Preserve its exact handle while observing; the next controlled retry should include this fix after headless/overlapping-child runtime regressions. No extra Simulator or current-app replacement in this checkpoint. Full DE, physical device, multiplayer, touch and sustained FPS objective remains active and unfulfilled.


## Descriptor cleanup passes Simulator regressions; corrected Steam running — windows-029

Previous turn made progress by fixing the descriptor-cache decoder and wrong deallocator, with host regression and build evidence. Revalidated the old Steam PID 64575 live at 6m35s, then deliberately replaced that run because its known cross-owner descriptor close had already occurred. This was a controlled corrected-build experiment, not timeout-based terminal inference.

With the new native build and optional linker-flush enabled, windows-fd-cleanup-headless logs the CRT callback/child-73/unchanged-parent pass, conhost's own clean exit 0, and parent exit 0. windows-fd-cleanup-two-child logs BOTH_READY, exits 73/74, unchanged parent and parent exit 0. Neither log contains CROSS! or the first-SEGV marker. These qualify the bounded regressions; absence of those markers does not prove all descriptor ownership or concurrent-release behavior. Native host cleanup is exercised; retail binaries are unchanged.

Launched windows-steam-fd-cleanup with the same retail process options, three private banks and source-built x64 conhost. PID 66030 is live at 45 seconds and completes installation verification. No helper/login acceptance yet. This is the current installed diagnostic. Preserve its exact process handle on continuation. Added runtime executable SHA256 to future runner manifests; captured this run's installed executable hash separately for native-build provenance.

Read-only device/input check: devicectl lists no physical devices, and ref still exposes the Mac app executable with no matching Windows AoE2DE executable found by the targeted scan. The retail Windows DE input and physical device acceptance remain outstanding. The existing classic candidate is preserved and the designated Simulator is the only booted device.

Additional performance lead, not changed: arm64x_check_call still reads PEB through x18, invoking native fault emulation frequently. Its historical comments discuss a failed fixed-TSD-offset experiment at 0x898; current logs instead publish a dynamic verified offset 0x8d8. A future experiment must use the published offset and check exact call-target classification/CEF behavior, not blindly restore that old hard-coded patch. No assembly change or performance claim in this checkpoint.

Evidence: docs/artifacts/2026-09-08/windows-029. Full DE/iPad/multiplayer/touch/sustained-FPS goal stays active and unfulfilled.


## Reentrant tracker teardown gate built; actual Steam still observed — windows-030

The prior turn made progress by qualifying descriptor cleanup in Simulator and launching corrected Steam. Revalidated PID 66030 live. Conhost again faults after FEX allocation quarantine, at a null call target in arm64x_check_call; descriptor cleanup therefore does not resolve that separate teardown failure. CEF independently reaches Chromium version and process-singleton logs. At 4m55s the same host is live with growing output; no login or terminal guest result. No restart in this checkpoint.

Prepared an iOS-only invalidation-notification lifetime gate. The original std::optional tracker is now held in a derived storage type whose destructor sets a separate atomic active flag false before the optional base destroys its value. Existing guarded memory/image/invalidation notification entrypoints test that flag first, before reading the optional or accessing the context. This addresses same-thread reentrant callbacks from FEX's own deallocation after tracker destruction starts. An optional destructor does not promise to clear has_value; querying a destroyed optional is invalid. The change does not skip guest destructors, preserve leaked translator state, or bypass a null call. It also does not solve callbacks that already passed the flag on another thread; process-thread quiescence and unguarded internal consumers remain outside this bounded fix. Causation/Steam acceptance are pending.

Added tests/test-invalidation-lifetime.py. It extracts the actual holder/gate definitions, supplies a mock tracker whose destructor reenters the callback, and proves access is allowed while live and withdrawn before member destruction. This is host C++ lifecycle evidence, not the full FEX runtime. FEX build, PE container and all three private child banks pass. FEX patch refreshed and reverse-check passes. The running app still uses the previous FEX without this gate. Next qualify CRT/headless and overlapping-child runtime behavior, then the real Steam lifecycle; preserve current CEF observation until a measured reason for replacement.

The x18 performance investigation remains source-only and unchanged. Full DE, physical iPad, genuine retail multiplayer, touch and sustained gameplay FPS objective remains active and unfulfilled. Evidence: docs/artifacts/2026-09-08/windows-030.


## Teardown gate passes Simulator checks; call-routing baseline passes — windows-031

Previous turn made progress by building the lifetime gate and its host test. Revalidated old Steam PID 66030 live at 5m50s, then deliberately replaced it to test the corrected translator after its captured shutdown fault. No timeout-based failure inference. The separate classic candidate remains preserved.

windows-invalidation-lifetime-headless passes callback/child exit 73, conhost's own exit 0 and parent exit 0. windows-invalidation-lifetime-two-child passes BOTH_READY, expected exits, unchanged parent and parent exit 0. No first-SEGV marker appears. These tests do not establish that Steam's intermittent teardown failure is fixed, or that concurrent callback quiescence is safe. The new gate remains a bounded same-thread destruction fix.

Built WindowsCallRoutingProbe to establish an ABI regression before any direct-TSD call-check experiment. The initial diagnostic used _snprintf from ucrtbase, where that export does not exist, so windows-call-routing-baseline correctly exits 61 on export resolution. Corrected it to the actual native signed msvcrt.dll export. windows-call-routing-msvcrt passes formatting of mixed integers/strings/doubles across the x64-to-native variadic boundary, native qsort callbacks into x64 with sorted-result validation, and exit 0. The initial diagnostic error is not counted as a runtime defect. No call-check assembly change has been made.

Started windows-steam-invalidation-lifetime with the descriptor fix, new translator gate, three private banks, original retail process arguments, x64 conhost and optional linker-flush. Inspect run.json for its exact new PID; this is now the current installed diagnostic. Launch is not Steam acceptance. Preserve the live process while it produces useful evidence, and check actual conhost teardown and CEF/login progression before attributing a fix.

Evidence: docs/artifacts/2026-09-08/windows-031. Only the designated Simulator was used. Full DE, physical iPad, retail multiplayer, touch and sustained gameplay FPS objective stays active and unfulfilled.


## Actual console-host shutdown passes this run; direct-TSD experiment built — windows-032

Previous turn made progress through lifecycle/ABI regressions and a genuine Steam retry. Revalidated the exact PID 68965 throughout this turn. Its actual Steam-created headless console host exits zero without the previously observed first-SEGV or CROSS! markers in the captured log. This is one successful retail helper shutdown, not a proof that the intermittent problem is eliminated. Webhelper startup is logged; at 3m44s the host is live and cef_log remains empty. No restart or login acceptance.

Prepared --direct-teb-check, off by default. Under AGEPAD_SIGNED_WINE_TSD, arm64x_check_call reads the loader-published per-image flag. If enabled and the discovered offset is nonzero, it loads TEB from (TPIDRRO_EL0 & ~7) plus ios_teb_tsd_offset, then PEB. Otherwise it retains the original x18 read. The rest of target classification is unchanged. x16/x17 are scratch and the original code overwrites x17 immediately afterward; x11 target, x10 dispatch metadata, arguments and stack remain untouched. Disassembly verifies these emitted branches and loads, but does not establish runtime ABI correctness.

The native loader sets the flag for both root and private-child ntdll after publishing the TSD offset, and rejects an explicit request if initialized exports are unavailable. Added the flag to signed writable-slot validation and the runner manifest. No hard-coded TSD index, no executable-memory patch, no global CEF-argument rewrite. The historical failed fixed-offset experiment is not evidence that this dynamic form works; the new variadic/callback baseline exists to test it.

Wine PE, native library, app, container and three child banks build successfully. Madeira/Wine patches refreshed and reverse-check. Running Steam still uses the preceding installed build without this experiment. Before enabling it for retail timing, run CPU/Win32, mixed variadic/callback, graphics and overlapping-child regressions; check root/child published flags and then genuine CEF. All runtime/performance acceptance for direct-TSD remains pending.

Evidence: docs/artifacts/2026-09-08/windows-032. No additional Simulator or app replacement occurred. Full DE/iPad/retail multiplayer/touch/sustained-FPS objective remains active and unfulfilled.


## Live Steam preserved; service DLL architecture verified — windows-033

Previous turn made progress by building the opt-in direct-TSD candidate while observing actual Steam. This turn repeatedly revalidates PID 68965 (live at 6m52s) without restart. CEF has reached Chromium version and process-singleton logs. A new two-second sample shows active native cache-flush work and associated virtual-mutex contention: 1198 sys_icache_invalidate top-of-stack samples, alongside many waiting-thread samples. This is neither a deadlock proof nor a gameplay-FPS measurement. No first-SEGV/CROSS marker appears in the observed current log; one successful helper teardown does not eliminate intermittent lifecycle concerns.

The root Steam process now attempts to load bin/steamservice.dll and receives STATUS_INVALID_IMAGE_FORMAT, followed by name-search failures. Verified local images: steam.exe is x64, while bin/SteamService.dll is i386. Inspected the retained bins_win64 archive: Valve's packaged member is also i386 and its SHA256 exactly matches the installed input (feaec497b4ba572cd1a9d4ba9c4dd9e1952d3d9c71e50476103f76b2bbff7a82). Thus the mismatch is not evidence that our extraction corrupted/replaced it. Whether this fallback/service path is required for the requested login/install workflow remains unproved; do not rename an unrelated DLL or hide the failure.

Refreshed the status document's stale opening summary, preserving historical checkpoint evidence while clearly stating current bounded passes and all unfulfilled DE/device/Steam/multiplayer/touch/FPS requirements. Direct-TSD remains built but runtime-unqualified and absent from this running app. No Simulator/app mutation occurred this turn. Full objective remains active; current run is a verified live wait with additional architecture evidence.

Evidence: docs/artifacts/2026-09-08/windows-033. Continue observing this exact run toward a real CEF result; prepare further experiments from measured failures, not elapsed time alone.


## Network-notifier error triaged; live UI checked — windows-034

Previous turn was a verified live wait with new service-DLL architecture evidence and corrected status documentation. Revalidated Steam PID 68965 in this turn. It remains active and CEF logs WSALookupServiceBegin failure 8. The current Wine source implementation of WSALookupServiceBeginW in dlls/ws2_32/protocol.c is a stub that sets WSA_NOT_ENOUGH_MEMORY and returns -1; this message alone therefore does not establish actual memory exhaustion.

Checked the matching upstream Chromium 126.0.6478.183 network_change_notifier_win.cc: RecomputeCurrentConnectionType logs this failure and returns CONNECTION_UNKNOWN. It does not abort in that branch. This supports treating the error as a network-detection limitation rather than proven terminal CEF failure. Steam's CEF may include modifications (its logged line number differs); this source check does not prove every later network/login operation works. Source: https://raw.githubusercontent.com/chromium/chromium/126.0.6478.183/net/base/network_change_notifier_win.cc . The Googlesource web opening failed; the official project's GitHub mirror succeeded. No fake success or network-stub bypass was added.

Checked installed simctl launch help: there is no documented background-launch option in this tool, so no parallel validation-app workflow was introduced. Kept the live Steam session intact. Captured and viewed an actual screenshot: the diagnostic viewport is black, presents remain zero, and no Steam login UI is visible. The shell's JIT indicator describes its original path and is not a validator for the custom signed/JIT adapter; do not reinterpret that badge as new execution evidence.

Direct-TSD remains ready for later runtime qualification, default off. No app update or extra Simulator this turn. Full actual DE/device/retail multiplayer/touch/FPS objective stays active and unfulfilled. Evidence: docs/artifacts/2026-09-08/windows-034.


## Direct-TSD passes four runtime regressions; genuine Steam retry started — windows-035

Previous turn was a verified live wait with source-based triage and a real screenshot. Revalidated baseline PID 68965 live at 11m19s, then deliberately replaced it for the prepared direct-TSD comparison targeting sampled thread-state exception overhead. It was not declared terminal and replacement was not attributed to a timeout. Baseline had no login UI; its logs/samples remain preserved.

With direct-teb-check and explicit-link-flush enabled, source-owned CPU million-branch checksum/Win32 file roundtrip, mixed integer/string/double variadic native calls plus native-to-x64 qsort callbacks, D3D11 clear/vertex-buffer draw/readback, and overlapping-two-child rendezvous/status/private-data tests all pass and exit zero. Root initialization logs the verified 0x8d8 offset and enabled flag. The two-child run also logs separate child module addresses with the same discovered offset/enablement. No first-SEGV marker in these logs. These are bounded ABI/execution regressions; no sustained gameplay performance or full Chromium compatibility follows from them.

Launched windows-steam-direct-teb with both cleanup fixes, three private banks, original retail process arguments, x64 conhost and both opt-in optimizations. Initial PID 71994 is live. Inspect that exact handle and its logs before further action. Compare actual startup milestones and samples before claiming a speedup. Direct-TSD remains off by default in the runner.

Evidence: docs/artifacts/2026-09-08/windows-035. Every runner rechecks the sole designated Simulator. Classic game and private inputs remain preserved. Actual DE gameplay, physical iPad execution, Steam authentication, retail multiplayer, DE touch controls and sustained gameplay FPS remain unproven; the full objective stays active.


## Direct-TSD reaches CEF; genuine service-bootstrap components prepared — windows-036

Previous turn made progress through four direct-TSD runtime regressions and a genuine Steam retry. Revalidated current PID 71994 live at 4m33s. Root and all three private ntdll images log enabled=1 with discovered offset 0x8d8. Conhost exits zero without an observed first-SEGV or CROSS marker. Webhelper and Chromium version/process-singleton logs appear. The old fixed-offset CEF-startup regression is not reproduced at these bounded milestones. Full CEF/login remains unproved. Timings are similar to the preceding run, so no clear startup speedup is claimed. A new sample still contains substantial instruction-cache flush/mutex work.

Source audit finds the signed-startup path starts wineserver and the selected Steam executable directly. The repo's fuller UI flow bootstraps services.exe; combase start_rpcss connects to SCM, opens/starts RpcSs and waits for running status. Existing actual logs have service-manager connection failures, and the current process tree lacks services.exe. This is a concrete unqualified infrastructure dependency, not proof that adding it alone makes Steam work.

Configured the existing x64 Wine build with --enable-services and --enable-rpcss, retaining --enable-conhost and all previous configuration options. Built actual Wine services.exe (x64 GUI) and rpcss.exe (x64 console); file identity, hashes and build logs are retained. No host service was installed or started. Runner now accepts explicit --services-exe and --rpcss-exe staging alongside conhost, validates PE x64 identity and filenames, and records hashes. Parser/help check passes; new staging is not yet runtime-qualified.

Built WindowsServiceBootstrapProbe: creates real services.exe detached, polls OpenSCManager while checking service-process survival, opens/starts real RpcSs and requires SERVICE_RUNNING. It is confined to the diagnostic Wine prefix and has bounded polling deadlines. It does not test COM activation or Steam acceptance. The current private-bank/JIT limits and service auto-start dependencies may be the next measured limitations; do not replace the service manager with fake success. Probe runtime acceptance remains pending while actual Steam continues.

Evidence: docs/artifacts/2026-09-08/windows-036. No current-app replacement or additional Simulator occurred. Full actual DE/device/retail multiplayer/touch/sustained-FPS objective remains active and unfulfilled.


## SCM connection and recovered alignment; cancellation crash isolated — windows-037

The status-only preceding turn did not change implementation; this continuation revalidated the live diagnostic, examined full exception traces, and built/ran a new source-owned Windows regression.

Real services.exe connected to the SCM probe (MANAGER_CONNECTED). Crucially, the initially alarming STLR alignment fault was recovered: runtime lines 1612–1616 dispatch 80000002 to FEX and report Handled unaligned atomic, followed by actual rpcss.exe creation. The earlier user-facing suggestion that this alignment write itself blocked service startup was incorrect and has been corrected. The old Mach backpatch only recognizes the older alias pool, but the downstream SIGBUS/FEX recovery handles this observed access in the new pool. Do not patch it based on the UNHANDLED Mach label alone.

The later native wineserver fault is real: req_cancel_async+0x158 writes through null x9 (address 8), repeats, and aborts the native wineserver thread. The app shell survived; it was revalidated PID77501 at 14:02:45 UTC before a deliberate diagnostic replacement. No timeout was treated as termination. RpcSs running status and SCM PASS are not established.

Native disassembly maps req_cancel_async+0x158 to list_remove(&async->process_entry) in inlined cancel_process_async, immediately after fd_cancel_async and optional cancellation bookkeeping. The list next pointer is null. This narrows investigation to cancellation/reentrant object and list lifetime; it does not yet prove a use-after-free or justify ignoring null links. Next inspect fd cancellation callbacks, async destruction and tracked-list ownership, then reproduce/repair the actual lifecycle.

Added WindowsUnalignedProbe and reproducible builder: explicit x64 64-bit stores/loads at offsets 0..7, verifying all stored bytes and unchanged surrounding bytes. windows-unaligned-baseline emits BEGIN/PASS and guest exit0. It does not demonstrate forced STLR backpatch at each offset, cross-thread atomicity or comprehensive alignment support. The service trace separately proves its observed STLR recovery. No runtime exception-handling change was made.

Only the designated Simulator was booted. The diagnostic bundle was replaced; the separate classic candidate was preserved. Full actual DE/device/retail multiplayer/touch/sustained-FPS objective remains active and unfulfilled.


## Cancellation use-after-free confirmed in actual service bootstrap — windows-038

Previous goal turn made progress by correcting the recovered-alignment diagnosis and passing a scalar alignment diagnostic. This turn added WINE_IOS/AGEPAD_SIGNED_NTDLL-scoped logging to async destruction and cancellation entry/return; no lifetime semantics were changed. The return log prints pointer identity without dereferencing potentially freed memory. Rebuilt all 46 server inputs and relinked the Simulator app successfully; async.c has no compiler warnings. Canonical Wine patch updated and reverse-apply checked.

Revalidated the previous alignment probe's host PID78369 and its guest exit0, then intentionally replaced the diagnostic with windows-service-cancel-trace. The designated Simulator remained the sole booted device; the classic candidate was preserved. New host PID79442 must be revalidated before further action.

Actual trace confirms the hypothesis: async=0x120f4a580 enters cancellation with refs=1 and non-null next/prev, then async_destroy logs the same address with canceled=1/terminated=1 BEFORE cancel-return logs that address. Immediately afterward req_cancel_async+0x1e8 faults writing address8. This is actual callback destruction followed by caller reuse, not merely an inferred null-list failure. The trace and precise build manifests are retained.

Source chain: default_fd_cancel_async -> async_terminate -> possible synchronous async_set_result -> drop queue reference -> final async_terminate temporary reference release -> async_destroy. cancel_process_async then attaches a cancellation tracker and unlinks the freed process_entry. A repair must retain selected asyncs through callback/list manipulation AND account for completion that occurs synchronously before cancellation tracking. Attaching a tracker after completed async_set_result can leave an uncompletable cancellation group; blindly adding a reference is insufficient. Investigate completed/signaled state and cancellation group ownership with a focused regression before changing semantics. Do not skip null links or return fabricated service success.

SCM connectivity was again reached; no RPCSS_RUNNING/PASS, Steam login, DE gameplay, device performance or multiplayer acceptance. Full objective remains active.


## Cancellation lifetime repair passes actual failure site — windows-039

Previous goal turn confirmed the cancellation UAF with native instrumentation. This turn changes cancel_process_async: retain each selected async before callback, move its process node to the tracked list before reentrant cancellation, attach completion tracking before the callback, and release the retained reference after restoring the process list. A temporary count sentinel keeps the cancellation group alive while synchronous completions occur during construction. Remove the sentinel before deciding whether a wait handle is needed. No null-link skip, fabricated completion or leaked lifetime substitute.

New tests/test-async-cancel-lifetime.py extracts actual cancel_process_async and async_complete_cancel into an AddressSanitizer/UBSan harness with modeled queue ownership and completion. It covers final-reference synchronous completion with/without a cancellation group, mixed deferred/immediate completion and wait-group signaling/release, callback removal of a sibling, and empty selection. All pass with no outstanding modeled refs. Running the same test against saved windows-038 source fails with an AddressSanitizer heap-use-after-free, confirming sensitivity. This is a focused lifecycle model, not an entire Wine server test suite.

All 46 native server sources and the Simulator app rebuild successfully. Wine patch updated and reverse-apply checked. Revalidated PID79442 live and deliberately replaced the diagnostic after confirmed server-thread failure, preserving the classic candidate and sole designated Simulator.

Actual windows-service-cancel-fixed (host PID80543, revalidate) passes the formerly crashing site: async=0x1257b9680 enters with refs=2, callback returns, then destructor runs after restoration. No observed req_cancel_async crash. SCM connects but RpcSs fails process_send_start_message's startup handshake; root probe emits FAIL and guest exits84 instead of losing wineserver. This is progress past the confirmed UAF, not RpcSs acceptance. Last RpcSs load logs are native module image notifications. services.c defaults service_pipe_timeout to10000ms and reports this error after its wait; next distinguish timeout from child exit and investigate startup loader progress before changing timing.

No DE gameplay, Steam login, device FPS, touch or multiplayer acceptance. Full objective remains active.


## RpcSs reaches RPC and faults in context-handle unmarshalling — windows-040

Previous turn repaired cancellation lifetime with sanitizer and actual service-site evidence. Revalidated PID80543 live before deliberately replacing the diagnostic. Added service connection wait/child-exit/elapsed diagnostics to source-built services.exe; no timeout or result semantics changed. First build needed the documented cross-toolchain PATH; corrected. A declaration-order warning was then corrected and services rebuilt cleanly after the run, so the saved run hashes describe the pre-cleanup binary.

windows-service-handshake-trace host PID81003 is terminal/missing, confirmed independently by ps after runner reported missing. It did not merely time out. SCM connects and RpcSs progresses farther into native RPC calls, then faults at rpcrt4.dll+0x1cca0, symbol #NdrContextHandleUnmarshall, writing address0x10. The service wait diagnostic is not reached before fatal guest handling ends the app. No cancellation-list crash is observed in this retry. Prior timeout and current crash show startup timing varies; do not assume increasing timeout fixes it.

Actual NDR diagnostics report the access-mask slot (offset0x10) contains a stack pointer, while the output-handle-pointer slot (offset0x18) contains0x10. Exact source-built signed sechost source hash46e4a4... matches its container manifest. Caller disassembly places dwAccessMask at [sp], handle at [sp+8], x4=sp, x5=16 and calls its import stub. The observed values resemble the ARM64EC variadic pointer/length registers, but where these replace the argument window is not yet proven. Existing rpcrt4 source comments document historical guesses and corrections; do not apply an arbitrary slot swap.

Saved caller/import/RPC-entry disassemblies. Next trace the native import/delay helper and ARM64EC variadic boundary, including the bundled rpcrt4 provenance versus newly built sechost. The earlier mixed-call probe covers msvcrt _snprintf, not this naked NdrClientCall2 boundary. No game/client binary patches, service timeout relaxation or fabricated RPC output.

Full DE/device/retail multiplayer/touch/FPS objective remains active and unfulfilled.


## Genuine SCM/RpcSs bootstrap passes with ordinary RPC import — windows-041

Previous turn exposed the NdrContextHandleUnmarshall bad pointer and preserved caller evidence. Source audit found existing loader notes describe the same first-call ARM64EC delayed-import corruption: the non-native first-call path deposits x4/x5 (varargs pointer/length) in ordinary x64 argument slots. Subsequent resolution redirects to EC, but cannot repair the already-entered first call. Current disassembly and NDR slot values match this mechanism. No argument-value substitution or RPC output fabrication was introduced.

Changed sechost/Makefile.in from DELAYIMPORTS=rpcrt4 to ordinary IMPORTS=kernelbase rpcrt4. Rebuilt source-owned ARM64EC sechost, root signed container and all three child banks. PE audit shows rpcrt4.dll/NdrClientCall2 in ordinary imports and a zero delay-import directory. Builds pass without compiler warnings. This is a targeted avoidance of the broken first-call delayed import, not a general correction to every ARM64EC variadic delay thunk. The dependency cycle through advapi32 is handled successfully in this tested startup.

Actual windows-service-eager-rpc host PID82533 (revalidate) reaches MANAGER_CONNECTED, service pipe wait=0 with child259/STILL_ACTIVE, then RPCSS_RUNNING and PASS. Root guest exits0. No observed prior NDR bad-pointer or cancellation-list crash. Uses real source-built Wine services.exe/rpcss.exe, not fake service responses. Only the designated Simulator was booted; classic candidate preserved.

This establishes SCM connectivity and RpcSs SERVICE_RUNNING in the bounded diagnostic. It does not establish COM activation, Steam login, DE gameplay or multiplayer. Next integrate service startup into genuine Steam execution and qualify real COM/client behavior. Account for current child-bank/table/JIT limits before adding a wrapper process: probe root + services + RpcSs + Steam + browser can exhaust existing ownership capacity. Preserve full scope and authentic Steam behavior.

Full actual DE/device/retail multiplayer/touch/sustained-FPS objective remains active and unfulfilled.


## In-process service startup hook passes CPU; genuine Steam retry active — windows-042

Previous turn passed real SCM/RpcSs bootstrap. To avoid adding a launcher process, added an opt-in AGEPAD_SIGNED_WINE_TSD kernel32 BaseThreadInitThunk hook. A Windows environment request is consumed/removed before creating children; a per-image interlocked guard prevents repeated entry. It launches real services.exe detached, waits on Wine's actual __wine_SvcctlStarted event or child exit with a120s bound, closes handles, and calls the application's original entry only on readiness. Failures exit92–95; no success substitution. This starts SCM, not explicitly RpcSs (normal COM/service requests can start it). Disabled unless requested. Runner --bootstrap-services validates required services.exe before mutations and records the option in run.json.

Rebuilt kernel32, signed root container, three child banks; Wine patch updated/reverse-apply checked. The CPU/Win32 test windows-service-entry-cpu logs service-bootstrap wait0, MILLION_BRANCH_CHECKSUM_OK, FILE_ROUNDTRIP_OK, PASS and guest exit0. No recursive service creation observed. This qualifies the hook's bounded startup and original entry preservation, not general process semantics.

Started genuine Steam from the preserved installed1788652215 snapshot with original arguments, graphics/WinINet, three banks, eager sechost RPC and the new bootstrap option. windows-steam-services initial host PID84122 revalidated live at14:25:01 UTC. At that observation it was still loading USER32 native image ranges, before the bootstrap readiness marker; no fresh Steam bootstrap log entries yet (copied historical logs are not current progress). A one-second native sample is saved, showing a native wait stack; further loader diagnosis is needed. Do not call this Steam service integration success. Do not restart merely due to elapsed time.

The current registration table remains64 entries and max staged3 banks with this dependency set. No capacity increase made. Current Steam run is active; revalidate exact PID and logs next. Sole designated Simulator reused and classic candidate preserved.

No Steam login, DE gameplay, physical device, touch/FPS or multiplayer acceptance. Full objective remains active.


## FEX logging moved outside interval lock; real Steam starts with services — windows-043

Previous turn built/qualified the optional kernel32 service startup hook but actual Steam waited during USER32 mapping. Revalidated PID84122 repeatedly. Attached LLDB read-only, captured native thread stacks, exact TEB syscall-frame pointer0x71fffe0378 and saved guest/native stack words, then detached/resumed each time. The wait is NtWaitForAlertByThreadId; raw stack symbol mapping against actual FEX base0x122a34000 names shared_mutex::lock, condition-variable wait, InvalidateAlignedInterval, HandleMemoryProtectionNotification, fmt formatting, VirtualFree and page_available_to_free. Raw saved stack words are evidence of the reentrant path, not a fully reconstructed ordered unwind.

Source has allocating LogMan formatting under IntervalsLock in HandleImageMap and free-removal paths. Formatting can release memory and recursively notify the same tracker. Moved image-map diagnostic formatting outside its scoped interval mutation lock; likewise moved containing-section/aligned-free logging after the locked removals. Required interval mutations remain locked; no memory notification skipped or forced lock success. Other tracker logging/allocation paths remain unaudited, so this is not blanket reentrancy correctness.

FEX build, root signed container and three child banks pass. FEX patch updated including new JIT scope header and reverse-apply checked. Revalidated oldPID84122 live at14:30:18, deliberately replaced it to test the measured lock change, not because a timeout declared it terminal. Sole designated Simulator reused.

Actual windows-steam-services-logfix initial PID85400 revalidated live at14:30:53, elapsed27s. Now passes USER32 mapping and logs service-bootstrap wait0. Genuine Steam writes NEW startup09:30:37 and installation verification09:30:49/50 entries. Historical copied bootstrap logs are not counted. This establishes service startup and actual Steam entry together, not login/CEF/COM acceptance. Leave active and inspect its next RPC/browser milestones; current three-bank capacity may constrain services/RpcSs/helpers.

No actual DE gameplay, device/touch/FPS or multiplayer acceptance. Full objective remains active.


## Measured browser bank refusal; eight-bank capacity built and tested — windows-044

Previous turn removed allocating interval logging from protected sections and got genuine Steam through service readiness. Current follow-up confirms verification complete, services in bank1, steamsysinfo in bank2 and conhost in bank3. Conhost exits0. Actual Steam then requests steamwebhelper, assigned bank4, but ntdll-child-4.dll.dylib is absent because only3 banks were staged. Loader refuses shared fallback. This is an observed missing private-bank failure, not speculation. OldPID85400 remained alive and was revalidated before controlled replacement.

Expanded native stable nonrecycled bank capacity4->8 and registration table64->144. Updated the PE relocation table scan to144, canonical/native header copies, runner bound and builder slot range1..8. Root plus eight full15-module banks requires135 entries. No reuse of exited owners, shared DLL fallback, protection relaxation or larger JIT pool introduced. Eight signed banks and root ntdll rebuilt; native runtime/app builds pass (existing unrelated ntdll warnings remain). Wine/Madeira patches refreshed and reverse-apply checked.

New test-child-bank-capacity.py extracts actual native allocator and tests eight concurrent owner reservations repeatedly, distinctness/stability, extra-owner refusal, header identity and matching native/PE table limit. Pass. Existing actual overlapping Windows two-child test passes with eight banks staged: BOTH_READY, exits73/74, parent data unchanged and parent exit0. It executes two banks, not all eight; high-bank and large-table runtime coverage remains actual Steam's next acceptance step.

Current genuine run windows-steam-services-eight launches with eight banks, service hook, eager RPC, interval-log fix and unchanged retail arguments. Initial host PID88732; revalidate. Leave it active for browser/RpcSs/COM progression. Native sample of prior run also maps hot x18 faults to FEX check_target_ec/enter_jit/ExitFunctionEC (separate from the optimized ntdll checker) and shows remaining full-cache-flush cost. No FPS improvement claimed.

Only designated Simulator used; classic candidate preserved. No Steam login, DE gameplay, physical iPad, touch, gameplay FPS or multiplayer acceptance. Full objective remains active.


## Fourth-bank webhelper starts; separate sysinfo cleanup fault identified — windows-045

Previous turn built eight banks and passed allocator/two-child tests. This turn revalidated actualPID88732 repeatedly; at14:40:56 UTC it is live, elapsed4m43s. Steam reports webhelper process84 and the actual helper writes its own fresh startup log09:40:02 with original retail arguments. Its fourth private bank loads successfully, advancing past the measured bank4 refusal. CEF log remains empty at this checkpoint; login/rendering/COM acceptance is not inferred.

A separate earlier steamsysinfo cleanup fault occurs on thread0044: repeated native PC0x106e672f0 writes to JIT-pool address0x129194000 and aborts that thread. Browser continues separately. Read-only LLDB image lookup identifies _platform_memmove+576; disassembly proves the faulting instruction is STRB w6,[x3],#1. This rules out misaligned scalar access as the reason for that byte-store fault; next capture caller/registers for the store into JIT memory before choosing a protection/lifetime repair. The currently capped first-fault logs do not establish the caller. No blanket writable mapping or memmove skip applied. LLDB detached/resumed after inspection.

Audited remaining hot x18 sites from previous sample: FEX Module.S check_target_ec, enter_jit and ExitFunctionEC. Generated build.ninja has FEX_IOS_HOST in C++ flags but not ASM flags; assembly currently uses x18 while ntdll's opt-in dynamic-TSD checker is enabled. Simply enabling FEX_IOS_HOST for assembly would introduce an unretargeted0x898 placeholder and other unrelated iOS paths, so do not do that. A future measured optimization must use the published dynamic offset and preserve scratch-register/call contracts, with separate qualification. No optimization implemented this turn.

No runtime/app replacement occurred. Sole designated Simulator remains active. Full actual DE/device/retail multiplayer/touch/FPS goal stays active and unfulfilled.


## CEF initializes then exhausts64MiB JIT; bounded256MiB retry — windows-046

Previous turn established fourth-bank webhelper startup and native sysinfo cleanup store fault. Current eight-bank run progressed to Chromium126.0.6478.183 and process-singleton logs, then FEX explicitly reported EXEC ALLOC FAILED even at0x100000 — JIT pool exhausted, before its forced0xdead fault. Host remained live; this is actual allocation failure evidence, not a timeout diagnosis. Screenshot inspected: black viewport, Present0/FPS0; native UI JIT badges do not describe the custom adapter's test status.

Added native stuck-fault register logging at the existing fifth-repeat diagnostic, including LR/FP/x0..x3 and thread port. It reads only captured thread state and changes no recovery decisions. Intended to identify the caller of the separate sysinfo memmove store into JIT memory on the next occurrence. Native build passes.

Added runner --jit-pool-mib choices64/128/256/512 (default64), passed via native environment and recorded in run.json. Native JIT service validates the same choices before pool creation; invalid values fail, and configured capacity is fixed once allocated. Retained MAP_JIT protections, owner-tagged chunks, monotonic allocation and quarantine; no reuse or forced successful allocation. Full-region cache flushing still scales with used bytes, so no performance improvement is claimed.

Native/app rebuild passes; Madeira patch refreshed/reverse checked. Actual windows-jit256-two-child logs poolsize268435456, BOTH_READY, child exits73/74, unchanged parent and parent exit0. Invalid runner capacity999 rejected before mutations. This confirms256MiB mapping and bounded existing execution, not filling the larger pool or device feasibility.

Revalidated oldPID88732 live at14:44:00 before deliberate replacement for the measured allocation-limit experiment. New genuine Steam run windows-steam-services-jit256 initial PID90304 is active with eight banks, services, eager RPC, interval logging fix,256MiB pool and cleanup diagnostics. Revalidate before further action. No additional Simulator or classic-candidate modification.

Steam login, actual DE, physical iPad, touch, sustained gameplay FPS and multiplayer remain unproved; full objective active.


##256MiB run passes64MiB extent; cleanup caller is signal emulator — windows-047

Previous turn responded to measured64MiB pool exhaustion with bounded256MiB capacity and a passing overlapping-child test. This turn keeps actualPID90304 live; revalidated at14:47:50 UTC elapsed3m, including one30s wait on the confirmed live run. Four private banks observed and Steam reports webhelper84. Logged pool extent83968000 bytes, remaining184467456, no out-of-range chunk records or exhaustion message. These are monotonic virtual extent values, not residency, complete-allocation proof or FPS.

Observer now reports unique logged chunks, extent/capacity/remaining, range validation, exhaustion marker, private banks seen, and recent stuck-fault register captures. Deduplicates identical records (UI log copies can duplicate them); scope explicitly warns missing logs can undercount. Verified current capacity256MiB and no out-of-range records.

The sysinfo cleanup write recurred. Captured pc0x10348f2f0 lr0x100d087b8 x0/x3=0x1256e9678 x1=0x71fff8f689 size4. Read-only LLDB lookup of LR names ios_emulate_unaligned_guest_access+368 in the native runtime. Thus the memcpy into JIT memory comes from the SIGBUS unaligned scalar-store emulator, not proven direct FEX/game backpatching. Caller source unconditionally memcpy's to siginfo fault address for recognized stores. Original faulting instruction/addressing context is still missing; do not merely enable writes or skip the store.

Added diagnostic BEFORE that scalar store to print original PC, instruction, fault address, size and value under AGEPAD_SIGNED_NTDLL. Native source build passes; no app rebuild/install yet, so the active run retains only the earlier stuck-register diagnostic. Madeira patch refreshed/reverse checked. Next use current browser progress first; on the next warranted diagnostic replacement, relink the app to capture the original store and address calculation.

No additional Simulator or current-app restart this turn. No Steam login, DE gameplay, device/touch/FPS or multiplayer acceptance. Full objective active.


## CEF initialization with spare JIT capacity; direct helper arguments prepared — windows-048

Previous turn identified the cleanup caller as the native unaligned-access signal emulator and built pre-store diagnostics. This turn revalidated actualPID90304 at5m25 and6m56 and after a bounded30s verified wait. Chromium initialization and process-singleton logs now appear in the256MiB run, with83968000 logged extent and184467456 remaining. No pool exhaustion observed. These are live CEF milestones, not login/rendering or game acceptance. No RpcSs child request observed yet in the current runtime log.

Added --guest-arg repeatable literal tokens to the runner, using the native bridge's existing MADEIRA_ARGS path. Its tokenizer only supports16 tokens and1023bytes without whitespace/quoting: runner explicitly rejects unsupported values before staging or installation and records supplied args. Default passes an empty string, avoiding unintended ambient MADEIRA_ARGS inheritance. Python compile check passes and a spaced token is rejected. Valid-token runtime acceptance remains pending. This prepares direct steamsysinfo execution with its observed query arguments, without changing Steam binaries or its normal launch flags; no helper-only run launched yet.

Relinked the app successfully with the prior pre-store instruction diagnostic. It is prepared on disk but NOT installed: currentPID90304 retains the earlier stuck-register capture. Leave the current run active while it advances; use the prepared diagnostic on a justified next replacement to identify original instruction/address calculation behind the cleanup emulator's JIT write. No timeout treated as terminal.

No additional Simulator, account access, input mutation or classic-candidate change. Full DE/device/touch/FPS/retail multiplayer objective active and unfulfilled.

## windows-049 — repair the observed delinker write

Previous status turn: verified wait (exact Steam host PID90304 live). This turn makes progress: isolated unchanged retail steamsysinfo query reproduces the fault; original PC identifies the direct branch-delinker store, not a guest unaligned access. Both delinkers now enter the existing conservative JIT write scope. Source rebuild, root container and eight banks pass. Retail helper gets past cleanup and exits -2 after failed Vulkan topology lookup. No result file, no successful query claim. Full genuine Steam rerun `windows-steam-delinker-fixed` is the next integration observation. Keep all W0–W7 requirements intact; device, game, multiplayer and performance are still unproved.

## windows-050 — full-client profile after cleanup repair

The live full Steam run reaches four banks with no repeated cleanup fault observed. A three-second native sample finds substantial full-pool instruction-cache flushing on one Wine execution thread (866/1968 samples); this is not an FPS measurement or exact caller attribution. Preserve the current run. Next optimization should qualify narrower flush ranges or identify conservative scope callers before changing TEB assembly based only on exception counts. Evidence: artifacts/2026-09-08/windows-050.

## windows-051 — prepared explicit delinker flush

Both audited delinkers now request the existing opt-in explicit-flush scope; each preserves its checked four-byte NtFlushInstructionCache. Translator/root container rebuilt. Runtime qualification pending; installed full Steam remains049 conservative candidate, live and advancing through webhelper startup. No claimed speedup. Compiler-scope narrowing requires additional write-path audit. See artifacts/2026-09-08/windows-051.

## windows-052 — retail helper qualifies explicit delinker cleanup

Unchanged sysinfo query completes cleanup with the explicit delinker scopes; guest exit -2 remains the failed Vulkan topology query. No recurring store fault and no output file. Sparse counters do not prove a speedup. Resume full real Steam as windows-steam-explicit-delinker; preserve all original game/device/multiplayer/FPS/touch acceptance gates.

## windows-053 — cache-hit flush shortcut rejected by source evidence

Pre-cache code can process real Wine cross-process memory/flush notifications and Mono invalidation; a cache hit does not imply the whole CompileBlock call performed no executable writes. Preserved compiler scope and active Steam PID97364. Exact source/evidence in artifacts/2026-09-08/windows-053. Next narrowing needs writer coverage, not a cache-hit flag.

## windows-054 — precise alignment backpatch flush candidate

Four audited instruction-patch paths now use checked eight-byte native cache flushes; ARM64EC wrapper opts into existing explicit scope mode. Scalar diagnostic passes but emitted no handler events, so patch-path acceptance depends on active full Steam windows-steam-unaligned-flush. Preserve that run; performance and full browser acceptance pending.

## windows-055 — visual check and Chromium singleton source

Black guest viewport/Present0 confirmed by actual Simulator screenshot. Chrome126 source establishes writable-lock warning follows successful CreateFile, then named message-window creation; it does not establish a fatal lock conflict. Preserve current PID445 run and trace onward rather than deleting lock state. Evidence and primary-source snapshots in artifacts/2026-09-08/windows-055.

## windows-056 — verified live wait and mutex profile

PID445 still live after45s bounded wait, no new browser milestone. Native sample identifies full-flush and memory-mutex waits on one execution thread; no deadlock proof. Preserve current run; no runtime mutation this turn. Evidence in artifacts/2026-09-08/windows-056.

## windows-057 — same run reaches Chromium

PID445 preserved through fresh Chromium initialization and singleton warning with no stuck context. Windows DE input/device still absent on read-only recheck. Continue actual browser call tracing; no reset or completion claim.

## windows-058 — debugger confirms flush contention

Read-only LLDB snapshot detached cleanly: named StackSamplingProfiler inside full-pool flush, two other threads waiting on agepad_jit_service mutex. Same PID445 alive after45s wait. Contention evidence, not deadlock/login acceptance. Preserve current run.

## windows-059 — actual loader-lock wait and owner state

Observed0094 waiting for loader owned0090; cached owner guest RIP maps into libcef immediately after ReleaseSRWLockExclusive. Cached RIP is not current execution proof. Owner identities/new browser threads change; no deadlock assertion. Read-only debugger detached; preserve PID445 and trace subsequent release/current context.

## windows-060 — genuine RpcSs startup order regression

Actual Steam hit RpcSs service timeout (wait0x102, live child). Added opt-in real RpcSs startup/status check before guest entry; controlled CPU/file test gets running1/state4/error0 and root0. Full Steam windows-steam-rpcss-prestarted launched for integration. Unexpected Simulator shutdown separately verified and only designated device rebooted. Original game/device/multiplayer/touch/FPS objective unchanged.

## windows-061 — verified wait on RpcSs-prestarted Steam

Same PID5497 live after45s wait; successful real RpcSs pre-start remains recorded, no new browser milestone. Preserve run and all final acceptance gates.

## windows-062 — prestarted services plus fifth-bank browser

Live5497 retained over three bounded45s waits; browser124 starts in bank5 with RpcSs prestarted. No interface acceptance or new service timeout. Preserve same run.

## windows-063 — browser DLL loading and96MiB flush snapshot

Same5497 live after debugger detach and45s wait. Actual full flush range grows with additional service buffers; another thread waits for memory mutex. DLL-loading progress, not interface acceptance. Preserve run; no unqualified flush narrowing.

## windows-064 — shared clock negative control and fix

Actual shared clock values frozen at zero traced to existing MADEIRA_USD_TIME opt-in. Added --usd-time; clock diagnostic disabled/root92 versus enabled/PASS/root0. Real Steam windows-steam-clock-enabled launched with clock publication and RpcSs prestart. All subsequent retail timing-dependent tests must use --usd-time unless explicitly serving as negative controls. Not a gameplay/FPS acceptance.

## windows-065 — prevent frozen-clock regression in launch defaults

Shared time now defaults on in runner; --no-usd-time explicitly selects historical negative control. Existing enabled Steam8142 preserved and verified live after45s. No new game/Steam acceptance.


# Clock-enabled Steam profile — windows-066

Previous goal turn: verified wait; the exact PID 8142 executable was live. This turn preserved that run and profiled it for three seconds. No app installation or Simulator restart.

The browser helper has now written its own startup command line (10:58:07 local); no CEF interface/login is established. At 15:59:29 UTC the host remained live at elapsed 7:51, with five private banks and logged JIT extent 100,761,600 bytes. Extent is not resident memory.

In the fresh profile, Thread_10069320 has 1,643 of 2,071 samples in the full-cache-flush path, plus additional flush stacks. Other threads wait for virtual_mutex at agepad_jit_service entry. This is per-thread sampling evidence, not an application CPU percentage, FPS benchmark, or proof of deadlock.

Source audit: virtual_ios.c agepad_jit_service holds virtual_mutex over full-pool clear_cache and write-protection restoration. server_ios.c server_leave_uninterrupted_section both unlocks and restores signals; moving that call before the flush would expose a signal-delivery window before executable protection is restored. Any proposed narrowing must preserve blocked signals through clear_cache and write-protection restoration, snapshot extent safely, retain nested conservative-scope semantics, and synchronize counters. Pool allocations are monotonic and release quarantines ranges; VPROT_SYSTEM suppresses ordinary delete_view unmapping, but all protection/teardown paths still require qualification before relying on mapping stability outside the mutex.

No lock-narrowing patch was applied. The next optimization experiment should test that contract with concurrent service operations before replacing the running Steam candidate. Keep genuine Steam execution as the acceptance workload; small tests only qualify the runtime change.

Actual DE, Steam login, physical-device execution, multiplayer, touch and gameplay FPS remain unproven.


# Opt-in flush lock experiment — windows-067

Previous turn was progress (fresh profile and locking audit) plus verified wait of exact PID8142. Current clock-enabled Steam remains installed and live, now with genuine CEF initialization and singleton diagnostics. No login interface, gameplay, FPS, multiplayer or physical-device acceptance.

Added native agepad_jit_flush_extent helper. Default retains metadata lock; AGEPAD_UNLOCKED_JIT_FLUSH exactly 1 temporarily unlocks only virtual_mutex, performs the same full snapshot extent flush, restores executable protection, and reacquires the lock. Outer server signal mask remains blocked throughout. Counters remain under the lock. Nested scope and explicit-flush decisions are unchanged. No extent reduction or omitted flush.

Runner exposes --unlocked-jit-flush (default false), deterministic environment 1/0, and manifest field. Existing PID8142 predates this binary and is unaffected. New native library and complete Simulator app build succeeded, but the new app has NOT been installed or exercised in Simulator.

Actual helper extracted into ASan/UBSan test passes both modes: a second thread can acquire metadata lock during flush/protection only in enabled mode; identical full range; signals remain blocked through executable protection restoration; caller lock held on return. This instruments cache/protection operations and does NOT establish ARM cache coherence, all Wine protection/teardown races, or performance. Those require runtime qualification before adopting the experiment.

Next: audit remaining pool protection/teardown stability, qualify concurrent real generated-code execution with flag enabled, then compare genuine Steam startup. Preserve current live run until a deliberate candidate test is ready. Canonical Madeira patch refreshed and reverse-apply checked. No proprietary binaries added.


# Real Windows qualification of unlocked full flush — windows-068

Previous turn: progress (implementation, source-extracted concurrency contract test, native/app builds). Revalidated exact old PID8142 live. Deliberately replaced diagnostic app for candidate qualification; no timeout/crash was inferred. Sole designated Simulator used. Separate classic app and saves preserved.

Actual Windows two-child diagnostic with --unlocked-jit-flush: BOTH_READY, child exits73/74, TWO_EXITS_PARENT_UNCHANGED, root exit0. Actual new x64 concurrent-code diagnostic: four Windows threads each own a code page; 64 rounds rewrite mov-eax-immediate/ret, change RW to RX, FlushInstructionCache and execute, checking every result. All256 revisions passed, root exit0. Each page has one owner; this does not test concurrent writes and execution on the same page, all Wine VM teardown paths, or comprehensive cache coherence. No gameplay/FPS claim.

Current installed candidate: windows-steam-unlocked-flush, initial PID10626 (revalidate exact path in run.json). Genuine retail processes, shared clock on, SCM/RpcSs bootstrap, eight banks,256MiB JIT pool, explicit linker/alignment flush, direct TEB, and opt-in unlocked full flush. At23s host live, real RpcSs reported running1/state4/error0, genuine Steam startup logs appeared. No browser/login yet at that checkpoint. No runtime performance improvement claim until profiling the relevant later startup stage.

Next: preserve and profile current genuine Steam run, compare metadata contention while browser initializes. Actual DE execution, physical iPad, multiplayer, touch and sustained FPS remain unproven.


# Early unlocked-flush Steam sample — windows-069

Previous goal turn: progress (real two-child and four-thread code-revision tests, new actual Steam launch). Revalidated exact PID10626 live, preserved run. Three-second sample at approximately64s startup shows agepad_jit_flush_extent active and substantial sys_icache_invalidate sampling. No __psynch_mutexwait stack entries in this early sample. It precedes the browser-heavy stage of checkpoint066, so it cannot establish an apples-to-apples speedup or absence of later contention. Steam installation verification completed at11:05:28 local.

Independent next-cost audit: current runtime logged over240,000 x18-emul3 events by early observation, concentrated at translator instruction sites reading TEB->PEB and TEB->ChpeV2CpuAreaInfo. The actual Module.S compile command does not define FEX_IOS_HOST; its else branches still read x18. C++ ProcessInit already imports the dynamically published IosTebTsdOffset before InitCore. Do not enable FEX_IOS_HOST wholesale for assembly: it also activates old alias/FFS bypasses, sweep behavior and a hardcoded-offset text-patching macro. A prospective narrowly gated assembly helper should read a per-bank runtime offset, use only x16/x17 scratch at audited transitions, retain legacy fallback when disabled, and leave all unrelated IOS branches unchanged. No such patch is applied in this checkpoint.

Keep current Steam run for later browser-stage profiling. No login interface, actual DE, physical device, multiplayer, touch or gameplay FPS acceptance.


# Direct assembly TEB candidate — windows-070

Previous turn: verified wait plus early profile and assembly audit. Current PID10626 revalidated; remains installed/running with unlocked flush, without this new assembly change.

Local FEX candidate adds per-image AgePadAsmTebOffset, default0. After CRT/logging initialization, AGEPAD_DIRECT_ASM_TEB exactly1 selects imported IosTebTsdOffset (nonzero,8-byte aligned), logging the value. Five default assembly TEB-field reads now select direct TPIDRRO_EL0-and-~7 plus runtime offset when enabled, retaining x18 fallback when disabled. Uses only x16/x17 scratch, preserving flags and other registers at reviewed transition sites. Does NOT enable FEX_IOS_HOST for assembly or alter the old FFS/alias/sweeper paths. No text patching or hardcoded pthread offset.

Translator build/link and root plus eight child containers succeeded. Actual object disassembly confirms relocations to the runtime variable, cbz fallback, register-offset TSD load and unchanged downstream transitions. Existing ARM64EC x23 assembler warnings remain. Runner exposes --direct-asm-teb, defaultfalse, explicit environment1/0 and manifest flag. Canonical FEX patch reverse-apply checked. Candidate NOT installed or runtime-qualified; next tests must cover CPU, callbacks, concurrent threads, child ownership and graphics before genuine Steam comparison.

Current unlocked-flush Steam wrote webhelper startup at11:08:31, about3:42 afterlaunch16:04:49UTC. Prior clock-enabled locked run wrote startup10:58:07, about6:29 afterlaunch15:51:38UTC. Single uncontrolled observations, not a repeatable benchmark or gameplay FPS. Current browser-stage sample saved separately when complete. No login interface, actualDE, physicaldevice, multiplayer, touch or FPS acceptance.


# Direct assembly TEB runtime qualification — windows-071

Previous turn: progress (narrow candidate build, all banks, disassembly, real browser profile). Revalidated exact PID10626 live; it had reached Chromium initialization. Deliberately replaced diagnostic app for new candidate tests, never treating observation expiry as termination. Sole designated Simulator; separate classic app/saves preserved.

Five actual x64 Windows tests with --direct-asm-teb, --direct-teb-check, --explicit-link-flush and --unlocked-jit-flush all pass with root exit0:
- Native mixed variadic arguments and native-to-x64 callbacks.
- Four Windows threads executing256 checked code-page revisions.
- Two simultaneous child processes: child exits73/74, parent unchanged; each private bank imports/logs offset0x8d8.
- Million-branch checksum and filesystem roundtrip.
- Direct3D11 device, GPU clear/readback, shader draw/readback.

Each test logs enabled AgePad-asm-teb offset0x8d8. These are bounded functional checks, not all Windows/ARM64EC transitions, native-device JIT, full cache coherence, game compatibility or FPS. Graphics is an offscreen readback test; no new gameplay screenshot claim.

Genuine Steam launch label windows-steam-direct-asm now includes both optimizations, real SCM/RpcSs prestart, shared clock, eight child banks and256MiB JIT pool. Inspect run.json/current observation for actual process state. Retail files/process arguments unchanged. Next: measure helper startup, exception count and browser progress, then genuine login and original Windows DE input. No actual game, multiplayer, physical device, touch or sustained FPS acceptance.


# Direct assembly Steam observation — windows-072

Previous turn: progress (five actual Windows tests and genuine Steam launch). Exact PID13879 revalidated live. Preserved current installed candidate throughout this turn; no restart.

Observer now records sparse x18-emulation counter lower bound, recent PC/instruction/TEB-offset samples, and logged direct-assembly offsets. Empty observations use null rather than reporting zero faults. Python compilation and execution on real runtime log passed. At elapsed2:03 maximum logged counter was20 with offset0x8d8 enabled; this is NOT an exact total or all-exception count. No high repeating4096-step records yet. Steam installation verification complete; browser helper not yet logged at that checkpoint.

A fresh three-second native profile still samples extensive full-pool instruction-cache maintenance, despite removal of the earlier repeating assembly thread-state fault path. No end-to-end speedup claim. Actual native runtime remains live and accumulating new activity. Next: let this candidate reach browser stage and investigate why conservative full flushes remain frequent; do not assume a cached-block lookup path is free of precompile/invalidation side effects.

No Steam login, actual DE, physical-device execution, multiplayer, touch or gameplay FPS acceptance.


# Cache-hit flush scope boundary — windows-073

Previous turn: progress (observer fields, fresh profile) plus verified wait. Revalidated exact live PID13879. Current direct-assembly Steam preserved, reached helper launch with five banks and100,761,600-byte logged JIT extent; thread-state counter lower bound remains20 in observation.

New source boundary audit: CompileBlock owns a conservative write scope before PreCompile and before either successful FindBlock return. ARM64EC PreCompile calls actual Wine ProcessPendingCrossProcessEmulatorWork. Its complete switch dispatches only six FEX callbacks: NotifyMemoryAlloc, NotifyMemoryFree, NotifyMemoryProtect, BTCpu64FlushInstructionCache, FlushInstructionCacheHeavy, BTCpu64NotifyMemoryDirty (heavy fallback also calls the latter heavy-flush handler). Merely removing outer flushing would fail to cover this work.

A candidate can retain outer RW protection with explicit-only leave during lookup, require a nested conservative scope for real compilation (including debug single-step), retain conservative handling around Mono activation, and add conservative coverage to all six queued-work callbacks when experiment enabled. Thus cached returns with an empty work queue avoid full flush, while real compilation and actual queued memory work retain full flushing. Unrelated prelookup diagnostic code and early returns must also be reviewed before implementing. Tradeoff: callback coverage may add flushes outside CompileBlock, so measure counts and startup rather than assume net improvement. No scope optimization applied yet.

Invalidation trace: InvalidationTracker::InvalidateIntervalInternalLocked -> ContextImpl::InvalidateCodeBuffersCodeRange -> GuestToHostMap::InvalidateRange -> Erase -> registered delinkers; those already have explicit write scopes with checked instruction flushing. Thread cache invalidation resets frontend executable-range cache and call/return data. Keeping conservative callbacks avoids depending solely on this narrower audit for queued work.

Next: implement a narrowly gated experiment with coverage for those mutating paths, test nested scope semantics and actual code invalidation before installing for Steam. Current live run should continue toward CEF/login. ActualDE, physicaldevice, multiplayer, touch and gameplayFPS remain unproven.


# Cache-hit flush candidate — windows-074

Previous turn: progress (complete queue callback audit) plus verified wait. Current PID13879 revalidated live, now past8minutes with Chromium initialization. No login yet. Installed candidate unchanged.

Implemented opt-in AGEPAD_CACHE_HIT_EXPLICIT_FLUSH (runner --cache-hit-explicit-flush, defaultfalse). CompileBlock outer scope can leave explicit-only on cached returns. Real compilation, debug single-step, Mono activation receive nested conservative scopes. All six actual Wine queued-work callbacks receive conservative scopes when experiment enabled. Native nesting therefore retains full flush when any of these paths runs. Callback scopes also run outside lookup and may increase flushing there; net performance remains to be measured. Disabled mode keeps prior flushing behavior. Missing explicit-leave capability falls back conservative.

Scope header adds optional enabled parameter. Actual header test under ASan/UBSan passes disabled scopes, cache-hit leave sequence, nested real compilation, callback/delinker nesting, absent explicit capability and absent hooks. This checks hook calls, not all guest invalidation behavior or native code coherence. Translator build/link, root container and all8 child-bank rebuilds succeeded; canonical FEX patch refreshed and reverse-apply checked. Candidate NOT installed or qualified with real Windows code yet.

Next: run actual concurrent code-revision/invalidation test and child/callback checks with new flag before genuine Steam comparison. Keep retail execution as acceptance workload. ActualDE, physicaldevice, multiplayer, touch and gameplayFPS remain unproven.


# Cache-hit qualification and pre-existing cross-process write failure — windows-075

Previous turn: progress (candidate implementation/build/scope tests). Exact PID13879 live and sole designated Simulator revalidated; deliberately replaced diagnostic app for qualification. Separate classic app/saves preserved.

New cache-hit flag enabled: actual concurrent256-code-revision test, mixed variadic/native callback test, and two-child isolation/expected-exit test all passed with root exit0. This is bounded functional evidence, not full queued-work coverage.

New WindowsCrossProcessCodeProbe: child allocates code returning1, executes it, publishes address via file then signals ready. Parent changes child protection RW with VirtualProtectEx, writes code returning2 through WriteProcessMemory, restores RX and flushes child instruction cache; child must execute2. New test fails WRITE_FAIL/root27. Identical executable with cache-hit flag disabled fails the same way. Thus no evidence this write failure was introduced by cache-hit scopes. Remote protection succeeds before write failure; write error number not yet captured.

Source discovery: build/wineserver/mach_ios.c get_process_port returns process->trace_data. Inherited task32 comment explicitly preserves missing ports/access-denied for read/write_process_memory because enabling mach_task_self globally previously reportedly regressed Steam. This historical claim is not independently reproduced. read/write implementations early-return STATUS_ACCESS_DENIED on missing port. Do NOT blindly change get_process_port: shared-host fallback can also reach task_suspend and thread/context operations. Next diagnostic should capture actual Win32/Mach error and establish allowed signed-process/host ownership, then provide narrowly scoped real memory transfer or an appropriate request path without activating unrelated ptrace behavior.

Current installed diagnostic: windows-cross-process-baseline, root exited27; its host/child lifecycle must be revalidated. Steam is NOT currently running. Cache-hit candidate passed three existing tests but remote queued-memory-write qualification is incomplete. Keep goal active: there is concrete runtime repair work.

ActualDE, Steamlogin, physicaldevice, multiplayer, touch and gameplayFPS remain unproven.


# Shared-host memory transfer and stale translated code — windows-076

Previous turn: progress (new cross-process regression and baseline failure). Added exact error diagnostic: baseline WriteProcessMemory returns Win32 error5, ACCESS_DENIED. Real server registers each guest process unix_pid from getpid(); process-handle access rights are checked in server process.c before memory helper calls.

New native opt-in AGEPAD_SHARED_PROCESS_MEMORY (--shared-process-memory, defaultfalse): memory transfer only when current and target guests have registered signed image ownership, same actual host PID, and target has running threads/not terminating. Uses real Mach read/write memory primitives, preserving get_process_port/debugger behavior. No task suspension or RX-protection fallback. Read branch checks transferred length. This enables same-host guest memory access, not actual OS process isolation. Simulator server46files and full app rebuilt successfully; canonical Madeira patch reverse-apply checked.

Actual test with shared memory enabled advances beyond WRITE_FAIL, but child executes STALE_CODE, exits15; root exits30. Same new native build with cache-hit optimization DISABLED produces identical stale-code failure. Therefore stale-code failure is not established as a cache-hit regression. Remote API success does not by itself prove target source bytes changed; next test must check child bytes before executing and trace notification enqueue/drain/target tracker.

Current installed diagnostic: windows-shared-memory-cross-baseline, root exit30, child15. Steam is not running. Native shared-memory path is experimental; successful complete code-revision test and memory-read/error-path qualification remain missing. Do not promote as correct complete remote-memory semantics.

Source next boundary: ARM64EC NtFlushInstructionCache calls send_cross_process_notification(CrossProcessFlushCache) for a noncurrent process only when enter_syscall_callback succeeds; target drains through ProcessPendingCrossProcessEmulatorWork. Trace actual queue/mapping/gating before bypassing it. ActualDE, Steamlogin, physicaldevice, multiplayer, touch and gameplayFPS remain unproven.


# Source bytes change, cached execution remains stale — windows-077

Previous turn: progress (actual error5, scoped real Mach memory transfer, stale-code positive/negative cache-hit observations). Installed diagnostic replaced deliberately on sole designated Simulator; no game saves touched.

Two revisions of the cross-process test expose instrumentation sensitivity. First: child reads code byte2, logs SOURCE_BYTES_UPDATED, then executes function; child/root both exit0 and REMOTE_CODE_REVISION_PASS. Second: child reads volatile code byte and immediately executes function with NO API/log call between resuming and execution; logs afterward report SOURCE_BYTES_UPDATED then STALE_CODE, child15/root30. Same native memory path and cache-hit flag disabled. Current source is second, stricter variant. Thus copy success and target source-byte change are established, but translated instruction invalidation timing remains wrong. Do not count the first logging-dependent pass as qualification.

Source boundary: ARM64EC RtlOpenCrossProcessEmulatorWorkConnection reads remote PEB/CHPE info, duplicates and maps target work-list section; send_cross_process_notification enqueues. FEX explicitly drains pending work at HandleSyscall entry, PreCompile and SyncThreadContext. Native-to-JIT transition assembly's ordinary cached-entry path does not explicitly drain. Extra logging can cause a new compile or another transition, so the missed-drain hypothesis is plausible but actual queue enqueue/drain/target state still needs tracing before assigning sole cause. No queue workaround or drain patch applied.

Current installed diagnostic windows-cross-code-no-prelog, child15/root30. Steam not running. Next: trace actual queued work and relevant return transition; preserve the strict test and avoid adding an API call before the failing execution to claim a fix. ActualDE, Steamlogin, physicaldevice, multiplayer, touch and gameplayFPS remain unproven.


# Pending work before dispatcher cache hits — windows-078

Previous turn: progress (source bytes vs stale translation; instrumentation-sensitive control). Added bounded native Wine enqueue/drain traces. Strict unchanged guest test still fails with tracing: parent enqueues protection/flush notifications, child drains work but saved execution result is stale. Work connection is present; no missing write or fabricated notification success.

New opt-in --dispatch-pending-work (AGEPAD_DISPATCH_PENDING_WORK) causes generated ARM64EC dispatcher to inspect its current guest's work-list first field before accepting L1/L2 cached blocks. Nonempty queue branches to existing NoBlock path, which spills/restores guest state and calls CompileBlock/PreCompile to drain notifications before lookup. Uses only existing scratch registers; guest RIP TMP3 preserved. No custom runtime-call ABI, text patching, or external logging before failing guest call. Queue layout offsets checked with Wine C_ASSERTs; acquire load includes heavy-flush bit. This covers dispatcher visits, not proof of immediate delivery inside arbitrary continuously linked guest loops.

Translator and Wine ntdll rebuilt; root and all8 child banks rebuilt; canonical Wine/FEX patches reverse-apply checked. Strict same guest executable with check enabled: SOURCE_BYTES_UPDATED, CHILD_OBSERVED_NEW_CODE, REMOTE_CODE_REVISION_PASS; child/root0. Same new build with check disabled: stale code child15/root30. Check enabled plus cache-hit optimization: pass child/root0. This establishes the bounded regression fix without the earlier logging workaround; not exhaustive cross-process, cache coherence or device qualification.

Genuine Steam launch started under label windows-steam-pending-work with real SCM/RpcSs, shared clock,8banks,256MiB pool, direct assembly TEB, unlocked flush, cache-hit scope optimization, shared memory transfer and pending work check. Inspect run.json/current observation for actual state. No Steam login, originalDE, physicaldevice, multiplayer, touch or gameplayFPS acceptance.


# Live Steam and active-only callback scopes — windows-079

Previous turn: progress (strict queued-code regression fixed with disabled control and combined cache-hit pass; genuine Steam restarted). Exact PID24583 repeatedly revalidated live; preserved candidate including a bounded30-second verified wait. First early profile still dominated by full-cache maintenance. Steam launched webhelper at11:46:24 local, about1:25 after hostlaunch; no full-login acceptance.

Prepared follow-up optimization: callback conservative scopes moved after validation and into actual tracker-mutating paths. Alloc/free/protect BEFORE notifications and failed/irrelevant AFTER notifications no longer enter a scope that only caused a full flush. Heavy/normal flush and dirty callbacks retain scope after tracker/thread validity checks. No tracker mutation before these scopes in audited functions. Translator, root container and8banks build; FEX patch reverse-apply checked. This follow-up is NOT installed or real-Windows-tested yet; current Steam run still uses initial callback coverage from078.

Input/device recheck: ref contains older AoK HD.exe/Launcher.exe but no Windows AoE2DE_s.exe; devicectl reports no devices. Continue useful runtime work; no new goal-blocked claim.

Next: preserve current Steam through browser initialization and subsequent actual state; do not restart solely for elapsed observation. Qualify active-only callback scopes with strict cross-process code test when an intentional candidate replacement is warranted. ActualDE, Steamlogin, physicaldevice, multiplayer, touch and gameplayFPS remain unproven.


# Browser UI calls and missing text services — windows-080

Previous turn: progress (prepared active-only scopes) plus verified wait of live Steam. This turn preserved exact PID24583. Sole designated Simulator inventory checked; actual screenshot inspected: diagnostic shell, black render area, Present0. No rendered Steam interface.

Browser advances beyond singleton warning into Windows UI APIs (Windows.UI.ViewManagement.UIViewSettings) and COM work. A concrete failure loads missing C:\windows\system32\msctf.dll for CLSID33c53a50-f456-4884-b049-85fd643ecfed. Local Wine msctf_classes.idl identifies this as TF_InputProcessorProfiles. Do not infer every missing GPU/vendor DLL is fatal, or that msctf is the sole blocker. Native browser-stage sample still contains substantial full-cache maintenance.

Neither x64 nor ARM64EC msctf was built/staged. Built actual x64 Wine msctf.dll from pinned source successfully; recorded hash, no binary in tracked artifacts. Runner adds --msctf-dll with exact filename, x64 PE validation, source hash manifest and same startup staging directory used by existing helpers. Existing helper filename/validation behavior preserved. Python compilation passes. No DLL copied into live signed app or prefix; this candidate input remains uninstalled and COM runtime test is pending.

Next: let current Steam continue; qualify real text-services class creation and active-only callback scopes at the next deliberate candidate replacement. Current Steam still078; generated FEX banks079 and optional msctf input080 prepared. No login, originalDE, physicaldevice, multiplayer, touch or gameplayFPS acceptance.


# Text-services activation and active-only callback qualification — windows-081

Previous turn: progress (missing class identified, DLL built/staging prepared) plus live Steam observation. Revalidated run and deliberately replaced diagnostic app to qualify concrete missing component; sole designated Simulator, separate classic saves preserved.

New source-owned x64 WindowsTextServicesProbe uses real CoInitializeEx/CoCreateInstance for ITfInputProcessorProfiles and GetCurrentLanguage, then releases/uninitializes. Without staged msctf: class creation fails HRESULT80070005/root11. With identical probe and actual source-built x64 msctf.dll staged: INPUT_PROFILES_CREATED, CURRENT_LANGUAGE_OK, PASS/root0. This establishes that supplying the missing DLL repairs this class activation in the diagnostic; not that it is the sole Steam blocker or all text/IME behavior works.

Current generated FEX079 active-only callback scopes also qualified with strict cross-process code probe, all flags enabled: SOURCE_BYTES_UPDATED, CHILD_OBSERVED_NEW_CODE, REMOTE_CODE_REVISION_PASS, child/root0. No logging inserted before tested execution. No comprehensive VM/coherence/performance claim.

Genuine Steam launch windows-steam-text-services now adds source-built msctf and active-only callback scopes to prior078 combined candidate: SCM/RpcSs prestart, shared clock,8banks,256MiB pool, direct TEB, explicit/unlocked/cache-hit flush, scoped shared memory and pending-work dispatcher check. Revalidate actual run.json/process. Next preserve through browser initialization and inspect whether text-services activation errors disappear and interface appears. ActualDE, Steamlogin, physicaldevice, multiplayer, touch and gameplayFPS remain unproven.


## Steam text-services integration advances; error-reporter capacity refusal — windows-083

Previous status turn yielded fresh helper/capacity evidence, classified as progress. Current run windows-steam-text-services retains the same PID28391 and exact installed executable path; no replacement or additional Simulator. Observer confirms the process remains live. Actual browser loads msctf.dll, advancing beyond the previously missing module. Chromium requests GPU and network utility processes; all eight private banks are observed. This does not prove those helpers fully initialized.

Steam reports CSteamEngine::BMainLoop stalled >15 seconds. Its subsequent steamerrorreporter64.exe child (guest pid0178) fails private signed ntdll initialization after eight banks have been assigned. With the known nonrecycled eight-bank allocator this is evidence of capacity pressure, not proof the original browser failed for that reason. Do not increase the timeout or suppress the assertion. A native two-second sample again shows substantial full-extent instruction-cache maintenance across multiple threads; it does not establish an exact CPU percentage or causation of the assertion.

Screenshot inspected: black viewport, Present0, no Steam login. Separate WindowsParentalControls class activation warning is identified from Wine wpcapi.idl; not established fatal. Existing upstream minidump header-only fast-success behavior is visible in the log, so crash-dump success must not be treated as reliable evidence. No such behavior was added this turn.

Observer now exposes private-child refusal count and Steam main-loop stall presence, with explicit limits on interpretation; compilation and actual observation pass. Evidence saved under windows-083. Next prioritize measured cache-maintenance cost and identify child roles/capacity requirements before changing the runtime. Current run remains active. No DE, multiplayer, physical-device, touch or sustained-FPS acceptance; full goal remains active.


## Sixteen private banks built and bounded child regression passes — windows-084

Previous goal turn was progress: measured text-services load, stall and child refusal. Revalidated same Steam process initially, then observed PID28391 absent twice without restarting it. Final log includes guest network-process thread termination; exact native exit cause remains unestablished. Three child-initialization refusals are recorded. Sequential log context assigns banks1/2 services/RpcSs,3 sysinfo,4 conhost,5 main webhelper,6 error reporter,7 GPU helper,8 network helper. Refusals include a later error reporter and gldriverquery64.exe, establishing normal graphics startup is also affected. Log adjacency mapping is saved, not treated as a concurrency-proof ownership trace.

Expanded nonrecycled child capacity8->16 and matching native/PE image table144->256. Full15-module root plus16 children needs255 entries. Header copies, PE loader scan, runner capacity/preflight and builder bounds updated together. No bank reuse, shared fallback, timeout suppression or JIT-pool expansion. Allocator test passes16 concurrent stable/distinct reservations and refuses the17th. Native ntdll, ARM64EC ntdll, app, root container and all16 signed banks build successfully. Canonical Madeira/Wine patches refreshed and reverse-apply checked.

Actual windows-bank16-children stages all16 banks and executes the existing two-child probe: BOTH_READY, child exits73/74, TWO_EXITS_PARENT_UNCHANGED, root0024 exit0. This proves the enlarged table did not break that bounded case, not execution of all16 banks. The next actual Steam run windows-steam-sixteen-banks is being installed/launched with unchanged256MiB JIT pool and prior flags. Revalidate its run.json/process before observing. Sole designated Simulator reused; classic candidate preserved.

Source audit found compiled blocks already call NtFlushInstructionCache for CodeOnlySize, but its return is unchecked and other emission/callback paths remain. No full-flush omission implemented. Profile still supports investigating maintenance cost; capacity change addresses an independently measured refusal. High-bank runtime correctness, Steam UI/login, DE, physical device, multiplayer, touch and gameplay FPS remain unproved. Full goal stays active.


## Compiled-block flush failure guard built; sixteen-bank Steam left running — windows-085

Previous turn was progress: sixteen-bank capacity built, tested and genuine Steam restarted after the old host disappeared. This turn revalidated PID33911 at its recorded installed path and observed it again without replacement. See artifact observation for current browser progress. No additional Simulator.

Source audit: JIT.cpp calculates CodeOnlySize before the non-instruction tail, adjusts CodeBegin by the final destination delta, copies emitted bytes, then calls NtFlushInstructionCache on that range. Its result was ignored. Added a nonzero-status trap before publishing/returning the compiled block, consistent with existing linker flush guards. FEX ARM64EC build passes; an extracted actual statement test verifies pseudo-handle/address/length forwarding, success return, and traps for positive/negative nonzero statuses. This tests failure handling, not actual hardware cache coherence. Canonical FEX patch refreshed/reverse checked.

IMPORTANT: newly built FEX is NOT installed. Existing root FEX container and child banks now refer to the previous source hash and must be rebuilt before a future runner install; current installed Steam remains consistent with its recorded manifest. No cache-flush range reduction or scope omission made.

Wine ARM64EC NtFlushInstructionCache calls native flush and then pBTCpu64FlushInstructionCache; that FEX callback uses a conservative pending-work write scope. This means even internal emitted-code flushes can enter invalidation handling. It is a source-established path, not a measured count or proof every call emits a full flush. Before optimizing, distinguish actual guest-code invalidation from internal host-code maintenance and preserve synchronization, nested callback behavior, and block publication. Current full-scope profiling still motivates this work.

Steam login, actual DE, retail multiplayer, physical iPad, touch and sustained gameplay FPS remain unestablished. Full goal active.


## Explicit invalidation callback experiment built, not installed — windows-086

Previous turn was progress: checked compiled-block flush and source audit. This turn revalidated current PID33911 at the exact recorded installed path; it progressed through CEF initialization and six private banks without a refusal at the captured4m35 observation. No restart. This is not yet high-bank or browser UI acceptance.

Audited FlushInstructionCacheHeavy/BTCpu64FlushInstructionCache/BTCpu64NotifyMemoryDirty: they call InvalidateAlignedInterval(false), which locks code invalidation, invalidates shared lookup ranges through Erase/delink callbacks, then resets per-thread data caches/call-return stacks. Both direct delink instruction stores already have checked4-byte flushes. New opt-in AGEPAD_EXPLICIT_INVALIDATION_FLUSH switches ONLY these three callback scopes to explicit-flush mode. Allocation/free/protection notification scopes, compilation scopes, actual invalidation and all locking remain. Missing explicit capability falls back to conservative flush through the existing header contract. Default off; runner --explicit-invalidation-flush records/passes flag.

FEX ARM64EC build and expanded actual-header ASan/UBSan scope tests pass, including explicit callback/delinker nesting and a reentrant conservative compile inside explicit callback. This does not qualify actual execution/coherence. Root FEX container and all16 child-bank rebuilds completed successfully for future Windows tests, NOT installed into current Steam. Must run strict cross-process code revision, multithread code revision and child tests before integrating the new flag. Also carries previous compiled-block flush failure guard. No performance improvement claimed.

Full DE/device/multiplayer/touch/FPS objective remains active and unfulfilled.


## Explicit invalidation flush passes Windows probes; Steam integration — windows-087

Previous goal turn was progress: opt-in callback optimization built with scope tests. Revalidated PID33911 at exact installed path, waited45s, and reobserved it live. Nine private banks initialized without refusal, crossing prior8-bank limit. Steam still reports its >15s main-loop stall. Saved this baseline before deliberately replacing it for the prepared optimization tests; elapsed time alone was not treated as termination. Logged JIT extent235044864/268435456, no exhaustion observed.

Actual --explicit-invalidation-flush plus prior options passes three Windows probes with16 banks staged: strict cross-process byte update and immediate execution returns new code, child/root0; four threads256 code revisions pass/root0; two children return73/74, parent unchanged/root0. Cross-process source still executes the modified function before any logging/API after resumption. This qualifies bounded execution and invalidation, not arbitrary thread interleavings or complete cache coherence. Build includes previous checked compiled-block flush guard.

Installed genuine Steam run windows-steam-explicit-invalidation with the new flag,16 banks, same256MiB pool, source-built msctf/services/RpcSs/conhost, genuine preserved client and arguments. Revalidate initial process in run.json. No FPS or startup improvement claimed before measurement. Sole designated Simulator used; classic candidate and private inputs preserved. Full DE, Steam login, physical iPad, multiplayer, touch and sustained gameplay performance remain unproved; goal active.


## Verified wait on explicit-invalidation Steam — windows-088

Previous turn was progress: three actual Windows tests pass and new Steam integration launched. This turn is a verified wait: PID38736 was confirmed live at exact C291CEFA installed executable path, then waited45s and reobserved live at elapsed2m. Browser helper120 has launched; private banks1..5, no child refusal or main-loop stall observed at this early stage. Prior baseline stall occurred later, so no performance/reliability improvement inferred.

Saved before/after observations and both runs' sparse cumulative flush counters. Counts are from different workload stages and cannot establish a speedup. No runtime source edit, reinstall, additional Simulator or account access this turn. Current windows-steam-explicit-invalidation remains active; allow it to reach later CEF/GPU/network states and profile then. Full game/device/touch/FPS/retail multiplayer goal remains active and unfulfilled.


## Profile retains full-flush cost; explicit compile candidate built — windows-089

Previous turn was a verified wait. Revalidated live PID38736 at exact C291CEFA installed path, took2s native sample, and reobserved live at4m28. Five banks, no refusal/stall reported at that observation. Profile shows full-extent agepad_jit_service -> agepad_jit_flush_extent -> sys_icache_invalidate on active threads. Top-of-stack aggregate2317 includes sampled thread observations, not a CPU percentage or matched speed comparison. No runtime replacement.

New default-off AGEPAD_EXPLICIT_COMPILE_FLUSH changes only the normal post-cache-miss compile scope to explicit leave. Already checked emitted-code flush covers CodeBegin relocated to final destination and CodeOnlySize through exit thunks, excluding non-instruction header/tail. InitCore/CreateThread/single-step/Mono and nested conservative callbacks remain unchanged. Runner --explicit-compile-flush requires --cache-hit-explicit-flush; missing explicit capability conservatively falls back. FEX build and existing ASan/UBSan nesting tests pass; root container/bank regeneration prepared separately. Canonical FEX patch refreshed/reverse checked.

NOT installed or actual-Windows-qualified. Next run actual CPU/branches, concurrent code revisions, strict cross-process code revision, child isolation and D3D11 draw before integrating this more consequential scope reduction. Current Steam still has ONLY the previously qualified explicit-invalidation change. No performance, Steam login, game/device/multiplayer/touch/FPS claim. Full objective remains active.


## Explicit compilation flush passes five Windows probes — windows-090

Previous goal turn was progress: compilation candidate built and profile saved. Revalidated PID38736 live at exact recorded path, elapsed5m55. Ten private banks observed without refusal; actual gldriverquery64.exe loads, crossing the previous blocked graphics-query stage. Main-loop stall remains. Preserved baseline before intentional replacement for qualification, not because observation expired.

Five actual Windows tests with --explicit-compile-flush and --explicit-invalidation-flush, sixteen banks and prior options all pass their required marker AND root0024 exit0: CPU million-branch checksum; four threads256 code revisions; strict cross-process immediate execution of remote-written code; two children73/74 with parent unchanged; D3D11 GPU draw/readback. Runner stops on a missing acceptance marker; results.json and full logs/manifests saved. Scope is these tests, not arbitrary synchronization, device correctness or game compatibility.

Installing genuine Steam candidate windows-steam-explicit-compile with both flags, same256MiB pool,16 banks, actual helpers and unchanged retail client/arguments. Revalidate run.json. No performance improvement inferred from passing tests. Sole designated Simulator reused; classic candidate/private inputs preserved. Full DE, Steam login, retail multiplayer, physical iPad, touch and sustained gameplay-FPS requirements remain unfulfilled; goal active.


## Faster CEF milestone reaches32-bit helper low-address failure — windows-091

Previous turn was progress: five Windows probes passed and Steam compilation-flush integration began. Revalidated PID43695 live at45s; CEF initialized at17:28:35 (~33s from launch), versus minutes in earlier candidates. Single-run milestone only, not repeated speed/FPS acceptance. Attempted native sample then reported PID gone; observer recheck confirms absent. Screenshot shows Simulator home screen. No deliberate restart and no usable Steam UI.

Terminal source/log chain: Steam requests bin/gldriverquery.exe; loaded PE Machine0x14c (i386). build_wow64_parameters allocates startup data below2GiB. Native searches0x10000..0x80000000 fail for8MiB and0x6000 with ENOMEM. env_ios.c:1917 assert(!status) fires. Subsequent null fault at PE RVA0x629ac maps to prepare_exception_arm64ec signal_arm64ec.c:3418; it is exception handling after the allocation assertion, not evidence of stale compiled code. Do not attribute the first failure to the cache optimization without a controlled comparison.

Actual baseline Mach-O reserves __PAGEZERO0..4GiB. Built a separate experimental app with xcodebuild -derivedDataPath generated/madeira-lowva-experiment and literal OTHER_LDFLAGS=$(inherited) -Wl,-pagezero_size,0x10000. Build succeeds; otool verifies __PAGEZERO64KiB and preferred __TEXT address0x10000. Default baseline app/project settings untouched. Experimental app NOT installed. This demonstrates linker acceptance, not actual low-address allocation, full WOW64 or iPad-device support.

Next: source-owned x64 low-address allocation/read/write/free probe, run against default and experimental app to measure the reservation hypothesis. Runner currently copies generated/madeira-baseline unconditionally; add an explicit recorded app-template argument to select the experiment, preserving default. Then audit available WOW64 translator/module path before claiming32-bit helper support. No helper binary substitution, successful stub or skipped game/Steam authentication introduced. Full DE/device/multiplayer/touch/FPS goal remains active; current Steam host is terminal, awaiting the concrete low-address test.


## Low-address failure verified; reduced PAGEZERO rejected by ARM64 loader — windows-092

Previous turn was progress: first fatal assertion identified and low-PAGEZERO app built. Added runner --app-template with explicit recorded source path, source bundle checks and self-staging rejection; baseline remains default. New source-owned WindowsLowAddressProbe uses NtAllocateVirtualMemory with same below2GiB mask, validates pointer bounds, fills/verifies allocation, then frees. Builder preserves source/executable hashes.

Actual standard-app probe returns STATUS_NO_MEMORY c0000017/root11, matching Steam's allocation barrier. Identical probe with64KiB-PAGEZERO app cannot launch: FBS request denied, underlying launchd spawn153. No run.json or guest result exists; do not count it as a failed guest test or low-address execution. Launch logs saved.

Apple primary source https://github.com/apple-oss-distributions/xnu/blob/main/bsd/kern/mach_loader.c explicitly requires a4GiB hard pagezero for64-bit ARM images and returns LOAD_BADMACHO if absent. Thus reduced-pagezero linking is not a viable supported ARM64 launch strategy. This source explains the observed rejection mechanism in principle; no claim to symbolicate proprietary host kernel error153. Default app is being restored via windows-low-address-restored. No extra Simulator or classic candidate changes.

Next inspect robust propagation of32-bit startup allocation failure instead of assertion, then test whether genuine Steam tolerates a failed graphics query. It is NOT yet proven optional for successful startup. Full32-bit support would require a different guest-address translation arrangement; no low-address allocation success,32-bit execution, Steam login, DE, multiplayer/device/touch/FPS acceptance. Goal active; this is a new measured architectural boundary, not a three-turn blocked impasse.


## Unsupported i386 child returns Windows error without host assertion — windows-093

Previous goal turn was progress: low-address probe failed and reduced PAGEZERO launch rejected; baseline restored. Audited NtCreateUserProcess cleanup/error propagation. In the signed runtime only, after validated PE file info and before startup serialization/server child creation, i386 images now return STATUS_INVALID_IMAGE_WIN_32 c0000359 through existing done cleanup. Windows maps this to ERROR_BAD_EXE_FORMAT193. Generic architecture capability check, not a helper-name filter or successful process stub; x64 paths unchanged. This does not implement32-bit execution and direct unsupported root startup remains outside this child guard.

Native ntdll/app rebuild pass; canonical Madeira patch refreshed/reverse checked. Actual source-owned x64 parent requests real source-owned i386 executable: logs machine014c/statusc0000359, observes error193 with no child handles, parent-alive marker and root0. Separate actual two-x64-child regression passes BOTH_READY, exits73/74, parent unchanged/root0. Source/binary hashes and logs preserved. No failing32-bit child reaches build_wow64_parameters or its low-address assertion in this test.

Retrying genuine Steam as windows-steam-machine-check with both explicit flush flags, same256MiB pool and16 banks. Revalidate run.json for current PID. Must observe whether Steam tolerates the actual failed helper request; do not assume it is optional or that unsupported32-bit functionality is solved. Sole designated Simulator reused, standard4GiB PAGEZERO restored, classic/private inputs preserved. Full DE/device/Steam login/retail multiplayer/touch/gameplay-FPS goal remains active and unfulfilled.


## Steam survives i386 refusal, reaches message loop, then native voluntary exit — windows-094

Previous turn was progress: real unsupported-child error and x64 regression passed, Steam retried. Revalidated PID46983 at recorded path; actual gldriverquery.exe request returns c0000359. After30s verified wait the host is absent. Steam browser logs Starting message loop, storage-service request and GPU retry; main/browser shared IPC objects now open successfully. GPU launch reports error65, but no proof it directly killed the host. Launchd/runningboard reports voluntary exit0 at17:42:55, not a fatal crash signal. Eleven banks, no private-bank refusal or logged JIT exhaustion. This establishes progress beyond the low-address assertion, not a usable UI/login.

Fresh identical exittrace retry PID47448 launched after prior terminal state. LLDB abort_process/_exit breakpoints were installed; first continue stopped on normal translated unaligned access, captured/detached. Second attach passed SIGSEGV/SIGBUS/SIGILL but stopped on Wine SIGUSR2; it did not capture the exit breakpoint. Host subsequently absent. No exit caller established; debugger perturbed timing/signal observation, so do not count that run as an unperturbed benchmark.

Source audit identifies native abort_thread decrementing shared nb_threads, then abort_process directly calling native _exit. Child process threads created through process_ios.c do not use the ordinary NtCreateThreadEx increment path. This is a candidate accounting problem, not yet proven cause. Added diagnostics only: abort_thread records remaining count/status/pthread/caller; abort_process records atomic count/status/pthread/caller before existing _exit. Termination decisions unchanged. Rebuilt native archive and app after final source edit; canonical Madeira patch refreshed/reverse checked.

New un-debugged run windows-steam-abort-diagnostic starts with same runtime flags/helpers,16 banks,256MiB. Revalidate run.json. Next inspect exact abort markers and callers, then repair only evidenced ownership/counting semantics. Sole designated Simulator reused; classic/private inputs preserved. Full DE/device/multiplayer/touch/gameplay-FPS objective active and unfulfilled.


## Direct guest self-termination no longer calls host _exit — windows-095

Previous turn was progress: termination diagnostics added and fresh Steam run started. Revalidated PID48311, waited45s, and reobserved terminal. Actual abort_process log shows status0 with native thread count62. Caller0x1006c3258 minus image slide0x44c000 maps to NtTerminateProcess's return after its abort_process call at preferred0x100277254. Matching native server-wait caller offsets support slide calculation. This rules out the last-thread branch for this observed exit.

NtTerminateProcess's self=true branch used abort_process for non-null self handle when exiting_flag was false. That calls host _exit. Changed signed-runtime branch to existing exit_process cleanup instead; server termination of the guest's other threads already occurred. Existing child master-socket/cache cleanup and guest exit shim retain status. No process failure converted to success, no root/other guest termination substituted, and normal non-signed behavior unchanged. Fatal abort_process paths remain available; broader shared thread accounting not repaired by this targeted change.

New source-owned WindowsDirectTerminateProbe: child creates a worker, waits until it is ready, then directly TerminateProcess(GetCurrentProcess(),47). Parent waits for child47 and must continue/root0. Actual baseline reproduces host death with abort_process status2f/count2 and no parent pass. Same executable on fix reports child47, CHILD_47_PARENT_ALIVE_PASS and root0. Native archive/app rebuild pass; canonical Madeira patch refreshed/reverse checked. This is bounded direct-termination correctness, not comprehensive worker reclamation/racing termination proof.

New actual Steam run windows-steam-guest-termination launched with prior flags,16 banks and256MiB; revalidate run.json. Next observe GPU failure/retry without losing host and inspect subsequent actual blocker. Sole designated Simulator reused; classic/private inputs preserved. Full DE/device/login/retail multiplayer/touch/gameplay-FPS goal active and unfulfilled.


## Host survives guest exits; Chromium65 is child base-address mismatch — windows-096

Previous turn was progress: direct self-termination fix passes paired regression and Steam retry started. Revalidated PID49378, waited45s and observed live again at1m59 and3m46, including guest exit1/0. Thus host survives beyond the earlier termination stage. Browser message loop/storage/GPU retry active, GPU launch error65 persists. Thirteen banks, JIT extent251838464/268435456 with16596992 remaining, no logged exhaustion. No usable UI demonstrated.

Fetched exact Chromium126.0.6478.183 primary sources sandbox/win/src/sandbox_types.h and target_process.cc from chromium.googlesource.com. Enum65 is SBOX_ERROR_INVALID_TARGET_BASE_ADDRESS. TargetProcess::Create obtains child image base, compares against CURRENT_MODULE(), terminates child and returns65 on mismatch. This fits this shared-address-space runtime's relocated child executables; not evidence of a D3D render failure. Source URLs: https://chromium.googlesource.com/chromium/src/+/refs/tags/126.0.6478.183/sandbox/win/src/sandbox_types.h and corresponding target_process.cc. Copies preserved.

Valve's Steam-for-Linux issue8420 documents -no-cef-sandbox (https://github.com/ValveSoftware/steam-for-linux/issues/8420); it alone does not prove Windows behavior. Exact argument string also appears in the supplied genuine Windows steam.exe and steamclient64.dll. Deliberate next experiment windows-steam-cef-compatibility passes --guest-arg=-no-cef-sandbox through the existing literal-argument mechanism, replacing prior still-live baseline for this measured compatibility test. Must verify generated helper arguments and actual behavior.

This explicitly disables Steam Chromium sandbox isolation; it does not fix address-space isolation or authenticate anything. No fake image-base response, binary replacement, game modification, GPU-disable flag or server response substitution. Native/macOS signing settings unchanged. Same256MiB pool/16banks/runtime flags. Sole designated Simulator reused, classic/private inputs preserved. Full DE/device/retail multiplayer/touch/FPS objective remains active and unfulfilled.


## Chromium sandbox experiment reaches JIT capacity failure — windows-097

Previous turn was progress: Chromium65 source identified and explicit Steam flag tested. Revalidated PID49842 at its exact installed executable path, alive at4m47. Helper command lines confirm --no-sandbox. CEF log has no GPU process launch error65 in this run; this does not establish functional GPU/renderer initialization. Runtime has two explicit EXEC ALLOC FAILED / JIT pool exhausted records. Allocated monotonic extent267616256 of268435456, leaving819200 bytes, insufficient for the next requested chunk. Thirteen private banks, no bank refusal. Host liveness does not repair these guest faults.

Preserved baseline logs/manifest under windows-097 before deliberate diagnostic replacement. Inspected native allocator: existing accepted512 setting reserves536870912 bytes via MAP_JIT, preserves owner checks, monotonic allocation and quarantine. No source or memory-reuse change. New windows-steam-cef-512 uses512MiB, same16banks and other flags. Sole designated Simulator inventory verified before installation; classic candidate/private inputs preserved. Chromium sandbox remains explicitly disabled for this compatibility experiment; no isolation repair claimed.

New PID50558 exact path verified at23s and again1m25 after45s wait. Steam installation verification complete; Chromium126 initialized, six banks,117555200 allocated extent, no pool exhaustion or child-bank refusal. This is early startup only, not evidence that doubling capacity suffices. Next observe past previous exhaustion stage and inspect actual GPU/renderer behavior. No Steam login/interface acceptance, actual DE gameplay, multiplayer, physical-device execution, touch or sustained FPS established. Full goal remains active.


## 512 MiB run passes former capacity boundary; remaining full flushes profiled — windows-098

Previous turn was progress: actual256MiB exhaustion preserved and512MiB experiment launched. Revalidated exact installed PID50558 at2m11,3m15 and4m12, without replacement. At4m12 allocated extent285442048 exceeds prior268435456 capacity, no exhaustion and251428864 bytes remaining. Thus the larger pool has permitted allocation beyond the prior limit; this does not establish enough capacity for full startup or gameplay. Browser requests GPU/network/storage children. Steam still reports webhelper initialization timeout, no usable interface.

Sole designated booted Simulator verified before screenshot. Actual screenshot shows black viewport, Present0/FPS0.0, displayed memory1742MB; not a measured gameplay performance result. Two-second native sample captured from live50558. Multiple threads spend samples in agepad_jit_service -> agepad_jit_flush_extent -> __clear_cache -> sys_icache_invalidate. One IPC:CSteamEngine stack has858 of876 samples there; other threads also show this path. This is a short sampled stack observation, not an overall CPU percentage or exact callback attribution.

Source audit identifies remaining conservative scopes in NotifyMemoryAlloc/Free/Protect (Module.cpp1347/1360/1373). Protection handler mutates interval metadata and conditionally calls InvalidateIntervalInternal; free calls the same invalidation then removes metadata. Internal invalidation locks CodeInvalidationMutex, calls shared LookupCache invalidation/delink, and resets per-thread executable/cache/callret metadata. These are candidates for scoped explicit flushing after full write-path validation, not justification to remove cache synchronization. Core InitCore/CreateThread, single-step and Mono scopes also remain conservative. No runtime source edits or relaxed synchronization this turn.

Next inspect actual later GPU/renderer outcome and qualify a narrowly scoped memory-notification optimization with real protection/free/code-change regressions before installing it. Current run remains live; no restart based on elapsed observation. No Steam login, DE engine/gameplay, retail multiplayer, device, touch or sustained FPS acceptance. Full goal active.


## Memory-notification explicit flush passes four Windows integrations — windows-099

Previous turn was progress:512MiB crossed old capacity boundary and native full-flush samples captured. Revalidated PID50558 at5m25 and6m51. Baseline eventually reaches16banks/one child initialization refusal,386154496 allocated JIT extent with150716416 remaining, no JIT exhaustion. CEF reports network service crashed/restarting. Preserve baseline logs; do not infer cause from capacity refusal or solve repeated crashes by blindly increasing slots.

Audited memory alloc/protect/free paths through InvalidationTracker, shared LookupCache::InvalidateRange/Erase, direct/indirect delink callbacks, and per-thread cache reset. Instruction mutations occur in checked4-byte delink flushes; interval and lookup updates are data. Added default-off agepad_explicit_memory_flush, initialized from exact AGEPAD_EXPLICIT_MEMORY_FLUSH=1 before InitCore. Only three successful AFTER notification scopes change to explicit mode when enabled. All callbacks, status guards, interval operations, invalidation locks and write protection remain. Missing explicit hook falls back conservative; nested conservative work still requests full flush. Existing InitCore/CreateThread/Mono/single-step scopes unchanged.

Runner --explicit-memory-flush records/env-passes option. FEX build, header ASan/UBSan scope test and runner compilation pass. Root FEX container and all16 signed banks rebuilt. Canonical FEX patch refreshed/reverse-checked. Deliberately replaced diagnostic Steam after preservation; sole designated Simulator used, classic/private inputs preserved. Actual Windows tests with flag enabled all have required marker and root0024 exit0: four threads256 protect/write/flush/execute revisions plus free; strict remote code update; children73/74 parent unchanged; D3D11 draw/readback. Results/logs/manifests preserved. These do not prove arbitrary allocation reuse races, all synchronization, performance, or physical-device correctness.

New actual Steam run windows-steam-memory-flush uses same512MiB/16banks/no-cef-sandbox and other flags plus new memory flag. Revalidate run.json/livePID. Next measure browser progress and identify network/GPU helper exit cause; no capacity expansion. Sandbox isolation remains disabled for experiment. No Steam login/interface, DE engine/gameplay, multiplayer, physical-device execution, touch or sustained FPS acceptance. Full goal active.


## Network helper clean exits need uncapped evidence — windows-100

Previous turn was progress: memory notification optimization passes four actual Windows integrations and Steam retried. Revalidated PID55760 exact installed path live at53s. No pool exhaustion,386154496 allocated extent,16banks/one refusal. CEF labels network service exits as crashes/restarts, but actual guest328/588 (0148/024c), main threads014c/0250, exit with raw status0. Their Windows cleanup and worker termination are logged. Do not equate browser wording with an unhandled CPU exception. Separate guest02ec/thread02f0 fast-fails code7/c0000409; role/callsite not yet attributed, must not conflate with network helpers.

Native NtTerminateProcess term-stack diagnostics previously log only first3 calls or bounded nonzero exits. Earlier helpers consume the first3, so network exit0 stacks are absent. Changed diagnostic counter to atomic InterlockedIncrement LONG and captured first96 calls for signed runtime, including0; retained bounded other-runtime first3/nonzero24 policy. No termination decision/status/cleanup change. Native archive/app builds pass, canonical Madeira patch refreshed/reverse checked.

Preserved baseline logs. Sole designated Simulator inventory verified. Deliberately replaced diagnostic only with windows-steam-clean-exit-trace, identical512MiB/16banks/flags and no-cef-sandbox plus new diagnostic binary. Revalidate run.json. Next attribute network's clean shutdown using caller stack and image maps; do not assume DNS warnings are fatal. No Steam login/interface, DE gameplay, multiplayer, physical-device, touch or FPS acceptance. Full goal active.


## Captured environment-lock suspension deadlock — windows-101

Previous turn was progress: zero-exit diagnostics rebuilt and Steam launched. Revalidated exact PID56528 at48s, then native2s sample. Browser stops after initial Chromium version record. Server stack is req_suspend_thread -> suspend_thread -> stop_thread -> ios_fill_thread_context -> getenv -> environment unfair-lock wait. Target thread is agepad_jit_service -> getenv -> __findenv_locked, sampled at samePC throughout. Logging worker also waits for environment lock through localtime_r/getenv_copy_np. Source confirms ios_fill_thread_context unconditionally thread_suspend(port), then lazily getenv(MADEIRA_CTX_FRAME), then eventually thread_resume. This is a concrete same-process lock cycle: suspended target owns environment lock needed by server before resume. Different blocker from previous network clean exits; no timeout-based restart inference.

Moved cached context-option read before thread_suspend, preserving option semantics and context capture/resume behavior. Wine server46-source build passes, archive copied into app and app relink passes. Canonical Madeira patch refreshed/reverse checked. This fixes observed getenv ordering only; other libc/logging calls within suspension remain an audit concern, not claimed comprehensively safe. No forced thread resume from debugger, no fake context, no termination behavior change.

Preserved sample/observation. Sole designated Simulator inventory verified; deliberately replaced deadlocked diagnostic with windows-steam-context-env, same512MiB/16banks/flags and bounded exit tracing. Revalidate livePID/run.json. Next verify passage through context capture and inspect network exit stacks. No DE gameplay, Steam login/interface, multiplayer, device, touch or sustained FPS acceptance. Full goal active.


## Context capture advances; signed-image diagnostic blind spot verified — windows-102

Previous turn was progress: environment lookup moved before suspension, server/app built and integration restarted. Revalidated PID57329 exact path live52s. Runtime contains seven completed srv-getctx captures, including target02b0 with native_pc0x18015c99c inside getenv, and continues afterward to helper exits/retries. Thus this run passes observed context-capture deadlock stage; not comprehensive suspension safety.

Expanded zero-exit traces now appear, but unwind immediately reports no module for signed PE addresses. Source ios_jit_module_base_for_va scans only ios_jit_mappings; signed images have a separate registration table. Offline audit joins exact reported exit PCs to logged signed base/size ranges and finds matches, e.g.0x1622cfabc -> base0x162250000+0x7fabc,0x167b84690 -> base0x167b44000+0x40690. This verifies diagnostic lookup omission, not corrupted code or missing loaded DLL. ARM64EC frames require appropriate decoding; do not feed them blindly to x64 unwind logic. No runtime edit this turn.

Fetched exact Chromium126 child_thread_impl.cc via googlesource base64 endpoint (web renderer rejected URL, curl succeeded). TerminateSelfOnDisconnect calls TerminateCurrentProcessImmediately(0) in non-sanitizer builds; OnChannelError quits child message loop; EnsureConnected invokes disconnect termination. Therefore IPC disconnection is consistent with observed clean network exits, not established as this run's cause. Primary source: https://chromium.googlesource.com/chromium/src/+/refs/tags/126.0.6478.183/content/child/child_thread_impl.cc . Source copy, mapping audit, runtime/CEF logs and observation preserved.

Next recover caller attribution with signed module coverage and architecture-aware stack handling, or trace actual IPC channel failure directly. Keep current process; no restart or capacity expansion this turn. No Steam interface/login, DE gameplay, multiplayer, physical-device, touch or sustained FPS acceptance. Full goal active.


## Raw exit-stack collection for signed runtime callers — windows-103

Previous turn was progress: context capture verified and diagnostic mapping gap proven offline. Revalidated PID57329 exact path live3m27 with network retries and one bank refusal. Network main0154 enters actual network utility command and returns0; expanded trace cannot unwind its signed ARM64EC exit path.

Added bounded256-byte raw stack snapshot from captured FEX greg4 via existing mach-read helper, tagged with guest thread and stack offset. Read failure prints no candidate. These are explicitly raw words, not x64-decoded ARM64EC frames or confirmed return addresses. New analyze-madeira-exit-candidates.py intersects words with previously logged executable sections, reporting module/section offset and explicit scope limits. Does not classify nonmatching data as code or apply runtime changes. Native archive/app builds and Python compile pass, canonical Madeira patch refreshed/reverse checked.

Sole designated Simulator inventory verified. Deliberately replaced diagnostic with windows-steam-raw-exit, all prior512MiB/16banks/compatibility flags preserved. Next collect network shutdown candidates, validate actual call instructions, then trace IPC path if supported. No termination behavior, game/client binaries or sandbox settings changed. Full goal active; no DE, Steam login/interface, multiplayer, physical-device, touch or sustained FPS acceptance.


## Actual helper and browser termination call instructions validated — windows-104

Previous turn was progress: raw stack diagnostic built/installed and candidate analyzer added. Revalidated exact PID58592 live44s, network retries continue. Raw snapshots now contain network main014c stacktop in steamwebhelper and browser00dc stacktop in libcef. Read-only disassembly of genuine installed files validates steamwebhelper returnRVA347058 follows FF15 call at347052 through IAT49a578 -> KERNEL32!ExitProcess. Thus helper normal-exit path is real, not a raw address coincidence. Additional return34702a is a direct call into this CRT-style exit path; no source function name claim.

Browser returnRVA68f5eca follows call68f5ec4 through IATc8c80a0 -> TerminateProcess. Its stack candidate57f6bb2 follows direct call57f6bad ->68f5e90, with edx=0/r8d=0. This validates a caller requesting helper termination0, not proof it causes the first network disconnect. Import addresses resolved using llvm-readobj IAT base plus symbol index*8; pefile unavailable, no installation needed. Objdump nearest exported symbol labels are NOT actual private function names.

Evidence files include disassembly from known function boundaries, explicit import/call attribution JSON, raw candidates, logs and live observation. No binary modifications, runtime restart, capacity changes or speculative IPC fix. Next recover original network main return or browser channel teardown path; current traces still reach cleanup rather than proving underlying IPC failure. Full goal active; no Steam login/interface, DE gameplay/FPS, multiplayer, physical-device or touch acceptance.


## Steam verbose option verified; adapter enumeration failure observed — windows-105

Previous turn was progress: actual termination imports/calls validated. Revalidated PID58592 exact path3m27, host live with Steam main-loop stall reported. Installed steamclient64.dll includes -cef-verbose-logging and its description. Preserved baseline and deliberately restarted diagnostic as windows-steam-cef-verbose with that added argument; same512MiB/16banks/runtime flags. Sole designated Simulator inventory checked. No code/binary modifications this turn.

New PID59459 exact installed path verified29s, then30s wait and same run observed. Actual helper command contains --enable-logging --v=1, proving Steam translates option. CEF still mostly warnings/errors; do not claim verbosity solved logging or root cause. New actual network helper632 log: network_interfaces_win.cc251 GetAdaptersAddresses failed:2. DNS config/hosts warnings persist. This provides concrete API failure to reproduce using source-owned Windows adapter enumeration probe; causation of helper shutdown not proven.

Source audit correction to102: ChildThreadImpl registration of SuicideOnChannelErrorFilter / disconnect handler calling TerminateSelfOnDisconnect is under IS_POSIX. It must not be used as evidence of Windows registration. Platform-independent OnChannelError quits child loop, but actual Windows shutdown cause remains unknown. Earlier POSIX termination-hook inference is explicitly withdrawn for Windows; raw verified ExitProcess/TerminateProcess calls remain valid evidence.

Next test actual GetAdaptersAddresses and inspect Wine iphlpapi/NSI backend error propagation rather than further speculative stack tracing. Current run retained. No DE gameplay, Steam login/interface, multiplayer, device, touch or sustained FPS acceptance. Full goal active.


## Standalone adapter probe proves missing NDIS table backend — windows-106

Previous turn was progress: verbose flag propagated and GetAdaptersAddresses error2 observed. Current Steam observation preserved before deliberate diagnostic replacement. Built source-owned WindowsAdaptersProbe, real AF_UNSPEC GetAdaptersAddresses size query then bounded allocation/list validation. Initial minimal staging lacks advapi32 and exitsc0000135 before entry; not API evidence. Repeated with same graphics/WinINet dependency set used by Steam: probe enters, SIZE_STATUS=2 BYTES=0, root0024 exit11. No success marker.

Actual log shows nsi.dll loads native nsi_unix_call_funcs, requests non-TCP module eb004a11 table0, native fallback explicitly returns STATUS_NOT_SUPPORTEDc00000bb. Wine nsi returns original missing \\.\Nsi device error2 when fallback unsupported. Source GetAdaptersAddresses -> adapters_addresses_alloc -> NsiAllocateAndGetTable(NPI_MS_NDIS_MODULEID,NSI_NDIS_IFINFO_TABLE). Native nsi_unixlib_ios.c implements TCP tables only and rejects all non-TCP modules. Thus standalone API failure is attributed to missing interface-table backend, not a DNS guess or Steam account issue. Not yet proven cause of CEF shutdown.

Upstream nsiproxy.sys/ndis.c has actual interface enumeration and Darwin conditionals; next audit reuse/compilation dependencies and provide real network interface records via existing unixlib route. Other required address/route/DNS tables may follow after NDIS, so do not claim one table suffices. No fake adapter, authentication bypass or success stub. Sole designated Simulator used, classic/private inputs preserved. Current diagnostic windows-adapters-dependencies completed expected failure; no Steam currently running after deliberate replacement. Full goal active; no DE gameplay, login/multiplayer, device, touch or FPS acceptance.


## Real NDIS enumeration advances to missing IPv4 table — windows-107

Previous turn was progress: standalone GetAdaptersAddresses failure traced to rejected NDIS table. Audited Wine nsiproxy.sys/ndis.c reuse. Original Darwin route/sysctl code cannot compile against iPad SDK (net/if_arp.h, net/route.h absent). Added WINE_IOS-only getifaddrs physical lookup using actual AF_LINK records, type mapping, bounded link-address copy; dynamic counters/speed read actual ifa_data. Other-platform branches retained. Interface names/index/list handling and NSI row assembly reuse Wine source. This is Simulator host interface data, not device acceptance.

Connected ndis_module enumeration into native NSI fallback with module/table/optional-field size validation. Existing TCP owner tables unchanged; unsupported modules remain errors. Build compiles ndis.c into native archive and links NDIS moduleID; no PE/bank rebuild necessary for native-only linked backend. Standalone object, native31-source build and app link pass. Madeira/Wine canonical patches refreshed/reverse checked.

Reused sole designated Simulator, replacing completed diagnostic only. Actual windows-adapters-ndis same probe/dependency set logs NDIS table0 status0 count19, then non-TCP IPv4 moduleeb004a01 table10 NOT_SUPPORTED; size query stillerror2/root11. Thus real interface enumeration now works through Windows caller, but full GetAdaptersAddresses does not pass. Next implement real IPv4/unicast and then remaining address/route/DNS tables as demanded, not return fabricated success. Upstream interface list retains existing lifecycle/failure-handling limitations; broader device correctness unqualified. No Steam running in current diagnostic, no DE/gameplay/FPS, multiplayer, touch or device acceptance. Full goal active.


## IPv4/IPv6 unicast tables return actual address records — windows-108

Previous turn was progress: NDIS interface table implemented/returns19. Added native nsi_unicast_ios.c using portable unicast functions/helpers from pinned Wine nsiproxy.sys/ip.c, preserving copyright/license and documenting derivation. getifaddrs supplies actual addresses/netmasks/scope and existing NDIS maps names to LUIDs. Wine lifetime60000, origin/DAD/creation-time approximations retained; these metadata are not measured DHCP state. Existing unsupported table errors remain. Native module dispatch validates optional field sizes before enumeration. Build includes new object.

Initial actual probe returns INVALID_PARAMETER87 with key24/rw28/dynamic8/static8. Added size trace, verified against netiodef.h: IPv4 module is eb004a00, IPv6 eb004a01, UDP eb004a02. Corrected my initial off-by-one ID definitions (and earlier106/107 wording calling eb004a01 IPv4). Rebuilt native/app and reran same actual Windows probe. Final NDIS19, IPv6 status0/count20 with24-byte key, IPv4 status0/count3 with16-byte key. Next request IPv6 forwarding table16 is unsupported, so full GetAdaptersAddresses stillerror2/root11, not a pass.

Native/app final builds pass. Canonical Madeira patch includes new unicast file and reverse-check passes. Sole designated Simulator reused; completed probes intentionally replaced, classic/private inputs preserved. Current windows-adapters-unicast-fixed completed expected failure; Steam not running. Next implement actual route table retrieval and assess remaining DNS dependency, then retest full API and Steam. No fake route or blanket-success fallback. Full goal active; no DE, Steam login/interface, multiplayer, device, touch or sustained FPS acceptance.


## Actual IPv4/IPv6 forwarding tables read in Simulator — windows-109

Previous turn was progress: unicast tables work, forwarding table missing. Added native nsi_routes_ios.c using actual sysctl CTL_NET/PF_ROUTE/NET_RT_DUMP for each family. iOS SDK exposes query constants but omits net/route.h. Reader uses ABI offsets verified by compiled static assertions against installed Xcode26.5 macOS net/route.h (size92, flags8, bitmap12, errno24, metric44, version/type/flags). No claim of future ABI/device compatibility; unknown version/malformed messages fail.

Reader bounds allocation64MiB, headers/message lengths/sockaddr steps, validates contiguous masks, translates actual interface indices through existing NDIS names/LUIDs, real destinations/gateways/prefixes/metrics, and implements count/buffer overflow. Route lifetime/origin metadata use compatibility defaults, not actual route provenance. Unsupported query/gateway families remain failure. No fake empty table on failure. Both native and app builds pass, canonical Madeira patch contains new source/reverse-check pass. Parser needs malformed-input/edge-case tests and IPv6 scope audit before broader integration.

Actual same Windows adapter probe windows-adapters-routes: NDIS19, IPv6 unicast20, IPv4 unicast3; IPv6 routes97 and IPv4 routes80 with expected first BUFFER_OVERFLOW then successful resized enumerations. Full API now returns3221225659(c00000bb), BYTES0/root11, rather than previous error2. Next source stage is dns_info_alloc/DnsQueryConfig; exact new failing call not yet isolated. Full GetAdaptersAddresses still NOT pass. Sole designated Simulator reused, completed diagnostic replaced, classic/private inputs preserved. Current test terminal/root11; Steam not running. Goal active, no DE/login/multiplayer/device/touch/gameplay-FPS acceptance.


## Full Windows adapter enumeration passes after resolver backend integration — windows-110

Previous turn was progress: actual route tables enumerated and laterc00000bb isolated by stage. Source DnsQueryConfig server/search queries call RESOLV_CALL; runtime had no dnsapi unixlib registration. Added Wine dnsapi/libresolv.c to native archive, registered dnsapi_unix_call_funcs in existing loader, linked system libresolv for app configurations. Native/app builds pass. Uses actual resolver configuration, not fabricated DNS servers.

Added tests/test-nsi-route-parser.py compiling actual route-reader source with ASan/UBSan and synthetic sysctl/interface boundary only. Covers valid IPv4 route mapping/prefix/metric/gateway, count/BUFFER_OVERFLOW, short header, zero/oversized message/sockaddr lengths, unsupported version, noncontiguous mask and field-size rejection. All pass. Harness exposed missing explicit stdio/stdlib/string includes; added them to source and rebuilt native/app. This does not cover every IPv6 scope or concurrent route-change scenario. Canonical Madeira patch refreshed/reverse checked.

Actual same WindowsAdaptersProbe: dnsapi unixlib registered; sizing returns111/ERROR_BUFFER_OVERFLOW with14544 bytes; enumeration returns0; required ENUMERATION_PASS marker then root0024 exit0. Count number interleaves with runtime logs; do not infer exact final count from marker line. Probe validates bounded nonempty adapter list, not DHCP semantics, DNS resolution, connectivity, or full Steam. This is the first full adapter API pass after prior errors2/87/c00000bb.

Sole designated Simulator inventory verified. Replaced completed probe with real windows-steam-network-tables, prior512MiB/16banks and compatibility flags plus unchanged verbose/no-sandbox args. Next observe actual client network helpers; adapter fix alone does not prove their shutdown solved. Classic/private inputs preserved. Full goal active; no DE, Steam login/interface, retail multiplayer, physical-device, touch or sustained gameplay FPS acceptance.

## Orphaned shared file-cache mutex — windows-112

Previous status turn was a verified wait: exact Steam host PID65306 remained live. This turn completed two native samples and two read-only LLDB captures, detached/resumed successfully, and checked that only the designated Simulator is booted. No restart or runtime edit.

CrBrowserMain, StackSamplingProfiler, IPC:CSteamEngine and RPC workers repeatedly wait in NtClose/NtDuplicateObject/server_get_unix_fd on the native fd_cache_mutex. The mutex at0x105efbc00 has owner value0xa0b431 (10531889) at offset0x18. The loaded libsystem_pthread disassembly confirms the firstfit owner slot is align_down(mutex+0x1f,8), offset0x18 for this aligned mutex, populated from the pthread thread-id slot. Both samples and LLDB thread inventory lack owner10531889. This is strong evidence of an orphaned shared mutex, not merely slow browser startup.

The preceding runtime excerpt records guest process00e8 terminating its other threads, including a reply-read EOF followed by abort_thread. Another abort caller0x1046332e4 maps to server_call_unlocked+616. Current source takes fd_cache_mutex around server requests in NtClose, NtDuplicateObject, server_get_unix_fd and APC result cleanup. read_reply_data calls abort_thread on EOF; abort_thread ultimately exits the pthread. These sections have no pthread-exit cleanup handler. Thus a server-disconnected guest worker can exit without releasing a mutex shared by surviving guest processes. Exact historical native owner-to-guest tid mapping was not logged, so that final association remains inferred.

Next implement and qualify scoped pthread-exit cleanup for these file-cache critical sections, preserving handle invalidation ordering and without force-unlocking another live thread's lock. First reproduce the early-exit path with the actual relevant source, then run Windows parent/child handle stress and direct self-termination regression before replacing Steam. Audit resource/cache lifetime interactions; a mutex release alone does not establish all termination safety. Do not patch the live mutex or treat browser flags/network warnings as the cause without evidence.

Full adapter API pass remains valid but did not prevent this separate integration stall. No Steam login, actual DE gameplay, physical iPad, touch, FPS or retail multiplayer acceptance. Full objective stays active.

## File-cache request exit cleanup qualified — windows-113

Previous turn made progress by identifying an orphaned shared fd_cache_mutex. This turn revalidated the stalled Steam PID65306 at its exact installed path, then deliberately replaced the diagnostic app to test a source repair. Sole designated Simulator reused; classic candidate and ref preserved.

Native server_ios.c now registers lexical pthread cleanup handlers around the four file-cache critical sections: APC result retrieval, server_get_unix_fd, NtDuplicateObject and NtClose. Server EOF may call abort_thread/pthread_exit from inside these requests. Cleanup releases only the exiting thread's acquired fd_cache_mutex, and closes a descriptor already removed from the cache by Close/Duplicate. The normal path pops without executing cleanup and retains the existing unlock/close ordering. NtClose initializes fd=-1 before registration. No live foreign-owner unlock, forced success, timeout change or blanket termination safety claim.

New tests/test-fd-request-exit.py compiles the actual NtClose critical section and cleanup function with ASan/UBSan. A substituted server transport injects pthread_exit (the observed EOF mechanism); a negative control removing registration reproduces both orphaned lock and removed descriptor leak. With cleanup, exit, successful request and failed request release the mutex and close the removed descriptor. Other three sites are checked for registration; their full semantics are not exercised by this harness.

New source-owned WindowsHandleExitProbe terminates a child with four DuplicateHandle/CloseHandle workers, then requires the parent to observe exit47 and complete1000 successful handle duplication/wait/close operations. Actual final candidate windows-fd-exit-handles-final prints CHILD_47_PARENT_1000_HANDLES_PASS and root0024 exits0. Earlier candidate also passed; source initialization was tightened during review and final stress rerun passed. Existing WindowsDirectTerminateProbe passes CHILD_47_PARENT_ALIVE_PASS/root0 before that initialization-only tightening. These are bounded executions, not exhaustive race/resource-lifetime verification.

Final native build34/34 and app build pass. Canonical Madeira patch includes all three existing added headers/sources and reverse-apply check passes. No PE/container/bank rebuild required for native-only edits. Real Steam retry windows-steam-fd-exit-cleanup launched with unchanged diagnostic flags (including prior --no-sandbox limitation); follow current run evidence before claiming browser improvement.

Ref re-audit finds Mac DE app and AoK HD.exe, no AoE2DE_s.exe through rg file inventory; devicectl reports no devices. No account accessed. Runtime work can continue, but actual Windows DE inputs and a physical iPad remain outstanding acceptance prerequisites.

Steam login, DE gameplay, physical iPad, touch, sustained FPS and retail multiplayer remain unproved. Full objective remains active.

Actual Steam follow-up at19:18:15 UTC: PID68121 remains live at installed path341AA838-328F-4047-A727-5705CBA8C8F5, elapsed37s. It advances to CreateBrowser/CreateResponse/BrowserReady handle65536, requesting network and storage helpers. Earlier stalled run had only GPU-helper launch in its captured helper log. This is a real IPC/browser-lifecycle milestone, not visible login: inspected Simulator screenshot is black with Present0/FPS0. Network service still reports crash/restart. Fifteen banks observed, no private initialization refusal or JIT exhaustion yet; logged extent369360896 of536870912. Screenshot also shows loader_section waits in later threads; investigate current ownership/exit behavior before choosing another fix. Leave exact live run active.

## Watchdog caused environment-lock deadlock — windows-114

Previous turn made progress through scoped file-cache exit cleanup, regression passes and BrowserReady. Revalidated exact Steam PID68121 live at1m53s then6m22s. Native sample shows network.CrUtilityMain10553163 fixed at __findenv_locked+96 inside agepad_jit_service, while browser/JIT calls and server/localtime logging wait on the host environment lock. LLDB registers identify the lookup as AGEPAD_SIGNED_CHILD_NTDLL; detached/resumed successfully. A separate task_for_pid helper was denied, so it did not establish a Mach suspend count.

The same sample identifies the diagnostic watchdog block at __server_init_process_done_block_invoke+176 waiting in wine_log_write->localtime_r->getenv_copy_np. Actual source suspends wine_mach_thread, captures registers, then calls wine_log_write repeatedly before thread_resume. This creates a direct deadlock when it suspends a target in getenv. This is distinct from the previously repaired server context snapshot getenv initialization and the fd-cache orphan. MADEIRA_REAL_SUSPEND remains0; no guest suspension policy changed.

Moved watchdog thread_resume immediately after register and optional syscall-frame Mach reads, before all successful-suspend logging. Captured frame pointer/x18 are read before resume and validated for full-length reads. The thread_get_state failure path also resumes before logging. Failed thread_suspend takes no hold and logs as before. Existing thread_resume return handling is unchanged; this is not a complete Mach-suspension safety audit. Other profiling and server diagnostic paths remain to inspect if evidence implicates them.

New tests/test-watchdog-suspend-logging.py compiles the actual watchdog body with ASan/UBSan and mocked Mach/log interfaces. Logging asserts no target hold; Mach reads assert target held. Success, suspend failure, register failure, VM read failure and short VM read pass. This tests ordering and failure paths, not actual OS scheduling. Final native/app builds pass; canonical Madeira patch refreshed including prior added files and reverse checked.

Deliberately replaced still-live diagnostic after preserving evidence; sole designated Simulator verified, classic/ref untouched. New genuine run windows-steam-watchdog-resume retains existing flags and prior no-sandbox limitation. Follow its real process/helper logs before claiming improvement. No DE gameplay, Steam login, physical iPad, touch, FPS or multiplayer acceptance. Full goal remains active.

Retry outcome correction: host shell PID69209 stays alive atEECB0AE1-6A21-4DAC-A84D-5BE59780538C, but actual root guest0024 exited97 before Steam entry. RPC bootstrap logged running0/state0/error1726 (RPC_S_CALL_FAILED) and raised000006be. This is terminal guest evidence, not a timeout; do not wait on the live UIKit shell as if Steam were progressing. The watchdog emitted complete capture logs on this retry, but the previous network-helper deadlock stage was not reached, so full integration qualification of the repair remains pending. Next inspect the failed bootstrap request and decide a controlled retry or targeted RPC repair from that evidence. Do not fake service readiness.

## RPC retry passes; renderer reaches fatal variant access — windows-115

Previous turn made progress on the watchdog suspension/logging deadlock. Revalidated prior host69209 and explicit root guest exit97. Added observer initial_guest.terminal_observed/exit_codes from the exact WineProc bridge result, because host liveness alone concealed terminal guest bootstrap failure. Actual prior log now reports terminal=true/97. No marker is not proof of guest progress.

RPC source/log audit: client raised1726, server RPC worker0038 exited, later closes received missing-context faults. No underlying pipe-close status captured, so causal repair would be premature. One unchanged retry after the observed terminal guest (not elapsed time) succeeds through service bootstrap and browser initialization. Thus prior RPC failure is intermittent across these runs, not resolved. No service-readiness bypass or timeout change.

Current genuine run windows-steam-watchdog-rpc-retry PID69852 exact installed path21EB0195-6436-43B0-B453-09CEA95C9BCE remains live. BrowserReady followed by storage/processor metrics/GPU and renderer requests. Native sample shows active browser execution and scattered short getenv samples rather than prior all-sample environment-lock stall. The watchdog change passes that observed stage; this is not a full deadlock audit. Root guest has no terminal bridge marker at saved follow-up.

All16 private banks assigned. Chronological child-parameter adjacency maps slot16 to renderer, followed by refusal during a later network utility request. This adjacency is not a concurrency-proof ownership tracer. Network service still crashes/restarts; do not simply increase banks indefinitely or infer that renderer was refused.

Actual renderer main0284 triggers fastfail7 at libcef base0x700d3a0000 + RVA0x3b6fe65. Retail disassembly confirms mov ecx,7/int29 in abort path. Raw stack candidate +0x28 maps to RVA0x3beb35c, immediately following direct call to that abort routine. Read-only LLDB successfully reads4096 bytes at retained stack0x316a1dda0, detaches/resumes. ASCII at+0x80 is '[bad_variant_access.cc : 44] RAW: Bad variant access'. Save only relevant diagnostic text in tracked artifacts; full raw snapshot remains generated/private.

Pinned Chromium126.0.6478.183 abseil bad_variant_access.cc fetched from primary googlesource (web wrapper failed; curl format=TEXT succeeded) confirms no-exceptions ThrowBadVariantAccess logs that fatal message. Source URL: https://chromium.googlesource.com/chromium/src/+/refs/tags/126.0.6478.183/third_party/abseil-cpp/absl/types/bad_variant_access.cc . This identifies failure class, not its upstream cause or the accessed variant's semantic type.

Additional retained-stack candidates and disassembly saved. RVA0x3501240 checks qword[rcx+0x18] against7, branching to RVA0x3be2180 on mismatch; saved RVA0x3501258 follows that call. Next trace the caller/data initialization, including candidate RVA0x3f47a9, before modifying Wine/FEX or interpreting a variant index. Do not bypass fatal checks. Objdump nearest exported labels (GetHandleVerifier etc.) are not actual private symbol names; unvalidated stack words remain candidates.

No runtime edit this turn; current app includes windows114 watchdog fix and windows113 fd cleanup. No extra Simulator, ref mutation or account access. Steam login/visible rendering, actual DE, physical iPad, touch, sustained FPS and multiplayer remain unproved. Full objective active.

## Retail CEF list probe narrows value-handling failure — windows-116

Previous turn made progress identifying renderer fatal Bad variant access. Revalidated Steam PID69852 at exact installed path and kept it untouched for read-only disassembly/LLDB. Caller RVA0x3f4730 through0x3f47a4 checks controller validity/locks, loads[object+0x18], calls list accessor expecting discriminator7, obtains list size, then switches element type. This matches CEF branch6478 CefListValueImpl::GetType(size_t), including list/element distinction. Primary source: https://raw.githubusercontent.com/chromiumembedded/cef/6478/libcef/common/values_impl.cc . Branch source is behavioral corroboration, not private debug symbols or proof of exact vendor source identity.

Manual stack/prologue audit: raw-log prologue pushes r15,r14,r13,r12,rsi,rdi,rbx then subtracts0xc10. Saved r14 at retained stack+0xc68 is0x12ac0062d7d0, consistent with GetType's preserved this pointer. LLDB reads this object, whose value pointer at+0x18 is0x12ac007f1c20. Underlying32 bytes show badbad00 pattern in24-byte payload and discriminator0. Reads occurred after renderer exit; no proof these bytes are unchanged since fault, nor proof of allocation history/poison origin. Did not modify memory, and detached/resumed. Do not call this a confirmed uninitialized/freed value or blame FEX solely from pattern.

New source-owned WindowsCefListProbe.c and builder exercise public CEF list ABI prefix against actual supplied libcef.dll. Verified field order/base callbacks against branch6478 public capi headers and VTYPE_NULL=1 against cef_types.h. DLL loaded by absolute executable-relative path with altered DLL search; no browser/login/CEF settings bypass. Public list interface is documented usable on any process/thread. Private DLL/support files copied to generated probe guest, no proprietary binary added to tracked sources.

Actual windows-cef-list-values: DLL_LOADED, CREATED, RESIZED, then root c0000005. Added phase markers and rebuilt probe (runtime unchanged). Actual windows-cef-list-phases passes TYPES_PASS, COPIED, EQUAL_PASS, then access violation before CLEAR_PASS/rootc0000005. This proves this bounded create/resize/type/copy/equality path executes; it does not reproduce renderer's exact variant fatal. Failure is within clear or subsequent size checks in one expression; add finer markers before assuming exact call. First run also logged rpmalloc CORRUPT op=consume mask0x20; phase run did not show that marker in inspected output. Correlation is not causation. Fault logs include native/guest PCs and wild-pointer state for next analysis.

No runtime patch, suppression, or broad cache-flush change this turn. Deliberately replaced revalidated live Steam only after preserving evidence to run the bounded component diagnostic; designated Simulator alone, classic/ref unchanged. Current diagnostic windows-cef-list-phases initial guest is terminal c0000005; UIKit shell may remain alive and must not be treated as progressing CEF. Next isolate clear versus post-clear size lookup and consider controlled cache-policy comparison only if evidence supports it. Retain actual Steam renderer initialization/IPC investigation: standalone list success through GetType does not clear that path.

No Steam login/visible renderer, actual DE, physical iPad, touch, gameplay FPS or retail multiplayer acceptance. Full objective stays active.

## Corrected CEF ownership probe passes — windows-117

Previous turn made progress constructing a bounded retail CEF probe but its failure interpretation required correction. Actual windows-cef-list-clear passes CLEAR_RETURNED/COPY_EMPTY then faults querying the original. Further windows-cef-list-lifetime passes COPY_ORIGINAL_INTACT and EQUAL_PASS, then faults querying the original before clearing. This isolates the loss to comparison/reference ownership, not clear.

Primary CEF6478 bridge sources explain the error: libcef_dll/cpptoc/list_value_cpptoc.cc list_value_is_equal calls Get(self)->IsEqual(Unwrap(that)); cpptoc_ref_counted.h Unwrap releases the wrapper reference added before a non-self refptr argument crosses the boundary. The hand-written probe failed to add that reference. It consumed its only reference to original list during comparison and later accessed a released object. Required self uses Get and does not need this transfer. Sources: https://raw.githubusercontent.com/chromiumembedded/cef/6478/libcef_dll/cpptoc/cpptoc_ref_counted.h and https://raw.githubusercontent.com/chromiumembedded/cef/6478/libcef_dll/cpptoc/list_value_cpptoc.cc . No inference of a runtime bug is justified by those earlier probe failures.

Corrected WindowsCefListProbe adds one base.add_ref immediately before passing original list as is_equal's non-self argument. Maintains normal reference releases for original and copy, adds phase checks confirming original remains intact after copy and comparison. Builder compiles. Actual windows-cef-list-ref-owned passes CREATE_RESIZE_TYPE_COPY_CLEAR_PASS and root0024 exits0. The test executes the supplied retail libcef.dll in the same Simulator runtime, without a browser or service bootstrap. No runtime/CEF binary change, fake success, exception suppression, or cache policy adjustment.

Updated current status and annotated historical windows116 section with ownership correction. That standalone AV was our diagnostic mistake. The real Steam renderer's Bad variant access remains separate/unresolved; this bounded passing test does not prove its initialization/IPC or concurrent lifetime handling. Retained post-exit discriminator0 observation remains indirect evidence, not causal proof. Next return to actual renderer creation/list population and capture the invalid value before abort, or build a faithful IPC/path reproducer; do not modify runtime based on the discarded probe failure.

Designated Simulator only; current diagnostic root completed0, host shell may remain. Prior Steam replaced for probes; no Steam session currently progressing. Classic/ref preserved, no account accessed. Full DE/gameplay/physical-iPad/touch/FPS/retail multiplayer objective remains active and unfulfilled.

## Renderer startup request narrowed — windows-118

The previous status-only turn did not advance the implementation. Revalidated the saved run observation: windows-steam-renderer-input PID72782 is missing; no initial guest terminal marker was captured. The last log entries are network-table queries, so the host termination cause is unknown. No restart was made in this continuation.

The actual renderer0294 reproduced the prior fatal call chain. A successful read-only LLDB capture retained8192 bytes of its stack before the host disappeared. Manually checked call instructions and prologue sizes extend the chain from libcef GetType through steamwebhelper RVA1ef081, helper2ed894, libcef2b6331, and libcef404b65. These are return addresses qualified by disassembly, not an automatic unwind. The helper consumes element0 as a CEF dictionary. Do not confuse CEF dictionary enum7 with the underlying base::Value list discriminator7.

The caller at libcef404a50 allocates a0x40 startup parameter object and invokes constructor4794d0. Newly inspected constructor calls3500cb0 on params+0x20. That function writes zero to value+0x18 and does not initialize its first24 bytes. Thus a default-created parameter has discriminator0 at params+0x38. This explains how a default value could have an untouched payload without establishing the origin of the previously observed badbad00 pattern.

The same caller invokes synchronous request47c5b0 with the parameter pointer address, ignores its returned boolean, then constructs the list wrapper from params+0x20. Request47c5b0 initializes a stack success byte to0 and passes its address and the output pointer to a responder. The responder vtable at RVA b082550 points to47cec0. That handler decodes via47e260; the failure branch returns false without replacing the caller output or setting success. Its accepted-response branch disposes the old output, installs the decoded pointer, and writes1 to the success byte. Request47c5b0 returns that byte. This statically supports failed request/response decoding as a route to the default object; actual request outcome has not been captured and the runtime root cause remains unproved.

The latest retained stack has params pointer at+0x1458 and list object at+0xc68. A follow-up LLDB attempt to compare the list value pointer and parameter discriminator failed because PID72782 no longer existed. It supplied no memory evidence. Earlier post-exit discriminator0 evidence remains indirect. Existing logs do not provide a decisive response validation failure. Upstream CEF6478 render_manager.cc corroborates the unchecked GetNewRenderThreadInfo pattern, but lacks Valve's added list callback and is not exact vendor source.

Next capture request completion status and whether the responder is reached, distinguishing channel closure from decoding failure before changing compatibility behavior. Do not synthesize initialization data, force success, suppress variant checks, or infer that an empty list enables Steam. Corrected windows117 public-list probe remains passing; its earlier reference-transfer error is not a runtime defect.

No runtime or proprietary binary edits, Simulator changes, account access, or game input changes in this continuation. Full DE gameplay, physical-iPad execution, touch, sustained FPS, Steam login and retail multiplayer remain unverified. Goal stays active.

## Response decoding admits an absent value — windows-119

Previous goal turn was progress: constructor and responder analysis narrowed the real renderer failure. Continued read-only inspection of the current retail libcef rather than changing behavior based on the failed-request hypothesis.

Static trace strings positively identify request47c5b0 as BrowserManager::GetNewRenderThreadInfo, interface cef.mojom.BrowserManager; its message identifier is0x746cb573. Message dispatch47d3a0 checks that identifier and branches at47d4f3, builds the response callback47cd40, then calls the implementation virtual method at vtable+8 through47d56e. Exact implementation address is dynamic and not yet resolved. These names come from binary strings, not nearest exported-symbol labels.

New inspection of response decoder47e260 changes the next experiment. It allocates a new0x40 parameter object, initializes its inline value discriminator to0, and decodes the first field via480c50. If that succeeds, it examines a32-bit field at wire-object+0x10. A zero takes the success path without invoking value decoder14561e0. The output therefore can be accepted with an unchanged discriminator0; a successful request does not by itself prove a list was supplied. For nonzero field,14561e0 dispatches on the wire union tag at+4 and returns a decode status. This is static control-flow evidence, not a claim that the actual incoming response contained a zero field or passed validation.

Corrected experimental requirement: capture both request success and decoded value type, plus whether the browser-side handler and response decoder execute. A false request suggests transport/validation investigation; a true request with type0 requires inspecting producer/serialized field, not treating transport as necessarily failed. Do not assume the previous post-exit memory proves either branch.

Primary upstream CEF6478 browser_manager.cc was retrieved from https://raw.githubusercontent.com/chromiumembedded/cef/6478/libcef/browser/browser_manager.cc . Its GetNewRenderThreadInfo populates cross-origin whitelist entries and invokes the response callback. It lacks Valve's added startup value field; it cannot establish what this binary's producer should populate. The upstream difference makes tracing the actual implementation important.

Inspected existing FEX diagnostics for a live capture mechanism. Compile-time IR capture can map a guest instruction to emitted host code; it is not an execution trace, and CompileBlock hooks can miss subsequently linked/cached executions. No new instrumentation or speculative repair was applied. Next resolve the actual producer target and use execution-level capture with module-relative sites47d56e (producer dispatch),47cf1e (decode return),47c697 (request success byte),404ab1 (request return), and404b10 (parameter used). Validate register locations at each stop; translated guest registers are not interchangeable with native LLDB registers.

Saved private disassembly under generated/steam-119-*.txt; no proprietary code copied into tracked artifacts. No Simulator restart, game input edits, account access, runtime change or new gameplay acceptance. The full goal remains active.

## Actual browser producer creates the list — windows-120

Previous turn made progress distinguishing absent-field decode success from request failure. Revalidated environment: no Simulator currently booted and old Steam PID72782 absent. No Simulator was opened or restarted during this read-only analysis.

Scanned direct-call encodings for parameter constructor4794d0 in the current retail libcef text section. Two candidates,404a85 and3066d9, were validated by disassembly: renderer initialization already known, and browser-side function3066a0. Pointer-table inspection places3066a0 at vtable RVA b39ba68+8, matching the BrowserManager request dispatch slot identified119. Neighbor slot+0x18 is3068a0, consistent with the other request dispatch. This statically identifies the producer; it does not prove the live request reached it.

Producer3066a0 creates the0x40 parameter object, fills the first field via375c60, then constructs a list value through270950 and13e3130 and assigns it to params+0x20 using3500cc0. Inspected13e3130 explicitly sets the value discriminator to7 after moving the three list payload words. This assignment occurs before nullable application/handler checks. The producer then optionally wraps that list using3f3eb0 and calls a browser-side customization method at vtable+0x38. Afterwards it passes the parameter object to the response callback and cleans up.

This is stronger than the upstream source comparison: the actual supplied binary intends to produce a list even if its application callback is absent. The static absent-field decode path from119 still exists, but does not explain why this producer would send an absent field. Remaining possibilities include request failure, producer callback/lifetime effects, serialization/decoding, or runtime corruption. No one possibility is established as the cause.

Added trace-sites.json with module SHA256, module-relative addresses and16-byte signature hashes (no proprietary instruction bytes). Sites cover producer entry3066a0, post-assignment306715, post-customization3067d3, pre-response30681f, decode return47cf1e, success-byte load47c697, request return404ab1 and renderer parameter load404b10. This is a static location inventory, not a passing test or executed trace. Live capture must validate the current module, translation mapping and guest register state; native LLDB registers cannot be assumed to equal guest x64 registers. Existing FEX IR-capture mechanism provides compile-time mapping only and does not itself establish execution.

Next use these producer and consumer boundaries to capture type changes and request status in the actual Steam process. No runtime repair based solely on static evidence. No account access, proprietary input changes, new game build, FPS evidence, physical iPad or multiplayer acceptance. Full objective remains active.

## Executed trace confirms failed startup request — windows-121

Previous turn made progress finding the actual browser producer. This turn adds and executes an opt-in diagnostic instead of relying on static control-flow possibilities.

New FEX AgePadStartupTrace utility binds nine module-relative sites to16-byte FNV signature checks in libcef. Disabled by default; initialized once from AGEPAD_STARTUP_TRACE. On matching module map, checks all signatures before publishing the base atomically; compilation rechecks the selected site's signature. Emits existing IR Print operations at actual instruction positions: marker followed by guest RAX,RCX,RDX,RBX,RSP,RBP,RSI,RDI,R14,R15. Uses register reads only, no guest memory/data writes or success overrides. Existing Print emitter preserves dynamic/static registers around runtime logging. No PrintMsg pointers embedded in cached code. Diagnostic logging affects timing and is not a performance mode. Sites include the eight120 boundaries plus public GetType3f4730 for qualification. This is signature-bound instrumentation, not cryptographic full-module authentication or a general debugger.

Runner --startup-trace propagates the explicit environment flag and records it in the run manifest. Added analyze-madeira-startup-trace.py: per-thread grouping of markers and10 register records, preserving incomplete records. Synthetic interleaving/truncation test passes. Build initially failed because invoking Ninja without the toolchain PATH omitted dlltool/ar; corrected PATH and arm64ecfex target builds successfully. Root FEX container and all16 signed child banks rebuilt. Canonical FEX patch, including the new header and prior JIT scope header, reverse-checks successfully.

Verified no Simulator booted, booted only designated574671AD-6F61-4558-9528-BF946DDB760A. Actual windows-cef-list-execution-trace enables trace, matches libcef signatures and produces four executed GetType records with RDX indices0,1,2,0, matching the source probe. All public-list checks pass and root exits0. This qualifies the diagnostic on a bounded real CEF execution; not all register/flag states or arbitrary concurrency.

After preserving the completed probe, deliberately replaced diagnostic with actual windows-steam-startup-trace, same integration flags plus trace. All16 banks current. Observed PID82258 live, no root exit marker at observation. Renderer0260 records47c697,404ab1,404b10,3f4730 in sequence, with no incomplete trace groups. At404ab1 immediately after GetNewRenderThreadInfo, RAX=0x00e40200, hence AL=0. The boolean ABI uses AL; nonzero upper bits are not success. Previous disassembly shows47c5b0 loads the success byte into SIL and returns ESI, explaining those upper bits. Renderer then enters GetType(0), followed by exit statusc0000409. Thus request failure preceding invalid-list use is executed evidence in this diagnostic run, not merely a hypothesis.

No producer or response-decoder records were observed in this captured log. Their absence alone does not prove nonexecution or locate transport failure. Next trace the synchronous request transport/channel state and browser receipt to determine why it returned false. Keep the live run; do not manufacture an empty list, force success, or suppress the abort. Raw register logs remain generated/private; tracked result includes only relevant RVAs, boolean and bounded probe results.

No classic/ref changes or account access. Diagnostic no-cef-sandbox remains enabled from prior work; no isolation claim. No DE gameplay, login, physical iPad, touch, sustained gameplay FPS or retail multiplayer acceptance. Full goal stays active.

## Send accepted; wait returns without accepted startup reply — windows-122

Previous goal turn made progress capturing generated GetNewRenderThreadInfo returning false. Revalidated prior PID82258 at its exact installed path, live. Read-only LLDB follows the retained proxy pointer from the actual trace to a remote object/vtable; all attachments detached. These post-renderer-exit reads identify a candidate vtable only, not contemporaneous object health. Vtable RVA b0e7d90 slot+0x18 points35542a0; static wrapper calls3553880. Subsequent actual trace below confirms execution through these paths.

Pinned Chromium126.0.6478.183 primary source retrieved from https://chromium.googlesource.com/chromium/src/+/refs/tags/126.0.6478.183/mojo/public/cpp/bindings/lib/interface_endpoint_client.cc . Its InterfaceEndpointClient::SendMessageWithResponder matches the binary's sequence: existing error gate, controller initialization, send, sync wait, weak-self/response handling. Source is behavioral corroboration, not private symbols. Its transport method may return true after waiting even if no response was accepted; the generated request independently tracks responder success.

Extended the existing opt-in signature-bound execution trace with six sites:3553880 entry,35538db before encountered-error check,35538e8 after it,35539bc after controller SendMessage,3553e7c after nonexclusive SyncWatch,35542d9 after outer transport. Only added locations; no new guest data reads, semantic fixes or forced results. arm64ecfex, root container and16 banks build. Parser interleaving/incomplete tests pass; canonical FEX patch reverse-check passes. Sole designated Simulator confirmed. Preserved prior run before deliberately replacing diagnostic with windows-steam-transport-trace; classic/ref unchanged.

Actual new run PID86249 live at observation, no root exit marker.349 complete register records and no incomplete groups. Renderer02e4 executes3553880,35538db,35538e8,35539bc with AL1; later3553e7c,35542d9 with AL1,47c697,404ab1 with AL0,404b10,3f4730. The two send-stage records use the same endpoint RSI, and the generated startup request immediately follows the transport return on that thread. This rules out the initial encountered-error return and immediate controller-send failure on this observed path. Transport returned true after the nonexclusive sync wait, while the generated startup request's success remained false. Do not interpret AL at3553e7c as a wait-success boolean; that virtual method's return is not established as such.

No producer/accepted-response evidence in this renderer sequence. Missing records alone are not proof of nonexecution. The useful next step is the actual nonexclusive SyncWatch implementation and endpoint-disconnection/response dispatch path: determine why waiting ended without an accepted startup reply, distinguishing wait failure, channel closure, object destruction and invalid response. Do not blame network adapters or synthesize response data from this evidence. Keep the live host available for read-only follow-up.

All runtime logs and raw register/object snapshots remain generated/private. Tracked result keeps relevant RVAs/AL values only. Diagnostic changes affect scheduling and are not performance measurements. No Steam login, DE gameplay, physical iPad, touch, FPS or retail multiplayer acceptance. Full goal remains active.

## Event-watcher destroyed flag ends the wait — windows-123

Previous turn made progress proving send accepted but no accepted startup response. Revalidated PID86249 live at exact installed path. Read-only LLDB followed retained endpoint+0xc8 to controller, and controller vtable RVA b2e9dc8 slot+0x18 to144a510. A batch LLDB attempt stopped on another thread's exception before requested memory commands; no pointer evidence came from that attempt and no LLDB remained. An interactive retry read the controller vtable and explicitly detached. These retained reads are post-renderer-exit evidence only; new execution trace below confirms the selected path.

Static144a510 ensures a watcher then tail-calls192e060. That function builds two stop pointers: caller response flag and watcher-state+4. It calls19302a0, which prepends its own preserved destruction flag and invokes1f0ff80. That wait loop checks pointers in order and branches to1f100ea when a flag is nonzero; RAX still holds the index and RCX the flag pointer at that site. Normal return reports true. The enclosing19302a0 returns false if its preserved destruction flag is set.

Pinned Chromium126.0.6478.183 sources corroborate these semantics: mojo/public/cpp/bindings/lib/sync_handle_registry.cc, sequence_local_sync_event_watcher.cc, and sync_event_watcher.cc. Exact source URL prefix https://chromium.googlesource.com/chromium/src/+/refs/tags/126.0.6478.183/ . SyncEventWatcher::SyncWatch prepends destroyed_->data before caller flags; sequence-local wrapper adds watcher_was_destroyed after caller should_stop. First two guessed source paths returned404; directory listing located the valid lib paths. This is behavioral source correlation, not exact private symbols.

Added five signature-bound execution sites144a510,192e060,1930392,192e183,1f100ea to existing opt-in tracing. No changes to guest data, waits or success behavior. arm64ecfex, root container and16 child banks build; parser tests and canonical FEX patch reverse check pass. Preserved previous logs and replaced diagnostic app for windows-steam-wait-trace. Only designated Simulator booted; classic/ref untouched.

Actual PID90344 live at observation, no root exit marker;349 complete trace records/no incomplete. Renderer02c4 accepts send(AL1), enters controller144a510 and watcher192e060 with identical response flag RDX. It reaches1f100ea with RAX0, selecting the first flag. Registry return1930392 has AL1, event-watcher return192e183 AL0, outer wait3553e7c AL0, transport35542d9 AL1, generated request404ab1 AL0, then GetType0. Binary/source mapping identifies flag0 as SyncEventWatcher destruction state. This narrows the failure to that set flag; it does not prove a correct destructor ran, when the flag was set, or why. A stale/corrupted lifetime flag remains possible until its transition is captured. Avoid conflating this with the second sequence-local watcher-destruction flag or response flag.

Next inspect SyncEventWatcher construction/destruction and capture the flag transition or triggering owner teardown in the actual renderer. Do not keep changing Windows wait timeouts or network adapters on this evidence. Keep new run available. Raw register/pointer logs private in generated; tracked artifact retains relevant sites/index and interpreted boolean returns only. Diagnostic timing is not representative FPS.

No Steam login, DE gameplay, physical iPad, touch, gameplay FPS or retail multiplayer qualification. Full goal remains active.

## Same watcher is destroyed during the pending wait — windows-124

Previous turn made progress identifying destruction-state flag0 as the stop condition. Revalidated existing run with observer and preserved it for this investigation. Static constructor1930060 allocates8-byte reference-counted flag, stores count0 and flag byte0; destructor1930120 loads watcher+0x28 and stores1 to flag+4 before releasing its reference. This matches already retrieved pinned sync_event_watcher.cc. Located four direct destructor-call candidates by relative-call scan;192e831 is a validated call from an enclosing destructor using owner+0x10. No caller is yet dynamically proved solely from this scan.

Added three signature-bound execution sites19300d1 (after constructor zero store),1930120 (destructor entry),1930131 (after destructor one store). These extend the same register-only trace; no wait, lifetime or guest-data behavior changes. arm64ecfex, root container and16 banks build successfully. Parser tests and canonical FEX patch reverse check pass. Sole designated Simulator verified; preserved current diagnostics and replaced only diagnostic app with windows-steam-lifetime-trace. Classic/ref untouched.

Actual PID94366 live at observation, no root exit marker;371 complete trace records/no incomplete. Renderer02b8 constructs watcher A, then the synchronous request's144a510 path constructs watcher B. At B's constructor post-store, RSI identifies the watcher and RAX its flag allocation. After entering192e060, trace records destructor entry1930120 for that same watcher, then1930131 with the same flag allocation. The next1f100ea stop pointer RCX equals that allocation+4 and RAX is index0. All pointer equalities are checked against raw generated trace; tracked result reports the equalities without raw pointers. Registry reports true, watcher returns false, outer transport reports true, generated request returns false, then renderer enters GetType0.

Thus the destruction flag is not merely an unexplained stale value in this run: actual destructor instructions execute on the matching watcher between its creation/wait entry and wait completion. This still does not prove correct owner lifetime/refcount handling or identify what triggers teardown. At destructor entry, preserved RSI is watcher-0x10, consistent with enclosing192e831 owner destructor; this is a caller hypothesis until execution/call-stack evidence confirms it. Next trace the sequence-local owner destruction and its release path while the request is pending. Do not bypass destruction or hold arbitrary references as a fix without establishing intended ownership.

Private disassembly and raw register trace remain in generated. Diagnostic scheduling differs from normal execution. No Steam login, DE gameplay, physical iPad, touch, measured gameplay FPS or multiplayer acceptance. Goal remains active.

## Last registration removal resets the shared owner — windows-125

Previous turn made progress matching watcher construction/destruction to the stop flag. Revalidated and preserved current runtime observations. Source inspection of pinned sequence_local_sync_event_watcher.cc shows UnregisterWatcher erases a registration and resets its sequence-local storage slot if no registrations remain and a current-thread storage map exists. This deletes the shared owner. Located the actual binary slot through getter192e550: index RVA ca475b0, stored deleter192e770, and owner destructor192e7a0. The third load of that slot index is192eb04 in registration cleanup. Disassembly validates count decrement at192ea09, empty check at192ea45, empty branch192ead1, current-map guard, and slot reset call192eb0d. This is more specific than assuming general thread shutdown.

Added five signature-bound execution sites192ea45,192ead1,192eb0d,192e770,192e7a0 to existing register-only tracing. arm64ecfex, root container and16 banks build; parser tests and canonical FEX patch reverse-check pass. Sole designated Simulator checked. Preserved windows-steam-lifetime-trace, deliberately replaced diagnostic for windows-steam-owner-trace. No classic/ref/account changes.

Actual PID98273 live at observation, no root exit marker;397 complete records/no incomplete. Renderer02d0 sends successfully and enters wait, then executes192ea45,192ead1,192eb0d,192e770,192e7a0, watcher destructor1930120/1930131, stop flag0, and failed generated startup request. RDI owner at empty branch equals RCX at owner destructor; destroyed watcher equals owner+0x10. These equalities are checked from raw trace. Thus the empty-registration cleanup path and slot deleter are observed on the actual owner, not just possible static paths. It does not prove the registration count itself was maintained correctly or explain who requests the last unregistration.

Next trace the registration destructor's caller and owner/controller release path before the empty count check. Determine whether endpoint teardown is justified by a channel failure or caused by wrong lifecycle/scheduling behavior. Do not preserve registrations indefinitely, fake a response or bypass a wait as a repair. Full runtime logs/registers remain private generated; tracked artifact stores relevant branch/path conclusions and RVAs.

No Steam login, DE gameplay, physical iPad, touch, sustained gameplay FPS or retail multiplayer acceptance. Goal stays active.

## Endpoint closure now has a concrete upstream trace target — windows-127

The preceding user-status turn was no progress; this continuation revalidated the current run and advanced static diagnosis. Observer confirms PID2355 at the exact designated Simulator app path, with no initial-guest terminal marker. Host liveness does not establish guest progress. No Simulator restart or app replacement this turn.

Completed interpretation of windows-126: renderer029c executes caller69769ac then destructor192de00, with matching watcher RCX. Caller RDI matches the controller RCX captured at144a510, proving this is the same endpoint. The enclosing69768f0 path calls6976070, branches past teardown if its boolean is true, and otherwise requires endpoint byte+0x1d equal1 before clearing watcher+0x60 and destroying it. This behavior matches InterfaceEndpoint::OnSyncEventSignaled: no more synchronous messages and peer_closed trigger watcher reset. This does not prove the peer actually terminated or that its closed state is correct. The126 trace contains410 complete records; raw addresses remain private.

Pinned Chromium126.0.6478.183 multiplex_router.cc explains UpdateEndpointStateMayRemove: peer closure sets peer_closed_, signals synchronous waiters, and may remove an endpoint when both ends are closed. Located a matching actual binary routine at14481f0. Its nonzero R8D branch stores1 at endpoint+0x1d (144821b), sets signal byte+0x58 and dispatches to watcher+0x60, then tests both closed flags before endpoint removal. Three relative-call candidates1447f16,1449cde,354e1e7 were confirmed as actual call instructions by local disassembly; all pass R8D=1. They have not yet been observed executing on the failing endpoint. Byte scanning is a candidate finder, not an exhaustive proof of all stores, tail calls or inlined code.

Next add signature-bound register traces at the three call sites and after the peer-closed store144821f, matching their endpoint argument to the failing renderer controller. That will select which upstream closure path to investigate. No speculative closure suppression or forced startup data was introduced. Current installed trace remains126; no new runtime build is claimed for127.

Primary behavioral source: https://chromium.googlesource.com/chromium/src/+/refs/tags/126.0.6478.183/mojo/public/cpp/bindings/lib/multiplex_router.cc . Source names are behavioral correlations, not symbols recovered from the private binary.

Game execution, Steam login, physical iPad, DE touch controls, sustained gameplay FPS and retail multiplayer remain unproved. Full goal stays active.

## Direct closure trace narrows coverage gap — windows-128

Previous goal turn made progress identifying upstream closure candidates. Revalidated old run and sole designated booted Simulator. Added four signature-bound register-only execution sites1447f16,1449cde,354e1e7,144821f. Parser tests pass; arm64ecfex, root container and all16 banks build successfully; canonical FEX patch reverse-check passes. Preserved old observations and deliberately restarted only diagnostic app for windows-steam-peer-close-trace.

New host PID6933 is live at observation. Trace has411 complete records and no incomplete groups. Renderer0294 again enters synchronous wait, executes69769ac with the same endpoint seen at144a510, destroys its matching watcher and returns startup failure before GetType0. None of the four new sites appears in the captured records across threads. Absence is not proof of nonexecution or corrupt peer state; trace coverage is not exhaustive.

Follow-up disassembly of earlier byte-store candidates reveals two additional inlined endpoint-update sequences:354c734 and3550389 both store1 at endpoint+0x1d, signal byte+0x58, use watcher+0x60 and check both closure bytes before endpoint removal. These match the relevant field layout, unlike an arbitrary byte-offset match. They are static candidates, not dynamically identified closure sources. Next trace immediately after these stores at354c738 and355038d and match RDI to the failing endpoint; investigate enclosing pipe-error path if confirmed. Other stores and indirect paths remain possible.

No semantic repair, fabricated startup response, account access or classic/ref changes. Current installed diagnostics include only the four new direct-path sites; inlined sites have not been built or run yet. Raw disassembly/registers remain generated/private. Actual DE, Steam login, physical iPad, touch, sustained gameplay FPS and retail multiplayer remain unproved. Full goal active.

## Pipe-error handler closes the matching renderer endpoint — windows-129

Previous turn made progress locating inlined closure candidates. Revalidated current run and sole designated booted Simulator. Added signature-bound register-only sites354c738 and355038d immediately after their peer-closed stores. Parser tests, arm64ecfex build, root container, all16 banks and canonical FEX patch reverse-check pass. Preserved prior observations and deliberately replaced only diagnostic app for windows-steam-inline-close-trace.

Observed new host PID10705 live. Parsed789 complete records, no incomplete groups. Renderer02f8 enters144a510 for its controller, executes354c738, then69769ac. RDI at354c738 equals the waiting controller and cleanup endpoint; RSI router at354c738 equals RSI at69769ac. Matching store record precedes cleanup on the same thread (raw log lines89065 and89082). This directly identifies the inlined peer-closed store on this endpoint, rather than merely a possible source path. Other closure records occur across other endpoints/threads and do not individually establish their causes.

PE exception metadata places354c738 inside function354c400..354dcad and355038d inside3550030..355191c. First function preserves boolean EDX, takes a router reference/optional lock, sets router error byte+0x349, allocates a vector from endpoint count+0x2d0, and performs the traced update loop. This behavior correlates with pinned Chromium126 MultiplexRouter::OnPipeConnectionError, including its endpoint vector and error notification behavior. This is behavioral source correlation, not recovered private symbols. The second function first closes/resets connector state then uses an equivalent loop; its role remains static inference.

No direct relative calls to354c400 found in text scan; RIP-relative LEA candidates referring to it occur354c1f5,354c379,3552890. They are reference candidates until surrounding instructions are inspected. Next follow its callback registration/invocation and connector error classification, distinguishing remote close, rejected message, local pipe failure and runtime error reporting. Do not suppress the peer flag or fake startup data.

Installed diagnostic is current129; no gameplay or account action. Classic/ref untouched. Raw execution registers/disassembly remain generated/private. Full DE execution, Steam login, physical iPad, touch, sustained gameplay FPS and supported retail multiplayer remain unproved; goal active.

## Connector error delivery mapped for the next capture — windows-130

Previous turn made progress proving the matching endpoint peer-closed store. Revalidated PID10705 at exact installed path. No restart or build this turn; current diagnostic remains129. Read-only LLDB attached and explicitly detached. The retained stack location derived from prior354c738 RSP had already been reused (a helper-consumer return occupied the expected slot); it does not identify the historic caller. No fault-time claim follows from that read.

Inspected three handler references from129.354c1f5 and354c379 construct callback state with target354c400, router at state+0x30 and boolean0 at+0x38, and install it at router+0x68.3552870 is the invocation thunk: it loads router and boolean and tail-jumps to354c400 when the target matches. Connector is embedded at router+0x60, making the callback slot connector+8. These are static mappings, not new runtime execution evidence.

Retrieved pinned Chromium126.0.6478.183 connector.cc from https://chromium.googlesource.com/chromium/src/+/refs/tags/126.0.6478.183/mojo/public/cpp/bindings/lib/connector.cc . HandleError checks existing error/valid pipe, combines paused with force_async_handler, optionally resets the pipe, cancels watchers, and invokes the stored connection error callback for synchronous delivery. Located matching binary144dbe0: RCX connector, DL force_pipe_reset, R8B force_async_handler; error flag+0xf8, pipe+0x10, pause+0xfb. Callback is removed from connector+8 and invoked at144dcaa. The source/binary mapping is behavioral, not exact private symbols.

Read-loop branch3557c70 compares EAX17, then3557c78 compares EAX9. The latter path passes reset=false and async=false to144dbe0 at3557c86; nonmatching fatal result takes another branch. This corresponds to source SHOULD_WAIT versus FAILED_PRECONDITION distinctions, but actual renderer result is still unknown. Full text relative-call/jump scan found24 candidate references to144dbe0, saved privately. Four calls in3557xxx/3558xxx are already locally disassembled; remaining candidates need boundary validation before tracing. Tail calls must be included.

Next trace144dbe0 entry and144dcaa plus validated call sites, matching connector to the failing router+0x60. Entry RDX captures reset choice; existing trace does not capture R8, so use site/branch evidence for async behavior or deliberately extend its schema with qualification. Prefer caller result branches over guessing why the pipe closed. No semantic repair or account activity. Classic/ref unchanged. Game, login, physical iPad, touch, sustained gameplay FPS and retail multiplayer remain unproved; full goal active.

## Connector caller trace built; run remains earlier in startup — windows-131

Previous turn made progress mapping connector error handling. Revalidated external state: no Simulator booted and old diagnostic no longer running. Validated all24 relative call/tail-call candidates against instruction boundaries. First preparation attempt stopped before editing because leaf6977430 has no .pdata entry; manual disassembly established its padded entry and tail jump6977435. Retried with that explicit leaf range. Added27 signature-bound sites:24 callers,144dbe0 entry,144dcaa callback dispatch,3552870 callback thunk. No schema or runtime semantic change.

Parser tests pass. arm64ecfex, root container and16 banks build; canonical FEX patch reverse-check passes. Booted only designated574671AD-6F61-4558-9528-BF946DDB760A and launched windows-steam-connector-error-trace. PID15123 live at exact installed app path. Module libcef signature_match=true is logged, confirming trace-site hashes match the mapped binary.

Initial and follow-up observations produce zero executed target records, no incomplete records. Steam launched webhelper124, which logged Chrome version but did not advance to the previously observed browser/renderer phase during observation. Runtime bytes grew from1429020 to1745868 through repeated network-table queries and missing SteamChrome_MasterStream section opens. No initial guest terminal marker. These repetitions are not proof of useful startup progress or of a specific new defect. No restart was performed merely because the observation window expired.

Captured one-second native host sample; many waits and unresolved translated frames appear. It does not identify the blocked guest instruction or establish a deadlock. Sample/raw runtime stays private generated. Next inspect the same live webhelper startup state and its waits, retaining current trace for when connector execution is reached. Current run is a verified live observation, not a captured connector-error result. Existing129 pipe-error evidence still stands;131 does not yet refine its cause.

Classic/ref untouched. No game, Steam login, physical iPad, DE touch, sustained gameplay FPS or retail multiplayer acceptance. Full goal remains active.

## Remove cross-process builtin initialization serialization — windows-132

Previous turn built the connector trace and verified a live wait. Revalidated PID15123: still before useful browser startup, no target records. Native sample identifies register_builtin_classes holding builtin_lock across KeUserModeCallback(NtUserInitBuiltinClasses), whose owner thread waits in NtWaitForAlertByThreadId; three other threads wait acquiring builtin_lock. Actual compiled source is build/win32u-unix/class_ios.c, not upstream class.c. Its shared mutex serializes guest callbacks across all pseudo-processes. The sample establishes the blocking shape, not the full guest lock dependency cycle.

Changed class_ios.c registry from completed(pid,PEB) entries plus global callback lock to stable(pid,PEB,pthread_once_t) entries. Global mutex now only selects/initializes an entry; pthread_once runs after unlock, retaining once-only synchronization within one process and allowing independent processes to initialize concurrently. Existing128-entry capacity and re-registration fallback preserved. No forced success or skipped guest callback. pthread_once supplies platform cancellation semantics; recursive same-process initialization is not newly qualified.

Added tests/test-builtin-process-once.py compiling the actual function with ASan/UBSan and controlled guest callbacks. Process A waits while B must finish; concurrent same-process callers execute once, repeated calls do not reinitialize, and samePID/differentPEB initializes separately. Negative control restores the global callback lock and fails the independence assertion as expected. Native win32u and Simulator app build successfully. Canonical madeira.patch includes the source change and reverse-check passes.

Preserved stalled131 logs and replaced only diagnostic app. First windows-steam-process-class-once run exited root97 during RPC bootstrap with error1726 before Steam; this provides no verdict on class init. Retried same build only after that explicit terminal result. Current windows-steam-process-class-once-retry PID16595 live. It advances beyond prior Chrome-version-only stage to BrowserReady, with936 complete trace records and zero incomplete groups on follow-up. Network-service crashes/restarts persist. No69769ac renderer cleanup records yet, so no connector error classification for that failing renderer is claimed. Trace thunk and closure records on other endpoints are not substituted for the target. Integration advancement is consistent with the fix but does not independently establish that every former wait was caused solely by global serialization.

Current native build132; FEX and all child banks131. Single designated Simulator reused. Classic/ref/account untouched. Keep current run for follow-up; no restart solely on timeout. Full DE execution, Steam login, physical iPad, touch, sustained gameplay FPS and retail multiplayer remain unproved. Goal active.

## Captured peer-closed errors precede target renderer evidence — windows-133

Previous goal turn made progress with a tested per-process builtin initialization repair. Revalidated PID16595 live at exact installed path, no root terminal marker. Trace remains936 complete records with no incomplete groups and no target69769ac cleanup. Fresh one-second host sample no longer contains register_builtin_classes/pthread_once stacks. CrBrowserMain predominantly waits in NtUserMsgWaitForMultipleObjectsEx, with other sampled activity; this is not proof of a new deadlock or healthy UI.

Examined the three executed144dbe0 records. Threads012c and02e8 arrive from69788a6 with EAX9 and DL0. Browser main0080 arrives from69774a7 with EAX9 and DL0. At each caller the binary explicitly zeros R8D, so force_async_handler=false without adding R8 to the trace schema. These are real failed-precondition/non-forced-reset paths, not arbitrary fatal error classification. They are not yet matched to the renderer endpoint from129 and must not be presented as that renderer's captured cause.

Binary6977440 correlates with Connector::WaitForIncomingMessage: existing error check, resume if paused, load pipe+0x10, call1451f00 for readable signal, test EAX, and on nonzero compare9 before69774a7. Thus browser-main error originates in the waiting step, before ReadMessage at144ddf0.69788a6 is in a read-loop branch distinguishing17 (should wait) from9 (failed precondition). Primary behavioral source is pinned connector.cc retrieved130. This confirms upstream APIs report peer closure, not that remote closure is justified or physically observed.

Saved disassembly of1451f00. It builds a trap/event context, registers through355e8c0 and arms/waits later. Next trace the browser connector's wait handle and trap result transitions, or capture upstream channel closure on the corresponding endpoint. Need identify peer/handle before assigning network-service causality. Browser log requests renderer launch, but no actual --type=renderer parent/child parameter record appears in captured runtime. All16 banks are seen and a storage-service child is refused at bank capacity. The refusal does not establish that renderer was the refused child. Network service restarts continue; increasing capacity alone would not fix them.

No Simulator restart or runtime changes this turn. Current native132/FEX131 kept available. Private samples/raw pointer records stay generated. Full DE gameplay, Steam login, device execution, touch, sustained gameplay FPS and retail multiplayer remain unproved. Goal active.

## Browser wait arms successfully then returns notification result9 — windows-134

Previous turn made progress capturing failed-precondition connector errors. Revalidated existing run and preserved observations. Read pinned Chromium126.0.6478.183 mojo/public/cpp/system/wait.cc from https://chromium.googlesource.com/chromium/src/+/refs/tags/126.0.6478.183/mojo/public/cpp/system/wait.cc . Wait creates trap/context, adds trigger, arms trap, returns blocking-event result if ArmTrap returns9, otherwise waits for context notification and reads its result. This distinction matters: ArmTrap result9 alone is not necessarily a failed wait; the blocking event carries its own result.

Binary1451f00 matches that flow. Added seven signature-bound register trace sites6977490,1451f00,1451fcb,1452005,1452015,145205c,1452040. Existing parser tests pass; FEX/root container/all16 banks build and canonical patch reverse-check passes. Verified only designated Simulator booted, preserved prior logs, deliberately replaced diagnostic for windows-steam-trap-result-trace. Native132 class-init repair remains current.

Observed new PID20845 live, no initial guest terminal marker.1038 complete records/no incomplete groups. Browser thread0080 executes6977490,1451f00,1451fcb(EAX0 AddTrigger),1452005(EAX0 ArmTrap),1452015(EBP9 loaded from context after event wait),1452040(EBP9),69774a7(EAX9),144dbe0. Same watched handle R15 persists through the wait stages. Thus actual browser error follows successful arming and event wait, rather than immediate blocking-event return. This does not yet prove the notification originated from a justified remote close or match the prior failing renderer's endpoint.

Located notification handler14520c0: loads event context+8 intoRSI, checks context result+0x18 equalsUNKNOWN2, copies event result+0x10 into context+0x18 and event signals+0x14 into context+0x1c, then signals event. Next trace14520de after result store (RAX result,RCX packed signal state,RSI context,RBX event), matching RSI to wait context. This would establish actual notification payload rather than only the consumer's loaded value. The callback has not yet been traced. MojoArmTrap wrapper355e940 dispatches through function pointer at moduleRVAca265b8; mapping current pointer can locate actual core implementation if needed.

No forced values or guest semantics changed134. Classic/ref/account untouched. Full DE, Steam login, physical device, touch, sustained gameplay FPS and retail multiplayer remain unproved. Goal active.

## Notification payload confirms peer-closed/unreadable state — windows-135

Previous turn made progress separating successful arming from eventual wait failure. Revalidated PID20845 live, sole designated Simulator. Read-only LLDB resolves MojoArmTrap function-pointer slot moduleRVAca265b8 to actual libcefRVA2d48980 and explicitly detaches. Static wrapper checks object kind6 then tail-jumps2d4b7d0. Pointer read identifies implementation location, not contemporaneous trap health.

Added signature-bound14520de immediately after notification result store: RAX result, RCX packed signals, RSI context, RBX event. No guest data mutation or trace schema change. FEX/root container/all16 banks build and canonical patch reverse-check pass. Preserved old run, deliberately restarted diagnostic for windows-steam-trap-notification-trace. Current native132 retained; no classic/ref/account changes.

PID24557 live, no initial guest terminal marker.1015 complete records. Browser0080 consumes context wait result9 at1452015. Earlier thread00c8 executes14520de with identical RSI context, RAX9 and RCX0x0000002400000004. Thus notification itself carries result9, satisfied_signals4, satisfiable_signals0x24, before the waiting consumer. Identity and order checked from raw trace. This rules out merely inferring notification value from a later context read, but not incorrect upstream signal computation or bad portal lifetime. These browser records are not yet matched to prior129 renderer endpoint.

Retrieved pinned primary mojo/core/ipcz_driver/mojo_trap.cc and mojo/public/c/system/types.h under Chromium126.0.6478.183. Types define READABLE1, WRITABLE2, PEER_CLOSED4, QUOTA_EXCEEDED0x20. Payload has peer closed satisfied and neither readable nor writable satisfiable; quota bit is only satisfiable, not an exceeded-quota report. PopulateEventForMessagePipe initializes satisfiable to peer_closed|quota, adds readable unless portal DEAD, sets peer_closed if flagged, and adds readable satisfaction if local parcels exist. Therefore this payload is consistent with DEAD+PEER_CLOSED/no local parcels in that source translation. Actual portal status has not been captured, so treat that as source-based inference. Notification handler dispatch path uses incoming ipcz event.status at source line458.

Next map actual ipcz event dispatch to this same trap/context and capture portal status/closure source. Follow native channel/portal lifetime rather than changing Windows wait timeout or manufacturing readability. No sustained gameplay/FPS, Steam login, physical iPad, DE touch or retail multiplayer acceptance. Full goal active.

Primary source URLs: https://chromium.googlesource.com/chromium/src/+/refs/tags/126.0.6478.183/mojo/core/ipcz_driver/mojo_trap.cc and https://chromium.googlesource.com/chromium/src/+/refs/tags/126.0.6478.183/mojo/public/c/system/types.h . Raw private execution data stays generated.

## Raw portal flags confirm DEAD and PEER_CLOSED — windows-136

Previous turn made progress capturing matching notification payload. Revalidated current run. Static MojoTrap arm implementation2d4b7d0 registers callback2d4bdb0. Its inlined message-pipe event translation loads event.status atR14+0x18, raw flags fromstatus+8, trigger context fromtrigger+0x28, checks data-pipe pointer null, and computes Mojo state. Matches pinned mojo_trap.cc behavior.

Extended executed register trace format with R8/R9: new marker prefixA6E3 has12 registers, oldA6E2 remains10. Parser accepts both, records format, preserves incomplete groups. Tests cover old interleaving, mixed-format interleaving and truncated extended record. Added sites2d4be77 (RAX trigger_context),2d4bea5 (R8 raw flags),2d4becd (R8 satisfied,RCX satisfiable),2d4bef2 (failure-result branch),2d4bf52 (callback dispatch target load). Canonical FEX patch regenerated/reverse-checked; root/all16 banks build. Native132 unchanged.

Sole designated Simulator verified; preserved old run and deliberately replaced diagnostic for bounded windows-cef-list-trace-v2 qualification. Four executed GetType records each decode12 registers; CEF list checks pass/root0. This qualifies new trace shape with bounded semantics, not arbitrary register correctness or timing. Then replaced completed probe with windows-steam-portal-status-trace.

New PID28908 live, no initial guest terminal marker;2254 complete records/no incomplete groups. Browser0080 consumes wait result9. Thread00c8 notification14520de has same context and result9. Earlier same-thread2d4be77 RAX equals that context; following2d4bea5 captures rawR8=3,2d4becd capturesR8=4/RCX0x24,2d4bef2 selects result9. This matches actual input portal flags to actual notification output, rather than assuming flags from the output alone. Source ipcz.h defines PEER_CLOSED bit0 and DEAD bit1. This proves reported raw flags, not that underlying peer lifetime was correct. Event status may itself reflect wrong transport/lifecycle behavior.

Next follow where ipcz sets DEAD/PEER_CLOSED and dispatches this event, linking the observed trigger handle/portal to route or transport disconnect. Do not suppress flags or synthesize readability. Current FEX136/native132 remains live. Classic/ref/account untouched; no game, login, physical iPad, touch, sustained gameplay FPS or retail multiplayer acceptance. Full goal active.

Pinned constants source: https://chromium.googlesource.com/chromium/src/+/refs/tags/126.0.6478.183/third_party/ipcz/include/ipcz/ipcz.h . Raw logs, disassembly and register identities remain generated/private.

## Map router trap and closure-store candidates — windows-137

Previous turn made progress capturing raw portal flags. Revalidated PID28908 live at installed path. Read pinned third_party/ipcz/src/ipcz/router.cc and trap_event_dispatcher.cc. Router::AcceptRouteClosureFrom, AcceptRouteDisconnectedFrom, parcel consumption and route setup paths can set DEAD|PEER_CLOSED; source flags alone cannot select a cause. TrapEventDispatcher defers event snapshots and invokes handlers after the owning scope unwinds, so a callback stack need not directly contain the status write.

Static getter2d48a80 returns ipcz API tableRVA c91a818; arm path reads its+0x68 slot. Read-only LLDB found actual targetRVA2d4f230 and detached. Read of old watched handle found reused contents, hence it supplies no router state, vtable or lifetime evidence. Do not treat that post-wait allocation as a current router.

Actual ipcz Trap2d4f230 checks handle kind1 and arguments then calls2d61390. That function matches Router::Trap, not a separate Portal object: takes mutex atthis+0x10, loads status_flags at+0x1c, passes traps at+0x20 and inbound sequence at+0x58 into2d63260. A guessed portal.cc fetch returned404; router.cc explicitly contains Router::Trap. Next capture entry2d61390 to tie actual watched handleRCX to trigger contextR9 and callbackR8 while valid.

Disassembled router region2d50000..2d63260 and found three validated memory stores setting both flags at correct+0x1c:2d5df79(orb3,[RSI+1c]),2d60e22(orb3,[RDI+1c]),2d619b5(orb3,[RDI+1c]). The initial dword-OR byte-pattern scan found none because compiler emits byte OR. Other flag writes/colder inlined paths may exist; this is not exhaustive. Store2d623fe targets+0x40 and is not qualified as router status. Next trace the three post-store sites and Router::Trap entry, comparing router identity against successful wait registration, then map the executed enclosing path to route closure versus disconnection/consumption.

No new runtime edits/build/restart this turn. Current native132/FEX136 run retained. Classic/ref/accounts untouched. Full DE, Steam login, physical iPad, touch, sustained gameplay FPS and retail multiplayer remain unproved. Goal active.

Primary source URLs: https://chromium.googlesource.com/chromium/src/+/refs/tags/126.0.6478.183/third_party/ipcz/src/ipcz/router.cc and https://chromium.googlesource.com/chromium/src/+/refs/tags/126.0.6478.183/third_party/ipcz/src/ipcz/trap_event_dispatcher.cc . Raw private reads and disassembly remain generated.

## Route disconnection sets the matching channel flags — windows-138

The intervening user-status turn added no experimental evidence. Revalidated prior diagnostic PID33138 live and only designated Simulator574671AD-6F61-4558-9528-BF946DDB760A booted. Preserved its observation before deliberately replacing only the diagnostic app. Classic candidate, saves, ref and accounts remain untouched.

First capture added Router::Trap entry2d61390 and post-store sites2d5df7d,2d60e26,2d619b9. It produced3678 complete records/no incomplete groups. Browser0080 wait and notification00c8 matched via context, trigger and registered router, but none of these three stores matched that router between registration and notification. They executed on other routers; that does not explain the target channel. An expanded whole-text scan found a fourth byte-OR store49b4be outside the initial region.

PE exception metadata places49b4be inside49b210..49b6f4. Disassembly from the verified entry shows router lock, is_disconnected byte, inbound/outbound sequence termination selected by link type, link release, terminal peer-close flag update and notification. This behavior matches pinned ipcz Router::AcceptRouteDisconnectedFrom; the name is source correlation, not recovered private symbols. Added signature-bound post-store trace49b4c2. FEX, root container and all16 child banks rebuilt; trace parser tests and canonical FEX patch reverse-check pass. Native132 retained.

Launched windows-steam-router-disconnect-trace; PID36710 verified live at observation, no initial guest terminal marker. Parsed3710 complete records/no incomplete groups. Browser0080 wait result9 matches notification00c8, its Mojo trigger and Router::Trap registration. Between that registration and notification, thread00c8 executes49b4c2 with RDI equal to the registered router. The trace is immediately after orb3 at router+0x1c. Thus the route-disconnection path actually sets DEAD|PEER_CLOSED on the watched router before the matching failure notification. This is stronger than interpreting flags alone. It does not establish why disconnection began, whether it was justified, or link this browser channel to the earlier129 renderer endpoint.

Full-text relative call/jump scan found10 candidates targeting49b210. All were verified at instruction boundaries by disassembling their PE function ranges:49277e,49c44f,49c889,49cc96,49d672,49e7ee,49f229(tail),2d61d46,3cf89a5,3cff23d. These are static callers, not yet observed for the matching router; indirect callers remain possible. Next trace these sites plus49b210 entry, preserving R8 link type and matching router identity, to locate the initiating disconnection path. Do not suppress closure or manufacture startup data.

Network-service instability and a child initialization refusal remain in the integration observation. A live host is not successful Steam startup. DE gameplay, Steam login, device execution, sustained gameplay FPS, DE touch and supported retail multiplayer remain unproved. Goal remains active. Raw disassembly, registers and addresses remain private under generated.

Primary source: [Chromium126 ipcz router.cc](https://chromium.googlesource.com/chromium/src/+/refs/tags/126.0.6478.183/third_party/ipcz/src/ipcz/router.cc).

## Matching outward-link notification initiates router disconnection — windows-139

Previous goal turn made progress: captured the matching router closure store. Revalidated PID36710 live and sole designated Simulator booted; preserved old observation. Added signature-bound49b210 entry and all10 previously instruction-validated call/tail sites. FEX, root container and all16 banks build successfully; parser tests and canonical patch reverse-check pass. Native132 unchanged. Deliberately restarted only diagnostic, retaining classic/ref/saves/accounts.

Current diagnostic windows-steam-disconnect-caller-trace produces3920 complete trace records/no incomplete groups. Browser0080 failed wait links to notification00c8 and the registered router. On that same router, thread00c8 executes caller49d672 with R8=2, entry49b210 with R8=2, then post-store49b4c2, before failure notification. Identity/order are checked, not inferred from unrelated endpoint events.

Function49d5e0..49d761 preserves routerRCX, contextRDX and remote linkR8, takes router mutex, compares/releases primary/decaying/inward links, unlocks, obtains link type and converts outward to2/inward to1 before49d672. It matches pinned Router::NotifyLinkDisconnected. Pinned link_type.h enum defines2 as kPeripheralOutward. This establishes the executed link-disconnection notification path for this browser channel, not the original reason for its link loss or a connection to earlier renderer129.

Whole-text relative call/tail scan for49d5e0 finds one candidate494a25 in494920..494cff. Full-function disassembly validates the instruction boundary. This enclosing routine swaps/clears a map under a mutex, iterates entries, calls49d5e0 with receiver+0x10 and router_link+0x8, then performs connection cleanup. Pinned node_link.cc HandleTransportError has the matching sublink-map swap, NotifyLinkDisconnected loop and DropConnection. This is static source correlation;494a25 has not yet been dynamically matched. No claim yet that transport OS failure, malformed message or peer exit initiated this path. Next trace494920/494a25 and49d5e0 entry, then follow actual HandleTransportError callers while matching node-link and router identities.

Retrieved pinned node_link.cc, local_router_link.cc and link_type.h with curl after Python urllib certificate verification failed; no certificate bypass. Raw files/disassembly/registers remain private under generated. Network-service instability and child initialization refusal remain. Host liveness is not Steam login. Full DE gameplay, physical iPad execution, sustained FPS, DE touch and supported retail multiplayer remain unproved; full goal remains active.

Primary sources: [Router](https://chromium.googlesource.com/chromium/src/+/refs/tags/126.0.6478.183/third_party/ipcz/src/ipcz/router.cc), [NodeLink](https://chromium.googlesource.com/chromium/src/+/refs/tags/126.0.6478.183/third_party/ipcz/src/ipcz/node_link.cc), [LinkType](https://chromium.googlesource.com/chromium/src/+/refs/tags/126.0.6478.183/third_party/ipcz/src/ipcz/link_type.h).

## Transport-error notification precedes matching channel closure — windows-140

Previous goal turn made progress locating the matching outward-link notification. Revalidated PID40664 live and sole designated Simulator booted; preserved previous observation. Validated two direct calls to transport handler494920:4948c3 in494880..494918 and496abe in496aa0..496ad6. First matches NodeLink::Deactivate (activation-state check/change, handler, transport deactivation, memory unlink). Second matches NodeLink::OnTransportError (construct transport-notification context1, invoke handler). Added these two sites plus494920,494a25,49d5e0. FEX/root/all16 banks build; parser and canonical patch reverse-check pass. Native132 retained.

Deliberately replaced only diagnostic with windows-steam-transport-entry-trace. Initial observation PID44454 live,81 complete records/no incomplete groups, no matching failure yet. Preserved run; captured native host sample and followed same live PID rather than restarting on timeout. Follow-up yields4385 complete records/no incomplete groups and the full matching browser0080 wait chain on notification thread00d4.

On00d4,496abe precedes494920 with the same node-link RCX; subsequent494a25 preserves that node-link inRDI and passes the registered watched router inRCX. Then49d672/49b210 pass link type2 and49b4c2 sets closed flags before matching notification. Identity and order are limited to the interval after successful trap registration and before notification. Thus this observed handler invocation comes from OnTransportError, not the Deactivate entry. It does not prove the initial physical/OS reason, exclude earlier lifecycle actions, or connect this browser endpoint to old renderer129.

Scanned upstream direct callers and verified instruction boundaries:48dc63 and3cf95f0 target494880;3d01000 targets496aa0. The last sits in3d00f40..3d0103f: retrieves a parcel fragment, checks addressability/adoption and takes failure branch to OnTransportError. It correlates with NodeLink::WaitForParcelFragmentToResolve callback, whose source reports out-of-bounds/invalid-header failure via OnTransportError. This caller has not been captured; do not assume invalid fragment is the cause. Indirect callers remain important.

A guessed node_transport.cc fetch returned404; directory listing identified driver_transport.cc. Retrieved pinned source successfully. DriverTransport::NotifyError retains its listener and invokes virtual OnTransportError; transport activity flagERROR invokes NotifyError. Therefore the next experiment must distinguish the direct fragment-failure caller from indirect driver transport notification. Trace3d01000 and its decision sites, identify the actual virtual dispatch/transport notification path, and match NodeLink identity. No suppressing errors or fabricated data.

Network-service instability remains; host liveness is not Steam acceptance. Classic/ref/saves/accounts untouched. Raw source, disassembly, traces and native sample stay generated/private. Actual DE, Steam login, physical iPad, sustained gameplay FPS, DE touch and retail multiplayer remain unproved. Goal active.

Primary sources: [NodeLink](https://chromium.googlesource.com/chromium/src/+/refs/tags/126.0.6478.183/third_party/ipcz/src/ipcz/node_link.cc), [DriverTransport](https://chromium.googlesource.com/chromium/src/+/refs/tags/126.0.6478.183/third_party/ipcz/src/ipcz/driver_transport.cc).

## Driver activity error invokes the matching NodeLink — windows-141

Previous turn made progress identifying transport-error entry. Revalidated PID44454 live and only designated Simulator booted. Preserved prior observation. Located DriverTransport::Activate-correlated48c330: callback argumentR8 is2d4fea0. That callback validates handlekind3, loads activity flags, prioritizes deactivatedbit2, then errorbit1. Error branch retains listener attransport+0x20 and invokes listener vtable+8 at2d4fff0. This matches pinned driver_transport.cc, including lifetime handling.

Added six signature-bound sites:2d4fed0(after flags load),2d4ffd1(error branch before listener load),2d4fff0(actual dispatch),3d01000(direct fragment-error caller),3d00fab(addressability check),3d00fc7(afterAdoptDataFragment). All lie at verified instruction boundaries inside PE function ranges2d4fea0..2d5002c and3d00f40..3d0103f. FEX/root/all16 banks build; parser tests and canonical patch reverse-check pass. Native132 unchanged. Deliberately restarted only diagnostic to windows-steam-driver-error-trace; classic/ref/saves/accounts untouched.

Initial capture PID48706 live had12 complete records and no matching wait. Retained same run, verified exact installed host path; follow-up1847 complete records/no incomplete groups captures matching chain. Browser0080 wait matches notification00c8, router and node-link. Thread00c8 executes2d4ffd1 withRAX1; same-stack-frame2d4fff0 hasRCX equal matching node-link. Actual dispatchRAX minus logged libcefbase equals496aa0, then496abe/494920 execute on that node-link. Subsequent494a25,49d672,49b210,49b4c2 and notification match watched router. Thus driver activityERROR invokes actual NodeLink::OnTransportError for this chain. Direct fragment caller3d01000 is not the observed invocation; its absence alone would not prove nonexecution, but the positively matched driver dispatch establishes this path.

Pinned ipcz.h definesERRORbit0 andDEACTIVATEDbit1. Pinned mojo/core/ipcz_driver/transport.cc Transport::OnChannelError invokes activity_handler withERROR; OnChannelMessage also routes a rejected callback result to OnChannelError(kReceivedMalformedData). Pinned channel_win.cc reports disconnection on failed I/O completion or zero-byte read, and malformed data when OnReadComplete rejects bytes. These source possibilities are not an identified runtime cause. Next map actual Transport::OnChannelError and Windows channel completion/error call, capture error category and Windows completion status/bytecount, matching driver transport identity from2d4ffd1. No forced flags, fabricated startup responses or authentication changes.

Current PID48706 live at observation is not successful Steam login. DE gameplay, physical iPad, sustained gameplay FPS, touch and retail multiplayer remain unproved. Goal active. Raw pointers/registers/disassembly and downloaded source remain generated/private.

Primary sources: [DriverTransport](https://chromium.googlesource.com/chromium/src/+/refs/tags/126.0.6478.183/third_party/ipcz/src/ipcz/driver_transport.cc), [Mojo transport](https://chromium.googlesource.com/chromium/src/+/refs/tags/126.0.6478.183/mojo/core/ipcz_driver/transport.cc), [Windows channel](https://chromium.googlesource.com/chromium/src/+/refs/tags/126.0.6478.183/mojo/core/channel_win.cc).

## Matching channel error is disconnected — windows-142

Previous goal turn made progress confirming actual driver activityERROR. Revalidated PID48706 live, sole designated Simulator booted, preserved observation. A byte-pattern scan for activity flags found488980..4889bd: loads ipcz transport atthis+0x80 and activity callback at+0x88, zeroes payload/handles/options, passesflag1. Adjacent4889c0 passesflag2 and releases self-reference, matching OnChannelDestroyed. This establishes strong static correlation of488980 with Transport::OnChannelError. No direct relative caller found. Absolute pointer referenceb361020 lies in a delegate vtable with neighboring message and destroyed methods; virtual invocation remains expected, not yet mapped to the originating Windows channel.

Added signature-bound488980 entry and4889b1 dispatch to capture incoming EDX category and bridge callbackRCX to ipcz transport. FEX/root/all16 banks build; parser tests and canonical patch reverse-check pass. Native132 retained. Restarted only diagnostic to windows-steam-channel-error-trace after preserving old logs; classic/ref/saves/accounts untouched.

Initial PID52710 live, Steam installation verified, no CEF records. Retained run and verified exact host path; one-second native sample saved privately. Follow-up captures2550 complete records and1 incomplete record. The incomplete group is a later browser0080 Router::Trap atline79437, after the complete matching failure chain around22846..23511; it is not used as evidence.

Thread00c8 executes488980 withEDX0, then4889b1 withRCX equal the DriverTransport at subsequent2d4ffd1. Entry/dispatch stack pointers differ by the known0x38 prologue allocation. Then errorflag1, listener dispatch and matching node-link/router closure lead to browser0080 failed wait. Pinned channel.h enum defines0=kDisconnected,1=kConnectionFailed,2=kReceivedMalformedData. Therefore this actual notification reports disconnected. It does not prove the peer genuinely exited or identify the underlying Windows status; a runtime I/O/lifetime defect could produce this report. Do not infer a malformed-fragment cause for this captured notification.

Pinned channel.cc Channel::OnError calls its delegate when present. channel_win.cc invokes disconnected for non-successful read/write I/O completion or zero-byte read, among other paths. Next locate ChannelWin::OnIOCompleted/OnReadDone and matching delegate dispatch, capture Windows error and bytecount, and correlate channel/handle to this transport while live. No simulated success, suppressed errors or guest-data changes.

PID52710 live at observation is not Steam acceptance. DE gameplay, Steam login, physical iPad, sustained FPS, DE touch and retail multiplayer remain unproved. Full goal active. Raw traces, addresses, disassembly and sample remain generated/private.

Primary sources: [Channel error enum](https://chromium.googlesource.com/chromium/src/+/refs/tags/126.0.6478.183/mojo/core/channel.h), [Channel error dispatch](https://chromium.googlesource.com/chromium/src/+/refs/tags/126.0.6478.183/mojo/core/channel.cc), [Windows channel](https://chromium.googlesource.com/chromium/src/+/refs/tags/126.0.6478.183/mojo/core/channel_win.cc), [Mojo transport](https://chromium.googlesource.com/chromium/src/+/refs/tags/126.0.6478.183/mojo/core/ipcz_driver/transport.cc).

## Successful zero-byte read completion causes matching disconnect — windows-143

Previous goal turn made progress identifying kDisconnected. Revalidated PID52710 live and sole designated Simulator booted; preserved old observation. Located channel_win.cc stringRVA b52f3fa and instruction references. Constructor-correlated489020 allocates ChannelWin, initializes Channel, sets IOHandler base at+0x58 and vtableb2eeed0. Its first entry3cf7300 is destructor adjustment(-0x58); second2d4ea40 is OnIOCompleted-correlated routine: accepts IOHandlerRCX, contextRDX, bytecountR8D,errorR9D, compares read_context atIOHandler+0x48 and write_context+0x78. Whole Channel base isIOHandler-0x58.

Read success branch2d4ebaa clears pending and testsEBPbytes; zero goes2d4edc9->482960. Nonzero error path2d4edb7 tests write-context then routes read errors to same report.482960 loads delegate atChannel+0x10, calls vtable+0x18 through482977, matching Channel::OnError. Added signature-bound2d4ea40,2d4edb7,2d4edc9,2d4ebaa,2d4ec11(ReadFile last-error check),482960,482977. FEX/root/all16 banks build; parser tests and canonical patch reverse-check pass. Native132 retained. Deliberately restarted only diagnostic to windows-steam-channel-io-trace; classic/ref/saves/accounts untouched.

PID56717 live at observation,624 complete records/no incomplete groups. Browser0080 failed wait links to notification00c8, registered router and transport. Matched488980 delegate via482977 RCX and same stack pointer;482960 entry supplies underlying Channel. Preceding2d4ea40 on00c8 hasRCX=Channel+0x58, contextRDX=IOHandler+0x48, R8D0 bytes,R9D0 error. Then2d4ebaa and2d4edc9 execute, followed by matching delegate kDisconnected, driverERROR, node-link/router closure and browser failed wait. Thus this is an observed successful zero-byte read completion, not merely a generic reported disconnection or a failed-I/O status. Windows API success itself has not yet been independently captured upstream; this establishes the values delivered to OnIOCompleted.

Pinned ChannelWin::OnReadDone treats zero bytes as disconnected. Pinned MessagePumpForIO::GetIOItem zeros IOItem, calls GetQueuedCompletionStatus, sets GetLastError and zero bytes on failed completion, then forwards item fields. Local Wine kernelbase/sync.c GetQueuedCompletionStatus uses NtRemoveIoCompletion, copies iosb.Information to count on STATUS_SUCCESS and maps negative iosb.Status. No repair chosen yet: need distinguish a zero-length request, actual peer end-of-stream, incorrectly generated IOCP packet, or lost count/status.

Located initial ReadMore-correlated3cf7310: before ReadFile at3cf7354, RCXhandle,RDXbuffer,R8Drequested bytes, stackoverlapped pointsChannel+0xa0; later read scheduling at2d4ec01 uses same layout. Next capture these actual read requests and returned status with matching context/Channel, and then the relevant completion producer if requests are nonzero. Do not assume the peer died or change zero-byte semantics. Runtime logs do not currently contain useful NtReadFile detail from the checked patterns.

Full DE gameplay, Steam login, physical iPad, sustained FPS, DE touch and supported retail multiplayer remain unproved. Goal active. Raw traces, disassembly and references remain generated/private.

Primary sources: [Windows channel](https://chromium.googlesource.com/chromium/src/+/refs/tags/126.0.6478.183/mojo/core/channel_win.cc), [Message pump](https://chromium.googlesource.com/chromium/src/+/refs/tags/126.0.6478.183/base/message_loop/message_pump_win.cc).

## Nonzero pending read precedes successful empty completion — windows-144

Previous goal turn made progress capturing zero-byte read completion. Revalidated PID56717 live and sole designated Simulator booted; preserved old observation. Added signature-bound initial ReadFile call3cf7354, return3cf735a, last-error3cf7364, subsequent call2d4ec01 and return2d4ec07; existing2d4ec11 captures last error. Sites are verified instruction boundaries in prior full disassembly. FEX/root/all16 banks build; parser tests and canonical patch reverse-check pass. Native132 retained. Restarted only diagnostic to windows-steam-read-request-trace; classic/ref/saves/accounts untouched.

PID60399 live,5791 complete records/no incomplete groups. Browser0080 failed wait links to notification00cc, matching transport, Channel and read IOContext. Six observed subsequent reads on that Channel each request4096 bytes. Most recent2d4ec01 before matching zero completion requests4096; same-stack return2d4ec07 EAX0 and2d4ec11 EAX997 establish false+ERROR_IO_PENDING. Next2d4ea40 onsameChannel/readcontext hasbytes0,error0, then zero-byte branch and matching disconnected/driverERROR/node-link/router chain. This rules out a zero-length request for the latest scheduled read. It does not prove the completion belongs to that exact operation rather than a stale/duplicate packet using the same reused OVERLAPPED; establishing producer identity remains necessary. Earlier pointer-matching read records are not treated as independent lifetime proof.

Read local Wine kernelbase/file.c ReadFile, kernelbase/sync.c GetQueuedCompletionStatus, ntdll/unix/file.c async_read_proc/server_read_file/irp_completion, ntdll/unix/sync.c NtRemoveIoCompletion, server/completion.c queue retrieval, server/async.c async_set_result and server/thread.c APC result handling. Current implementation provides several boundaries to inspect: requested bytes and IOSB through pending completion callback; async_set_result(status,total); completion queue packet; NtRemoveIoCompletion output; GetQueuedCompletionStatus output; Chromium IOItem delivery. Source alone does not identify loss or fault. async_read_proc normally turns zero bytes with no prior data into PIPE_BROKEN; this is not proof that path handled the actual named pipe. Server-backed IRP path differs.

Next instrument a bounded matching completion chain through queue production and consumption, preserving guest process/handle/context identity. Capture status and count at each boundary and distinguish stale/duplicate packet, peer closure, runtime bookkeeping or callback-result loss. Do not synthesize a count or suppress end-of-stream. Trace pointer data remains private under generated.

Full DE gameplay, Steam login, physical iPad, sustained gameplay FPS, touch and supported retail multiplayer remain unproved. Goal active. Native source inspection is diagnostic only; no semantic repair this turn.

Primary source: [Chromium Windows channel](https://chromium.googlesource.com/chromium/src/+/refs/tags/126.0.6478.183/mojo/core/channel_win.cc). Runtime source paths inspected are in worktrees/madeira/wine.

## Missing APC result produces STATUS_ALERTED completion — windows-145

Previous goal turn made progress establishing4096-byte pending request. Revalidated PID60399 live and sole designated Simulator; preserved old capture. Added opt-in WINE_IOS native logging gated by AGEPAD_STARTUP_TRACE=1: server thread APC destruction, async_set_result, completion queue add/immediate take/thread take, and both NtRemoveIoCompletion reply paths. Logs inspect existing status/count/context fields without changing guest results, allocation, callbacks or completion decisions. APC result union status/count logged only when result_type is APC_ASYNC_IO. Added stdlib include where needed. Canonical Wine patch regenerated/reverse-check passes.

Rebuilt Wine server archive from46 sources and ntdll-unix for Simulator; both pass. Copied rebuilt server archive, linked app successfully and confirmed four key diagnostic strings in executable. Current native145 includes earlier native132 class initialization repair; FEX/root/childbanks144 unchanged. Deliberately restarted only diagnostic to windows-steam-iocp-boundary-trace. Classic/ref/saves/accounts untouched.

PID61562 live,5622 complete FEX records/no incomplete groups. Matching browser0080 chain is onnotification00c4. Latest matched read requests4096, returnsfalse/E997, then I/O callback receives0bytes/error0 and disconnects. Native queue logs identify the same IOHandler key/read context. Earlier completions preserve72,56,80-byte results across queue and client. The failing chain is different: APC destruction atline23423 hasresult_type0(APC_NONE),call_status101, followed at23424 bysameowner async_set_result status101/info0, thenqueue_add23425,queue_take23445 andclient_take23446 allstatus101/info0. Same allocation packet matches enqueue/dequeue, key/context match throughclient, and asynccontext matches packetvalue. Raw pointer identity checks saved privately; earlier reuse of that owner address is not treated as same lifetime.

0x101 isSTATUS_ALERTED, an internal notification status here. Source async_terminate uses it when an IRP has output data to retrieve. thread_apc_destroy falls back to async_set_result(apc.call.async_io.status,0) if no APC_ASYNC_IO result exists. The observed fallback therefore propagates101/0 into the queue. GetQueuedCompletionStatus returns true for nonnegative IOSB status; Chromium consequently receives success/zero and reports end-of-stream. This is not evidence of a genuine peer EOF, and the queue/count copies are faithful in this captured chain. Data loss occurs before queue insertion via missing callback result, not during the inspected queue transport.

Why that APC lacks a result is unresolved. Inspected queue_apc, thread_queue_apc, thread_cancel_apc, clear_apc_queue and select previous-APC result handling. Possible paths include queue rejection, cancellation, clearing or missing return. Madeira mach_ios.c send_thread_signal extracts a Mach port and uses __pthread_kill; queue_apc rejects if required signaling fails. This is a concrete next diagnostic, not a proven cause. Next capture queue result, chosen target thread state, cancellation/dequeue/result-store and signal outcome for this specific APC owner/lifetime. Do not mask STATUS_ALERTED or manufacture data; repair callback delivery/lifetime once identified.

Full DE gameplay, Steam login, physical iPad execution, sustained FPS, touch and supported retail multiplayer remain unproved. Goal active. Raw execution logs and addresses remain generated/private.

Runtime sources: worktrees/madeira/wine/server/{thread,async,completion}.c, dlls/ntdll/unix/sync.c, dlls/kernelbase/sync.c, and worktrees/madeira/build/wineserver/mach_ios.c. Chromium reference: [Message pump](https://chromium.googlesource.com/chromium/src/+/refs/tags/126.0.6478.183/base/message_loop/message_pump_win.cc).

## Failed thread signal rejects the matching async callback — windows-146

Previous turn made progress tracing missing APC result to queuedSTATUS_ALERTED/zero. Revalidated PID61562 and sole designated Simulator; preserved old run. Added opt-in APC lifecycle logs for queue entry, signal result, queue return, cancellation, dequeue, result store, clear and destruction. Helper preserves errno and logs APC/owner identity and chosen thread state. Actual signal call remains once; its existing return branch is unchanged. Wine patch reverse-check passes. Rebuilt46-source server archive and app successfully; verified trace string linked. Native146 retains native145 completion logs and earlier132 repair; FEX144 unchanged.

Restarted only diagnostic to windows-steam-apc-lifecycle-trace; classic/ref/saves/accounts untouched. PID63184 live,5672 complete records/no incomplete groups. Matching browser0080 failure onnotification00c8 again includesSTATUS_ALERTED101/info0 entering and leaving completion queue. Immediately before matching async_result27336, same APC/owner lifetime has queue_enter27331 onthreadc8 state0, signal27332 detail0, queue_return27333 detail0, destroy27334 executed0/result_type0. No successful queue event occurs in that lifetime. Previous records at27145..27153 reuse the same allocations but describe a completed earlier callback; do not merge those lifetimes. Current record proves send_thread_signal returnedfalse and queue_apc rejected the matching callback, causing destructor fallback and downstream false end-of-stream.

Logged errno35 may be stale because send_thread_signal can returnfalse without calling a failing system API; do not call it the signal failure cause. mach_ios.c get_process_port returns process->trace_data, and send_thread_signal early-outs when that is absent. It may also fail during Mach port extraction or __pthread_kill. Next inspect/capture exact branch and process/thread registration, then implement scoped signal delivery repair with a meaningful queued-APC regression test. Do not globally change process-memory behavior or merely suppress the failed completion. No runtime semantic fix yet.

The user's status question was answered during this run: diagnostic progress is real, but Steam login, DE gameplay, FPS, physical iPad, touch and retail multiplayer remain unproved. Full goal active. Raw logs/identities stay generated/private.


## windows-147 — exact signal branch captured

Progress: missing process task port prevents SIGUSR1 attempt. Host Mach signal probe passes. Current browser error is PIPE_BROKEN, not146's false successful empty read; keep the chains distinct. Next scoped same-host signal fallback, host regression test and actual Steam APC integration. Full objective remains active and unfulfilled.


## windows-148 — scoped signal repair and new cleanup evidence

Progress: same-host task-port fallback built and tested, negative control fails as expected, real Steam signaled callbacks now return results. Integrated run ultimately terminates during helper cleanup after successful SIGQUIT. Preserve148 capture; next inspect explicit-TEB cleanup callback versus implicit TEB access and lock release bookkeeping. No DE/device/FPS/login/multiplayer gate claimed.


## windows-149 — explicit TEB cleanup and key lifetime

Progress: repaired implicit-x18 flag/CPU-area access in native-invoked FEX cleanup and native exit's post-key-clear lookup. Extracted callback/wrapper tests with negative controls pass; full runtime/root/16 banks rebuilt. Real Steam cleanup now records a shared hold release; PID69815 live at00:08:01 UTC with BrowserReady. Leave active; next observe helper termination and IPC outcome, not timeout-based restart. Full goal remains unfulfilled.

149 follow-up: host live at00:08:44 UTC, two real shared releases and no stuck-fault markers. Browser explicitly triggers shutdown after GPU helper restarts; child-bank refusal follows. Next diagnose mapped GPU helper exits. Do not label live UIKit shell as guest progress.


## windows-150 — connection-watchdog termination proved

Progress: three149 GPU exits map to EnsureConnected, not proven graphics failure. Pinned source defines15-second weak-cancelled watchdog. New signature-bound actual150 trace matches scheduled15000000us and watchdog owner for GPU and other helpers. GPU uses source-default legacy IPC; nonlegacy helpers also time out. Next inspect actual OnChannelConnected and legacy hello delivery, alongside Ping transport. PID73750 live00:15:55 UTC with child-bank refusal; no timeout-based restart, no disabled graphics or timeout overrides. Cleanup149 retained. Full DE/device/FPS/touch/multiplayer goal remains unfulfilled.


## windows-151 — direct connection callback trace

Progress: source traces legacy peer-PID handshake; binary factory reset/error callback locations validated and actual signature-bound traces built/root16 banks. FirstGPU owner reaches15-second watchdog with no matching connection/reset/error records. PID77652 live00:21:07 UTC. Absence of trace is not proof of nonexecution. Next inspect peer-PID send/receive and listener forwarding, retaining current live run. Native149 fixes retained; no Steam/game/device/FPS/multiplayer acceptance.


## windows-152 — peer-PID submission traced

Progress: mapped reader/proxy/receive/listener paths and built actual trace. Browser submits hello successfully then reader getsFAILED_PRECONDITION; no peer-PID receipt recorded. FirstGPU reaches watchdog without recorded reader initialization. PID81917 live00:27:37 UTC after verified wait. Next ChannelMojo Connect sequence/task dispatch and FinishConnect callers14fb347/14fb457; distinguish no initialization from later transport loss. Native149 retained. Full goal active, no login/game/device/FPS/multiplayer acceptance.


## windows-153 — Connect path qualified

Progress: actual Connect traces show inline reader initialization(AL1 sequence check), not posted FinishConnect tasks. Server thread ownership maps no recorded Connect to firstGPUe8 before watchdog, while browser and later children connect. PID85636 live00:31:53 UTC after verified wait; private-bank refusal. Next higher-level ChannelProxy Init/Open and child IO work, retaining current run. No scheduler workaround or timeout change; full goal remains unfulfilled.


## windows-154 — successful channel-open post, missing first dispatch

Progress: firstGPU Init/create-now and successful post traced; no matching context dispatch before watchdog. Later helpers produce positive matched dispatches intoRVA1c71440. PID89445 live00:36:48 UTC after verified wait. Next queue/runner/thread association and direct callback, distinguishing unexecuted work from alternate path. Native149 retained. Full DE/device/FPS/touch/Steam login/multiplayer remain unproved.


## windows-155 — real runner target and direct open

Progress: actual channel-open posts enterRVA3627fb0 and returntrue for firstGPU and later helpers. Direct sync/base callback records present for later helpers and absent for firstGPU; retained source/identity caveats. PID93256 live00:42:45 UTC after verified wait. Next inspect target's task queue/handoff/runner association. Native149 retained; no gameplay/login/device/FPS/multiplayer acceptance.


## windows-156 — incoming queue insertion and initial wakeup observed

Progress: actual firstGPU channel-open task inserts2->3 behind older work. Earlier same-queue first post0->1 requests ScheduleWork, so no evidence for simply forcing wake on this later post. Incoming count later drops; not callback execution proof. PID97016 live00:48:03 UTC. Next reload/execution and IO-thread state after wakeup, older pending tasks and controller dispatch. Native149 retained; full game/device/FPS/touch/multiplayer goal unfulfilled.

## Actual wakeup controller identified — windows-157

Previous status turn yielded no new functional progress; revalidated existing live run before continuing. Pinned queue source confirms TakeImmediateIncomingQueueTasks swaps incoming and work deques under lock, so an incoming count drop does not establish callback execution. Added signature-bound register-only trace at ScheduleWork virtual dispatch RVA3506b82. FEX canonical patch reverse-check and FEX/root/all16 private-bank builds pass; native149 unchanged. Checked sole designated Simulator and replaced diagnostic only with windows-steam-controller-target-trace. Classic candidate/ref/saves preserved.

Actual capture00:55:24 UTC: host1735 live. FirstGPU mainEC channel-open post34641 has queue insertion old2/new3 at34738/34764. Same queue's earlier ScheduleWork31679 nests into dispatch31692 on same thread with stack-8; captured actual target is RVA362e6b0, normalized using that guest's module base. This replaces guesswork about the controller implementation. Raw identities, disassembly and captures remain generated/private.

Full target362e6b0..362e753 correlates with ThreadControllerWithMessagePumpImpl::ScheduleWork: invoke WorkDeduplicator::OnWorkRequested at37caa20 using controller+1b0; if returned enum is nonzero, return without pump call. Otherwise record wakeup attribution then dispatch pump at362e6fb (pump member+230, virtual slot18). Leaf37caa20..37caa46 performs atomic OR2 via cmpxchg and returns zero only when previous state equals4. This matches pinned source's pending-bit/idle decision. Function3632350 found through ScheduleWork string is the attribution helper, not the actual controller wakeup implementation.

Next trace362e6d3 return decision,37caa3b previous flags after successful atomic operation, and362e6fb actual pump target; correlate to this queue/controller before inferring a suppressed wakeup or transport failure. No deduplication bypass or scheduling repair applied. Existing trace proves controller dispatch, not pump execution or task execution. Full DE/Steam login/device/touch/gameplay FPS/retail multiplayer remains unfulfilled; goal active.

Sources: [controller](https://chromium.googlesource.com/chromium/src/+/refs/tags/126.0.6478.183/base/task/sequence_manager/thread_controller_with_message_pump_impl.cc), [work deduplicator](https://chromium.googlesource.com/chromium/src/+/refs/tags/126.0.6478.183/base/task/sequence_manager/work_deduplicator.cc).


## Initial wakeup is deferred while controller is unbound — windows-158

Previous turn made progress identifying actual ScheduleWork controller. Revalidated157 host1735 live00:57:04 UTC. Added signature-bound register-only sites362e6d3 dedup result,37caa3b old flags after successful atomic OR,362e6fb pump target,362e701 return boundary. Controller sites validated in.pdata362e6b0..362e753; deduplicator leaf decoded completely37caa20..37caa46. Matcher bounds by same thread, controller identity, actual stack footprint48 and nested leaf stack-8; no global adjacent-event assumption. FEX canonical reverse-check and FEX/root/all16 bank builds pass. Native149 retained. Sole designated Simulator checked; diagnostic-only restart windows-steam-pump-decision-trace. No scheduling behavior changes.

Actual capture00:59:14 UTC host5508 live. FirstGPU mainEC connection post35730 enters queue with old2/new3 at35821/35847. Same queue earlier ScheduleWork33083 enters controller33096; old flags0 at33109 and result1 at33122 suppress pump dispatch. Only one recorded ScheduleWork for this controller in capture. This is unbound state, not a demonstrated already-running task or lost OS wakeup. Other controllers transition from unbound to idle4 and call actual pump target3637bc0, providing positive trace comparison. Those calls do not establish the affected controller's pump behavior.

Pinned WorkDeduplicator flags: in-work1, pending2, bound4. OnWorkRequested marks pending while unbound; BindToCurrentThread sets bound and returns schedule-immediate when pending was already set. Thus inspect binding rather than force a wakeup before initialization. Located leaf37caa00..37caa17 implementing atomic OR4/test2, with direct callers190bcd8 and74eddad. Full190bbe0..190bd6b matches ThreadControllerWithMessagePumpImpl::BindToCurrentThread: associated-thread binding, pump install+230, thread-local/run-loop/default-runner setup, then deduplicator call190bcd8, decision190bcdd and pump dispatch190bcef. Next trace those stages with controller identity and37caa0d old flags to determine whether this controller binds, stalls in setup, or dispatches its pending wakeup. No absence-of-binding claim yet: those sites are not instrumented in158.

Raw evidence and private identities remain generated/steam-158-*. Source: [binding and wakeup](https://chromium.googlesource.com/chromium/src/+/refs/tags/126.0.6478.183/base/task/sequence_manager/thread_controller_with_message_pump_impl.cc), [state definitions](https://chromium.googlesource.com/chromium/src/+/refs/tags/126.0.6478.183/base/task/sequence_manager/work_deduplicator.h). Diagnostics affect timing; no gameplay FPS claim. DE/Steam login/device/touch/retail multiplayer remains unfulfilled; goal active.


## Binding and initial I/O wakeup delivery confirmed — windows-159

Previous turn made progress observing initial unbound scheduling. Revalidated158 host5508 live01:01:17 UTC. Added signature-bound register-only binding stages190bbe0,190bbf8,190bcd8,37caa0d,190bcdd,190bcef,190bcf5. Controller sites validated in.pdata190bbe0..190bd6b; deduplicator is complete decoded leaf37caa00..37caa17. Matcher uses same controller/thread and entry-to-body stack48, nested leaf additional8; observes old flags and actual target without modifying them. FEX reverse-check and FEX/root/all16 bank builds pass; native149 retained. Sole designated Simulator checked; only diagnostic restarted windows-steam-controller-bind-trace.

Actual capture01:03:10 UTC host9230 live. FirstGPU mainEC channel-open post36300 inserts old2/new3 at36352/36380. Its queue maps through earlier ScheduleWork to controller that binds on thread128 at34881. Server ownership confirms128 belongs to same firstGPU processe8 as mainEC. Binding passes associated-thread stage34894, reaches dedup34907, sees old flags2 at34920, returns schedule-immediate0 at34933, dispatches pump34946 and returns34960. Thus startup binding and deferred wakeup pickup actually happen, not just inferred source behavior.

Pump target normalizes to34fdbb0 using same-process EC libcef base (128 has no separate base record). Binary34fdbb0..34fdc54 matches MessagePumpForIO::ScheduleWork: atomic scheduled flag, completion-port post with key and context both this, zero bytes. Existing native diagnostics already prove its packet queue_add34959, matching queue_take35378 and client_take35379 with same port/key/context/status0/info0. No extra trace is needed merely to prove initial packet delivery. This does not prove all subsequent pump iterations or callbacks.

First IO thread128 then processes actual channel completions at36030,36059,37467,37570, with byte counts72,2320,56,80 and error0; handler/context are distinct from pump. It is not simply a thread that never starts. Connection task is posted amid those events. Next inspect pump Run/DoWork and selected application-task execution after initial wakeup, including task-execution permission/nesting and incoming-to-work reload. Do not change deduplicator or claim missing OS wakeup on this evidence. Raw trace, matched private identities and disassembly are generated/steam-159-*.

Source: [Windows IO message pump](https://chromium.googlesource.com/chromium/src/+/refs/tags/126.0.6478.183/base/message_loop/message_pump_win.cc). Full DE/Steam login/device/touch/gameplay FPS/retail multiplayer remains unfulfilled; goal active. Diagnostics affect timing; no performance claim.


## Affected controller executes five earlier tasks — windows-160

Previous turn made progress proving binding and initial IO wakeup delivery. Revalidated159 host9230 live01:05:19 UTC. Located inlined DoWork/DoWorkImpl362eba0..362f6e0 and TaskAnnotator RunTask350a700..350a8c9. Added signature-bound register-only sites362eba0 entry,362ec85 permission-pass branch,362f4d8 disallowed branch,362edec/362edf1 task selection call/return,362f05e/362f063 task execution call/return,350a827 OnceClosure dispatch. All sites decoded and validated within.pdata. DoWork receives delegate subobject controller+f0, corroborated by deduplicator offsetc0 versus full controller1b0. Task runner nested stack deltaa0 from3 pushes+80 locals+return. Matcher binds actual controller/thread/task and same-stack return; callback target normalized by same-process module base.

FEX reverse-check and FEX/root/all16 banks pass; native149 unchanged. Booted inventory unexpectedly became empty after build; runner correctly refused before staging. Booted only designated574671AD-6F61-4558-9528-BF946DDB760A, bootstatus completed, then diagnostic-only launch windows-steam-application-task-trace. No additional device or classic/ref/save changes. No assumption about why Simulator stopped.

Actual host13350 live01:08:23 and01:09:23 UTC. FirstGPU mainEC connection post54323 maps to controller bound onIO188 (not prior run128). Five DoWork entries52417,52756,54615,56191,56336 all pass application-task permission and complete SelectNextTask. Five task calls52469,52808,54680,56243,56405 all return, callback targets respectivelye982d0,3732d0,488a90,35581c0,3732d0. Zero disallowed-branch records for this controller. None of their captured callback states matches connection post state54336. Thus this controller actually executes older application tasks; it is not globally forbidden from execution and none of these five callbacks is demonstrated stuck.

The fifth callback state matches an earlier post at51759 before connection initialization. Generic thunk3732d0..3732e9 loads receiver adjustment and target from binding state then tail-dispatches at3732e6; its actual target is not yet traced. Next inspect this fifth task's target and pump DoRunLoop progression/quit state after its return, alongside queue reload/remaining work. Do not assume the fifth task quits, or infer missing connection execution solely from absent direct trace. Pinned pump source checks should_quit after DoWork and each IO/idle stage. Initial IO wakeup and earlier task execution do not prove later continuation. Raw evidence/private identities undergenerated/steam-160-*.

Full DE/Steam login/device/touch/gameplay FPS/retail multiplayer remains unfulfilled; goal active. Instrumentation affects timing and cannot support performance claims. Source: [controller execution](https://chromium.googlesource.com/chromium/src/+/refs/tags/126.0.6478.183/base/task/sequence_manager/thread_controller_with_message_pump_impl.cc), [IO pump loop](https://chromium.googlesource.com/chromium/src/+/refs/tags/126.0.6478.183/base/message_loop/message_pump_win.cc).


## Connection task executes; later signal/lock deadlock lead — windows-161

Previous turn made progress proving five earlier callbacks returned. Revalidated160 host13350 live01:10:49 UTC. Added register-only signature-bound3732e6 generic callback target,34fddba DoWork dispatch,34fddc4 post-work quit test,34fddce nonquit continuation,34fe0e7 loop exit,34fdd98 blocking wait call,34fde1f completion poll result. Pump sites decoded within34fdc60..34fe12f; generic thunk complete leaf3732d0..3732e9. Canonical FEX reverse-check and FEX/root/all16 bank builds pass, native149 unchanged. Sole designated Simulator checked; diagnostic-only replacement windows-steam-pump-continuation-trace, ref/classic/saves preserved.

Actual host17217 live01:13:31 and01:14:30 UTC, with20-second verified wait. Affected controller binds onIO188. Fifth callback tail-dispatches14f9580 and returns; loop continues rather than quitting. In this run ninth task has the actual connection callback state, invokes3732d0 then2f9210 at62225, reaches2f921e62268, SyncOpen62294, baseOpen62424, Connect62463, reader initialization62661 and endpoint Accept return62703. This is real forward execution evidence, not a runtime fix: only diagnostic instrumentation changed, which can alter timing/code layout. Prior absence remains a variable-run observation; do not generalize that connection task can never execute.

Thirteen tasks captured; first12 return. Thirteenth dispatch355d740 at63929 has no matched return through followup. No peer-PID receive/direct connected/watchdog record for first helper in capture. Pump nonquit continuation is observed through12th task. Do not call13th callback intrinsically faulty based only on missing return.

Existing native diagnostics change next action: immediately after last task enters, APC queue_enter63956 targets thread188, successfulSIGUSR1 at63957, queue succeeds; no matching dequeue in this segment. Later FEX STUCK read-wait diagnostics identify thread0188 as owner of write-held mutex, multiple other threads waiting. Read-only sample17217 (1 second, no debugger attached) shows Chrome_ChildIOThread in usr1_handler -> wait_suspend -> server_select -> wait_select_reply -> read. This is a concrete signal-suspension/write-lock interaction lead, not simply the fifth task stopping the pump. Thread sample's OS identifier is not the Mach port name in signal log; correlate via guest ownership/bank/name before claiming precise native identity.

Native signal_arm64_ios.c usr1_handler directly calls wait_suspend after saving context; thread_ios.c wait_suspend calls server_select with context and zero timeout. No safe-lock deferral is visible in that handler. Next investigate how FEX write-held sections and Wine context/APC suspension interact, including server context handling and signal-safe deferral/resumption; do not blindly unlock compiler state from a signal handler or disable APC delivery. Preserve live run17217 for inspection. Raw evidence/sample/disassembly undergenerated/steam-161-*.

Full DE/Steam login/device/touch/gameplay FPS/retail multiplayer remains unfulfilled, goal active. No performance or stable-handshake claim. Sources remain pinned controller and IO pump linked above.


## Live server snapshot identifies rejected suspend-select — windows-162

Previous turn made progress executing channel-open task and identifying signal/write-lock wait. Revalidated161 live host17217; preserved exact run and did not rebuild/restart. Read native usr1_handler/wait_suspend/server_select and server select/context/APC handling. Stock check_wait prioritizes pending system APCs ahead of suspension. A write lock alone therefore does not explain why native wait_select_reply remains blocked.

Read-only LLDB inspection selected Chrome_ChildIOThread by name, after discovering thread indices changed between attachments. Confirmed native stack usr1_handler -> wait_suspend -> server_select -> wait_select_reply -> read. No target function calls or target memory edits; all sessions explicitly detached. Earlier index82 sample selected a worker and was discarded as IO evidence.

Generated exact server struct offsets using clang -fdump-record-layouts with the actual archive manifest's compile flags and source (syntax-only, exit0, no rebuild). Read live thread_list through symbol address and bounded list traversal using those offsets. Matched guest188, TEB and unix_tid161575 to signal/lock records. Snapshot and repeated confirmation: suspend0, physicalMachhold0, runningstate0, system APC queue nonempty, context nonnull with statusSUCCESS0, suspend_cookie still5555555555555555, no registered wait. Last request29 resolves from generated protocol enum toREQ_select; last errorc000000d STATUS_INVALID_PARAMETER. This is direct server state, not inference from missing logs. Private addresses/layout output/LLDB scripts remain generated/steam-162-*.

Source conflict: iOS stop_thread uses older synchronous ios_fill_thread_context instead of sendingSIGUSR1, sets context statusSUCCESS and leaves thread->context. Server select receiving native context rejects existingcontext unless statusPENDING (goto invalid_param). Native server_select sees signaledfalse and goes to wait_select_reply even on that rejection, so no wait is registered to wake, pending APC never dequeues, and interrupted FEX owner retains write lock. This explains captured shape more precisely than assuming generic lock-unsafe signal delivery. It still needs a targeted regression and repaired run to prove causality/end-to-end effect.

Next repair the coexistence of completed Mach snapshots and actual signal-based context publication while preserving Get/SetThreadContext semantics and logical/physical suspension accounting. Audit context flags/modifications before replacing anything; do not blindly drop a completed context or force-release FEX locks. Test realistic completed-snapshot -> signal-select transition and pending-context modification retention, with negative control reproducing rejection. Consider defensive native error handling separately; it must not swallow APCs or restore uninitialized context. Current live run available17217, no debugger attached. No runtime patch this turn.

Full DE/Steam login/device/touch/gameplay FPS/retail multiplayer remains unfulfilled; goal active. This turn identifies a concrete repair target, not successful gameplay.


## Snapshot-to-signal repair enables helper handshake — windows-163

Previous turn identified live serverREQ_select rejection with completed Mach snapshot. Revalidated existing161 before edits. Audited Get/SetThreadContext: snapshot register flags include captured data, whereas pending-context flags preserve explicit edits. Blindly allowing the completed snapshot would restore stale PCs/registers.

Implemented iOS-only context provenance and per-native/WOW modified-group masks in private server context struct (thread ABI unchanged). create_thread_context initializes metadata; successful Mach capture marks snapshot. SetThreadContext records only groups actually copied into a snapshot. On incoming signal context, ios_context_begin_signal converts markedSUCCESS snapshot toPENDING and retains only explicitly modified flags; normal pending-context merge then fills fresh register groups and applies existing WOW precedence. Unmarked completed/error contexts still reject, and ordinary pending modifications retain existing semantics. No FEX lock release, APC suppression, timeout extension or native wait-error swallowing. Updated obsolete stop_thread comment to reflect functioningSIGUSR1 alongside retained Mach context capture.

New tests/test-snapshot-signal-context.py extracts actual helper and select merge block, compiles ASan/UBSan harness with simplified flag-addressed register groups. Covers completed snapshot publication, stale-group replacement, native edits, WOW precedence, ordinary pending edits and rejection of unmarked/error contexts. Negative controls removing transition or retaining stale flags fail. Harness does not prove architecture register unions/full context APIs; those remain runtime scope. Test passes. All-source simulator wineserver archive build passes; canonical wine.patch reverse-check passes; app build passes. FEX/root/all16 child banks remain161; native runtime now163(server change only from149). Source comment-only edit after build does not change compiled semantics.

Sole designated Simulator checked; diagnostic-only replacement windows-steam-snapshot-context-repair. Actual host19371 live01:28:02 and01:29:26 UTC. FirstGPU mainEC, IO178: peer-PID receipt59680 and direct OnChannelConnected61039; further helper connected callbacks observed, zero watchdog sites in initial trace. Affected IO controller executes47 tasks, final captured tasks return. Native APC lifecycle matching bounded by each queue_enter generation:148 matched IO178 dequeues,137 with queued status101; zero FEX STUCK reports in initial52MB capture. This is meaningful real-runtime improvement consistent with repair, beyond unit tests. Do not equate handshake with login or game acceptance.

Actual Simulator screenshot generated/steam-163-simulator.png inspected: Madeira shell with black rendering area, Present0/FPS0, no Steam login UI. Followup no child-bank refusal. CEF now reports network errors10014 mappedERR_FAILED; next isolate failing Winsock operation/buffer contract and remaining renderer readiness. Preserve live run; do not restart merely because capture elapsed. Raw trace growing rapidly due broad diagnostics; reduce overhead only with a deliberate validated change. Full DE/device/touch/gameplay FPS/retail multiplayer remains unfulfilled; goal active.


## Network failures localized to WSASendTo/WSARecvFrom — windows-164

Previous turn repaired snapshot/signal transition and observed real helper handshake. Revalidated163 host19371 live01:30:33 UTC; no child-bank refusal. Network helper logs repeated10014 with nearbySO_RANDOMIZE_PORT notices, but proximity alone does not identify failing API. Read pinned Chromium net_errors_win.cc/udp_socket_win.cc. Randomize-port failures are deliberately ignored; do not change that option to mask send/receive errors.

Located MapSystemError-correlated14a2850..14a2b40 via exact Unknown error string; found54 directE8 callers. Validated every caller as a decoded call instruction within its.pdata function to actualtarget14a2850. Added signature-bound register-only trace at54 sites to recordECX Windows error and actual call-site, no socket code changes. FEX reverse-check and FEX/root/all16 bank builds pass; native163 retained. Sole designated Simulator checked; diagnostic-only replacement windows-steam-network-error-trace. Classic/ref/saves preserved.

Actual host23623 live01:36:36 UTC. Initial capture error10014 at19603c8 onthread1f8 occurs36 times, and195ff9f onC8 occurs twice. Disassembled full callers1960210..1960568 and195fd10..19600a0. First error branch follows import call196030b, nonzero return, WSAGetLastError and rejection of997(PENDING); second follows195fddf and analogous non-pending error. Parsed PE import table: IATc8c82c8=WSASendTo, c8c82b0=WSARecvFrom, c8c8280=WS2_32 ordinal111(WSAGetLastError). Thus actual failures are async datagram send/receive, not merely a guessed connect/bind or DNS failure. Pinned UDPSocketWin send path passes a singleWSABUF, bytes result, optional destination and core write-overlapped; receive analogous.

Next capture/inspect compatibility WS2_sendto and WS2_recv_base arguments, validation and AFD/Unix status conversion. Need distinguish invalid user buffer/length from structure/ABI or overlapped handling mismatch; do not assume the exact cause from10014 alone. Existing deployedWS2_32 is app arm64ec-windows module, outside signed-root dependency list; no DLL replacement or Winsock patch applied. Prepared build plan only, no module build. Raw binary/source findings and captures undergenerated/steam-164-*.

Source: [UDP socket implementation](https://chromium.googlesource.com/chromium/src/+/refs/tags/126.0.6478.183/net/socket/udp_socket_win.cc), [Windows error mapping](https://chromium.googlesource.com/chromium/src/+/refs/tags/126.0.6478.183/net/base/net_errors_win.cc). Full DE/login/device/touch/gameplay FPS/retail multiplayer remains unfulfilled; goal active. Trace overhead is not performance evidence.



## windows-166: remove observed false IOSB address rejection

Read actual bundled WS2_32 call layouts and found prior ntdll guard rejecting mapped high status buffers before native socket dispatch. Focused extracted-wrapper regression and old-ceiling negative control pass; ARM64EC ntdll/root/16 banks built. Retain null/alignment guard. Native165/FEX164 retained. Actual Steam retry windows-steam-iosb-ceiling-repair underway; validate network and rendering, then continue full DE/device/multiplayer objective. See status166 and private generated evidence. Prior status-only turn no progress; this turn changes runtime and adds concrete rejection evidence.


## windows-167: renderer protected-write fault localized

Previous166 progress confirmed; live29370 inspected, no restart. Renderer thread284/process268 aborts after unaligned scalar-store emulator copies into RX target page. Native PC/caller resolved read-only and debugger detached. Readability-only fault classification misses write protection; FEX has separate AV/RWX invalidation route needing correct dispatch. Next implement/test full-span write-permission classification preserving actual fault semantics, then retry real Steam. No broader success claim; see status167/private capture.


## windows-168: protected stores route to AV

Native whole-span writable-region check added to scalar/paired alignment emulator; protected writes return AV without copying or advancing PC. Actual Mach mmap tests with extracted code and negative control pass; native/app builds and canonical patch reverse-check pass. Diagnostic retry windows-steam-protected-store-repair in sole Simulator, PE166/FEX164 retained. Next validate actual renderer and FEX protection path. Full objective active.


## windows-169: server getenv dependency cycle

Previous168 progress; live30846 preserved. Two native samples identify server post-signal trace getenv waiting on environment lock while interrupted Chrome_IOThread is inside getenv and awaiting server reply in SIGUSR1 handler. Renderer waits behind server. Next cache server trace configuration at main_ios startup across mach/APC/completion paths; audit guest JIT getenv outside uninterrupted section. No168 branch hit yet, no login/game acceptance. See status169.


## windows-170: trace snapshot removes observed server getenv cycle

Snapshot server trace option in main_ios startup; APC/async/completion/signal diagnostics read value without getenv. Parsing/wiring regression and actual Mach signal tests pass. Server/app builds and canonical patches pass. Diagnostic retry windows-steam-server-trace-snapshot, native168/PE166/FEX164 retained. Next validate real renderer progression and protected-store route; continue full objective.

Actual170 exposes next shared-lock dependency: server fprintf waits on FILE lock held by signal-interrupted client waiting for server. Remove shared stdio from callback diagnostics before claiming deadlock resolved. Live32269 preserved, sample saved.


## windows-171: isolate server FILE lock

Server stderr now uses its own FILE over duplicated log fd initialized before request loop. Actual initializer/native pthread test succeeds while guest holds original stderr; shared-stream negative control hangs as expected. Server/app build, trace regression and patch checks pass. Real Steam retry windows-steam-server-private-log, native168/PE166/FEX164 retained. Next qualify renderer/server progress. Full objective active.


## windows-172: distinguish native stack from emulator overflow

Actual GPU exitsC00000FD after heuristic labels misaligned load inside adjacent native pthread stack as emulator overflow. NativeSP at emulator top; initial native stack bounds and later RW memory inspection establish concrete false-classification lead. Next qualify guard classification preserving FEX alignment path. Later512MiB JIT exhaustion also observed; do not conflate with earlier GPU failure. Current33123 preserved. Full acceptance absent.


## windows-173: guard classification requires inaccessible mapping

Native overflow heuristic now excludes accessible adjacent regions; only nearby hole/no-access qualifies, query failure preserves prior exception. Actual Mach tests and negative control pass; protected-store tests/build/patch checks pass. Retry windows-steam-stack-guard-classification with512MiB unchanged, server171/PE166/FEX164. Next qualify GPU and pool behavior. Full goal active.


## windows-174: restore intended TEB compilation

Profile identifies hot legacy x18 checker.166 rebuilt signal_arm64ec without canonical AGEPAD_SIGNED_WINE_TSD flag. Restored explicit flag; actual disassembly verifies dynamic direct TEB path. Packaging now rejects missing compiled path. Root passes, banks rebuilding; next actual Steam/profile. Native173/server171/FEX164 retained.


## windows-175: guard JIT environment read, snapshot async diagnostic gate

Actual sample exposes async_destroy getenv wait and signal-interrupted JIT getenv -> APC virtual_mutex wait. Snapshot server SIGNED_NTDLL presence for async diagnostics; move JIT gate within existing uninterrupted section, preserve rejection/result semantics. Focused tests/native/server/app builds/patch checks pass. Retry windows-steam-jit-env-guard PE174/FEX164 retained. Full acceptance pending.


## windows-176: real protected-store SMC path, larger diagnostic pool

Actual175 reaches AV/SMC handling for three protected renderer stores, no prior nested memcpy fault in capture; later512MiB pool exhausts. Server requests continue. Add1GiB Simulator diagnostic capacity retaining bounds/quarantine; native/app build/patch and invalid-capacity checks pass. Retry windows-steam-jit1024; next verify old boundary crossed and rendering. Full goal active.


## windows-177: observed vector-store decode

Actual renderer25c exits after unsupported STR Q1 (3d800001), replacement renderer starts. Add unsigned/unscaled128-bit store decode before earlySIMD rejection, full-span permission check, no writeback; remove unreachable legacy branch. Extracted Mach tests and SIMD/scalar negative controls pass; native/app/patch checks pass. Retry windows-steam-vector-store-repair1GiB, server175/PE174/FEX164 retained. Next qualify actual rendering.


## windows-179: verify mapping before alias repair

Read-only live inspection finds fault mapping RX but registered anonymous alias table empty. Correct prior assumed alias diagnosis; next measure actual NtProtectVirtualMemory result/requested protection at SMC boundary and distinguish normal retry from alias recovery. Actual Steam creates/unhides a Sign in to window object, but screenshot remains black Present0.1GiB pool exhausts; do not increase blindly. No restart/runtime edit this turn. Goal active; full acceptance absent.


## windows-180: measure SMC unprotect outcome

Add bounded startup-trace FEX diagnostic capturing actual NtProtectVirtualMemory result/request/old protection/span before recovery. No behavioral fix claimed. FEX/container/16banks/patch checks pass. Diagnostic retry retains native177/server175/PE174 and1GiB; next inspect actual renderer protection results. Goal active.

Actual180: seven renderer unprotect calls returnSTATUS_SUCCESS (RX->RWX logical,4KiB span), differing write targets, scalar recovery follows. No syscall failure proven. Next inspect native/write-watch/reprotection semantics and subsequent renderer/vector lifecycle. Host45790 retained, pool587448320/1GiB without current exhaustion.


## windows-181: isolate startup trace overhead

Traced180 reaches login-window object then1GiB exhaustion; no proof repeated protected accesses are terminal. Wine source permits logicalRWX with native watch protection. Retry same builds/config except startup-trace disabled; actual46274 reachesBrowserReady with520339456-byte extent, screenshotblack. Keep run for comparable lifecycle/exhaustion observation. RefstillMacDE/WindowsHD, WindowsDE executable absent. Full goal active.


## windows-182: quantify quarantine pressure

Actual untraced run has671203328 bytes released/quarantined versus386039808 without release markers, near1GiB extent. Observer now reports release accounting with scope limits; actual data verified. Native monotonic quarantine does not reuse releases. Next audit FEX code-buffer/reference/signal lifecycle before safe reuse; do not disable quarantine wholesale. CEF also reports GPU AV, capture requires helper correlation. Current46274 retained; full objective incomplete.


## windows-183: bounded JIT reuse experiment

Audited FEX destructor/shared-buffer/retained-signal/rollover contracts. Native opt-in reuses exact full-released size within same owner, zeroes and cache-flushes before return under write scope/metadata lock; partial releases remain quarantined, default unchanged. Helper ASan/UBSan tests and owner-negative control pass; native/app/patch checks pass. Observer handles reuse lifecycle. Retry windows-steam-jit-chunk-reuse1GiB, trace off, native183/server175/PE174/FEX180. Actual lifetime and rendering qualification pending.


## windows-184: graphics output becomes next gate

Actual reuse20events/640MiB cumulative, extent570687488, no observed exhaustion. Steam issues700x440 Metal draws/present and FRAME_STATS4608; screenshotblack. Simulator present fallback bypasses overlaycounter, soPresent0isnotno-callproof. Native sampleGPU/rendereractive. Next command completion and actual texture pixel readback to locate black-output cause. Current48195 retained; full goal active.


## windows-185: inspect actual drawable pixels

Native DXMT opt-in samples4presentations with ordered shared-buffer blit, asynchronous completion status, nonblackRGB count and private PPM export. Simulator-only; diagnostic disables framebufferOnly before drawable acquisition. Builds/archive-member update/patch checks pass. Retry windows-steam-present-readback retains ntdll183/server175/PE174/FEX180, reuse/1GiB, no broadtrace. Next inspect actual GPU completion/images. Full goal active.


## windows-186: resolve startup lock ordering

Actual01f4 owns FEX invalidation lock while waiting heap owned015c;015c waits FEX lock. This blocks before first readback. Read-only state/syscall frame capture detached; no restart. Unknown sampled address chain proved RWdata/unwind artifact, not executing code. Next identify heap/invalidation acquisition paths and valid ordering repair. Current49564 retained; full goal active.


## windows-187: image-tracker allocator ordering repair

Captured ownerstack+actualsymbols identify default std::map allocation within HandleImageMap's FEX lock. Change image/AOT maps to fextl::map/FEXallocator, preserve locking/invalidation. Actualtype/header allocation test plus old-std-map negative control pass underASan/UBSan. FEX/rootcontainer/patch checks pass,banks packaging. Next realSteam retry with readback/reuse unchanged. Full objective active.

Actual187 retry54396 reaches loginBrowserReady; drawable readbacks1/64/512 complete.512histogram18white pixels/307982black, inspectedPNGshowsverticalcaret. Real near-black pixels localize next step upstream of present: textured/composited drawing. Preserve currentrun, nofullgameclaim.

## Texture sampling fails with verified uploaded data — windows-188

The preceding user-facing status turn only revalidated state and restated status (no implementation progress); current authoritative logs confirm Steam GPU process C0000005 and webhelper shutdown despite a live host. Do not treat PID54396 as progressing Steam. This turn creates and executes a bounded graphics reproducer.

Added --sampled-texture to scripts/build-windows-d3d11-integration.py, preserving existing default/fresh/procedural variants and rejecting mixed texture variants. Uses pinned Wine ps_sample_code DXBC (Texture2D.Sample at t0/s0), existing vertex-buffer quad, 64x64 RGBA8 target, 1x1 RGBA8 source initialized to DWORD0xff332211, point/clamp sampler and default SRV. The single texel intentionally removes UV-scale dependence; this is not UV/interpolation coverage. Sixteen interior GPU-readback pixels must match. A second phase changes the texel using UpdateSubresource to0xffa0b0c0 and validates another draw; this phase is implemented but NOT reached in current failed runs.

Actual windows-texture-sampling-188: GPU clear passes, textured draw produces0x00000000 at all16 sample locations and guest exits34. Same runtime/options untextured control windows-texture-control-188 passes clear, draw and guest exit0. Enhanced windows-texture-upload-188 first copies source texture to staging and reads exact0xff332211, proving initialization/copy/readback for that resource; subsequent textured draw again returns sixteen zero pixels and exits34. Source readback adds synchronization but does not correct sampling. The failure is reproducible without Steam or child processes. This narrows investigation to shader-resource binding/sampler/shader translation (and their integration); it does not prove the same cause explains Steam's black UI or its separate GPU-process crash.

Sole designated Simulator inventory checked before launches. Only diagnostic bundle deliberately restarted; classic/ref/saves preserved. Native/runtime libraries unchanged (ntdll183, DXMT185, FEX187); startup trace off, same explicit flush/TSD flags,1GiB and reuse retained. Last diagnostic windows-texture-upload-188 host56210 remains shell only after observed guest exit34; no wait for guest progress warranted. Private run logs and three observations under generated/steam-188-*, detailed per-run logs under generated/madeira-signed-startup/. Next inspect actual texture/sampler GPU resource IDs and argument-buffer encoding; distinguish a resource-ID/Simulator limitation from wrong shader translation before changing runtime behavior.

Full DE execution, physical iPad, Steam authentication, sustained gameplay FPS, DE touch and retail multiplayer remain unfulfilled.


## Simulator texture ID is zero; argument encoder supplies nonzero binding — windows-189

Previous goal turn was progress: source-owned texture reproducer fails while untextured control passes. This turn adds bounded Simulator-only diagnostics to native winemetal_unix.c under existing AGEPAD_SIGNED_NTDLL: first16 texture/sampler/view creation IDs and first16 fragment-buffer initial bindings (bounded64-byte CPU reads). These initial bindings precede later offset commands; do not claim the logged offset0 words are the final shader table without observing the offset updates. Source encodeShaderResources writes TextureView.gpuResourceID into texture SRV slots.

Actual windows-texture-bindings-189: target and sampled1x1 texture gpuResourceID both0; sampler IDs nonzero. Upload readback still correct, sample zero, guest exits34. Thus zero texture IDs are an observed upstream defect candidate, not merely hypothesized shader arithmetic failure.

Added a second read-only experiment: for first16 new textures, create a one-texture MTLArgumentEncoder matching textureType, encode the actual texture into a temporary shared buffer, print encoded length/first8bytes versus gpuResourceID, then release temporary encoder/buffer. Does not alter returned GPU ID or render bindings. Actual windows-texture-encoding-189 obtains encodedLength8 and nonzero bindings1(target)/8(sampled texture), while both gpuResourceID values stay0. Uploaded pixel remains0xff332211 and textured draw still fails/exit34 as expected with unchanged bindings. This proves this Simulator encoder can supply an opaque nonzero encoding; it does NOT yet prove substituting it works in DXMT's argument table or across texture views/lifetimes.

Both native DXMT builds20/20 and app builds pass. Replaced only winemetal_unix.o in combined app archive, preserving LLVM/airconv. File-specific canonical DXMT patch updated and full reverse-check passes. Existing sole Simulator inventory checked before each diagnostic restart; classic/ref/saves preserved. No performance claim from diagnostic builds. Private steam-189-*-build.log, run logs, two observation JSONs and per-run runtime logs. Latest windows-texture-encoding-189 guest terminal34; host shell existence is not guest progress.

Next implement a narrowly gated Simulator texture-binding fallback via actual argument encoding, preserving nonzero native IDs and normal platforms. Cover normal textures, buffer-backed textures and texture views consistently, validate encoded layout rather than blindly reinterpret arbitrary length, then rerun initialization/sample/update and untextured control. Only after correct pixel evidence retry genuine Steam; zero-ID repair does not itself explain its separate GPU crash. Full DE/device/Steam login/touch/FPS/retail multiplayer objective remains unfulfilled.


## Encoded texture fallback passes sampled draw and update — windows-190

Previous turn made progress by measuring zero texture IDs and nonzero argument encodings. Added native agepad_texture_binding helper used by ordinary texture creation, buffer-backed texture creation and texture-view creation. It preserves a nonzero direct ID and all non-Simulator behavior. On Simulator only, exact AGEPAD_ENCODE_TEXTURE_IDS=1 permits a zero-ID fallback: encode the actual texture using matching textureType/read-only descriptor; accept exactly8-byte encoding, copy complete value, release temporary buffer/encoder/descriptors. Other layouts or allocation failure return0, not fabricated success. Existing resource lifetime/residency remains required. Added runner --encode-texture-ids, explicit0/1 environment and run.json field. Removed redundant189 scratch-encoder diagnostic; bounded resource/binding logging remains. Shared-texture unsupported Simulator path and remote early-return paths unchanged.

Native DXMT build20/20, app build, runner compile and canonical file-specific DXMT patch reverse-check pass. Replaced only native winemetal_unix.o in combined archive. Actual windows-texture-fallback-190 with same source-owned x64 probe now passes clear, exact uploaded0xff332211, all16 initial sampled pixels, then UpdateSubresource0xffa0b0c0 and all16 updated sampled pixels, guest exit0.189same probe without fallback failed34 with zero samples. Returned texture encodings1/8 are nonzero. This is actual Windows x64 -> DXMT -> Metal -> GPU readback qualification of the bounded1x1 texture path, not broad texture-format/view/UAV/device correctness or FPS. Existing untextured control passed188; no separate post190 untextured rerun, but190 itself clears/draws with the same vertex-buffer quad successfully.

Sole designated Simulator checked before installs; diagnostic-only restarts, classic/ref/saves preserved. Started genuine Steam retry windows-steam-texture-fallback-190 with encoded IDs, bounded present readback, reuse/1GiB,16 banks, native190/FEX187/ntdll183/server175/PE174, startup trace off. Observe actual browser/rendering outcome next; do not infer login or repair of separate GPU crash from the small test. Private steam-190-*-build.log, run/observation files and per-run diagnostics. Full DE/device/touch/FPS/retail multiplayer still unfulfilled.


Actual Steam190 follow-up: host58002 revalidated live, BrowserReady/login-window unhidden. Completed readbacks64/512 contain308000nonblack pixels of308000, versus prior18white pixels. Actual Simulator screenshot generated/steam-190-simulator.png inspected: recognizable Steam sign-in form with logo, account/password fields, sign-in button, links and QR area with loading overlay. This is the first visible login-screen rendering qualification in this Windows path. No credentials entered, no authentication/session acceptance, no assumption QR challenge is ready, no FPS claim from misleading Present0 overlay. Current run preserved for input/network/authentication readiness. Native shell UI is unchanged diagnostic scaffolding; not final game touch UI. Full DE/device/gameplay/multiplayer objective remains unfulfilled.

## Windows HTTPS directory probe passes; Steam-specific connection pending — windows-191

Previous turn was progress: texture fallback gives real Steam login rendering. Revalidated58002 and preserved observations plus fresh login/connection/JS/transport logs. Steam reports basic HTTP/IPv6 UDP connectivity success, WaitingForCredentials, UI connect, then GetCMListForConnect request with no completion through repeated observations. CEF/JS logs report TypeError reading assertInstanceof of undefined. Neither error nor missing completion alone proves causal failure; one-second native sample shows HTTP worker event waits and activity, not a demonstrated deadlock. Simulator CUA accessibility inventory inspected; no click/typing/authentication performed and input responsiveness remains unqualified.

Host curl to HTTPS api.steampowered.com/ISteamDirectory/GetCMListForConnect/v1/?cellid=0&qoslevel=3 returns200, certificate verification result0, ~0.15s. Built source-owned WindowsHTTPSProbe.c and reproducible build-windows-https-probe.py. Actual WinHTTP synchronous request uses default proxy, standard secure request,10s resolve/connect/send/receive timeouts, status200 requirement, bounded nonempty body read, no credentials/certificate bypass, stage/error/exit markers. Does not log body or claim Steam-specific transport compatibility. Initial nostdlib link had chkstk dependency from4KiB local buffer; changed to static buffer. Build succeeds.

First diagnostic windows-https-directory-191 lacked graphics-group dependencies (also imported by WinHTTP), failed C0000135 before entry; not network evidence. Corrected runner configuration --graphics --wininet stages user32/advapi32/etc like Steam. Actual windows-https-full-deps-191 reaches SEND/RECEIVE, HTTP200,20805body bytes, PASS and guest exit0. This disproves blanket WinHTTP HTTPS failure for this endpoint; Steam may use different implementation/state/concurrency. No assumption QR/authentication works.

Sole designated Simulator verified before diagnostic changes; only diagnostic bundle restarted, no established account session, classic/ref/saves preserved. Restored genuine Steam as windows-steam-after-https-191 with same native190/FEX187/ntdll183/server175/PE174 and encoded-ID/readback/reuse/1GiB/16bank flags, trace off. No native runtime change this turn. Private steam-191 logs, sample, host-directory response, observations, probe binary/build manifest. Next inspect restored Steam's own request progression and UI readiness; keep the full DE/device/touch/FPS/retail multiplayer goal active and unfulfilled.


## Targeted WinHTTP trace identifies proxy-discovery calls — windows-192

Previous turn was progress: actual Windows HTTPS probe passes. Revalidated restoredSteam59119, preserved connection/login/CEF logs and sampled threads/sockets. CM-directory request still has no completion in bounded follow-up. One external443socket established; this does not identify the request or establish TLS/HTTP completion. HTTP worker sample mixes waits with filesystem/module activity, not a proven deadlock. Nearest module mapping of sampled guest addresses points inside steamclient64 (raw private addresses only); no exact function interpretation from unsymbolized stack. The previous assertInstanceof error has not recurred in this early restored-run capture. Local retail JS contains that symbol in protobuf helpers; no JS modification justified.

Added opt-in --http-trace runner flag, explicit AGEPAD_HTTP_TRACE0/1 and run.json field. WineProcessBridge checks exact1 before general verbose selection and sets err+all,err-virtual,trace+winhttp. Default remains unchanged. This is for unauthenticated diagnostics; disable before entering credentials because HTTP traces may contain headers. No auth entered. App build and runner compile pass; file-specific Madeira patch refreshed and full reverse-check passes.

Sole designated Simulator verified; diagnostic-only controlled restart windows-steam-http-trace-192. Native190 graphics fix retained, FEX187/ntdll183/server175/PE174, encoded IDs/readback/reuse1GiB/16banks, startup trace off. Actual trace produces WinHttpOpen SteamHTTPClient, GetIEProxyConfigForCurrentUser, GetProxyForUrl for connectivity probes, DHCP/WPAD discovery and failed wpad.local resolution. At host59812 elapsed1m20s,46trace records, no WinHttpSendRequest observed. This establishes that at least the observed Steam usage is proxy discovery; it does not prove Steam never uses WinHTTP for transport. The directory request/login-window phase has not been qualified in this traced retry; HTML log so far contains initial BrowserReady65536 only. A20s verified wait followed confirmation of live59812; no timeout treated as terminal. Keep run active and inspect later progression before another mutation.

Next correlate actual CM request timing with proxy results and Steam's own socket/transport activity; do not disable proxy discovery, certificate validation or patch protobuf based on current weak evidence. Private steam-192 logs/sample/socket inventory and observations. Full Steam authentication/DE/device/touch/FPS/retail multiplayer remain unfulfilled.


## Local TCP accept failure precedes missing login window — windows-193

Previous turn was progress: targeted WinHTTP trace deployed. Revalidated59812 and inspected later logs. It has initial shared-JS BrowserReady but no login window; replacementGPU helpers and eventually an extra steamerrorreporter64 child appear. All16 private banks allocated and additional error reporter refused. This refusal is not the first failure. Console log establishes earlier assertion: CTCPHost::OnAcceptComplete reports1000consecutive errors, last error21, and explicitly stops accepts. Browser JS subsequently retries local clientdll WebSocket and fails to reach open state. transport_client.txt absent in this run (read attempt handled as missing evidence, not inferred empty successful transport). Thus this retry is blocked before the prior CM request stage by local listener failure; it does not qualify the pending remote-request hypothesis. Error reporter can be assertion-triggered; no specific unhandled CPU exception was identified as its cause. Unaligned/SMC diagnostics alone were not counted as fatal.

Source complete_async_accept terminates async on failed accept_into_socket. Native accept EWOULDBLOCK maps to STATUS_DEVICE_NOT_READY, which can map to Win32 error21 through generic I/O completion. This is a plausible connection to console error21, not verified actual status yet. Added WINE_IOS-only first32 failure diagnostic in accept-into completion recording status, socket state and nonblocking flag before unchanged async_terminate. No altered accept/proxy/TLS behavior. Initial build used wrong AGEPAD_SIGNED_NTDLL compile guard; archive string verification caught diagnostic missing. Changed to actual WINE_IOS guard, rebuilt46serverunits with no failures, verified diagnostic in archive, copied app libwineserver.a and rebuilt app successfully. Initial incomplete diagnostic app was never installed. Canonical Wine full diff/reverse-check passes.

Sole designated Simulator checked, controlled diagnostic-only restart windows-steam-accept-trace-193, same native190/FEX187/ntdll183/PE174 plus server193 logging. Encoded texture fallback/readback/WinHTTP trace/reuse1GiB/16banks retained, startup trace off. Classic/ref/saves preserved; no authentication attempted. Preserve new run to capture actual accept failures if recurring. Next require exact NTSTATUS/error evidence or a source-owned asynchronous-accept reproduction before retry-vs-terminal repair; do not enlarge bank capacity to mask failed listener or force successful accepts. Private steam-193 observations/console/JS logs/build/run evidence. Full DE/device/authentication/touch/FPS/retail multiplayer unfulfilled.


193 retry follow-up: host61322 revalidated live at54s, login-window BrowserReady131073. No accept-failure diagnostic or CTCPHost assertion observed so far; this does not qualify a fix because behavior was unchanged. WinHTTP trace now records GetProxyForUrl for actual HTTPS api.steampowered.com/ISteamDirectory/GetCMListForConnect/v0001/ on thread01b4, alongside the connection log's CM request. No WinHTTP send observed in captured trace. This reaches the remote-request investigation stage that192failed before. Preserve61322; inspect proxy return and subsequent transport. Prior standalone probe used endpoint versionv1 (not literalv0001), so do not call it an exact byte-for-byte request reproduction.

## Host terminated after null FEX thread-state allocation — windows-194

Previous turn was progress: accept diagnostic built; retry reached login and actual directory proxy lookup. Current observation and independent ps confirm61322missing. Final log explicitly records2000identical redeliveries atPC0 then host termination guard. This is terminal evidence, not timeout. No new native crash report needed to establish this logged termination. Added observer host_failure fields for recorded redelivery termination and current missing process, separate from initial_guest markers; actual run validates bothtrue while initial_guest exit marker remains absent.

Preserved first-fault excerpt and mapped actual built FEX PE symbols. Earliest relevant0348 fault is in xtajit64-child15 at PE RVA f31c, ContextImpl::CreateThread. Disassembly shows aligned_alloc(4096,12288), returnedx0=0, then STP constructor write throughx0. Thread belongs bank15 renderer PEB, not rootSteam. Later exception delivery enters ntdll-child15 and indirect null dispatch; this is secondary to allocation failure, not proof that fixing the null dispatcher fixes original crash. Existing diagnostic remarks about missed patch/aliases are historical heuristics and were not accepted as root cause. Original aligned allocation failure reason unknown; absent HOST MAP FAILED log is weak because rpmalloc's selector log is deferred/flushed at startup. Visible guest-band VA-scan failures are not proof of FEX-band exhaustion.

Added bounded first64 failed address-constrained MEM_RESERVE calls in native NtAllocateVirtualMemoryEx, after allocate_virtual_memory releases its lock. Records NTSTATUS, requested size/bounds/alignment and thread via dprintf. No allocation policy/size/ownership change. Native build/app build pass, file-specific Madeira canonical patch reverse-check passes. The diagnostic only covers failures reaching this native allocation path, not all rpmalloc validation/cache failures or early parameter exits. Existing return statuses preserved.

Sole designated Simulator checked; fresh diagnostic windows-steam-allocation-trace-194 after verified host termination. Native194/DXMT190/server193/PE174/FEX187; encoded IDs/readback/WinHTTP trace/reuse1GiB/16banks retained, startup trace off. Classic/ref/saves preserved. Next correlate any constrained-allocation failure with FEX null allocation, otherwise inspect allocator/thread heap state; do not expand memory bands or skip constructor writes based on size alone. Private steam-194-null-entry.txt, fex-symbols.txt, terminal-observation, build/run logs. Full DE/device/Steam auth/touch/FPS/retail multiplayer remains unfulfilled.


## Missing certificate-cache profile directory repaired live — windows-195

Previous goal turn was progress: null-allocation crash traced and failure diagnostics deployed. Revalidated62463; login window remains created, directory request pending, no observed constrained-allocation or accept failure at checkpoint. HTTP worker01ac repeatedly logs cryptnet open_cached_revocation_file cannot resolve LocalAppDataLow (HRESULT80070003). Source SHGetKnownFolderPath requires directory existence before it can create Microsoft/CryptnetUrlCache/Content. Actual users/wine/AppData contained onlyLocal; LocalLow missing. Native legacy madeira_repair_profile populates users/madeira, so it does not satisfy the signed diagnostic's wine profile.

Created only users/wine/AppData/LocalLow in the running diagnostic container, preserving contents and process. No restart, credentials, TLS flags, revocation settings or certificate data altered. Actual process then creates4cache records. Parsed against source signature and exact35-byte record layout: all4dwError values0. Missing-path error count remains1896across later observations, rather than continuing to rise. This establishes functioning cache storage and those cached success values, not whole-chain validity or authentication. Directory request still lacks completion in latestconnection log.

Persisted LocalLow creation in run-madeira-signed-startup.py after container lookup, before guest launch, with profile_locallow_prepared run.json field. Runner compile passes. Current live mutation and resulting cache writes qualify the directory choice; future-launch path not yet rerun because current process remains useful. No native/runtime rebuild required. Private steam-195-profile-repair.json, cache-verification.json and observations record evidence. No accept/allocation behavioral fixes inferred from absence of failures so far.

Current windows-steam-allocation-trace-194 host62463 preserved. Next investigate what follows successful revocation caching in Steam's pending connection path, and monitor existing native allocation diagnostics. Full actual DE/device/touch/sustained-FPS/retail multiplayer and Steam authentication remain unfulfilled.


## HTTPS with revocation checking passes after profile repair — windows-196

Previous turn was progress: LocalLow cache path repaired live and persisted in runner. Revalidated62463 at4m55, no fatal-host marker. Native sample: HTTP workers waiting; TCP inventory has no established external connection, while directory request still pending and UI logs protobuf instanceof assertion failures. These facts do not identify a lost completion or prove TLS failure. One fdtrace CROSS warning exists during child cache release, but the ledger tracks raw numbers and not every close/reopen, so it can be stale; no cross-process-close behavioral repair inferred from it.

Extended source-owned HTTPS probe/build script with --revocation variant. Uses observed endpoint versionv0001 (GET/query remains probe-specific, not a byte-identical Steam request), enables WINHTTP_ENABLE_SSL_REVOCATION via supported option, checks option success, retains status200/body checks and ordinary certificate validation. Default v1 variant preserved. Adds elapsed GetTickCount reporting. Builds and Python compile pass.

Actual windows-https-revocation-196: REVOCATION_ENABLED, SEND/RECEIVE, HTTP200,21396body bytes, elapsed303ms by guest clock, PASS/root exit0. No LocalLow missing error in this probe log; run.json profile_locallow_prepared=true verifies the new startup setup path executed. Existing profile/cache preserved across installs, so this is not cold-cache verification or proof fresh revocation network retrieval occurred. It rules out blanket failure of this configured Windows HTTPS/revocation path; Steam's own transport/callback and UI failures remain separate.

Sole designated Simulator checked; controlled diagnostic replacement announced, classic/ref/saves preserved. Restored genuine Steam as windows-steam-profile-ready-196 with profile setup before entry and existing194native/193server/190graphics/187FEX/174PE, same16banks/1GiB/reuse/encoded IDs/readback/WinHTTP trace, startup trace off. No native/runtime code changed this turn. Follow actual CM completion and renderer health; no authentication attempted. Private steam-196 sample/socket inventories/probe observation/run logs and build manifest. Full DE/device/touch/FPS/retail multiplayer and Steam authentication remain unfulfilled.



## FEX constrained allocations fail before null-pointer crashes — windows-198

Previous status turn yielded new evidence: GPU subprocess exit and browser shutdown, so it was progress rather than a verified wait. Revalidated exact host63910 before read-only vmmap; no restart or runtime mutation. The host remained present, but helper shutdown is authoritative and is not counted as active Steam progress.

The deployed194 diagnostic now records STATUS_NO_MEMORY (c0000017) for allocations constrained to the16GiB FEX host band, including16MiB requests aligned16MiB and a256MiB request aligned64KiB. Thread0350 then faults writing through a null-derived pointer in FEX child16 (container-relative offset c6034); thread0358 similarly fails allocations and repeats the earlier ContextImpl::CreateThread null allocation at offset f31c in child10. Later ntdll exceptions are secondary. This establishes the missing allocation-failure evidence; it does not yet connect every GPU failure to the same cause or identify why mapping fails.

Read-only post-failure vmmap census:16GiB band,14,866,235,392bytes mapped/reserved union;2,313,633,792bytes gaps; largest gap33,619,968bytes;25 geometric16MiB-aligned slots. These include inaccessible reservations and are not residency, allocation-at-failure state, or proof those gaps are mappable. vmmap labels its snapshot target corpse; that snapshot label alone is not used to override independent process/guest lifecycle evidence. This argues against simply claiming the entire band has zero space or increasing its bounds without investigating Wine views and host mapping failures.

Next capture allocation-time scan geometry and mapping rejection specifically for this band. Existing general va-scan failure logging has a256record cap, which can be spent by unrelated guest-band failures; add a narrowly scoped diagnostic if current logs cannot answer. Preserve locks and mapping behavior. Do not pursue unrelated JS flag changes before resolving this concrete lead. Private evidence: steam-198-vmmap.txt and steam-198-band-census.json, plus196 runtime-followup log. No authentication, DE gameplay, physical iPad, touch/FPS or multiplayer acceptance. Full goal remains active.



## Dedicated FEX scan failure diagnostic deployed — windows-199

Previous goal turn was progress: actual constrained STATUS_NO_MEMORY evidence narrowed the null-allocation crashes. Added a separate first64 failure budget immediately after map_free_area for windows entirely within the established FEX host band. Captures requested/native sizes, alignment, direction, tries/skips, Wine-view geometry, stop reason and first host mapping errno before subsequent census code. No mapping behavior, memory limits or return status changed. General guest-window failures cannot consume this budget. This covers map_free_area failures, not every allocate_virtual_memory failure path.

Native Simulator build and app build pass; canonical Madeira file-specific patch updated and full reverse-apply check passes. Checked actual booted inventory: only designated AgePad G5. Announced diagnostic restart; classic/ref/saves preserved. Launched windows-steam-fex-scan-199 (host65883), retaining196 configuration with native199 logging. Real login-window BrowserReady131073 and unhidden records appear. Revalidated exact host at31s,1m25s and2m20s, with two40s waits after live checks. No dedicated FEX or constrained-allocation failures in captured log yet; no new GPU exit in CEF tail. This is not a fix qualification or authentication success. Leave this run intact; investigate its next actual event, including other failure paths if the host remains live without guest progress.

Private steam-199 build/run/observation logs. Active full DE/device/touch/FPS/retail multiplayer goal remains unfulfilled.



## Unfailed-run memory geometry compared with prior failure — windows-200

Previous turn was progress: dedicated FEX allocation-scan diagnostics built and deployed. Revalidated host65883 at2m58 and4m42; no constrained/FEX-scan failure captured, no fatal guard. Browser log launches another GPU child at23:33:21, but captured CEF log contains no corresponding exit status; do not equate replacement launch with a diagnosed crash. CM directory request remains pending after successful basic connectivity probes. HTTP native sample includes event waits and active registry/file operations; this does not establish deadlock. No credentials entered.

Captured read-only vmmap for the current unfailed-at-observation run and added scripts/census-vmmap-band.py to reproducibly union saved snapshot regions, count gaps and aligned slots. Reprocessing198 independently saved snapshot reproduces its prior totals exactly. Current band union14,677,344,256bytes, gaps2,502,524,928bytes, largest gap536,870,912bytes,38geometric16MiB slots; prior failed snapshot largest gap33,619,968bytes and25slots. Thus similar total occupied space can have very different contiguous geometry. This supports investigating fragmentation/retained reservations, not claiming a total-capacity shortage or guaranteed allocatability. Snapshots are at different post-launch stages; vmmap reports AttributeGraph symbolication warnings, so no symbol-specific conclusions drawn. Neither snapshot proves allocation-time Wine view state.

Current run preserved without restart. Next correlate dedicated failure geometry when it occurs; investigate pending Steam transport separately if no recurrence. Source review finds WinHTTP autoproxy detection has an SRW-locked cache, but no evidence its lock is deadlocked; no speculative lock bypass applied. Private steam-200 sample/socket/vmmap/observation/census files. No Steam authentication, DE gameplay, device, touch/FPS or retail multiplayer acceptance. Full goal active.



## Span counter semantics corrected; Windows DE input rechecked — windows-201

Previous goal turn was progress: reproducible vmmap census and current/prior geometry comparison. Revalidated65883 at6m15; still no FEX-scan/constrained-allocation failure in captured199 runtime. Steam updater logs a terminal manifest-download failure (HTTP error0) while host remains live; this is a separate actual transport failure, not proof root guest exited or directory request completed. No runtime replacement this turn.

Source audit: rpmalloc_thread_finalize returns heap to global_heap_queue; heap_release does not destroy cross-thread allocations. ENABLE_UNMAP defaults1 and Windows os_munmap invokes MEM_RELEASE. Do not free all exited-thread spans as a speculative fix. Existing historical comments describe earlier live-demand failures but are not accepted as current measurements.

Found current diagnostic defect: ios_span_census runs after successful allocation syscalls including MEM_COMMIT-only, while its FREE hook executes before release success. Its live=alloc-free number therefore cannot be used as distinct live reservation count or leak proof; current~1800 balance must not be multiplied by16MiB. Corrected diagnostic-only labels to ALLOC_SUCCESS/RELEASE_ATTEMPT, live to call_balance, and included operation type at both allocation callsites and release callsite. Native Simulator build passes; canonical Madeira file-specific patch updated and full reverse check passes. Built archive on disk only, no app relink/install; active199 retains old labels. No allocation behavior changed.

Rechecked private ref inventory: Mac DE app executable and Windows AoK HD.exe present, no AoE2DE_s.exe found. Asked user asynchronously to supply installed Windows DE folder at ref/WindowsDE for the actual Windows-game milestone; runtime work can proceed independently. No credentials requested or entered. Next qualify current allocation failure geometry when reproduced, or isolate Steam HTTPS/proxy transport failure with a targeted reproduction. Full DE/device/touch/FPS/retail multiplayer remains unfulfilled.



## Windows automatic proxy discovery plus HTTPS passes — windows-202

Previous turn was progress: diagnostic call-counter semantics fixed, native archive built, missing Windows DE input requested. Revalidated199 run before replacement; no captured FEX-scan failures. Extended source-owned WindowsHTTPSProbe and builder with optional --autoproxy, composable with --revocation. Reads current-user IE proxy configuration (frees strings), explicitly exercises DHCP+DNS automatic detection with automatic proxy authentication disabled, reports outcome/time, applies discovered proxy when present, accepts only ERROR_WINHTTP_AUTODETECTION_FAILED as a no-PAC fallback; other detection errors fail. Then performs existing certificate-validated HTTPS status/body test. These are diagnostic choices, not a byte-identical recreation of Steam's transport or proxy policy. Default and revocation-only variants still build.

Relinked app with201 native log labels; build passes. Verified sole designated Simulator and announced controlled diagnostic replacement. Actual windows-https-autoproxy-202: IE_PROXY_RESULT0; AUTOPROXY_RESULT0x2f94 (12180, expected no auto proxy),81ms; revocation enabled; HTTP200,19,855body bytes; overall377ms by guest clock; PASS/root exit0. No proxy/TLS/authentication bypass introduced. This rules out unconditional failure of this sequential proxy-discovery+HTTPS path, not concurrent proxy correctness or Steam's own TLS/callback implementation. Existing profile/cache preserved, not cold-cache test.

Restoring genuine Steam as windows-steam-after-autoproxy-202, retaining native201/graphics190/server193/FEX187/PE174,16banks,1GiB/reuse, encoded texture IDs/readback/WinHTTP trace, startup trace off. No credentials entered; disable HTTP trace before account input. Classic/ref/saves preserved. Next investigate Steam's own transport or concurrent request behavior rather than assume generic WinHTTP is broken, while retaining199 allocation-failure geometry. Full DE/device/touch/FPS/retail multiplayer unfulfilled.



## Genuine Steam certificate chain reports untrusted root — windows-203

Previous turn was progress: actual sequential Windows autoproxy+HTTPS passed. Revalidated68070 at57s; directory pending, no allocation failure observed. Added opt-in --certificate-trace and recorded environment/run.json field. WineProcessBridge enables crypt/chain/cryptnet traces and composes with optional WinHTTP trace; defaults unchanged. Runner compile, app build and canonical Madeira file-specific patch full reverse-check pass. Only unauthenticated use; disable both trace flags before credential entry.

Checked sole designated Simulator, announced diagnostic restart, started windows-steam-certificates-203 host68666. Revalidated24s, then30s live wait; at1m06 trace output active (~41MB, significant timing overhead). Actual Steam HTTP thread01b8 repeatedly calls CertGetCertificateChain for certificate with subject-alt-name api.steampowered.com / community.steam-api.com, flags48000001.204chain calls return BOOL1; chain diagnostic reports error status00000020. Local wincrypt.h defines this as CERT_TRUST_IS_UNTRUSTED_ROOT.249logged revocation returns succeed/error0; no CertVerifyCertificateChainPolicy call captured at this checkpoint. BOOL success of chain construction is NOT trusted-chain success. This is concrete integration evidence beyond the passing standalone HTTPS probe, though not yet proof it explains every connection failure.

Root-store import also occurs in this run: thread00c0 loads app cacert.pem via MADEIRA_CA_BUNDLE and reports120roots added. Therefore do not claim root store is simply empty or disable certificate checking. Source import uses named semaphore and per-image root_certs_imported state; cross-process visibility, exact root identity, chain flags/cache and effective stores need comparison. Standalone WinHTTP TLS success does not establish Crypt32 chain trust. Next reproduce Crypt32 validation against server certificate in source-owned HTTPS probe with observed flags, and inspect which root/store the failing chain uses. Preserve current live trace for bounded capture; do not leave verbose crypto logs running indefinitely without checking size. Full DE/device/Steam authentication/touch/FPS/retail multiplayer unfulfilled.



## Crypt32 chain probe passes; genuine Steam still rejects root — windows-204

Previous goal turn was progress: actual Steam trust error isolated. Extended source-owned HTTPS probe with --chain, composable with revocation/autoproxy. After HTTP200 obtains WINHTTP_OPTION_SERVER_CERT_CONTEXT, calls CertGetCertificateChain with flags0 and observed48000001, reports chain/element errors and certificate display names, frees contexts, fails exit36 for any chain error. Builds with crypt32 import; default variant still builds and builder compile passes. No certificate-store edits or validation bypass.

Checked sole designated Simulator, announced controlled diagnostic replacement to stop verbose203 trace. Actual windows-https-chain-204: proxy no-PAC outcome; HTTP200; chain error0 and all element error0 with BOTH flag sets. Names in order: api.steampowered.com, YR1, Root YR, ISRG Root X1. Body21,343bytes, total448ms guest clock, PASS/root0. This qualifies Crypt32 trust in the simple probe, not only WinHTTP backend trust.203Steam dump_element shows same subject/issuer names and an ISRG Root X1 validity2015–2035; names alone do not prove DER identity.

Restored genuine Steam as windows-steam-after-chain-204, host69504, unchanged203runtime/traces/config/profile. Revalidated23s and performed30s verified wait. Root import thread00c0 has successful chain checks; subsequent actual Steam HTTP thread01ac again reports error00000020. Thus successful standalone initialization/persisted profile is insufficient; do not repeatedly reimport or replace all trust roots hoping to fix it. Source CRYPT_FindCertInStore obtains CERT_HASH_PROP_ID and looks up CERT_FIND_SHA1_HASH in engine hRoot; next discriminate property failure, missing/different root, stale/effective store, and lookup failure in actual Steam. No claim of root hash identity yet.

Private204 probe/build manifest/run/observations. Current verbose trace must be bounded and disabled before authentication. Windows DE executable still awaited; independent runtime work continues. Full DE/device/touch/FPS/Steam authentication/retail multiplayer unfulfilled.



## Shared root enumeration fixed; actual Steam connects and renders QR — windows-206

Previous turn was progress: source-built root-lookup diagnostic prepared. Added runner --crypt32-dll with existing PE x64 validation/staging/hash manifest path, preserving bundled DLL. New DLL imports same dependency names; native Unix entry table reviewed. Actual windows-https-rootlookup-206 passes chain probe/root0 with diagnostic DLL before Steam deployment.

Actual windows-steam-rootlookup-206 host71101 reports ISRG Root X1 hash cabd2a79a1076a31f21d253635cb039d4329a5e8, hash_ok1, size20, but hRoot enumerates only5certificates. Trace shows thread00c0 imports120roots; thread01a0 later reads the same X1 hash, then explicitly CRYPT_RegDeleteFromReg removes it. Source cause in native crypt32_unixlib_ios.c: one global loaded flag and destructive list_remove/free enumeration shared across all guest processes. Later process sees exhausted host roots and rootstore reconciliation deletes previously imported certificates. This connects actual deletion to an incompatible shared-library lifecycle, not missing CA bundle or failed certificate hash.

Fixed native enumeration by retaining immutable loaded list and maintaining mutex-protected per-PEB cursors. Buffer-too-small leaves cursor unchanged; each process reaches independent EOF; no root content/trust-policy changes. Cursor/list retained for host lifetime; current diagnostic uses stable guest PEB ownership. PEB reuse/process-lifecycle reclamation needs separate qualification before general runtime reuse. Native build and app build pass; canonical Madeira file-specific patch/full reverse check passes. Actual extracted function test covers interleaved guest owners, short-buffer retry, EOF, four concurrent guests, one-time root loading with ASan/UBSan; passes. Not a broad allocator or device test.

Actual fixed windows-steam-root-enumeration-206 host72083: Steam HTTP threads report chain error0; directory response now lists connection managers; ConnectionCompleted WebSocket103.28.54.100:27020 after multiple failed CM probes. Screenshot inspected: actual Steam sign-in form with fully visible QR instead of spinner. Simulator orientation is upside-down in raw capture; no UI orientation change made. ConnectionCompleted and QR are unauthenticated milestones, not login/DE/multiplayer proof. Private logs/screenshot; QR not exported to public artifacts.

Announced final diagnostic restart to disable certificate+HTTP traces before any account input and replace QR challenge. Current windows-steam-root-fixed-quiet-206 retains native fix and source-built diagnostic crypt32 (root lookup gated off), all existing graphics/runtime settings; no trace flags supplied. Verify actual connection again and user sign-in readiness. No credentials entered. Only designated Simulator, classic/ref/saves preserved. Full actual DE/device/touch/sustained-FPS/retail multiplayer goal remains active and unfulfilled.



## Sign-in attempt deferred after terminal CallRetStack allocation failure — windows-207

Previous goal turn was progress: fixed shared root enumeration; genuine Steam directory/WebSocket/QR milestones, repeated connection with HTTP/certificate traces disabled. Revalidated quiet206host72326 at1m42, inspected actual Simulator screenshot with QR, asked user asynchronously to sign in using mobile scanner. Later authoritative observation shows host missing AND fatal redelivery termination marker. Immediately told user to hold QR sign-in. No user credentials entered by agent, no successful authentication recorded. Login log reports logon failure and CEF auth-session polling result2/transport2; their relation to native failure remains unproved. Screenshot upside-down orientation left unchanged; no UI code change.

New199 allocation-scan diagnostic now captures exact failure: thread0358 requests0x1002000bytes (native rounded0x1004000) within16GiB FEX band;1887Wine views, largest reported gap0x1000000, stop gaps-exhausted(bottom-up), zero host mapping attempts, errno0. This is allocation-time Wine-view geometry, stronger than prior post-failure vmmap gaps. Actual vname is FEXMem_CallRetStacks atNULL. Built FEX symbol/disassembly address maps container offset108f2c to FEX::Windows::CallRetStack::InitializeThread; it continues through unchecked reserve failure and zero-scrubs address0x1000. Secondary ntdll exceptions end in fatal guard. Another thread later repeats same geometry. No timeout treated as terminal.

CallRetStack source reserves16MiB plus two4KiB guards from same FEX band. It currently does not check reserve/commit before pointer arithmetic; memory deficit and failure propagation both require work. Do not shrink constant blindly: JIT inline guard windows and DefaultLocation depend on geometry. Next audit these consumers and choose a bounded, tested reduction/placement or reclamation strategy, while preserving host isolation and genuine execution. No new runtime change/restart this turn.

Read-only devicectl inventory finds no devices. Windows DE executable remains absent in ref (prior request pending). Private207 observation/screenshot/device inventory/FEX symbols. Current diagnostic terminated; sign-in request is deferred until stable replacement. Full DE/device/touch/FPS/authentication/retail multiplayer goal active and unfulfilled.



## Call/return geometry experiment built; external review requested — windows-208

User requested a prompt for another bot to independently deep-dive the repository, return a report, and redirect this goal loop. Saved docs/reviews/EXTERNAL-DEEP-DIVE-PROMPT.md; expected report docs/reviews/EXTERNAL-DEEP-DIVE-REPORT.md. On receipt, read and verify its findings, preserve the report, and explicitly update priorities/experiments rather than blindly applying recommendations.

Before the request, audited three hardcoded CALL/RET guards and callback guard. Changed FEX_IOS_HOST prediction-cache size16MiB->8MiB via named size/shift/offset constants, updated those guard consumers and geometry log. Non-iOS size remains16MiB. FEX arm64ec build succeeded (steam-208-fex-build.log). This is NOT deployed or runtime-qualified: signed root container and16child banks still need rebuilding; canonical FEX patch sync pending. Deep translated recursion/reset-boundary test is planned, not implemented. Allocation failure propagation remains unchecked. Historical comments near guard code may still describe old numeric geometry. Review full diff and all consumers before qualification. Do not mistake successful compilation for correctness or Steam stability.

Last installed quiet206session terminated as recorded207; no fresh sign-in request should be issued yet. Full DE/device/touch/FPS/authentication/retail multiplayer remains unfulfilled. External review prompt includes verified root-enumeration fix, current fragmentation failure, pending experiment, missing Windows DE/device inputs, and challenges to overall strategy.



## 8MiB call/return cache passes deep Windows recursion; Steam retry — windows-209

Previous user turn completed review handoff prompt. Rechecked repository: external report absent, pending208 FEX build present and not yet packaged. Actual booted inventory was empty (previous Simulator shut down externally); booted only the designated AgePad G5 and waited for bootstatus. No other device started.

Added source-owned WindowsCallRetProbe.c and reproducible builder. Compiled with tail-call optimization disabled, noinline recursion,32MiB architectural guest stack. Disassembly confirms recursive CALL and real stack frame. Test verifies triangular sum and per-frame volatile tags at depth1024, then98304 twice. Built current FEX root signed container; actual windows-callret8-depth-209 logs size0x800000, default+0x200000, guard[+0x100000,+0x300000), all three DEPTH_CHECK_OK, PASS/root0. Depth exceeds the nominal downward predictor window capacity if every recursive call pushes a frame; no separate reset-event counter captured, so do not claim directly measured reset counts. This demonstrates translated deep-call correctness, not full callback/SEH/unwind or gameplay acceptance. Unchecked allocation-failure propagation remains to fix.

Canonical FEX patch synchronized including new headers and reverse-apply checked. Rebuilt all16child banks successfully with updated FEX. No native/app code change in this turn; native206root-enumeration repair retained. Started genuine windows-steam-callret8-209 with source-built crypt32, graphics190, prior runtime flags,1GiB JIT/reuse,16banks, HTTP/certificate/startup traces off. Runner validates staged source/container hashes. Observe actual stable connection, memory geometry and later lifecycle before claiming the8MiB change resolves fragmentation; it may only defer exhaustion. No new QR sign-in request yet.

Private steam-209 build/bank/probe logs, disassembly, observations and manifests. Full DE/device/touch/FPS/authentication/retail multiplayer remains unfulfilled. Await external review, but independent runtime experiments continue.


## Steam survives initial window but exhausts private child banks — windows-210

Previous turn updated the external review prompt: progress on the requested handoff. External report remains absent. Read-only observation of windows-steam-callret8-209 confirmed host86564 live at elapsed3:45 and4:57, with no fatal termination marker and no constrained/FEX-band allocation-failure marker in captured logs. This is bounded evidence, not sustained stability or proof the8MiB cache solves exhaustion. No app restart, Simulator interaction or credential entry this turn.

Actual connection_log records three WebSocket ConnectionCompleted events. The first two are followed roughly61–62seconds later by RecvMsgClientLogOnResponse 'Try another CM' / 'Failure' and remote disconnection; the log explicitly says the response was ignored because it was not waiting for a logon response. Do not infer authenticated login, invalid credentials, or a causal relationship to memory without more evidence. Live network activity distinguishes this observation from merely a live UIKit host.

A separate finite-resource failure is now source-correlated: all16 distinct signed child banks were assigned; a subsequent distinct guest reaches ios_load_child_ec_ntdll but returns before the bank-assignment diagnostic, then logs private initialization refusal. agepad_signed_ntdll.h:6–26 caps banks at16, retains owners for host lifetime, and returns0 when no free slot exists. loader_ios.c:2389–2391 returns failure on bank0 before the missing diagnostic. Given the16prior assignments and distinct owner, bank exhaustion is sufficient to explain this refusal; no allocation failure is needed. Banks deliberately are not reused because surviving callbacks/native threads may retain references. Merely raising the cap worsens finite memory demand and is not a sustainable fix.

One stuck self-modifying-code fault diagnostic is also present, and webhelper logs show later renderer/GPU child launches. Causality between that fault, child churn, and bank exhaustion is not yet established. Next: correlate child creation/exit reasons and ownership lifetime; determine whether helper crashes/restarts drive exhaustion, then design safe teardown or a different isolation mechanism. Do not blindly recycle banks. Separately investigate unauthenticated CM response behavior without certificate bypasses. Preserve deep-recursion success, retain allocation-failure propagation and callback/SEH qualification work. Windows DE inputs and physical-device acceptance still absent/unproved.

Evidence: generated/steam-210-observation.json, generated/steam-210-observation-later.json, current209runtime-followup.log and private connection/webhelper logs. Full goal remains active: no DE gameplay, authenticated Steam, sustained gameplay FPS, physical iPad, DE touch or retail match proved.


## Child lifecycle and renderer fault localized — windows-211

Previous turn is progress: bank exhaustion was source-correlated. Reobserved actual209host live at6:19 without fatal termination; no restart performed. External review remains pending.

Reconstructed private lifecycle table from initialization/bank records and exact initial guest TID matches to exit_process records (generated/steam-211-child-lifecycle.json). Bank/init pairing is log-order correlation, not a new process registry. Eight retained banks have explicit exit records:3,4,8,11,12,13,14,15. Four exit0; others -2,2,1 and renderer -36861. Thus capacity is historical owner count, not16simultaneously live guests. Exit alone does not establish callback/native-thread quiescence or safe bank reuse. Source process_ios.c child entry frees argv/args and clears TEB TLS; signed image/bank state is deliberately retained. General safe teardown remains unimplemented.

Renderer initial guestTID0264, bank14, receives an unreadable-target access violation and reaches NtTerminateProcess(self,0xffff7003); a replacement renderer obtains bank16, and a later GPU child is refused. This gives stronger lifecycle linkage than the earlier isolated stuck-SMC marker. Do not equate the earlier stuck marker with the terminal cause: no captured BREAKING LOOP event establishes that. The semantic meaning of exit0xffff7003 remains unverified.

Mapped the reconstructed guest RIP using the same-thread libcef handler module/RVA anchor. Fault is libcef.dll RVA0x33e809d. Actual installed binary disassembly is `movl -0x1(%r8), %r9d`, preceded by `movl 0xf(%r9), %r8d; addq %r14,%r8`. This is a concrete data-load failure; no basis yet to blame certificate checks, cache-size reduction, or instruction translation. Objdump nearest exported label is not the containing function name. Saved generated/steam-211-renderer-fault-disassembly.txt. Next discriminating evidence is the original guest R8/R9/R14 and source object contents immediately before this load, then compare the reconstructed context and translated instruction; avoid suppressing the exception or inventing data. Separately design lifecycle accounting before bank recycling.

Full DE execution/device/touch/FPS/authentication/multiplayer remains unproved. Missing Windows DE remains a separate prerequisite; current work is retail Steam runtime qualification.


## Bounded reconstructed guest AV diagnostic packaged — windows-212

Previous turn is progress: localized renderer data-load fault and retained exited owners. Reobserved209host live at8:55, later11:04; no inference of healthy guest from that. The captured terminal renderer sequence lacks the guest operand registers needed to discriminate object corruption from translation/reconstruction errors. External report and WindowsDE executable still absent. Actual Simulator inventory contains only designated AgePad G5.

Added FEX_IOS_HOST-only guest-av-state agepad212 diagnostic in ARM64EC/Module.cpp::RethrowGuestException, immediately after ReconstructThreadState and before packed context/guest SEH. Captures nativePC, reconstructed guestRIP, exception parameters/access/address, and reconstructed R8/R9/R14. Atomic per-instance budget32; no guest-pointer dereference, no behavior change to exception delivery. These are reconstructed registers, not an independently validated pre-fault snapshot. This first stage can reveal whether R8-minus1 matches the failed address and constrain the missing data; it cannot alone prove the preceding object load or translator correctness.

FEX build passed; root signed container and all16child banks rebuilt successfully; canonical FEX patch synchronized and reverse-check passed. No broad test added for logging-only change. Announced diagnostic-only restart of existing Steam session, preserving classic/ref/saves. Started runner windows-steam-guestav-212 with the same8MiB geometry, root-enumeration fix,1GiB JIT/reuse and runtime flags; HTTP/certificate/startup tracing off. Build/artifact success is not runtime fault-capture success; inspect this run's actual process/manifest/logs next. Private212build/container/bank/observation artifacts retained.

Full goal unfulfilled: actual DE engine/gameplay/device/touch/FPS/authentication/multiplayer remain unproved. Continue from discriminating fault evidence, not capacity increases or exception suppression.


## Reconstructed registers capture a different renderer fault — windows-213

Previous turn is progress: actual diagnostic code built, packaged and launched. Revalidated212host98839 at0:49,1:32 and2:47, with one45second verified wait. No restart. Latest capture has16assigned banks; no bank refusal at that observation, so do not claim recurrence yet.

Diagnostic succeeds on guestTID02b8: guest AV reconstructed R9 plus7 equals the recorded fault address exactly. Same-thread libcef handler/RVA anchor maps guestRIP to libcef.dll RVA0x3344325. Actual binary instruction is `movzwl 0x7(%r9), %r15d`; preceding instructions load a32bit value from R12-minus1 into R9D and addR14. R9-minusR14 is0xffd0d022. The target lies inside a4GiB Wine reservation whose logged protect is0, and the native probe cannot read it. These constrain pointer provenance, but the preceding object's contents and original R12 were not captured. This is a different fault RVA from209; no proof that one deterministic instruction defect explains both. Reconstructed registers are not independent validation of reconstruction correctness.

Important diagnostic discrepancy: supplied AV access=1(write), yet reconstructed x86 instruction is a16bit read. signal_arm64_ios.c around9552–9560 uses a broad bit22 heuristic on native opcodes to infer store direction. FEX MemoryOps.cpp emits LDAPURH/LDAPRH variants for16bit TSO reads, so direction decoding needs qualification against the actual native opcode before blaming a guest write. The current capture lacks that opcode. Next capture it at the already-existing native opcode read, then test the classifier against load/store classes; avoid changing exception direction from guessed x86 intent alone. Wrong metadata is not yet proved to cause the invalid pointer or renderer crash.

Primary-source research resolves exit-code semantics: Crashpad util/win/termination_codes.h defines0xffff7003 as kTerminationCodeNotConnectedToHandler, a dump requested for a client never registered with the handler. This is crash-reporting state, not a diagnosis of OOM or the preceding access violation. Source: https://github.com/chromium/crashpad/blob/main/util/win/termination_codes.h (accessed2026-09-09). Local exact Crashpad revision not independently matched; applying the upstream code identity to this binary is an inference consistent with its value and exception sequence. Do not prioritize enabling crash reporting as a substitute for fixing original fault.

Private evidence: steam-213-observation*.json, steam-213-guestav-excerpt.txt, steam-213-renderer-disassembly.txt. Full DE/device/touch/FPS/authentication/retail multiplayer goal remains active and unproved. Next runtime change should capture missing native opcode and R12 before a targeted decoder correction or object/translation probe; keep current candidate running until ready.


## RCpc load direction misclassification reproduced and corrected — windows-214

Previous turn is progress: actual register capture and disassembly constrained a second renderer AV. Reobserved212host98839 at5:11, now with one private-child initialization refusal: the finite-bank failure has recurred. No claim of stable Steam or auth. Only designated Simulator booted.

Assembled actual ARMv8.4-A instruction fixtures with toolchain clang and inspected llvm-objdump: LDAPRH has bit22 clear and is misclassified as a write by existing bus_handler heuristic. FEX MemoryOps.cpp emits LDAPR-family instructions. Added exact masked recognition for LDAPR B/H/W/X in agepad_bus_instruction_is_store, preserving prior fallback for other encodings. This is a narrow correction, not a complete ARM load/store decoder; other classes still require audit. In particular the opcode at the213fault was not captured, so the fix is not claimed causal for that crash.

New tests/test-bus-rcpc-direction.py extracts actual source helper, compiles with ASan/UBSan, verifies4096width/register encodings and6assembled load/store controls. Pass. Native runtime build passes; canonical Madeira file patch synchronized/reverse-check passes. Added exact native opcode to BUS->AV unreadable-target diagnostic at a PC already read in this path, to qualify the real fault instruction on next run. App relink passed; current212installed candidate is unchanged until a subsequent announced deployment. Private214native/appbuild and instruction fixture/disassembly artifacts.

Next: deploy only after app build succeeds, reproduce renderer AV and confirm opcode/read direction. Retain original goal and pointer-corruption investigation: corrected metadata does not repair an invalid address. R12/source-object contents remain uncaptured, so do not infer a prior load result from assumptions. DE/device/touch/FPS/authenticated Steam/retail match acceptance remains missing.


## Decoder correction deployed; guest startup still in progress — windows-215

Previous turn is progress: assembled-instruction regression, exact RCpc decoder correction, native/app builds. Rechecked build success and actual inventory: designated AgePad G5 only. External report absent. Announced diagnostic Steam restart and deployed windows-steam-rcpc-215 with214native opcode/read-direction change,212FEX guest-register logging, existing8MiB cache and unchanged runtime options. Root/child container source hashes validated by runner. HTTP/certificate/startup traces remain off; classic/ref/saves preserved. HostPID1661 verified live after runner exit and at1:23/2:34; two45second waits tied to this live handle. No timeout interpreted as terminal.

At2:34 captured16banks, no guest-av-state or unreadable-target diagnostic, no private child refusal yet. This is NOT a fix acceptance: Steam startup is slower in this run. Subsequent live helper log records fallback GPU launch then creation of login popup at00:43:09; steamui_login.txt still absent and connection log contains only connectivity tests, not ConnectionCompleted. Seven routine guest exits recorded so far, no0xffff7003. Host liveness and absent fault marker do not prove renderer stability or successful connection.

Source CPUFeatures.cpp iOS path sets SupportsRCPC=true and leaves SupportsTSOImm9 defaultfalse; MemoryOps.cpp therefore selects LDAPR-family GPR TSO loads. This strengthens relevance of214decoder test but does not identify a past runtime opcode. Continue observing this same candidate until actual fault/opcode or a stronger stable milestone; do not repeatedly restart because startup is slow. New native opcode diagnostic and212register capture are ready to discriminate fault metadata from bad object pointers. MissingR12/source object remains an evidence gap if the new fault needs it.

Evidence: generated/steam-215-run.log, steam-215-observation.json, steam-215-observation-later.json, run manifest/private runtime and Steam logs. Full DE execution/device/touch/FPS/authentication/retail multiplayer remains unproved; goal stays active.


## Corrected candidate reaches actual CM connection without captured renderer AV — windows-216

Previous turn is progress: deployed214native correction and verified215startup. Observed same host1661 at3:55 and6:34, with a30second verified wait. No restart, no input. Actual inventory still designated Simulator only. Screenshot steam-216-screen.png visually shows genuine Steam Waiting for network, upright portrait; no UI change made. Overlay Present/FPS remains unsuitable as gameplay measurement.

Guest logs advance from WaitingForCredentials at00:43:53 to network pings and actual ConnectionCompleted WebSocket at00:46:09. At6:34 no guest-av-state, new unreadable-target opcode diagnostic, or private-child refusal captured; all16banks have been assigned. This is bounded better survival than212, not proof of causality or sustained renderer correctness. Slow startup means wall-clock comparisons alone are insufficient. No authenticated account or DE.

Read-only1second sample and TCP inventory retained. Many sampled waits are reads, alongside FEX execution and UIKit/log work; no demonstrated deadlock. TCP snapshot had38closed,8established,2listening descriptors; descriptor aliases exist, so this is not a count of unique connections and does not prove leak/exhaustion. No EMFILE evidence found in captured runtime. Do not chase incidental waits/closed descriptors without causal evidence. Live connection progress supersedes the earlier suspicion of complete network stall.

Evidence: steam-216-observation.json, steam-216-observation-later.json, steam-216-sample.txt, steam-216-tcp.txt, private screenshot and connection logs. Continue observing this candidate for stable QR/authentication readiness or exact fault evidence. Do not request sign-in from an obsolete screenshot or infer performance from overlay. Full DE/device/touch/FPS/authenticated retail multiplayer goal remains active/unproved.


## Live QR sign-in ready for user attempt; session preserved — windows-217

Previous turn is progress: actual CM connection beyond startup. Revalidated same215host1661 at7:25 and8:55, with30second verified wait. Still no host fatal marker/private-child refusal; initial217capture no guest AV/opcode fault. This does not prove indefinite stability. Actual booted inventory designated only. Screenshot steam-217-screen.png inspected: real Steam username/password form and fully visible QR, upright. No UI or runtime changes; no screenshot/QR published externally.

Connection log shows another ConnectionCompleted; UI logs show received logon failure and auth polling Result2/TransportError2 between connections. Therefore authentication is an experiment, not an assured working path. Asked user asynchronously to scan the LIVE Simulator QR using Steam mobile and report result; explicitly no credentials/Guard codes in chat and no obsolete screenshot. HTTP/certificate/startup tracing remains off per215manifest. No credentials entered by agent; no account authentication claimed. Preserve current session while user attempts sign-in; do not restart it merely for another probe.

External report and WindowsDE input remain pending. Independent source review can continue while user acts, but authenticate only through legitimate retail flow. Next verify actual login result and guest lifecycle, then actual game installation/execution prerequisite. Full actual DE/device/touch/FPS/retail multiplayer acceptance remains missing. Evidence: steam-217-observation.json, steam-217-observation-later.json, private screenshot and215connection/UIlogs.


## Callret allocation failure checks and Wine propagation implemented — windows-219

Previous turn is progress: external review ingested, verified priorities and gate ledger saved. Implemented the first narrow allocation-failure correction without changing/installing the live215candidate.

CallRetStack::InitializeThread now returns checked bool, zeroes unpublished stack state, stops before pointer arithmetic/ZeroScrub when reserve fails, and releases the reservation on commit failure. Failed-init DestroyThread is a no-op; HandleAccessViolation declines a missing cache. ARM64EC ThreadInit destroys the completed core thread and its explicitly owned segment array, releases emulator-stack allocation, clears CPU-area dispatch/state fields, finalizes CRT TLS, and returns STATUS_NO_MEMORY before map/sweeper/frontend registration. Wine loader now checks secondary-thread arm64ec_thread_init status, leaves loader_section and exits that thread rather than proceeding to guest dispatch. Main-process init already has a separate returned-status path. WOW64's void init consumer now explicitly fail-fast checks the bool; graceful WOW64 failure recovery is not claimed or qualified.

Actual extracted CallRetStack implementation tested with injected reserve failure, injected commit failure and successful init, ASan/UBSan: pass. Checks no scrub/name after reserve failure, one release after commit failure, zero dispatch stack fields and safe failed-init destruction. This unit test does NOT execute ARM64EC cleanup or Wine's guest exit path. No claim of end-to-end recovery yet. FEX arm64ec build and Wine arm64ec ntdll build pass; Wine built with required AGEPAD_SIGNED_WINE_TSD=1. FEX/Wine canonical patches synchronized and reverse-checked.

Remaining work before deployment: package updated FEX/ntdll root/child containers; add controlled guest secondary-thread failure injection; verify parent survives and no partial CPU-area dispatch/null fault occurs. Do not replace live QR session before its pending user attempt is resolved or a new test is explicitly scheduled. Other constructor failures (emulator stack, core CreateThread/LookupCache, segment/frontend allocation) are not comprehensively handled by this narrow change and remain open. Resource exhaustion/lifecycle itself is not fixed.

Files: tests/test-callret-allocation-failure.py; private steam-219-fex-build.log / steam-219-wine-build.log. Full DE/device/touch/FPS/authenticated retail multiplayer remains unproved. Priorities remain the reviewed allocation/lifecycle work, early physical device gate when connected, direct DE boundary as soon as the Windows files arrive.


## Guest failure probe and isolated injection package prepared — windows-220

Previous turn is progress: reserve/commit checks and Wine status propagation built with actual-helper unit coverage. Revalidated live215host1661 at16:46 with no fatal marker/private-child refusal. User QR attempt still pending; no restart/install this turn.

Added WindowsThreadInitFailureProbe.c plus reproducible builder. In a test-only FEX build whose second callret init fails, first CreateThread must return a handle, exit STATUS_NO_MEMORY and never enter worker; then a second worker must return73 with exactly one worker entry; parent logs PASS and exits0. Bounded15second waits yield explicit failure codes. Built PE and hash manifest. These expectations are discriminators to test; actual guest outcome is NOT yet known.

Added CMake AGEPAD_TEST_CALLRET_FAIL_AT, default0 with numeric validation, and an atomic counter injection before reserve. Built option2 and saved DLL/hash manifest separately under generated/steam-220-failure-build; finally restored option0 and rebuilt normal FEX successfully. Compiled test hook therefore cannot activate in the default build. Existing actual-header reserve/commit/success tests pass after hook addition. Prepared separately named signed diagnostic FEX container and updated signed root ntdll container; canonical FEX patch synchronized/reverse-checked.

Runner now accepts explicit --fex-container for root-only diagnostic probes, applies existing source/dylib hash checks and records override path; rejects child-bank use with override to avoid mixed FEX versions. Help parsing passes. No runtime test yet; this is infrastructure for the defined parent-survival discriminator, not end-to-end recovery proof. Normal root FEX container and child banks are still older than new normalFEX/ntdll sources and require packaging before a future retail run; runner stale checks remain in force. Do not mistake prepared test artifacts for the currently installed215binary.

Next when current authentication attempt is resolved: run guest probe with explicit diagnostic container and new ntdll, inspect injection marker, failure status, parent/next-worker survival, and absence of null-state dispatch. Continue input-independent root/lifecycle review meanwhile. Full original DE/device/touch/sustained-FPS/authenticated retail multiplayer goal stays unproved.


## Report steering retained; incomplete root enumeration no longer deletes roots — windows-221

User supplied the review summary while work continued; original report already preserved and independently ingested218. Continue the adopted resource/device/direct-DE priorities, not blanket acceptance of estimates or platform/legal exclusivity statements. Previous220turn is progress: source-owned failure probe and isolated package built, normal injection disabled; live215session preserved.

Implemented Wine crypt32/rootstore.c guard: capture the actual native enumeration NTSTATUS; only STATUS_NO_MORE_ENTRIES permits deletion of imported roots absent from the new list. Initial buffer OOM, growth-buffer OOM and initial crypto-provider failure exit safely; growth allocates replacement before releasing the old buffer. Other enum errors free temporary resources and close import key before deletion or persistence. Normal complete enumeration still permits removal of roots genuinely absent on the host; no certificate validation bypass introduced.

New tests/test-rootstore-enumeration-failure.py executes the ACTUAL root-sync function with mocked crypto/registry APIs under ASan/UBSan: initial enum OOM, partial enum then OOM, initial buffer OOM and growth OOM cause no imported-root deletion; normal EOF removes an absent imported root. Pass. First harness compile needed a C++ stub return-type correction; production C was unaffected. Wine x64Crypt32 build passes, canonical Wine patch reverse-check passes. Not deployed over live215; not an actual guest/device test.

Scope remains narrow: native empty-first-load latch, PEB reuse and retry/restart semantics are still unaddressed. Existing root_certs_imported latch is unchanged: failure is not automatically retried in this process. Do not add retries until cursor restart and partial-import semantics are defined. Hashing/certificate API failures beyond reviewed allocations need separate handling if qualifying all error paths. This is protection against error-as-EOF deletion, not completion of root-store lifecycle work.

Private steam-221-crypt32-build.log and221observation. Full DE/device/touch/sustained-FPS/authentication/multiplayer remains unproved. Keep current live QR session until user attempt resolves; physical-device/input gates remain dependent on missing hardware/files.


## Actual guest allocation-failure recovery passes; Steam preserved — windows-222

Previous turn is progress: rootstore incomplete-enumeration guard built and regression tested. Revalidated215host1661 at25:22; no host fatal/private-child refusal. Fixed native empty-root-load latch: empty load returns STATUS_UNSUCCESSFUL before cursor creation and does not set loaded, permitting later native enumeration attempts to reload. Actual enumerator test now covers initial empty-load failure followed by same-owner successful enumeration plus existing interleaved/short-buffer/concurrent cases. Pass; native build passes; canonical Madeira patch reverse-check passes. This native change is not in the installed app (no app relink/deployment); PE import retry/lifecycle remains open.

Added runner --probe-bundle: separate local.agepad.runtime-probe app/data, same designated Simulator; existing source/dylib checks retained. Announced temporary foreground probe. No extra Simulator booted. Used baseline214native template, updated219ntdll, explicitly selected220test-onlyFEX signed container, source-owned WindowsThreadInitFailureProbe. Actual windows-thread-failure-222 host12013: init2 injection marker; Wine reports thread init STATUS_NO_MEMORY; first worker is rejected; following worker returns73; parent logs PASS and guest exit0. No no-state-at-exception/fatal-redelivery marker. Registry-miss cleanup path is observed for the rejected unregistered thread. This qualifies this specific secondary-thread reserve-failure path and recovery, not every core/commit/OOM path or overall resource lifecycle. Commit failure has unit coverage only.

Original SteamPID1661 survived concurrently, unchanged. After guest probe terminal0, explicitly terminated ONLY runtime-probe, launched already-running Steam bundle, and confirmed samePID1661 at27:30. Saved and inspected restored Simulator screenshot: Steam sign-in is foreground, QR is blurred with a refresh control (fresh challenge required before scanning). Steam installation/data/process preserved; authentication still not claimed. New failure-injection DLL remains isolated; normal FEX build option0 restored previously. Current215Steam still has older runtime, not219failure-handling code.

Evidence: steam-222-failure-run.log, steam-222-failure-observation.json, windows-thread-failure-222/runtime-followup.log, steam-222-native-build.log, private restored screenshot. Next expand source-owned failure qualification and root/lifecycle work without waiting on the account by using isolated probe bundle on this same Simulator and restoring Steam. Full actualDE/device/touch/FPS/authenticated retail multiplayer remains unproved.


## Actual guest commit-failure recovery passes — windows-223

Previous222turn is progress: actual guest reserve-failure recovery and native empty-load fix; Steam preserved. Added compile-time commit-stage injection alongside numbered callret injection, defaultOFF/0. Diagnostic build saves separately under steam-223-failure-build; normal FEX rebuilt with both controls disabled. Existing actual-helper ASan/UBSan tests pass after change. Canonical FEX patch synchronized/reverse-checked.

Checked sole booted device designated G5; original SteamPID1661 live at29:49. Announced isolated probe foreground. Built test signed FEX and ran windows-thread-commit-failure-223 in local.agepad.runtime-probe with same guest recovery probe/new219ntdll/baseline214native. Actual log: init2 commit injection, commit failure, reservation release-success message (VirtualFree returned true), Wine statusc0000017, FAILED_THREAD_REJECTED, PARENT_AND_NEXT_THREAD_SURVIVED, PASS, guest0. No null-state or fatal-redelivery marker. This proves the targeted partial-allocation cleanup status and subsequent thread recovery under the harness, not an independent kernel census of every freed byte or all OOM sites.

After terminal guest0, terminated only probe app and reactivated already-running Steam; originalPID1661 retained beyond30minutes. No Steam restart/data change/account input. Half-hour host survival is not authenticated Steam or complete G1 qualification: QR/polling/connection and resource plateau require separate evidence. No fresh sign-in claim from stale screenshot.

Both targeted secondary-thread reserve and commit failures now have actual guest pass evidence. Next work should move beyond this hypothesis to rootstore guest integration and ownership/lifecycle accounting, while device and WindowsDE inputs are still missing. Do not broaden failure recovery claims to emulator-stack/core compiler allocation or process teardown. Production containers/child banks still need rebuilding before retail deployment of219/223changes. Evidence: steam-223-observation.json, run manifest/runtime log, isolated test build/container logs. Full DE/device/touch/sustained-FPS/authentication/retail multiplayer goal remains unproved.

