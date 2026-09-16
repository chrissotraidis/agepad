# FEX frame lifetime boundary — windows-256

## Finding

Native registry leases pin a TEB identity under the intended native retirement protocol. They do not participate in FEX frame destruction. Deferred TEB cleanup alone cannot close this gap.

Authoritative source:
- `worktrees/madeira/FEX/Source/Windows/ARM64EC/Module.cpp::ThreadCPUArea`: StateFrame aliases EmulatorData[0]; ThreadState aliases EmulatorData[1]. These are ordinary pointer references.
- `DestroyRegisteredThreadState`: removes the FEX thread entry, drains the separate FEX sweep registry, deletes frontend/segment data, destroys call/return state, calls CTX->DestroyThread, releases emulator stack, then clears CPU-area frame/thread/dispatcher/stack pointers. No native registry drain surrounds this sequence.
- `worktrees/madeira/wine/dlls/ntdll/signal_arm64ec.c::NtTerminateThread`: invokes pThreadTerm before syscall_NtTerminateThread. pThreadTerm is declared void; returning a failure from FEX alone cannot stop this wrapper proceeding to native termination.
- `worktrees/madeira/build/ntdll-unix/thread_ios.c::exit_thread`: joined-native retirement happens later, when another exiting thread reclaims prev_teb.
- `signal_arm64_ios.c`: native Mach diagnostics follow request_lease.value.teb -> +0x1788 -> CPUArea+0x30 and dereference frame fields (state_rip_q, fex_state_pre). RSP signal diagnostic similarly follows diagnostic_lease to frame_r. Other diagnostic reads use mach_vm_read_overwrite; readable memory is not identity/lifetime proof.

## Runtime corroboration and limits

`generated/steam-256-frame-lifetime-order.json` matches all15 joined-reclamation TIDs in run255 to earlier [thr-term] deinit records. The inspected source emits deinit after state destruction. Every paired deinit precedes the native before-free marker. This establishes the separation in the actual fixture; it does not demonstrate a concurrent use-after-free or identify one as the cause of any prior crash.

## Revised implementation boundary

1. Separate FEX-state access from native TEB/port access. Closing all native Mach identity access before PE ThreadTerm completes could prevent the remaining teardown code from servicing its own exceptions. Do not move the joined-retirement hook earlier indiscriminately.
2. Add a per-identity state-access domain that native consumers acquire before following FEX state. Frame teardown closes this domain and drains existing users before destroying anything they reference. Missing/closing state skips optional diagnostics; required exception behavior needs explicit no-state handling.
3. Use the existing validated PE-to-native bridge design for the state-close command; never call raw ARM64EC export RVAs from native C. Resolve target identity/ownership explicitly, including cross-thread termination.
4. Do not wait on readers while holding ThreadCreationMutex or another lock a reader needs. Define failure propagation through the Wine wrapper: its current void callback cannot communicate a refusal. Pending/unknown teardown must retain state without silently running a freeing path, including CRT whole-allocator finalization at process exit.
5. Test a native state reader held across the requested FEX teardown boundary, release it, then prove destruction happens afterward. Cover self exit, cross-thread exit, final worker and process detach. Keep the separate TEB retirement test and existing guest fixture as regressions.

Clearing CPU-area pointers before freeing would reduce one exposure window but would not protect a pointer already captured by a reader. A source-order patch alone is insufficient. Native Mach rights, deferred TEB reclamation and bank recycling remain later gates. No Simulator mutation or build changes in256.

## Independent FEX-state reference foundation — windows-257

Previous256 produced a concrete ordering/contract finding. Added state_access to each native identity, independent of native CLOSED/WRITING/count. ios_state_lease_for_teb owns a native lease first, then acquires a state count in one nonblocking CAS attempt. Failure releases native ownership. Scoped cleanup releases state before native. ios_state_retire requires a held native identity and closes only state acquisition, reporting pending count. Identity publication refuses nonzero state_access, so closure cannot be silently reset. No runtime consumer or FEX teardown bridge uses these helpers yet; this is preparation, not active frame lifetime protection.

