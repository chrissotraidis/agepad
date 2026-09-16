#include "global/Config.h"
#include "resource/DataManager.h"
#include "resource/AssetManager.h"
#include "render/SfmlRenderTarget.h"
#include "render/Camera.h"
#include "mechanics/GameState.h"
#include "mechanics/UnitManager.h"
#include "mechanics/Unit.h"
#include "mechanics/UnitFactory.h"
#include "mechanics/Map.h"
#include "render/UnitsRenderer.h"
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
    auto map = std::make_shared<Map>();
    map->setupBasic();
    auto manager = std::make_shared<UnitManager>();
    manager->setMap(map);
    if (!manager->init()) throw std::runtime_error("Unit manager init failed");
    auto gaia = std::make_shared<Player>(0, 0, map, ResourceMap{});
    auto human = std::make_shared<Player>(1, 1, map, ResourceMap{});
    auto enemy = std::make_shared<Player>(2, 2, map, ResourceMap{});
    manager->setPlayers({gaia, human, enemy});
    manager->setHumanPlayer(human);
    auto archer = UnitFactory::createUnit(4, human, *manager);
    auto target = UnitFactory::createUnit(72, enemy, *manager);
    manager->add(archer, MapPos(480, 480));
    manager->add(target, MapPos(576, 480));
    map->updateMapData();
    auto renderer = std::make_shared<SfmlRenderTarget>(Size(800, 600));
    auto camera = renderer->camera();
    camera->setViewportSize(Size(800, 600));
    camera->setTargetPosition(MapPos(528, 480));
    UnitsRenderer unitRenderer;
    unitRenderer.setUnitManager(manager);
    unitRenderer.setVisibilityMap(human->visibility);
    unitRenderer.begin(renderer);
    unitRenderer.render(renderer, {archer, target});
    unitRenderer.display(renderer);
    manager->setSelectedUnits({archer});
    const auto rect = target->screenRect() + camera->absoluteScreenPos(target->position());
    ScreenPos targetClick;
    bool found = false;
    for (int y = rect.y; y < rect.y + rect.height && !found; ++y)
        for (int x = rect.x; x < rect.x + rect.width && !found; ++x)
            if (manager->clickedUnitAt(ScreenPos(x, y), camera) == target) {
                targetClick = ScreenPos(x, y);
                found = true;
            }
    if (!found) throw std::runtime_error("Visible target pixel unavailable");
    manager->onRightClick(targetClick, camera);
    auto action = archer->actions.currentAction();
    std::cout << "first_click_action=" << (action ? int(action->type) : -1) << '\n';
    if (!action || action->type != IAction::Type::Attack)
        throw std::runtime_error("Target click without prior hover did not attack");
    manager->onCursorPositionChanged(targetClick, camera);
    manager->onRightClick(camera->absoluteScreenPos(MapPos(384, 576)), camera);
    action = archer->actions.currentAction();
    if (!action || action->type != IAction::Type::Move)
        throw std::runtime_error("Ground click reused stale attack target");
    manager->onRightClick(targetClick, camera);
    const float initialHealth = target->healthLeft();
    bool sawMissile = false,sourceRecorded = false;
    size_t hits = 0;
    float lastHealth = initialHealth;
    float lastHitpoints=target->hitpointsLeft();bool oneDamagePerProjectile=true;
    Time firstHit = 0, finished = 0;
    for (Time time = 20; time <= 600000 && target->healthLeft() > 0; time += 20) {
        manager->update(time);
        sawMissile |= !manager->missiles().empty();
        if (target->healthLeft() < lastHealth) {
            ++hits;
            oneDamagePerProjectile &= lastHitpoints-target->hitpointsLeft()==1.f;
            lastHitpoints=target->hitpointsLeft();
            sourceRecorded |= target->lastAttacker.lock()==archer && target->attackRevision>0;
            if (!firstHit) firstHit = time;
            lastHealth = target->healthLeft();
        }
        finished = time;
    }
    std::cout << "initial_health=" << initialHealth << " final_health=" << target->healthLeft()
              << " one_damage_per_projectile=" << oneDamagePerProjectile
              << " source_recorded=" << sourceRecorded
              << " projectile_observed=" << sawMissile << " damaging_hits=" << hits
              << " first_hit_ms=" << firstHit << " last_tick_ms=" << finished << '\n';
    return sawMissile && sourceRecorded && oneDamagePerProjectile && hits > 1 && target->healthLeft() == 0 ? 0 : 1;
} catch (const std::exception &error) {
    std::cerr << error.what() << '\n';
    return 1;
}
