# Source map

Pinned freeaoe source in dependencies.lock.json. Platform/build patches live under port/patches; modifications occur only in worktrees/freeaoe. Public reference remains clean.

- Startup/config: src/main.cpp, global/Config.cpp, core/Utility.cpp.
- Game data/media: resource/DataManager.cpp, AssetManager.cpp, AssetManager_HD.h, TerrainSprite.cpp, LanguageManager.cpp; pinned genieutils parses DAT/scenario/campaign/SLP records.
- Simulation: mechanics/GameState.cpp, Player.cpp, Unit.cpp, UnitManager.cpp, Building.cpp, Civilization.cpp, Map.cpp and MapTile.cpp.
- Ordinary orders: mechanics/UnitActionHandler.cpp, actions/ActionMove.cpp, ActionGather.cpp, ActionBuild.cpp, ActionAttack.cpp.
- Scenarios: mechanics/ScenarioController.cpp; AI: ai/ScriptLoader.cpp, AiPlayer.cpp, actions/Actions.cpp, conditions/Conditions.cpp.
- Render boundary: render/IRenderTarget.h, IRenderer.cpp, SfmlRenderTarget.cpp, MapRenderer.cpp, UnitsRenderer.cpp. Current host diagnostic renderer is SFML/OpenGL, not the required production Metal path.
- Audio: audio/AudioPlayer.cpp and Implementations.cpp using pinned miniaudio/TinySoundFont.
- Shell: ui/HomeScreen.cpp, ActionPanel.cpp, FileDialog.cpp, Minimap.cpp. No implemented UIKit shell yet.

PaperPad reference at 74b6e45830a06c7f274c5ac1ddd7c625bc13a557 inspected for pin verification, safe clones, package/source audits and Apple path/lifecycle architecture. Its N64 mechanics and process shutdown workaround are not imported. No PaperPad game dependencies are initialized.
