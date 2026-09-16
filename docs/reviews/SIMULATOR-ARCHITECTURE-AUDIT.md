# Simulator compatibility architecture audit

**The central problem is incomplete behavioral contracts between related APIs, not simply a long list of missing functions.** The adapter has enough implementation to reach original gameplay, but input ordering, presentation lifetime and graphics capability coverage are not yet coherent enough to establish reliable play. These are shared infrastructure problems that can generate many visible symptoms.

This September 14, 2026 follow-up focuses exclusively on getting the existing original DE route working in Simulator. Physical-device deployment is outside its acceptance criteria. It adds executed probes of current source to the previous review; it does not claim that invisible units, box selection or sustained play have been repaired.

## Findings and strength of evidence

| Finding | Evidence | Consequence |
| --- | --- | --- |
| Delayed touch-up can arrive during a subsequent interaction | Reproduced using the exact current `sendGameMouse` method and actual event classes/queue on G5; zero-delay control restores order | Shared input ordering defect; can invalidate capture and interaction ownership |
| Synthetic key-down and physical polling disagree | Reproduced in Simulator **and native AppKit** | Not sufficient evidence of an adapter defect; determine the original consumer before changing polling |
| Hardware keyboard forwarding accepts only five keys | Current source whitelist | General text entry and gameplay keyboard support are absent from this forwarding path |
| Finished-but-uncomposed drawable remains retained and nonterminal | Executed probe includes actual presentation adapter | Retirement coverage gap requiring a real transition/occlusion reproducer; not a proven freeze cause |
| Graphics support is advertised more broadly than implemented | Active source capability override and explicit operation rejection | Every exercised resource operation needs a supported contract; decoder pixel tests alone are insufficient |
| Animation diagnosis lacks the first divergent request | Historical 400 successful SLD parses, no idle/walk; native gameplay control still unavailable | Strong investigation lead, insufficient evidence to choose a rendering fix |

The tests below used only the already booted G5 device. They ran as small command-line fixtures, did not install an application, and did not replace the game or restart a scenario. Native DE was opened to establish a control, reached its main menu, and was closed. No other Simulator was booted. Production source was not edited.

## 1. A confirmed interaction-ordering defect

`sendGameMouse:touch:cancelled:` defaults to delaying every release by 100 milliseconds. Presses and drags are posted immediately. At touch end the view clears `gameTouch`, allowing another interaction to begin before the delayed release is posted. The release has no interaction-generation guard. [1]

The probe extracts the exact method from the current source and includes `EventCompat.m`, `EventQueueCompat.m` and `PointerEventCompat.m`. Fixture objects supply touch coordinates and window ownership; the adapter's event creation and scheduling execute unchanged. This is an adapter test, not execution of the original Feral event consumer.

The input is a press/release at A followed 20 milliseconds later by a press/drag at B. Observed queue order:

```text
Default 100 ms delay:  Down A → Down B → Drag B → Up A
Zero-delay control:   Down A → Up A   → Down B → Drag B
```

This is a concrete causal result: the independent release timer changes the ordering of successive interactions. The default also changes the release timestamp to delivery time. Event numbers retain original generation order, while queue order differs.

The window dispatcher stores a single `deMouseDownTarget`, overwrites it on each down, and clears it on any up. Thus an old up delivered after the next down can clear the newer capture. That downstream consequence follows from source; it was not executed against the original game in this probe. It is a plausible shared contributor to unreliable rapid taps and drag interactions, **not proof that it caused the previously recorded slow box-selection failure**. [1]

The foundational correction is to give each interaction an identity and preserve its down/move/up/cancel ordering across the entire pipeline. If the original consumer needs a minimum observed press duration, implement that as an ordered interaction policy. Do not independently delay only the release. Setting the delay to zero is a useful control, but previous menu sensitivity means it cannot be declared a production fix without original-game validation.

Cancellation belongs in the same contract. The current code synthesizes an offscreen drag and delayed release when UIKit cancels the touch. That needs to release the correct interaction without accidentally completing an order or cancelling a newer touch. Primary selection and a winning two-finger gesture must agree on who owns the stream. [1, 2]

## 2. A rejected theory and a real keyboard limitation

The Simulator probe queued a slash key-down through the exact `DEPostGameKey` implementation. The queued event was type 10, key code 44. `CGEventSourceKeyState(0, 44)` returned false with no physical keyboard present. It was tempting to call this a broken input-state implementation. [1, 3]

A native AppKit oracle then posted a real `NSEvent` key-down into a native `NSApplication` event queue and checked the native CoreGraphics polling API. It produced the same result:

```text
Native:     queued slash key-down; physical/session poll false
Simulator:  queued slash key-down; physical/session poll false
```

Therefore, changing polling merely to eliminate this difference would not be justified by parity evidence. The important unresolved question is whether DE's click-drag-scroll implementation consumes queued key state, physical polling or another translated state. The gesture adapter uses a synthetic slash key to enable scroll mode. Trace that consumer before choosing the fix. This comparison prevents another plausible but unsupported patch. [2, 3]

