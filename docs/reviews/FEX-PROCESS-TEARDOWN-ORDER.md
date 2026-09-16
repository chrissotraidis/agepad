# FEX process teardown: unresolved ownership order

Checkpoint windows-234. This is a source-backed design constraint, not an implemented shutdown protocol.

## Current evidence

The 232 probe creates two children with 16 workers each. Its log contains 32 FEX thread-deinitialization records, matching the workers. The child main threads (002c and0074) and root main thread0024 have no such record. This absence is corroborated by the code below; it is not by itself proof of every allocation's lifetime. Private record extraction is `generated/steam-234-teardown-audit.json`.

- `Source/Windows/ARM64EC/Module.cpp::GetThreadsMap` stores raw `InternalThreadState*` values. Destroying this map does not destroy the pointed-to threads.
- `FEXCore/Source/Interface/Core/Core.cpp::ContextImpl::CreateThread` allocates a thread and returns its raw pointer. `DestroyThread` explicitly deletes it; context ownership must not be assumed from the name.
- `Module.cpp::DestroyRegisteredThreadState` performs additional frontend, segment-array, call/return cache, emulator-stack, sweeper and CRT cleanup. A bare allocator unmap bypasses all of that.
- `BTCpu64IosPendingThreadCleanup` deliberately excludes the querying main thread. Its zero result permits worker-drain progress; it cannot certify that the entire process allocator is unused.
- `ProcessTerm` remains empty. Normal `RtlExitUserProcess` goes from `NtTerminateProcess(NULL)` to `LdrShutdownProcess`, then self-termination. No newly added path disposes of the main FEX thread before DLL detach.
- `LookupCache::~LookupCache` invokes `ctx->SyscallHandler->UnmarkOvercommitRange` after releasing its mapping. Thread-state destructors therefore need live context and syscall-handler dependencies, not merely readable allocator memory.
- Module.cpp declares CTX before SyscallHandler and other global dependencies. Ordinary reverse C++ destruction order does not provide a new safe main-thread teardown hook. Function-local registry/mutex objects introduce additional construction/destruction order constraints.

## Required sequence

1. Stop guest thread creation and prevent new callbacks that require process state.
2. Drain workers through full FEX cleanup; keep context, syscall handler, overcommit tracking, allocator and executable callback mappings alive.
3. Finish guest DLL/TLS callbacks that still need translated main-thread execution. Identify the final such callback from actual loader order; do not assume all callbacks are native.
4. On a proven native stack, detach and destroy the remaining main FEX state while its dependencies still exist. Returning to translated guest execution afterward is forbidden.
5. Destroy remaining process-owned C++ objects and invalidate callback access in an explicit order. All previously acquired callbacks must finish before executable mappings are reused.
6. Finalize/unmap allocator heaps only after their last users and destructors finish. Retired heaps, cached blocks and deferred remote frees are not equivalent to unused memory.
7. Retire native registries/PEB identities, reset private DLL state and reuse a bank only after the complete lifetime is verified.

The next implementation must establish a shutdown owner or equivalent explicit phase protocol covering steps3–6. Adding `rpmalloc_finalize` to `ProcessTerm`, putting a last-minute raw CTX pointer in a callback, or treating the worker-drain counter as full quiescence does not meet these constraints.

## Validation required

Preserve the existing four-/sixteen-worker comparison. Add main-thread state disposal evidence before allocator reclamation and check mapping results, not just guest exit codes. Include an actual x64 DLL/TLS detach callback that executes guest code, a shared allocation surviving worker exit, and a parent that remains operational after the child exits. Verify callback rejection after retirement and repeated bank reuse separately. None of these are claimed complete here.

## Additional evidence — windows-235

Actual x64 fixture callbacks execute successfully after worker drain and before FEX module TLS process detach in both child modes. The current binary's DllMainCRTStartup calls DllMain before _CRT_INIT on process detach. A custom DllMain is therefore the next candidate for explicit main-thread disposal while dependencies remain alive. This is not yet implemented or proven safe for general retail loader graphs; allocator finalization must still follow all allocator-dependent destructors. See235 status and private detach-verification/disassembly artifacts.

## Main-thread cleanup experiment — windows-236

