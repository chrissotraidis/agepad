#include "global/Config.h"
#include "resource/DataManager.h"
#include "resource/AssetManager.h"
#include "render/SfmlRenderTarget.h"
#include "mechanics/GameState.h"
#include "mechanics/ScenarioController.h"
#include "mechanics/UnitManager.h"
#include "mechanics/UnitFactory.h"
#include "mechanics/Unit.h"
#include "mechanics/Player.h"
#include <genie/script/ScnFile.h>
#include <genie/util/Utility.h>
#include "render/Camera.h"
#include <iostream>
#include <stdexcept>

int main(int argc, char **argv) try {
    if (argc != 2) throw std::runtime_error("Expected verified snapshot path");
    Config::Inst().testMode = true;
    Config::Inst().setValue(Config::GamePath, argv[1]);
    Config::Inst().setValue(Config::GameSample, "combat");
    auto &data = DataManager::Inst();
    if (!data.initialize()) throw std::runtime_error("DAT load failed");
    AssetManager::create(data.isHd());
    if (!AssetManager::Inst()->initialize(data.gameVersion())) throw std::runtime_error("Asset init failed");
    auto renderer = std::make_shared<SfmlRenderTarget>(Size(800, 600));
    for (int threshold : {0, 1}) {
    GameState state(renderer);
    if (!state.init()) throw std::runtime_error("Combat fixture init failed");
    auto scenario = std::make_shared<genie::ScnFile>();
    for (auto &player : scenario->players) player.victoryConditions.clear();
    auto &victory = scenario->playerData.victoryConditions;
    victory.victoryMode = genie::ScnVictory::Custom;
    victory.allConditionsRequired = 0;
    victory.conquestRequired = 0;
    victory.numRelicsRequired = 0;
    victory.exploredPerCentRequired = 0;
    genie::Trigger activation{};
    activation.startingState = 1;
    activation.looping = 0;
    genie::TriggerCondition timer;
    timer.type = genie::TriggerCondition::Timer;
    timer.timer = 1;
    activation.conditions = {timer};
    genie::TriggerEffect enable;
    enable.type = genie::TriggerEffect::ActivateTrigger;
    enable.trigger = 1;
    activation.effects = {enable};
    genie::Trigger outcome{};
    outcome.startingState = 0;
    outcome.looping = 0;
    genie::TriggerCondition fewer;
    fewer.type = genie::TriggerCondition::OwnFewerObjects;
    fewer.amount = threshold;
    fewer.sourcePlayer = 2;
    fewer.object = 74;
    outcome.conditions = {fewer};
    genie::TriggerEffect win;
    win.type = genie::TriggerEffect::DeclareVictory;
    win.sourcePlayer = state.humanPlayer()->playerId;
    outcome.effects = {win};
    scenario->triggers = {activation, outcome};
    ScenarioController controller(&state);
    controller.setScenario(scenario);
    auto manager = state.unitManager();
    std::vector<std::shared_ptr<Unit>> enemies;
    for (int i = 0; i < 3; ++i) {
        auto enemy = UnitFactory::createUnit(74, state.player(2), *manager);
        manager->add(enemy, MapPos(700 + i * 48, 700));
        enemies.push_back(enemy);
    }
    auto check = [&](const char *phase, GameState::Result expected) {
        std::cout << "threshold=" << threshold << " phase=" << phase << " result=" << int(state.result) << '\n';
        if (state.result != expected) throw std::runtime_error(phase);
    };
    controller.update(500);
    check("disabled-three-alive", GameState::Result::Running);
    controller.update(1000);
    check("activated-three-alive", GameState::Result::Running);
    enemies[0]->kill();
    controller.update(1100);
    check("two-alive", GameState::Result::Running);
    enemies[1]->kill();
    controller.update(1200);
    check("one-alive-inclusive-threshold", threshold == 1 ? GameState::Result::Won : GameState::Result::Running);
    enemies[2]->kill();
    controller.update(1300);
    check("zero-alive", GameState::Result::Won);
    }
    genie::CpxFile campaign;
    campaign.setFileName(genie::util::resolvePathCaseInsensitive("cam8.cpn",AssetManager::Inst()->campaignsPath()));
    campaign.load();
    auto tutorial=campaign.getScnFile(0);
    std::cout << "tutorial-camera=" << tutorial->playerData.player1CameraX << "," << tutorial->playerData.player1CameraY
        << " fallback=" << tutorial->players[0].initCameraX << "," << tutorial->players[0].initCameraY << '\n';
    for(const auto &unit:tutorial->playerUnits[1].units)
        std::cout << "tutorial-unit=" << unit.objectID << " position=" << unit.positionX << "," << unit.positionY << '\n';
    GameState tutorialState(renderer);tutorialState.setScenario(tutorial);
    if(!tutorialState.init()) throw std::runtime_error("tutorial init");
    for(std::size_t id=1;id<tutorialState.playerCount();++id)
        if(tutorialState.player(id)->alliedVictory!=(tutorial->players[id-1].alliedVictory!=0))
            throw std::runtime_error("authored allied victory flag not imported");
    std::cout << "allied_victory_import_checks=1 errors=0\n";

    renderer->setSize(Size(800,600));
    const ScreenRect playable(20,90,760,350);
    if(!tutorialState.ensureInitialUnitsVisible(playable)) throw std::runtime_error("offscreen starting army not centered");
    Unit::Ptr soldier;
    for(const auto &unit:tutorialState.unitManager()->units())
        if(unit->playerId()==tutorialState.humanPlayer()->playerId && unit->data()->ID==74) soldier=unit;
    if(!soldier || !playable.contains(renderer->camera()->absoluteScreenPos(soldier->position()))) throw std::runtime_error("tutorial soldier not in playable area");
    const auto centered=renderer->camera()->targetPosition();
    if(tutorialState.ensureInitialUnitsVisible(playable) || renderer->camera()->targetPosition()!=centered) throw std::runtime_error("already visible starting view changed");
    for(Time t=0;t<=25000;t+=50) { tutorialState.update(t); tutorialState.followInitialUnit(); }
    const auto screen=renderer->camera()->absoluteScreenPos(soldier->position());
    std::cout << "after_intro_soldier=" << soldier->position().x << "," << soldier->position().y << " screen=" << screen.x << "," << screen.y << " camera=" << renderer->camera()->targetPosition().x << "," << renderer->camera()->targetPosition().y << '\n';
    if(!playable.contains(screen)) throw std::runtime_error("scripted introduction lost starting unit");
    tutorialState.releaseInitialCamera();
    renderer->camera()->setTargetPosition(MapPos(0,0));
    if(tutorialState.followInitialUnit() || renderer->camera()->targetPosition()!=MapPos(0,0)) throw std::runtime_error("manual camera snapped back");
    std::cout << "initial_camera_checks=5 errors=0\n";
    std::cout << "late_activation_ownership_checks=10 errors=0\n";
    return 0;
} catch (const std::exception &error) {
    std::cerr << error.what() << '\n';
    return 1;
}