There is a separate concrete limitation: `DEConnectGameKeyboard` forwards Escape, period, H, F10 and F11, then returns for every other key. `interpretKeyEvents` has a printable-text insertion path, but this keyboard callback does not deliver ordinary letters to it. General keyboard/text behavior cannot be inferred from the success of the five shortcuts. This is source evidence of a missing delivery path, not a new runtime reproduction of the named-save failure. [1]

The right repair scope is a complete input adapter for the declared play sequence: mouse/touch transitions, gesture ownership, keyboard commands and text insertion. Adding one more shortcut leaves that contract incomplete.

## 3. Presentation has an unresolved terminal-state path

`DrawablePresentationCompat.m` retains drawables when presentation handlers are registered. It marks them terminal on observed composition. It can also retire an older immediate-FIFO drawable after a newer one on the same layer composes. Its `setDidFinish:` wrapper forwards the notification but performs no retirement itself. [4]

A probe including the actual adapter registered a presentation handler and delivered a finished notification to a fixture drawable that had not composed. The result was:

```json
{"finished":1,"composed":0,"pending":1,"terminal":0,"callbacks":0}
```

This proves the adapter's behavior for that notification sequence. It does **not** prove that `didFinish` is sufficient evidence of permanent dropping, or that this sequence causes the live game's freeze. Calling the completion handler immediately would be another unsupported approximation. The missing knowledge is the Simulator drawable's valid terminal transitions when no later frame arrives.

The risk is nevertheless specific. If composition never occurs and no qualifying successor composes, the current state remains retained. The existing drop logic depends on future presentation activity, which is weakest during pauses, hiding, layer replacement or exit. Those are the transitions that should be tested next, with the real callback sequence recorded.

There is also an exact-address main-thread condition-variable hook that unlocks, flushes Core Animation and pumps the run loop before returning as a spurious wake. This helps the engine receive composition callbacks while waiting, but permits callbacks to run inside an original engine wait. Its correctness requires checking reentrancy and object lifetime, not just showing that the wait eventually ends. The call-site address must remain tied to the exact binary. [5]

A finite presentation contract should account for every acquired/submitted drawable, permit exactly one justified retirement, and drain pending ownership at known lifecycle transitions. It must distinguish GPU completion, composition and dropping. Arbitrary completion timers would hide the problem rather than establish correctness.

## 4. Graphics tests cover a component more thoroughly than its integration

The BC decoders have useful direct tests: decoded values, private-buffer uploads, strides, cropped blocks, destination boundaries and typed formats. That is genuine evidence for the conversion algorithms. The inspected non-ignored tests do not reference `DEBC4Texture`, `DEBC4Encoder`, `DEInstallBC4` or `DEExperimentalBCSupport`. Private historical experiments may provide additional coverage; the repository tests inspected here do not constitute an integration suite for those objects. [6]

The active graphics path does substantially more than decode pixels:

- It overrides the BC support query when the software profile is enabled.
- It substitutes uncompressed backing textures while reporting a logical compressed pixel format.
- It maps texture views and shader/resource bindings through proxies.
- It ends a blit encoder, inserts a compute decode, then creates a replacement blit encoder.
- It handles adapter-created view lifetimes for unretained command buffers.
- It adapts alpha render targets, pipeline descriptors and sample views.
- It represents some cube-array storage while explicitly rejecting cube-array shader sampling.

Those transformations interact. A correct decoder does not establish that every path binds the right view, retains it long enough or preserves the command sequence. The capability override is broader than the implemented operation subset: 2D sampled BC is supported in qualified cases, while other descriptors and transfers explicitly stop. That can be a workable title-specific strategy, but the actual game's use must be enumerated and validated. [7]

The adapters mostly stop explicitly on unsupported operations. That is preferable to silent fabricated success. The problem is not evidence that every placeholder lies; it is that successful paths still need cross-operation guarantees. Sixteen diagnostic AppKit class declarations in the active source are not sixteen mandatory rewrites: several concern optional desktop UI. Count operations required by the pinned game's ordinary workflows, not class names. [8]

The next useful graphics test should replay a captured engine resource sequence through the actual adapter: allocation, upload, views, binding, submission, readback and retirement. Compare its pixels and lifetime behavior against a native reference. Keep the existing decoder tests underneath it.

## 5. Invisible units remain an open branch, not a reason for more speculative GPU changes

The selected-unit ring/portrait evidence establishes that the simulation and some unit UI state exist. The parser evidence establishes 400 successful observed SLD calls, including villager death animations and excluding idle/walk records. It does not establish whether another cache, shape format or loading route supplies live animation data. [9]

The historical `immediate-touch-1` log contains 15,081 lines. Of these, 10,909 are drawable-terminal messages; it has 400 SLD parse records, 208 resource-file records and no AIO records. The absence of AIO records does not establish that no asynchronous I/O occurred: that trace is separately gated. Large output volume has not yielded complete coverage of the suspected causal path. [9, 10]

