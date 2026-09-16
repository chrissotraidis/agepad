# Controls status and acceptance

The user Simulator demo is an older engine slice. It does not establish usable iPad controls. The newer toolbar has not been installed in that session; an earlier restart question remains unanswered because current tutorial progress cannot yet be saved.

| Interaction | Current implementation/evidence | Required next validation |
|---|---|---|
| Selection versus orders | Tap/box selection and explicit Order target; movement, gathering and combat observed in earlier Simulator slice | Repeat with current toolbar, including box selection near HUD and cancellation |
| Camera | Minimap navigation observed on Simulator; Pan/Select toolbar drag verified with Mac pointer, including final release delta | Actual touch drag, map edges, selection retention; zoom implemented in touch-45; extend picking to slopes, edge-scroll box selection and all layouts |
| Cancel and pause | New Cancel clears placement/selection; Menu opens existing pause dialog; Mac pointer checks pass | Touch placement cancellation, modal suppression and resume |
| Idle villager | New Idle selects and centers eligible owned worker; native selection tests and Mac pointer checks pass | Actual touch repeat |
| Unit commands | Existing ActionPanel handles Stop, stances, attack-ground, garrison, building pages and unit deletion | Inspect each supported command in real fixtures, readable labels and reachable touch targets; do not infer behavior from icon presence |
| Production and research | Original panel supports queue actions; earlier Simulator slice exercised training/research/cancel | Queue readability, repeated commands, exact cancellation target, touch layout |
| Groups and appended orders | Ten control groups implemented; shared assign/append/recall/extend behavior passes17 actual-data checks. Panel assign/recall and Ctrl+number/number verified on Mac in touch-43. Queue button and Shift-right-click now append contextual commands (touch-44);14 actual-data checks and live Mac Queue movement pass | Actual touch and multi-unit UI checks, group persistence, held-Shift input and touch queue checks |
| External keyboard/mouse | Mouse gameplay exists; Engine keyboard handler exposes arrow-key camera movement, result Return, and control groups | Add deliberate keyboard mappings to the same command paths; document and test modifiers, shortcuts and pointer behavior separately |
| Interrupted gestures | Adapter cancels on second contact and focus loss; automated event checks pass | Real multitouch/background checks; no stale order on return |

Implementation priorities: expose a coherent contextual command panel and selection/order modes; groups and appended orders; zoom with correct world picking; actual touch economy/combat pass. Every mandatory action must be reachable without a keyboard. External keyboard/mouse support is a separate requirement and does not replace touch acceptance.

Source audit: src/Engine.cpp, src/ui/ActionPanel.cpp, src/mechanics/UnitManager.cpp and src/mechanics/UnitActionHandler.cpp in worktrees/freeaoe. PRD requirements: AgePad-PRD.md, minimum RTS controls. G5 only records selected mechanics; G8 remains open.

## Control groups (touch-43)

Open Groups. Set replaces a numbered group with the current owned selection; Add adds selected units to an existing group. Recall selects a group and centers its first available unit. Extend adds the group to the current selection. The count shows currently available members; garrisoned members remain assigned and become available on ungarrison. Empty/enemy-only assignment preserves an existing group. Close dismisses the panel. Outside panel taps are suppressed.

Keyboard: Ctrl+1 through Ctrl+0 assign; Ctrl+Shift+number adds members; number recalls; Shift+number extends selection. Escape closes the group panel. Keyboard recall does not move the camera. Mac UI tests verify basic assignment/recall, while the native test verifies add/extend and membership filtering. Neither substitutes for actual iPad touch evidence. Groups are not saved across sessions yet.

## Queued orders (touch-44)

Select units, use Order for an immediate command, then Queue and a target for the next command. Queue is one-shot and shows Target + while armed. Order switches back to replacement targeting. Cancel disarms targeting and clears selection; the unit Stop command clears active and queued actions. Shift-right-click uses the same append path, with left/right Shift tracking cleared on input interruption. Holding Shift through a group selection keeps the modifier active.

Actual-data tests cover two waypoint completion, queued context attack through damage, replacement, idle append, stop and enemy exclusion. Mac pointer UI verifies travel toward the first target then return to the queued second target, mode switching and cancel. Held-Shift pointer and actual iPad touch remain unverified. Building placement, explicit attack-ground/garrison target modes and production queue controls have separate paths; these have not gained Shift/Queue placement semantics in this change. Failed actions still clear remaining actions under existing engine behavior; wider failure/recovery handling remains open.

Pending ActionMove objects no longer embed two full-map bitsets (about36MiB per action). Pathfinding caches allocate on first use. Active-path cache size remains large; army performance and memory acceptance are not established. Movement save/restore regression passes16 checks after this change.

## Zoom (touch-45)

Touch +/- controls, mouse wheel over the world and two-contact pinch share a0.5x–2x world zoom path. HUD dimensions stay fixed. Pointer input, placement previews, hover targeting and Pan deltas use the same world-coordinate conversion. Wheel/pinch keeps its world anchor under the pointer/midpoint (subject to map-edge clamping). Pinch cancels pending single-contact gestures; a third finger or crossing into the HUD blocks it until all contacts lift.

Eleven pinch adapter checks and the existing single-touch regression pass. Live Mac tests cover enlarged selection/move/pan/house placement, reduced selection/move, both zoom limits, minimap rectangle changes and wheel anchoring. Zoom-out initially exposed a reversed terrain texture-size comparison; fixed and repeated on a new artifact. Actual multitouch, terrain elevations, edge-scroll box-selection at nondefault zoom, memory/performance and layout/safe-area coverage remain open. The user Simulator still runs the older tutorial build; AgePadTouchZoom45.app is only a packaged candidate.

