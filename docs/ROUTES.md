# Route register

Spec: agepad-v2-2026-09-06. Active profile: apple-singleplayer; first ipad-singleplayer.

R1 freeaoe at `f5e46da59761868aa1814037f712f277c71b5bb3`, supplied HD snapshot, classic-compatible candidate ruleset is provisionally selected. Native engine source and explicit HD loader exist; ordinary tutorial select/move observed; broader gameplay unrun. The exact source has partial commands/economy/combat implementations worth testing. This is not a complete-game finding.

Round 1: step 1 unmodified host configure failed because SFML is unavailable. Remedy: build pinned SFML 2.6.2 in an isolated prefix, matching the source's SFML 2 APIs. No global package/toolchain changes. SFML audio/network modules are not required by this graph (game audio uses pinned miniaudio); their omission does not remove game audio. Qt is optional for unrelated genieutils viewers.

R2/DE0/DE1: deferred, no DE copy supplied in the authorized local root. Reopen when a separate DE input arrives. R3 waits for DE and a proven core. R4 not yet active: exact HD EXE exists, but no evidence yet justifies AOT over testing R1. R5/R6 deferred outside active baseline. Android and N1–N4 are deferred, without support claims.

Native dependency/build and partial original-tutorial boot succeeded. Next: complete G3 terrain/audio and G4 mechanics before the early G5 iPad proof. Missing saves, result flow, AI/RMS and campaign selection are ENGINE gaps, not reasons to suppress build errors or prematurely promise a complete game.

2026-09-07 reassessment137 supersedes the initial “R4 not yet active” disposition: user explicitly questioned full-game viability; substantial missing essential behavior is now confirmed. R1 is classified as engine development. R4 is reopened for a bounded read-only exact-executable/original-logic feasibility comparison, not selected as a replacement. See ROUTE-REASSESSMENT.md for current evidence and decision tests. Preserve the working R1 candidate. Prioritize engine viability over further isolated UI polish.