This distinction matters. Repeating that trace can reproduce the symptom without revealing why it occurs. The missing observation is the live unit's graphic/animation choice and the first requested shape before the parser. Record the chosen ID, request, cache decision, resolved resource, completion and first atlas/draw result. Compare the same save and settings on native DE.

The fresh native control attempt reached the original main menu. Automated click and keyboard attempts did not establish gameplay entry. The native app was then quit and process absence verified. Native-versus-Simulator gameplay comparison remains unqualified; this report does not label native rendering broken or claim an animation root cause.

## 6. What should change in the engineering approach

The audit supports a focused restructuring of the compatibility work, **not an engine rewrite and not a move away from Simulator**. Keep the original game and working platform bridge. Replace symptom-led iteration with four explicit contracts:

| Contract | First decisive evidence | Completion criterion |
| --- | --- | --- |
| Input delivery | Rapid A/B interaction replay and original-consumer trace | Ordered gestures, stable capture, usable text and commands across one ordinary session |
| Presentation lifetime | Real callback sequences during pause/hide/return/layer replacement | No unjustified completions, no stranded retained drawables, bounded waits |
| Resource compatibility | Engine resource-operation replay through actual proxies | Reference pixels plus valid ownership/order for every exercised operation |
| Animation loading | First native/Simulator divergence for a known live unit | Idle/walk/work/attack/death render after cold load and save reload |

Each contract needs a small record of assumptions, native behavior, supported cases and explicit exclusions. The same representative session must exercise all four: cold launch, load, select, drag, pan, order, build/train, fight, save, quit and reload. Passing this session repeatedly is the integrating milestone. A growing collection of unrelated green tests is not a substitute.

The most immediate implementation candidate is the interaction-ordering repair because its defect and controlling variable are now reproduced. It should be tested at the original consumer before installing a new visible candidate. Presentation retirement requires one further runtime observation before its correction can be chosen. Animation loading requires the missing differential trace. These are distinct confidence levels, not three equally certain fixes.

There is no evidence yet that one root cause explains all symptoms. There **is** evidence that multiple symptoms can arise from a few shared adapter contracts, and that the current tests leave those contracts underqualified. A bounded effort to qualify them is better justified than another sequence of UI or format patches. If the operation set continues expanding across repeated runs of the same fixed gameplay sequence, that is evidence against convergence; if it stabilizes and the contract tests pass, it supports continuing this route.

## Evidence and reproduction

Private artifacts are under `generated/architecture-audit-20260914/`:

- `build-probe.py` extracts current adapter methods and builds `InputProbe`; `extracted-source.json` and `source-hashes.json` record identity.
- `input-result.json` and `input-zero-delay-result.json` record default and zero-delay runs; their stderr files preserve event logging.
- `NativeKeyOracle.m` and `native-key-result.json` record the native AppKit counterexample.
- `PresentationProbe.m` and `presentation-result.json` record the exact adapter's finished-without-composition behavior using fixture notifications.
- `historical-log-summary.json` records counts and the historical input filename.
- `appkit-warnings.log` records syntax checking of the actual current AppKit translation unit. It compiled successfully; its warnings do not establish runtime correctness.

Probe dependencies are the local Xcode toolchain and the already booted designated G5. No probe result constitutes full-game acceptance. Initial probe build omissions were corrected in the fixtures: CoreGraphics linking for the input probe and UIKit declarations/linking for the presentation probe. Production adapter code was unchanged.

Source references:

1. [Window and input adapter](../../port/de/WindowViewCompat.m): `sendGameMouse`, touch termination/cancellation, `sendEvent`, `DEPostGameKey`, `DEConnectGameKeyboard`, `interpretKeyEvents`.
2. [Native gestures](../../port/de/NativeTouchGestures.m): order, slash-held pan and wheel-based zoom.
3. [Pointer/key polling](../../port/de/PointerEventCompat.m) and [event queue](../../port/de/EventQueueCompat.m).
4. [Presentation adapter](../../port/de/DrawablePresentationCompat.m): pending ownership, composition, successor retirement and finish wrapper.
5. [Main-thread graphics wait](../../port/de/MainThreadGraphicsWait.cpp).
6. [Basic GPU decoder tests](../../tests/de_bc_basic_gpu_test.m), [typed GPU tests](../../tests/de_bc_typed_gpu_test.m) and [native decoder oracle](../../tests/de_bc_native_oracle.m).
7. [Metal device adapter](../../port/de/MetalDevicesCompat.m), [texture/encoder proxy](../../port/de/BC4TextureCompat.m), [alpha adapter](../../port/de/AlphaTextureCompat.m).
8. [Diagnostic class policy](../../port/de/UnsupportedBoundary.h); private `generated/mac-de-simulator-375/AppKit.m` active translation-unit declarations.
9. Private `generated/render-audio-20260912/REPORT.md`, `sld-results.json`, and `generated/mac-de-simulator-375/immediate-touch-1/game.stderr`.
10. [File/AIO tracing](../../port/de/RuntimeFileTrace.m) and [SLD parser trace](../../port/de/SLDParseTrace.h).
