# Physical-iPad route: verify the existing fallback first

Source audit, windows-263. No connected physical iPad or device execution evidence.

The earlier claim that a new device JIT backend is necessarily required was too strong. The current single-address AgePad service rejects non-Simulator targets, but its FEX caller explicitly handles rejection by selecting a pre-existing dual-mapping route. Whether that route works with the current signed-container candidate must be tested.

| Boundary | Current source | Device evidence needed |
|---|---|---|
| Obtain executable memory | `app/Madeira/StikJITHelper.swift::allocatePool` requests debugger-backed memory, then maps a writable alias | Actual target iPad, signing and debugger setup; allocation and execution succeed |
| Publish pool | `ContentView.swift` sets `WINE_IOS_JIT_RX`, `WINE_IOS_JIT_RW`, `WINE_IOS_JIT_SIZE` before Wine starts | Values belong to the same live mapping and reach the selected launch path |
| Select FEX backend | `FEX/Source/Windows/ARM64EC/Module.cpp`: successful InitAgePadJit uses offset0; otherwise reads RX/RW and sets DualMap::WriteOffset | Fallback selected, nonzero correct offset, no missing-pool message |
| Allocate translated code | `FEXCore/Utils/AllocatorHooks.h` uses normal Windows allocation when AgePad service is disabled; `virtual_ios.c::NtAllocateVirtualMemoryEx` handles EC_CODE from the legacy pool | Code allocation stays within the actual pool and uses the matching alias for writes |
| Execute and update code | FEX DualMap emit/write/flush paths | Small real translated x64 workload plus code-change/reexecution and drawing; device results, not Simulator counters |
| Start the original game | Original Windows Steam DE installation, isolated launch | DE startup/menu or exact legitimate Steam dependency; then actual skirmish frame times |

Do not merely remove the non-Simulator rejection and call macOS MAP_JIT APIs on iPad. Do not feed a shared RX/RW pool to both independent allocators without proving ownership boundaries. Do not treat comments about upstream device runs as results from this workspace/user's iPad.

Device build update, windows-267: all required native device archives and the isolated unsigned iphoneos app now compile/link successfully. Executable platform IOS, minimum18.0. Corrected a Simulator library search-path leak in the isolated project generator. Evidence: generated/device-gate-267/result.json. Update268: all14 root PE containers now build for IOS with preserved-code verification; generated/device-runtime-probe-268 contains the separate unsigned app. The device-specific setup flag configures signed paths, then the existing Enable JIT / x64 DX11 cube actions use the normal dual-map allocation route. No child banks or hardware execution yet. This is build evidence, not execution.

Provision the prepared device runtime probe using user signing inputs, then test on hardware. Preserve the installed Simulator candidate. Signing and physical-device execution await the user's hardware/team/JIT inputs. First try the existing route; introduce a new backend only if an observed incompatibility requires it. Teardown work is parked pending a concrete engine/device blocker.
