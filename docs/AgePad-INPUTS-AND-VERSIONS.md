# AgePad inputs and versions: classic/HD first, DE separately

**Spec ID:** `agepad-v2-2026-09-06`.

**Revision: v2 — 6 September 2026.** Use with [AgePad-PRD.md](AgePad-PRD.md) and [AgePad-GOAL-LOOP.md](AgePad-GOAL-LOOP.md). Supersedes the previous input/testing recommendation. In a repository, install as `docs/INPUTS-AND-VERSIONS.md` alongside `docs/PRD.md` and `docs/GOAL-LOOP.md`, adjusting these links.

**Provide an existing complete HD or classic AoE II installation first. Provide DE separately when available. One suitable copy is enough to start; the agent must not wait for the whole comparison set.** No supplied game copy has been inspected or verified by this revision.

The first product objective is a complete, explicitly supported **classic/HD single-player game on iPad**, followed by iPhone. That would be a successful product even if full DE or commercial multiplayer is not feasible. A tutorial-only experiment is an important milestone, not that complete product.

## 1. Best first gameplay hypothesis: AoE II HD / 2013

**Windows Steam application `221380`**, identified as **Age of Empires II (Retired)** in the earlier audit. The existing `freeaoe` source has an explicit HD asset loader, making this a concrete candidate to test rather than a fresh whole-game reconstruction. Exact-build compatibility and game completeness remain unproven. [S1, S3, S4]

Supply the **complete installed Windows folder**, preferably unmodified and English for the first baseline. Preserve all resource directories, data, audio, campaigns/scenarios, localization and any matching executable. A lone EXE, desktop shortcut, screenshot or Steam receipt cannot supply the game's data.

Do not buy additional DLC for the first test. Keep already-installed content visible to the inventory; do not manually delete files to imitate a different revision. HD data may support a classic-compatible ruleset before complete HD equivalence exists. The agent must label that distinction rather than calling every HD behavior supported.

The earlier audit recorded a purchase option despite the “Retired” name. This editing pass did not recheck the storefront. Verify legitimate availability in the relevant account/region before a purchase, and do not buy multiple editions on an untested compatibility promise.

## 2. Already have classic Age of Kings + The Conquerors? Start there

A complete original **Windows Age of Kings + The Conquerors** installation is a useful alternate first input for an existing-engine probe, and a possible original-logic fallback. Keep its **matching executable and data together**. The executable matters particularly if the investigation later uses static recompilation or selective reconstruction. [S3, S5]

Do not hunt for a guessed patch version, alter the original EXE, or mix it with HD/DE data. The agent should inspect the actual revision, determine its supported parser/engine path and explain any missing input precisely. Possession of a classic EXE does not automatically make the AOT route the best route.

An archive or disc image is acceptable for safe identification. An installed folder is usually a more direct testing input; an installer/disc image may need a separate legitimate installation/extraction step. The agent must not run an unknown bundled installer just to identify it. No cracked game, leaked source or third-party redistributed executable is requested.

**With only this classic copy available, begin its inventory and bounded R1 probe now instead of requiring an HD purchase.** A failed classic variant can justify testing HD next; it does not prove every AoE route fails.

## 3. Second input: AoE II: Definitive Edition

**Windows Steam application `813780`**, supplied in a separate complete standard installation. DE remains the preferred future modern-content candidate, not the prerequisite for the first classic product. No optional Enhanced Graphics Pack or extra paid content is needed for the initial probe. Inventory bundled DLC and the actual schema; “standard” does not mean an old 2019 data set. [S2]

The agent should identify the supplied copy early and run a **bounded schema/conversion probe** when feasible. That is DE0/DE1, not “DE works.” A converter's output is not automatically compatible with the selected classic engine. [S6]

Keep the progression explicit:

| Stage | What it proves | What it does not prove |
|---|---|---|
| DE0: identify | Edition/build confidence and available data | Successful conversion or gameplay |
| DE1: convert representative data | The named parser/converter handles that tested subset/build | Complete engine behavior or a compatible freeaoe package |
| DE2: play a declared subset | That exact subset/ruleset works through the tested core | Full modern DE rules, campaigns, original saves or network services |
| DE3: complete a separately defined DE target | Its own scoped engine/content requirements pass | Automatic N4 commercial multiplayer interoperability |

