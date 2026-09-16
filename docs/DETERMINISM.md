# Repeatability

Unrun. Initial host build preserves upstream -ffast-math; no simulation parity or deterministic claim. Before simulation acceptance create a separately keyed strict build and fixed-seed ordinary-command traces. Canonical state must exclude pointers/wall-clock/render-only state; investigate first semantic divergence. Apple single-player parity is required; network lockstep remains deferred.

## Session random state (save-42)

Gameplay flying behavior and projectile smoke now use a UnitManager-owned integer minstd_rand transition, default seed 1, with a versioned snapshot. Nine component checks cover reference sequence, save/restore continuation, instance isolation and malformed-state rejection. Audio variation retains its separate presentation generator. This changes the old platform C rand sequence and does not establish classic-engine parity.

The missile collection still uses pointer-based unordered iteration; after reconstruction, random draws may reach different missiles. Stable execution order and whole-game state restoration are required before claiming reproducible simulation. Fast-math and cross-SDK simulation parity remain unverified. See artifacts/2026-09-06/save-42/result.json.
