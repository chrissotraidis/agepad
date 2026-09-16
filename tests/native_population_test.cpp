#include "global/Config.h"
#include "resource/DataManager.h"
#include "resource/AssetManager.h"
#include "render/SfmlRenderTarget.h"
#include "render/Camera.h"
#include "mechanics/GameState.h"
#include "mechanics/UnitManager.h"
#include "mechanics/Unit.h"
#include "mechanics/UnitFactory.h"
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
    const auto resource = genie::ResourceType::PopulationHeadroom;
    const float baseline = player->resourcesAvailable(resource);
    size_t errors = 0;
    auto check = [&](const char *phase, float expected) {
        const float actual = player->resourcesAvailable(resource);
        errors += actual != expected;
        std::cout << "phase=" << phase << " expected=" << expected << " actual=" << actual << '\n';
    };
    auto house = UnitFactory::createUnit(70, player, *manager);
    for (const auto &storage : house->data()->ResourceStorages)
        std::cout << "storage type=" << storage.Type << " amount=" << storage.Amount << " mode=" << int(storage.Paid) << '\n';
    check("completed-create", baseline + 5);
    house->setCreationProgress(0);
    check("foundation", baseline);
    house->increaseCreationProgress(house->data()->Creatable.TrainTime);
    check("completion", baseline + 5);
    house->increaseCreationProgress(1);
    check("repeated-completion", baseline + 5);
    house->kill();
    check("death", baseline);
    house.reset();
    check("destruction-after-death", baseline);
    auto canceled = UnitFactory::createUnit(70, player, *manager);
    canceled->setCreationProgress(0);
    canceled->kill();
    check("foundation-death", baseline);
    canceled.reset();
    check("foundation-destruction", baseline);
    std::cout << "population_lifecycle_checks=8 errors=" << errors << '\n';
    return errors ? 1 : 0;
} catch (const std::exception &error) {
    std::cerr << error.what() << '\n';
    return 1;
}