New actual-helper pthread test holds a state reader, closes state, verifies another state reader rejects while native port lookup remains available, then drains on reader completion. Verifies nested native count, unchanged identity, refused replacement after state closure, and eventual separate native retirement. All eight native lifetime harnesses pass ASan/UBSan. Native Simulator build34 succeeded,0 failed; canonical patch reverse-check and changed-source whitespace check pass. No app relink/install or Simulator operation.

Next migrate native frame-reading scopes to state leases and define bridge failure behavior before connecting pre-destruction closure in FEX. The state helper result alone does not permit freeing: unconverted consumers, void ThreadTerm callback, process allocator finalization and abnormal exits remain unresolved. No frame-domain reopening, native slot/Mach-right recycling or bank reuse implemented. FullDE/device/FPS/touch/authentication/multiplayer remains unproved.


## Native frame diagnostics acquire state references — windows-258

Previous257 made progress with independent state-reference helpers. The two audited Mach TEB->CPUArea->frame chains (state_rip_q and fex_state_pre, including later frame fields within the same scope) now own scoped ios_state_lease references before dereferencing CPUArea. Missing/closed/busy acquisition leaves frame null. The signal RSP diagnostic now uses a state lease with its nested native lease instead of native-only protection. Normal C scope exit releases state then native. No teardown closure caller is connected yet.

Extended state-lifetime test source checks the two Mach pointer chains are gated by held state and cleanup scopes, plus the signal migration. Actual concurrent helper coverage and all eight native lifetime tests pass ASan/UBSan. Native build34 succeeded,0 failed; canonical Madeira patch reverse-check and whitespace check pass. No app relink/install or guest/Simulator operation. Source integration checks do not prove actual fault branch execution or all scope-unwinding behavior.

Remaining coverage includes raw register-derived frame pointers and mach_vm_read_overwrite diagnostic samples (e.g. fault census reads x28+0x18). A readable address does not prove current state ownership. Continue that audit and introduce a validated PE/native state-close/drain bridge with explicit pending/failure handling before FEX destruction. Whole-process allocator cleanup must honor that result. Do not claim frame lifetime solved, enable state reopening, or recycle banks from these reader changes. FullDE/device/FPS/touch/authentication/multiplayer remains unproved.


## Owner-checked native state-close boundary — windows-259

Previous258 migrated three readers. Audited existing PE/native callback command: version4 validates current PEB, and pending process callbacks take a nonreturning native quarantine path before destructors. This differs from Wine's void pThreadTerm callback; an ordinary returned busy status there is ignored.

Added ios_state_close_for_owner(target_teb,owner) in native signal TU. Acquires exact native identity, compares TEB->Peb while held, then closes only state acquisition. Returns0 for closed/drained, positive reader count for pending, UINT64_MAX for invalid/missing/unknown. Scope cleanup releases native reference on every return. No waiting, freeing, native closure or recycling. Caller must supply an independently validated PEB; this internal helper is not authentication of an arbitrary external caller. No PE ABI/teardown caller is connected yet.

New actual-helper test covers null/missing target, null/mismatched owner leaving state unchanged, pending reader, rejection of new state readers, idempotent drained query, and continuing native lookup. Existing owned-port harness's mock TEB includes Peb for compilation of the new adjacent helper. All nine native lifetime harnesses pass ASan/UBSan; native build34 succeeded,0 failed; canonical Madeira patch reverse-check passes. No app relink/install/Simulator changes.

Next define the explicit PE/native command and its non-freeing pending/error path before connecting FEX teardown, including abort cleanup and main/CRT allocator finalization. Do not merely change the void callback return type without compatible negotiation. Remaining raw-register readers still require audit. FullDE/device/FPS/touch/authentication/multiplayer remains unproved.


## Explicit native state-close command — windows-260

