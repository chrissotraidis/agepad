#include "global/Config.h"
#include "actions/ActionMove.h"
#include "actions/ActionAttack.h"
#include "actions/ActionFollow.h"
#include "render/GraphicRender.h"
#include "resource/Sprite.h"
#include "mechanics/Map.h"
#include "mechanics/Building.h"
#include "mechanics/EntitySaveIndex.h"
#include <genie/dat/UnitCommand.h>
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
    int checks=0;
    auto check=[&](bool ok,const char *name){++checks;if(!ok)throw std::runtime_error(name);};
    auto rejected=[](auto action){try{action();return false;}catch(const agepad::SaveError &){return true;}};
    auto map=std::make_shared<Map>();map->setupBasic();map->updateMapData();
    auto manager=std::make_shared<UnitManager>();manager->setMap(map);
    if(!manager->init())throw std::runtime_error("manager init");
    auto human=std::make_shared<Player>(1,1,map,ResourceMap{}),enemy=std::make_shared<Player>(2,2,map,ResourceMap{});
    auto actor=UnitFactory::createUnit(74,human,*manager);
    manager->add(actor,MapPos(480,480));map->updateMapData();
    actor->stance=Unit::Stance::NoAttack;
    auto target=UnitFactory::createUnit(74,enemy,*manager);
    manager->add(target,MapPos(850,480));map->updateMapData();
    auto follow=std::make_shared<ActionFollow>(actor,target);
    actor->actions.setCurrentAction(follow);
    actor->update(100);actor->update(200);
    check(actor->position().x>480,"follower moves toward distant target");
    agepad::EntitySaveIndex index;index.add(actor->id,actor);index.add(target->id,target);index.seal();
    auto saved=follow->saveRuntime();auto restored=IAction::fromRuntime(IAction::Type::Follow,saved,index,200);
    check(restored->saveRuntime()==saved,"moving Follow target and child roundtrip");
    actor->actions.setCurrentAction(restored);
    for(Time t=300;t<=20000;t+=100)actor->update(t);
    const auto stopped=actor->position();
    const float sight=actor->data()->LineOfSight*Constants::TILE_SIZE;
    check(actor->distanceTo(target)<=sight+1 && actor->distanceTo(target)>sight-20,
          "Follow stops at sight distance rather than colliding with target");
    for(Time t=20100;t<=21000;t+=100)actor->update(t);
    check(actor->position()==stopped && actor->actions.currentAction()==restored,"waiting retains Follow order");
    auto idleBytes=restored->saveRuntime();
    restored=IAction::fromRuntime(IAction::Type::Follow,idleBytes,index,21000);
    actor->actions.setCurrentAction(restored);
    target->setPosition(MapPos(950,700));map->updateMapData();
    for(Time t=21100;t<=30000;t+=100)actor->update(t);
    check(actor->position()!=stopped && actor->distanceTo(target)<=sight+1,"restored waiting Follow resumes when target moves");
    bool truncations=true;
    for(std::size_t i=0;i<saved.size();++i) {
        agepad::SaveBytes partial(saved.begin(),saved.begin()+i);
        truncations &= rejected([&]{ActionFollow::fromRuntime(partial,index,30000);});
    }
    check(truncations,"all Follow truncations rejected");
    check(rejected([&]{ActionFollow bad(actor,actor);}),"self Follow rejected");
    actor->actions.clearActionQueue();const auto stop=actor->position();actor->update(30100);
    check(actor->position()==stop && !actor->actions.currentAction(),"Stop cancels Follow and nested movement");
    auto expired=std::make_shared<ActionFollow>(actor,std::shared_ptr<Unit>{});
    check(expired->update(30200)==IAction::UpdateResult::Completed,"missing target ends Follow safely");
    manager->setHumanPlayer(human);manager->setSelectedUnits({actor});
    manager->selectFollowTarget();
    check(manager->state()==UnitManager::State::SelectingFollowTarget,"Follow target entry available");
    manager->cancelPendingCommand();
    check(manager->state()==UnitManager::State::Default,"Follow target entry cancels");
    std::cout << "follow_checks=" << checks << " errors=0\n";
    return 0;
} catch(const std::exception &error){std::cerr << error.what() << '\n';return 1;}
