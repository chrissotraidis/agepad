# DE installation and online acceptance

Updated 2026-09-12. This is the intended flow and a list of unproven requirements, not a working end-user installation guide.

See the root [README](../README.md) for the explicit distinction between the intended IPA setup and the currently Mac-assisted Simulator process.

## Intended user flow

1. Own DE on Steam. Install it using Steam on the source computer. For the current arm64 route this means the Mac edition on a Mac. AgePad must identify the edition and version rather than silently treating Mac and Windows inputs as interchangeable.
2. Point the preparation tool at that installation. Validate required executable, resources, Steam libraries and game version; stage a private copy and apply reproducible compatibility transformations. Do not bundle another user's game, account credentials or session data in the project. Preserve the source installation. Preserve original filename spellings. The September 14 candidate requires the companion ResourceFileTrace runtime with AGEPAD_CASE_INSENSITIVE_RESOURCE_ROOT set to the staged AgeOfEmpires2Data tree; it retries failed read/query lookups with the source spelling. Lowercasing the tree broke villager animation loading. The resource tree must remain unchanged while the game is running.
3. Build/sign the iPad wrapper and transfer the prepared installation. Physical-device signing and execution remain unproven for this candidate. Simulator success is not device acceptance.
4. Establish a genuine Steam session through the compatible runtime. This is not solved by merely copying game files or by having Steam installed on the source Mac. Current engineering launches use `scripts/run-de-game-relay.py` with a host-assisted Steam discovery helper; a self-contained on-device service is not demonstrated. A setup tool must report this dependency clearly rather than presenting import as success.
5. Start DE locally. Test touch selection, movement, camera, commands, save/load and sustained gameplay. Current early-adapter-1 runs fresh skirmishes with textured terrain and buildings. House construction and villager production are demonstrated, but unit bodies remain invisible. A 30-second diagnostic observation measured23.4 Simulator composition completions/second, not physical display FPS or accepted normal-speed play.
6. Join an untouched retail client in the supported ecosystem and complete a match. A displayed account name, a multiplayer menu or a successful login alone is not multiplayer acceptance.

## Multiplayer route decision

The supplied Feral Mac edition supports online multiplayer with other Mac players. This is confirmed by [Feral's game page](https://www.feralinteractive.com/en/games/ageofempires2/mac/), checked September10. The publisher says existing Steam DE owners receive the Mac edition: [Age of Empires support](https://support.ageofempires.com/hc/en-us/articles/360050470032-Age-of-Empires-II-Definitive-Edition-coming-to-Mac).

The current arm64 work therefore targets interoperability with an untouched, same-version retail Mac client. It does not establish Windows/console cross-play. If Windows ecosystem compatibility is required, the Windows DE executable and compatible Steam/Windows runtime must pass the same gameplay and match gates; resizing this Mac edition cannot supply that interoperability.

## Concrete release gates

- Reproducible source-installation detection, staged transformations and build from a clean checkout.
- Original scenario terrain and units render correctly; sizing remains stable across menus, loading, rotation and return from background.
- Touch commands change actual game state reliably; no repeated-tap workaround needed.
- Sustained scenario frame-time and memory measurements with verbose diagnostics disabled.
- Physical iPad launch and the same gameplay checks.
- Genuine Steam authentication and required services on the intended user configuration. If a companion computer is still required for services, demonstrate and disclose that dependency; rendering must remain on iPad.
- Completed online match against the untouched supported retail client, with matching version and ownership. Check disconnect/reconnect and absence of desynchronization.

Do not publish a one-click installation claim or declare multiplayer complete until these gates have evidence.

## Simulator packaging discovered in359

`simctl install` replaces the application's bundle container, including manually staged siblings. After an engineering install, `scripts/stage-de-simulator-adjacent.py ref/AoE2DE <private-manifest-path>` reconstructs the original adjacent Frameworks and game-data layout and verifies required hashes. It refuses to overwrite an existing staged tree. Run this only after installation and before launching the test relay. A release installer must keep imported game data in a persistent supported app container and resolve paths there; the current sibling layout is not a robust device distribution design. Copying these files does not establish a Steam session or qualify online play.
