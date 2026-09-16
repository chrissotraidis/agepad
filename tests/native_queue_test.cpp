#include "global/Config.h"
#include "resource/DataManager.h"
#include "resource/AssetManager.h"
#include "render/SfmlRenderTarget.h"
#include "render/Camera.h"
#include "mechanics/GameState.h"
#include "mechanics/UnitManager.h"
#include "mechanics/Unit.h"
#include "mechanics/UnitFactory.h"
#include "mechanics/Building.h"
#include <genie/dat/Research.h>
#include "mechanics/Player.h"
#include <iostream>
#include <stdexcept>

int main(int argc, char **argv) try {
    if (argc != 2) throw std::runtime_error("Expected verified snapshot path");
    Config::Inst().testMode = true;
    Config::Inst().setValue(Config::GamePath, argv[1]);
    auto &data = DataManager::Inst();
    if (!data.initialize()) throw std::runtime_error("DAT load failed");
    AssetManager::create(data.isHd());
    if (!AssetManager::Inst()->initialize(data.gameVersion())) throw std::runtime_error("Asset init failed");
    auto renderer = std::make_shared<SfmlRenderTarget>(Size(800, 600));
    GameState state(renderer);
    if (!state.init()) throw std::runtime_error("Basic fixture init failed");
    auto manager = state.unitManager();
    auto player = state.humanPlayer();
    Building::Ptr town;
    for (const auto &unit : manager->units())
        if (unit->data()->ID == 109 && unit->playerId() == player->playerId) town = Building::fromUnit(unit);
    if (!town) throw std::runtime_error("Town center fixture missing");
    const auto food = genie::ResourceType::FoodStorage;
    const float initialFood = player->resourcesAvailable(food);
    size_t errors = 0;
    const auto &villager = player->civilization.unitData(83);
    manager->enqueueProduceUnit(&villager, {town});
    manager->enqueueProduceUnit(&villager, {town});
    errors += town->productionQueueLength() != 2;
    errors += player->resourcesAvailable(food) != initialFood - 100;
    town->abortProduction(1);
    errors += town->productionQueueLength() != 1;
    errors += player->resourcesAvailable(food) != initialFood - 50;
    town->abortProduction(0);
    errors += town->productionQueueLength() != 0;
    errors += player->resourcesAvailable(food) != initialFood;
    std::cout << "after-cancel expected_food=" << initialFood
              << " actual_food=" << player->resourcesAvailable(food) << '\n';
    town->abortProduction(99);
    errors += player->resourcesAvailable(food) != initialFood;
    const auto &watch = data.getTech(8);
    std::cout << "research=8 name=" << watch.Name << " effect=" << watch.EffectID << '\n';
    if (watch.ResearchLocation != 109) throw std::runtime_error("Research fixture does not belong to town center");
    const float beforeResearch = player->resourcesAvailable(food);
    manager->enqueueResearch(&watch, {town});
    errors += !town->isResearching();
    errors += player->resourcesAvailable(food) != beforeResearch - 75;
    const float beforeLos = town->data()->LineOfSight;
    size_t visibleBefore = 0;
    for (int x = 0; x < 22; ++x) for (int y = 0; y < 22; ++y)
        visibleBefore += player->visibility->visibilityAt(x, y) == VisibilityMap::Visible;
    // Advance normal simulation updates; do not call applyResearch or set completion.
    for (Time time = 20; time <= 120000 && town->isProducing(); time += 20) town->update(time);
    errors += town->isProducing();
    errors += town->data()->LineOfSight != beforeLos + 4;
    size_t visibleAfter = 0;
    for (int x = 0; x < 22; ++x) for (int y = 0; y < 22; ++y)
        visibleAfter += player->visibility->visibilityAt(x, y) == VisibilityMap::Visible;
    errors += visibleAfter <= visibleBefore;
    std::cout << "visible_tiles_before=" << visibleBefore << " after=" << visibleAfter << '\n';
    std::cout << "town-watch los_before=" << beforeLos << " los_after=" << town->data()->LineOfSight
              << " queue=" << town->productionQueueLength() << '\n';
    std::cout << "queue_research_errors=" << errors << '\n';
    return errors ? 1 : 0;
} catch (const std::exception &error) {
    std::cerr << error.what() << '\n';
    return 1;
}