Previous259 added/tested owner-checked close helper. Existing unixcall_ios_register_hold_release now accepts command6 in its existing sized argument layout; versions1–4 retain their behavior and5 stays invalid. For command6 only, callback field carries target TEB (never invoked as code), peb must match current native TEB's PEB, and target must be nonnull. The helper separately validates target ownership. AGEPAD_RETIRE_FEX_STATE must equal1; otherwise STATUS_NOT_SUPPORTED is returned, not success. Unknown target returns STATUS_INVALID_PARAMETER, a positive held-reader count STATUS_PENDING, and drained0 STATUS_SUCCESS. A future PE caller must require exact zero: NT_SUCCESS(STATUS_PENDING) is true and is insufficient. Command performs no wait, destruction or native retirement. No PE caller or runner option is connected yet.

Actual dispatcher test covers disabled/unset0, wrongsize, reservedversion5, missing currentTEB, wrong caller owner, nulltarget, helperunknown, pending anddrained; rejected callers never reach the close helper. Helper outcomes mocked here; actual helper owner/count tests were259. Existing callback-retirement, alias-ownership and loader-retirement tests pass ASan/UBSan. Nativebuild34 succeeded,0 failed; canonicalMadeira patch reverse/whitespace checks pass. No app relink/install/Simulator operation.

Next add a compatible PE caller with explicit non-freeing pending/error handling across normal, abort and main teardown before FEX destructors. Caller must not rely on the void pThreadTerm return contract. Keep process-wide allocator finalization blocked when any state teardown is retained. Remaining raw-register readers and guest held-reader qualification stay open. FullDE/device/FPS/touch/authentication/multiplayer remains unproved.


## Versioned PE binding and unified pre-destruction guard — windows-261

Previous260 provided native command6. Wine now resolves BTCpu64IosSetStateClose through its existing arm64ec_redirect_ptr machinery and supplies a PE callback that constructs sized command6 with current PEB and target TEB. FEX setter accepts ABI1/non-null callback, refuses a different rebinding and returns0x261. This is a PE callback path, not a native call to a raw EC export RVA. Actual cross-boundary invocation is not yet guest-qualified.

New AGEPAD_TEST_STATE_RETIRE build option defaultsOFF. Enabled unified DestroyRegisteredThreadState calls AgePadDrainNativeState after ScopedThreadCleanup begins and before ThreadCreationMutex/map erasure or destruction. ThreadCPUArea now retains its owning TEB. Pending status polls the same callback with Sleep(1); only exactzero proceeds. Missing callback/unsupported/error sets a process-scoped blocked flag and never returns into void ThreadTerm or CRT teardown. Post-CRT allocator finalization additionally requires no blocked flag. This is conservative retention; indefinitely pending readers or loader-lock dependencies can stall and are not resolved by this guard.

Actual extracted C++ guard test compiles optionON and verifies pending twice thenzero, incompatible binding rejection, nonreturning error behavior (test intercepts Sleep via longjmp), blockedflag, and source order before locks/destruction. Wine wrapper argument/binding is source-checked. Wine ntdll PE build passes after using repo LLVM-MinGW PATH (first attempt could not find compiler, not a source error). FEX default and all-three-options-enabled builds pass. Saved enabled artifact and hash under generated/steam-261-state-retire-build; all three options restoredOFF and normal FEX rebuilt. Wine/FEX canonical patches synchronized/reverse-checked. No common container/bank packages, app or Simulator changed.

Next add explicit probe-runner state-retirement setting, package current Wine and enabledFEX in the isolated probe, and qualify binding plus before-destruction markers in the existing16worker fixture. Native AGEPAD_RETIRE_FEX_STATE=1 is required for enabledFEX; disabled native support intentionally cannot masquerade as drained. Remaining raw-register readers, forced held-reader guest tests, process-wide state coverage and reuse remain open. FullDE/device/FPS/touch/authentication/multiplayer unproved.

