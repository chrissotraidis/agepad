#include "global/Config.h"
#include "resource/DataManager.h"
#include "resource/AssetManager.h"
#include "render/SfmlRenderTarget.h"
#include "render/Camera.h"
#include "mechanics/GameState.h"
#include "mechanics/UnitManager.h"
#include "mechanics/Unit.h"
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
    auto camera = renderer->camera();
    camera->setViewportSize(Size(800, 600));
    camera->setTargetPosition(MapPos(480, 480));
    manager->startPlaceBuilding(70, player);
    std::vector<MapPos> sites;
    for (int x = 4; x < 18 && sites.size() < 2; x += 4) {
        for (int y = 4; y < 18 && sites.size() < 2; y += 4) {
            manager->onMouseMove(MapPos(x * 48, y * 48));
            const auto &preview = manager->buildingsToPlace().at(0);
            if (preview.canPlace) sites.push_back(preview.position);
        }
    }
    if (sites.size() != 2) throw std::runtime_error("Two legal fixture sites unavailable");
    manager->onMouseMove(sites[0]);
    const size_t count = manager->units().size();
    manager->onLeftClick(camera->absoluteScreenPos(sites[1]), camera);
    size_t errors = manager->units().size() != count + 1;
    if (manager->units().size() == count + 1) {
        const auto placed = manager->units().back()->position();
        errors += placed.x != sites[1].x || placed.y != sites[1].y;
        std::cout << "expected=" << sites[1].x << "," << sites[1].y
                  << " placed=" << placed.x << "," << placed.y << '\n';
    }
    // An old legal preview must not authorize a new click overlapping the town center.
    manager->startPlaceBuilding(70, player);
    manager->onMouseMove(sites[0]);
    const auto beforeInvalid = manager->units().size();
    const float wood = player->resourcesAvailable(genie::ResourceType::WoodStorage);
    for (const auto &unit : manager->units()) {
        if (unit->isBuilding()) std::cout << "building=" << unit->data()->ID
            << " pos=" << unit->position().x << "," << unit->position().y
            << " size=" << unit->data()->Size.x << "," << unit->data()->Size.y << "," << unit->data()->Size.z
            << " obstruction=" << int(unit->data()->ObstructionType) << '\n';
    }
    manager->onLeftClick(camera->absoluteScreenPos(MapPos(96, 96)), camera);
    std::cout << "invalid_count_before=" << beforeInvalid << " after=" << manager->units().size()
              << " wood_before=" << wood << " after=" << player->resourcesAvailable(genie::ResourceType::WoodStorage) << '\n';
    errors += manager->units().size() != beforeInvalid;
    errors += player->resourcesAvailable(genie::ResourceType::WoodStorage) != wood;
    // Cancel placement through the ordinary right-click handler.
    manager->startPlaceBuilding(70, player);
    manager->onMouseMove(sites[0]);
    manager->onRightClick(camera->absoluteScreenPos(sites[0]), camera);
    errors += !manager->buildingsToPlace().empty();
    std::cout << "placement_checks=4 errors=" << errors << '\n';
    return errors ? 1 : 0;
} catch (const std::exception &error) {
    std::cerr << error.what() << '\n';
    return 1;
}