## Simulator touch validation (touch-46)

A separate temporary iPad Air11 M4 Simulator (65031498-6AE9-4575-A28E-3052E0736DA4) now provides actual touch-event evidence for Idle, Pan, group Set/Recall, Queue movement, +/- zoom, enlarged selection, house placement, Menu/Cancel and return home. It used a fresh profile and11777 hash-verified files, preserving the original user tutorial. It is shut down after testing; its data can be reused for future isolated runs. The old restart question no longer blocks touch engineering.

This uncovered two mobile defects missed by Mac pointer checks: menu layout used physical rather than logical dimensions, hiding Cancel beneath the HUD; and Quit stopped rendering but left a frozen mobile frame. The menu now uses logical coordinates,44-point buttons and draws above the HUD. The iOS action is Return to home; home->fresh original tutorial->first flag advancement->home passes on the final artifact. Desktop Quit is unchanged. Menu Save and other marked placeholders remain unfinished.

Camera movement now reprojects the original selection anchor after clamping and zoom instead of subtracting an unscaled requested delta; desktop live edge-scroll validation is still outstanding. Actual pinch, Add/Extend group UI, keyboard modifiers, safe-area/status-bar layout, full control coverage and game persistence remain open. See artifacts/2026-09-06/touch-46/result.json for exact per-artifact scope and failures.

## Keyboard/pointer bridge (input-61, partial)

Escape now opens the gameplay menu and closes its modal or Groups panel. Physical key events reach the optional Metal backend through UIKit. The app suppresses the software keyboard for gameplay. Text entry needs its own explicit UI.

The packaged app declares indirect input support; the Metal view separates pointer buttons/motion from touch emulation and recognizes secondary clicks. End-to-end right-click remains unverified: ordinary Simulator mouse mode delivers direct touch with no button identity; captured synthetic input produced no observed secondary callback/order. Do not label this pointer parity. Simulator capture may consume Escape to release capture; turn capture off to exercise the verified keyboard menu path. Mouse wheel, complete hotkeys, modifiers, pointer drag/hover and physical device behavior still need validation.

Only the existing AgePad G5 iPad may be booted/open. This supersedes the earlier separate-engineering-Simulator workflow.

## Mouse button routing (input-62)

Primary clicks activate HUD/dialog controls. Secondary world clicks bypass touch modes. Secondary minimap press/release issues an order at its mapped location while preserving camera position; Shift appends. Cancelled minimap presses cannot issue later orders. Native actual-data tests cover this routing; iPad pointer delivery remains unaccepted.

Visual comparison source: https://standardof.net/age-of-empires-ii-hd/william-wallace-01-marching-and-fighting/ (HD reference viewed2026-09-07). Our current toolbar consumes excessive map area and lacks the original age display. Future layout changes require rendered screenshots and actual interaction checks, retaining touch target accessibility.

## Compact controls (ui-64)

Tap Controls to open the touch action row. Choosing Pan, Order, Queue, Cancel, Menu, Idle, Groups or zoom closes the row. Active modes keep guidance visible. Escape closes the row first, then opens/closes the game menu. Live selection->Controls->Order->target movement and Escape dismissal pass on the sole Simulator; the remaining drawer actions/lifecycle still need full repeat.


## Original DE native touch iteration — 2026-09-12

Current touch-strip-2 replaces the bottom-center ORDER overlay with a right-side
red/gold serif strip, above the minimap and outside the bottom command panel.
IDLE (period) and TOWN (H) visibly select/center the original villager and town
center through actual Simulator UI. MENU routes Escape. Single-finger taps
opened Single Player, Load Game, and loaded the autosave on first attempts.
F11 now reaches the engine and displays the actual game clock/speed.

NativeTouchGestures.m adds UIKit two-finger tap (right-click pair), two-finger
pan (original slash-bound click-drag scroll), and pinch (scroll-wheel zoom).
These gesture paths compile but are NOT yet accepted by actual multi-touch
execution. Pan currently inherits original click-drag behavior; natural,
distance-proportional movement is still to be checked/refined. Recognizers
exclude side buttons, keep pinch/pan exclusive, and require movement/zoom to
fail before a two-finger tap can order. Single-finger drag latency also needs
checking because multi-touch recognition delays initial touch delivery.

HD visual reference inspected: Standard of Entertainment William Wallace
mission1 screenshot (linked above), captured privately as
generated/mac-de-simulator-375/hd-control-reference.png. It confirms the bottom
command panel and minimap should remain clear; the added strip is a touch
adaptation rather than part of the original HUD.

Update touch-strip-3: MENU now uses the shipped F10 binding and opens the
original menu immediately from a selected TC (verified). ZOOM+/− buttons
exercise the same wheel event path as pinch and visibly change world scale
without scaling the HUD (verified). Side ORDER starts movement and resets its
mode after targeting (verified). Multi-finger recognition and natural pan
still require direct validation; do not infer them from button-path success.

Pointer-consumption-1: short drags now emit a final mouseDragged before release,
and polled logical pointer state matches each event when consumed. Logs verify
that correction. Actual box selection still failed around a known villager, so
drag selection and two-finger pan remain unaccepted. Do not present native touch
as complete merely because the shortcut buttons work.

Immediate-touch-1: disabled the two-finger tap recognizer's delayed primary
touch delivery. Single taps still open the original menus. CUA drag around
the idle-selected villager (373,315 to474,399 after Escape) still failed
selection. Logs contain down/drag/up delivered to CFeralNSWindow, so this
change alone does not fix selection. Multi-finger acceptance remains open.
