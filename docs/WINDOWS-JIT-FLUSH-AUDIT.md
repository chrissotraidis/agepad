# Simulator generated-code flush audit

The live Windows Steam sample in windows-022 places most sampled Windows execution-thread stacks in the full-region flush at native `agepad_jit_service` operation 3. This is a startup cost, not a game FPS measurement.

The current outer write scope flushes `[agepad_jit_pool, agepad_jit_pool + agepad_jit_used)` before restoring executable mode. Do not remove this merely because several emitters also flush their output.

## Source findings, 8 September 2026

- FEX `Interface/Core/JIT/JIT.cpp` flushes emitted blocks using `NtFlushInstructionCache(CodeBegin, CodeOnlySize)` on FEX_IOS_HOST. Direct and indirect linker patches flush one instruction through `IOSFlushOneInstr`. Delinking paths have similar explicit flushes.
- `Interface/Core/Dispatcher/Dispatcher.cpp` still uses inline ARM64 cache-maintenance instructions for its Windows/iOS branch. It does not use the same native flush route as block emission. Changing the outer flush requires qualifying dispatcher publication too.
- `Utils/ArchHelpers/Arm64.cpp` backpatches unaligned instruction sequences and calls `ClearICache` on eight-byte ranges. The scope around the Windows exception helper must still restore executable permissions before returning to guest code.
- `ContextImpl::CompileBlock` opens its write scope before lookup. However, work before lookup is not purely observational: Mono bridge activation can invalidate code and `SyscallHandler::PreCompile` invokes `ProcessPendingCrossProcessEmulatorWork`. Simply moving the scope after the cache-hit return could expose invalidation/delinking writes without write permission.
- `ExitFunctionLink` can compile a missing block inside its scope. Splitting compiler/linker scopes could introduce two large flushes where the nested scope currently requires one. Measure rather than assume that a narrower lexical scope improves startup.

## Next admissible experiment

Inventory executable writes, including invalidation/delinking and dispatcher setup. Make each mutation report its exact dirty range to a scope that preserves nested write permissions and native cache invalidation. Retain a conservative fallback for unqualified paths. Test fresh emission, repeated linking/delinking, unaligned backpatching and overlapping children before interpreting Steam startup timing. No such optimization is implemented or accepted yet.

The active x64-console-host Steam run must be observed independently; a slow observation is not grounds to declare it terminal.


## Bounded linker experiment prepared — windows-025

The opt-in implementation covers only ExitFunctionLink. Four-byte native flushes remain in both instruction-patch paths, with status checks; nested conservative scopes force the normal full-region flush. Other code-write paths are not generalized to dirty ranges. Counters and a runner flag are available, builds pass, and runtime regression remains pending. The broader dirty-range experiment above is still unimplemented.


## Runtime regressions — windows-027

Opt-in path passes CPU/Win32, overlapping-child, and D3D11 clear/draw/readback tests. CPU counters establish at least one explicit-only completion. All three guest results are exit 0. These bounded tests do not establish universal cache correctness or throughput; actual Steam retry windows-steam-link-flush is pending observation. Default remains off. See checkpoint 027 for exact logs.
