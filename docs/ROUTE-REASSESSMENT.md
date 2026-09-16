# Route reassessment after user viability concern

2026-09-07. Full original AoK/AoC single-player scope remains unchanged. Previous work made real progress, but narrow UI/mechanics regressions do not establish a credible complete-game route.

## Decision

R1 is **engine development**, not a nearly complete platform port. Preserve the running candidate and source locks. Deprioritize cosmetic/interface micro-fixes until the missing simulation can be assessed against an ordinary AI/campaign workload. Reopen the PRD's bounded R4 original-logic comparison; do not assume AOT is easier or already possible.

## Current evidence

- Native ARM64/Metal Simulator and device builds work. Specific mechanics, saves, and Wallace tutorial paths have recorded tests. This validates platform feasibility and limited mechanics, not the declared nine-campaign/57-scenario baseline or useful skirmish.
- `src/ai` is compiled, but searches of `src/mechanics`, `src/Engine.cpp`, and `src/main.cpp` find no references to `AiPlayer`, `AiScript`, or `ScriptLoader`. The current ordinary game does not have demonstrated AI script integration.
- `AiScript::update` still has an unfinished scheduling comment. Its timer loop has a non-advancing continue and appears to invert expiry comparison. These are source findings requiring an isolated reproducer, not tested runtime failures.
- `ai/actions/Actions.cpp` places buildings beside the builder rather than searching valid strategic sites. ScriptLoader has unsupported conditions. Merely connecting its parser cannot prove useful AI.
- The current El Cid runtime explicitly warns that AIScriptGoal, LockGate and UnlockGate are unsupported. This is direct evidence that campaign behavior remains missing.
- Gameplay save reconstruction currently constructs ordinary Player objects. Any real AI integration also needs durable script/goal/timer/rule state and a save/resume proof.
- `ref` contains freeaoe source, the original HD installation, SFML, FreeType and PaperPad. It contains no verified alternative complete native AoE II engine.
- Supplied `AoK HD.exe` is PE32 x86 Windows code. Read-only identity/header evidence is in `artifacts/2026-09-07/shortcuts-137/original-executable.json`. No native original-logic execution, dependency reconstruction, or translation feasibility has been demonstrated.

## Next decision-producing work

1. R1: execute an isolated supplied-script/parser and scheduler fixture, enumerate unsupported constructs from actual baseline scenario AI, then assess the minimum end-to-end route to an AI economy that builds, trains, advances and fights. Require ordinary simulation and save/resume evidence; do not substitute a toy scripted opponent for the original requirement.
2. R4: inspect imports/code boundaries of the exact preserved EXE and identify one bounded original-logic path suitable for a translation feasibility test. No authentication/DRM bypass, CPU-interpreter fallback, or generic emulator project. Preserve R1 while evaluating.
3. Compare observed blockers and the amount of essential behavior remaining. Reuse platform/render/input work if a route change becomes justified. Neither a promise of eventual completion nor a claim of impossibility is supported now.

Full profile loading, contextual hotkeys, UI fidelity, AI, campaign triggers, rules, pathfinding and physical/performance acceptance remain unfinished. There is no defensible completion ETA from the present evidence.