If DE conversion needs substantial missing tooling or fails, record the blocker and park the probe. **Continue the working classic/HD route.** Do not postpone iPad gameplay indefinitely while finishing an unrelated converter or engine.

If DE is the only input supplied, inspect/probe it and continue independent source/synthetic tests. Then report whether a classic/HD installation is needed for the chosen gameplay route. Never pretend the DE folder is an HD installation simply because both games contain villagers and campaigns.

## 4. Optional inputs, not requirements

An existing **Mac DE installation** can be a retail reference or a separately scoped layout/dependency audit. It is not the preferred sole input for the initial Windows-HD loader test, and its ARM64 executable is not an iPad application. A retail Mac launch cannot satisfy AgePad's own native Mac build gate. [S7]

Original **Age of Empires + Rise of Rome** can support a separately labeled first-game experiment when deliberately chosen. It cannot satisfy the AoE II objective. Do not search for it merely to avoid completing AoE II's missing systems. [S8]

No Android-specific game copy, mobile spinoff or separate iPhone asset set is required by this proposed shared-core design. Actual portability remains to be demonstrated. Android and multiplayer are preserved follow-on branches, not acquisition requirements for the first Apple single-player result.

## 5. What to give the agent

Place each copy in a separate folder or provide explicit read-only paths within the authorized workspace. Preserve internal names and structure. A ZIP of the complete folder is acceptable when it can be safely unpacked into an ignored staging directory. A cloud placeholder is not a complete local copy.

Example labels only; they are not proof of edition:

```text
ref/inputs/originals/
  aoe2-hd-steam-windows/       preferred first candidate when available
  aoe2-classic-existing/      alternate first input and possible AOT fallback
  aoe2-de-steam-windows/      separate optional early probe; future content target
  aoe2-de-macos-reference/    optional reference
  aoe1-ror-existing/          optional different-game experiment
```

A brief private note may include installation source, known language, known DLC/mods and whether the copy has been altered. Include the matching `appmanifest_221380.acf` or `appmanifest_813780.acf` when available as private metadata, not as a replacement for file inspection/hashes. No Steam password, token, account directory or unrelated personal file is needed.

No exact release number or expected hash is prescribed yet. Those must come from the actual supplied input and a verified compatibility decision, not a template copied from another game.

## 6. Required agent intake and report

Before running any game code:

1. Inspect only the authorized supplied roots. Distinguish installer, disc image, full install, archive, partial download and asset-only export. Do not infer a version from the filename.
2. Preserve originals. List archives before extraction; bound expanded size/file count; reject traversal/escaping paths, unsafe symlinks and unresolved case collisions; check storage; mount disc images read-only when needed.
3. Make a stable ignored working snapshot and a deterministic SHA-256 file manifest. Do not identify an actively updating Steam directory as an immutable build.
4. Combine file headers, data formats, directory layout, product/version/architecture metadata and known detector evidence. Keep **edition confidence**, **exact-revision confidence** and **tested compatibility** separate. An unknown hash is not automatic rejection or acceptance.
5. Report the exact route/input/ruleset candidate, available representative assets/scenario, blockers, next bounded test and any genuinely required missing file. Do not mix editions to make a loader stop crashing.

The first report should look like this, populated from actual evidence:

```text
Input label and snapshot ID:
Container/install type and completeness:
Source platform / edition / language / expansions / mods:
Edition confidence and supporting observations:
Exact build confidence; known Steam build ID if available:
Manifest and executable hashes (where relevant):
Data schema and compatible route hypothesis:
First map/scenario candidate and required mechanics:
Missing or unsupported components:
Next test; precise additional input only if needed:
```

For a reimplementation, data may be sufficient at runtime; an EXE may be identification/reference material. For AOT, the exact EXE is a build input and another revision may require a new generated/signed core. Mobile asset import must not secretly execute a Windows binary, invoke a guest-CPU JIT or download executable code.

