# External review ingestion and revised priorities

Ingested 2026-09-09, windows-218. Original report preserved unchanged at EXTERNAL-DEEP-DIVE-REPORT.md (SHA256 `ef877a17e6edc64ef93399189b408bb157bf53de161fe59013f483507f863e7d`). Report snapshot predates native214correction and live215candidate. Do not mistake its current-state descriptions for the latest run.

## Verified and accepted

- Finite retained process banks are a structural limit, separately demonstrated in209/212. Safe quiescence and teardown must precede reuse; no cap increase as a substitute.
- CallRetStack reserve/commit are unchecked. ARM64EC ThreadInit calls it unconditionally; Wine loader.c:5602 discards secondary-thread initialization status. Failure handling must cover both layers and partially constructed resources. The report's pseudocode is a design sketch, not a ready-to-apply patch: validate actual ownership, mutexes, CRT setup, thread registration, segment ownership, and destructor order first.
- LookupCache compares against -1 despite an allocator path that can return NULL. Correct failure contracts must span construction, not just add a logging assertion.
- Crypt32 rootstore.c loops until ANY nonzero enum status, then enters root deletion. This supports the review's OOM concern. Its extracted native test demonstrates EOF/OOM statuses; it does not itself execute PE deletion. Rootstore source supplies that second part of the argument. Harden completion/error handling before permitting PEB reuse.
- Two stale native callret diagnostic bounds remain in signal_arm64_ios.c (8MiB geometry versus16MiB literals). They need shared/authoritative geometry; do not treat old diagnostic bounds as proof of safety.
- Rechecked device inventory: no devices. Rechecked ref: no AoE2DE_s.exe. Physical-device execution and direct WindowsDE tests cannot run yet.

## Accepted with limits or deferred verification

- 80MiB thread-placement stride is a useful measured pattern, not an unsampled live-reservation accounting result. Cumulative vnames minus other cumulative classes cannot establish a precise live-byte attribution. Use result-aware ownership census if needed to choose an arena/teardown design.
- Simulator VA does not establish physical-device VA/footprint. Accept early device probes; do not turn an SDK constant or another phone's footprint into the user's iPad limit.
- Review's definitive distribution/legal exclusivity statements require separate primary-source verification and appropriate qualification. Do not repeat them as proven or infer a user's signing team, device RAM, or acceptable deployment workflow.
- Report assertion that relevant Wine files are absent from canonical patches is too broad: native signal_arm64_ios.c changes are included in Madeira's canonical patch, reverse-checked214. Exact stale upstream literals may be inherited unchanged; audit reproducibility per file/commit rather than equating an absent diff hunk with absent source.
- Suggested 30/60minute Steam acceptance windows are proposed engineering gates, not prior user instructions. Preserve the already offered live QR attempt. A bounded authentication attempt does not certify long-session stability.
- No blanket approval for process-wide cleanup from process_exit_wrapper: there may still be native threads/callbacks. Prove quiescence with source-owned lifecycle tests first.

## Revised execution order

1. Preserve live215session for the user's QR attempt. Read-only observation only; avoid another diagnostic-only Steam restart unless discriminating evidence requires it.
2. Implement allocation failure propagation end to end, including controlled failure injection in a source-owned threaded Windows test. Pass means no dispatch with partial CPU state, no null fault, bounded cleanup, explicit failure status, and surviving parent process for a secondary-thread failure.
3. Harden root enumeration completion semantics and lifecycle identities before reuse. Test injected OOM/partial enumeration and a recycled owner against PE-side deletion behavior.
4. Audit lifecycle accounting and teardown, then test repeated guest/thread creation before recycling banks. Account for reservations and resources by owner; no blind freeing or guessed baseline from sampled call_balance.
5. Device gate starts as soon as hardware/signing are available. Prepare probes independently; no Simulator result can close this gate. Explicitly compare upstream single-process CEF configuration as a hypothesis rather than assuming it works on the target.
6. WindowsDE input immediately opens direct original-engine startup testing up to its legitimate Steam-required gate, independently of full-Steam soak completion. Never patch ownership/anti-tamper checks to claim acceptance.
7. Genuine authenticated DE gameplay, measured sustained frame times, device execution, touch controls, and real retail multiplayer remain the full objective. Determinism tests require actual available replay/checksum mechanisms; do not assume DE exposes the proposed per-turn checksum API.

## Iteration discipline

Each experiment declares a falsifiable hypothesis and discriminator. At most two diagnostic-only iterations per hypothesis before a behavior change or written reassessment. After three iterations without new discriminating evidence, park that hypothesis and advance another open gate. No automatic restart from timeout. User sign-in waiting and missing hardware/files remain explicit dependencies, not accomplishments. Preserve reference installations/saves and the one-Simulator constraint. Do not delete private generated artifacts merely to meet the review's suggested disk cap.

Current evidence ledger: ../WINDOWS-DE-GATES.json. This response, not every proposal in the external report, controls the revised priorities.

## Follow-through checkpoint — windows-224

The original report remains unchanged. Targeted secondary-thread reservation and commitment failures now pass actual translated Windows recovery probes (222/223): failed worker never enters guest code, exits STATUS_NO_MEMORY, the parent survives and a subsequent worker completes. Normal injection settings were restored. This does not close allocation geometry, broader constructor failures or finite-resource lifecycle.

PE root import now distinguishes incomplete enumeration from EOF; extracted-function tests and the Crypt32 build pass. Native empty initial root load no longer latches success; enumerator retry tests and native build pass. These root changes are not deployed in the preserved Steam session and are not yet guest integration evidence.

Additional source audit: server_ios.c::ios_register_proc_socket increments ios_proc_socket_count before checking the 64-entry capacity. ios_proc_socket_index scans that count without clamping it. Therefore a 65th registration can make later lookups read beyond the array. The registration function returns void and server_init_process_child proceeds after rejection; missing-owner lookup falls back to the root master socket. These are source-derived boundary defects, not observed failures of the current Steam session (its 16-bank cap is hit earlier).

Next bounded experiment: test capacity rejection with more than 64 owners, including no out-of-bounds lookup and no fallback to the parent's socket. Audit early-child failure cleanup before implementing it: process_exit_wrapper's missing-owner branch closes the root socket, and fatal_error uses pthread_exit rather than the usual process-exit shim. Do not solve this by merely increasing the cap or reusing slots: ios_process_exiting_ptr exposes a raw slot pointer, so reuse requires proven lifetime/quiescence. Registry publication also needs consistent synchronization.

No runtime modification or Simulator action in224. Device and Windows DE gates remain open; the last inspected QR requires refresh before a new user attempt.

## Allocator reclamation checkpoint — windows-237

Experimental main-state cleanup followed by normal CRT detach and whole-allocator finalization passes the actual two-child x64 TLS/DLL fixture. First-child occupied-band growth is16,785,408 bytes; second-child incremental growth is4,096 bytes, versus184,578,048 bytes per child in236. This is constrained guest VA evidence, not device RSS or complete lifecycle correctness. Both experimental build options and common root/two-bank packages were restored to normal afterward; preserved Steam was not restarted.

The review's finite-resource priority remains active: qualify higher concurrency, retire native callbacks/registries with explicit lifetime guarantees, then test bank reuse. Increasing the bank cap would not resolve the ownership problem. Device and direct Windows DE gates remain dependent on missing inputs. See WINDOWS-DE-STATUS.md and the gate ledger for evidence and remaining limits.