Test-only custom FEX DllMain disposes of main emulator state before CRT detach, preserving allocator TLS/heaps for subsequent destructors. The same x64 TLS/DLL fixture passes in both children and root, with three successful main-cleanup markers and less retained VA. Normal build option and common root/two-bank packages restored to defaultOFF. Post-destructor allocator finalization and complete callback retirement remain open; this does not close the final teardown phases.

## Allocator reclamation checkpoint — windows-237

Experimental main-state cleanup followed by normal CRT detach and whole-allocator finalization passes the actual two-child x64 TLS/DLL fixture. First-child occupied-band growth is16,785,408 bytes; second-child incremental growth is4,096 bytes, versus184,578,048 bytes per child in236. This is constrained guest VA evidence, not device RSS or complete lifecycle correctness. Both experimental build options and common root/two-bank packages were restored to normal afterward; preserved Steam was not restarted.

The review's finite-resource priority remains active: qualify higher concurrency, retire native callbacks/registries with explicit lifetime guarantees, then test bank reuse. Increasing the bank cap would not resolve the ownership problem. Device and direct Windows DE gates remain dependent on missing inputs. See WINDOWS-DE-STATUS.md and the gate ledger for evidence and remaining limits.

## Broader worker qualification — windows-238

The same guest DLL/TLS fixture now passes with16workers per child and unchanged experimental237 runtime. All16 terminal-waiter cleanup results are0; three main/allocator detach sequences complete, expected81/82 child statuses reach the parent, and root exits0. First-child retained VA growth16,785,408 bytes and second-child4,096 bytes match the4worker test. This supports reclamation across increased worker count; it does not close native callback retirement or bank reuse. Those phases are the next discriminator, rather than another identical cleanup test.

## Callback retirement foundation — windows-239

The three native FEX callbacks now use tracked acquisition/invocation/release; raw hold-release pointer lookup was removed. Nonblocking retirement rejects new calls and returns in-flight count; retired entries cannot re-register and remain tombstones. Actual extracted-registry pthread test proves a blocked callback keeps retirement pending until return while another owner stays usable; ASan/UBSan and native build pass. No exit hook or bank reuse is enabled yet. Nonreturning callbacks retain a count rather than falsely reporting drain.

Before integration, audit process_exit_wrapper: socket close signals parent, fd cache releases, then JIT reclamation relies on a grace delay. Neither elapsed grace nor this registry's zero count proves all native callback/thread lifetimes have ended. Retire before any relevant code/state reuse, after the last required cleanup callback; verify that location in the actual guest fixture.

## Final exit guard — windows-240

Opt-in retirement at process_exit_wrapper entry passes the actual16worker guest detach fixture. Zero count precedes socket/JIT release; nonzero/unknown retains those resources in native guard tests. This is too late to certify allocator destruction: closure/drain must also occur before main-state and CRT teardown, after the last required guest callback. Next add that earlier handshake with failure retention and retain the final-exit check. Bank reuse remains disabled; no grace-delay-based safety claim.

## Earlier handshake candidate — windows-241

MODULE_InitDLL calls TLS callbacks before the entry point. Use the actual translator DllBase from load_arm64ec_module to select that boundary; do not use a basename heuristic. Native version4 retirement command now requires current-owner identity and NULL callback. Enabled pending/unknown never returns to destructors; zero succeeds. Actual pthread test covers pending nonreturn then drained return. The loader caller remains to be implemented and guest-qualified, including unexpected ABI-error behavior.

## Earlier handshake integrated — windows-242

Wine tracks the actual translator module identity and invokes retirement after its TLS callbacks, before entry. Actual16worker guest fixture passes early closure before main/CRT/allocator destruction, then final retirement before exit. Guest callbacks and parent survival pass; census unchanged. The three tracked callback kinds are now covered in this workload. Separate global JIT-alias pushback and exact-RIP diagnostic callbacks remain outside this registry and require ownership/quiescence audit. Signal-context callbacks cannot safely use a blocking pthread-mutex wrapper. No bank reuse enabled.

## Alias callback retirement — windows-243

Active global alias pushback replaced by owner-specific tracked kind5. Startup replay and later mapping calls use acquisition/release; early retirement now includes alias calls. Concurrency test proves child pending/rejection with parent preserved; actual16worker fixture registers three owners and passes shutdown. Next force parent late mapping after child exit; replay still filters child-owned entries. Exact-RIP diagnostic call remains gated by flag with only zero initialization in inspected native sources; no signal locks or activation added. Other native references still block reuse qualification.