## 7. How these inputs become evidence

**HD/classic identity → native macOS BASIC-SLICE → same slice in iPad Simulator → original scenario and save/reload → completeness audit → complete iPad single-player baseline → iPhone adaptation.**

BASIC-SLICE includes selection/movement, gathering/dropoff, construction, training/research and combat through ordinary commands. One verified original scenario may not exercise all those mechanics, so use additional labeled fixtures rather than pretending a tutorial covers everything.

Completing an original scenario plus persistence is the first end-to-end feasibility milestone. It is not full campaign, useful AI, physical performance or release proof. The physical iPad scout should happen early when actual access exists; the final candidate still needs exact hardware acceptance.

## 8. Online play and version compatibility

The first baseline is **N0 offline single-player**. N1 is AgePad-to-AgePad LAN; N2 is AgePad-to-AgePad Internet. N3 targets a specific classic/HD retail client. N4 targets a specific commercial DE ecosystem. Neither N1/N2 nor DE asset import implies N3/N4.

Do not acquire DE on a promise of cross-play that this project has not demonstrated. The earlier audit recorded a Mac-specific multiplayer limitation in the official FAQ; check current service/platform facts when that branch is actually considered. The lasting requirement is explicit protocol, ruleset, authentication and real mixed-client testing—not reliance on a historical FAQ statement. [S9]

## 9. Inventory and evidence status

**All of Chris's game copies remain uninspected in these planning documents.** The earlier session reported no connected Drive access. This revision does not make a new connection check or claim those copies are absent. The execution agent must use its actual authorized local/connected access rather than inheriting that limitation as permanent.

These revised files were produced by editing the prior documents and incorporating the follow-up discussion, not by testing a game. The source leads below are carried forward. Source inspection, successful compilation, scenario gameplay, full-game coverage and physical acceptance remain different evidence levels. No numerical probability in a conversation may substitute for them.

## Source leads carried forward

- **S1:** [Steam HD/2013/Retired, app 221380](https://store.steampowered.com/app/221380/Age_of_Empires_II_Retired/) — earlier product/acquisition lead; current availability was not rechecked in this revision.
- **S2:** [Steam Definitive Edition, app 813780](https://store.steampowered.com/app/813780/Age_of_Empires_II_Definitive_Edition/) — future content-source lead; inspect exact installed build.
- **S3:** [freeaoe README at the earlier inspected pin](https://github.com/sandsmark/freeaoe/blob/f5e46da59761868aa1814037f712f277c71b5bb3/README.md) — partial-engine and data-support claims, not runtime acceptance.
- **S4:** [freeaoe HD loader at that pin](https://github.com/sandsmark/freeaoe/blob/f5e46da59761868aa1814037f712f277c71b5bb3/src/resource/AssetManager_HD.h) — concrete starting HD path.
- **S5:** [M-HT/SR](https://github.com/M-HT/SR) — selected-game static-recompilation precedent, not an AoE compatibility guarantee.
- **S6:** [openage README at the earlier inspected pin](https://github.com/SFTtech/openage/blob/9a5a7ccbfc20c2de658fc746462cd4a69aa758ef/README.md) — conversion/engine investigation lead.
- **S7:** [Official native Mac DE launch](https://www.ageofempires.com/news/age-of-empires-ii-definitive-edition-available-now-on-mac/) — retail reference, not a community source tree or IPA.
- **S8:** [Original AoE/Rise of Rome project](https://github.com/FolkertVanVerseveld/aoe) — optional different-game foundation.
- **S9:** [Official Mac DE FAQ](https://support.ageofempires.com/hc/en-us/articles/360050470032-Age-of-Empires-II-Definitive-Edition-coming-to-Mac) — recheck before a future network decision.

The authoritative execution policy is the matching v2 PRD and goal loop. All three documents carry revision `agepad-v2-2026-09-06`; do not mix them with old bundle policies that make Android or multiplayer mandatory for the iPad baseline.
