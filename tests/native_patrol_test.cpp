#include "global/Config.h"
#include "actions/ActionMove.h"
#include "actions/ActionAttack.h"
#include "actions/ActionPatrol.h"
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
    auto patrol=std::make_shared<ActionPatrol>(actor,std::vector<MapPos>{MapPos(480,480),MapPos(720,480)});
    actor->actions.setCurrentAction(patrol);
    float furthest=480;bool reversed=false;
    for(Time t=100;t<=20000;t+=100) {
        actor->update(t);furthest=std::max(furthest,actor->position().x);
        if(furthest>700 && actor->position().x<520){reversed=true;break;}
    }
    check(reversed && actor->actions.currentAction()==patrol,"patrol reaches endpoint and returns while retaining order");
    agepad::EntitySaveIndex index;index.add(actor->id,actor);index.seal();
    auto saved=patrol->saveRuntime();auto restored=ActionPatrol::fromRuntime(saved,index,20000);
    check(restored->saveRuntime()==saved,"active route direction and child movement roundtrip exactly");
    actor->actions.setCurrentAction(restored);
    bool again=false;
    for(Time t=20100;t<=40000;t+=100){actor->update(t);if(actor->position().x>700){again=true;break;}}
    check(again,"restored patrol continues another outward leg");
    bool truncations=true;
    for(std::size_t i=0;i<saved.size();++i) {
        agepad::SaveBytes partial(saved.begin(),saved.begin()+i);
        truncations &= rejected([&]{ActionPatrol::fromRuntime(partial,index,40000);});
    }
    check(truncations,"all patrol truncations rejected");
    actor->actions.clearActionQueue();actor->setPosition(MapPos(480,480));
    auto target=UnitFactory::createUnit(74,enemy,*manager);manager->add(target,MapPos(580,530));map->updateMapData();
    human->setDiplomaticStance(2,Player::Enemy);
    auto fighter=std::make_shared<ActionPatrol>(actor,std::vector<MapPos>{MapPos(480,480),MapPos(720,480)});
    actor->actions.setCurrentAction(fighter);
    bool defeated=false,returned=false;
    for(Time t=40100;t<=100000;t+=100) {
        actor->update(t);
        defeated |= target->healthLeft()<=0;
        if(defeated && actor->position().x>700 && std::abs(actor->position().y-480)<2){returned=true;break;}
    }
    check(defeated && returned && actor->actions.currentAction()==fighter,"patrol engages enemy then returns and resumes route");
    actor->actions.clearActionQueue();actor->setPosition(MapPos(480,480));
    auto runner=UnitFactory::createUnit(74,enemy,*manager);manager->add(runner,MapPos(580,530));map->updateMapData();
    auto leashed=std::make_shared<ActionPatrol>(actor,std::vector<MapPos>{MapPos(480,480),MapPos(720,480)});
    actor->actions.setCurrentAction(leashed);actor->update(100100);actor->update(100200);
    agepad::EntitySaveIndex combatIndex;combatIndex.add(actor->id,actor);combatIndex.add(runner->id,runner);combatIndex.seal();
    auto combatBytes=leashed->saveRuntime();
    auto resumedCombat=ActionPatrol::fromRuntime(combatBytes,combatIndex,100200);
    check(resumedCombat->saveRuntime()==combatBytes,"patrol engagement and nested attack persist");
    actor->actions.setCurrentAction(resumedCombat);
    runner->setPosition(MapPos(580,950));map->updateMapData();
    bool stayedNear=true;
    for(Time t=100300;t<=120000;t+=100){actor->update(t);stayedNear &= actor->position().y<700;}
    check(stayedNear && runner->hitpointsLeft()==runner->data()->HitPoints,"enemy leaving route sight is not chased indefinitely");
    actor->actions.clearActionQueue();actor->setPosition(MapPos(480,480));
    runner->setPosition(MapPos(580,530));map->updateMapData();actor->stance=Unit::Stance::StandGround;
    auto passive=std::make_shared<ActionPatrol>(actor,std::vector<MapPos>{MapPos(480,480),MapPos(720,480)});
    actor->actions.setCurrentAction(passive);
    for(Time t=120100;t<=128000;t+=100)actor->update(t);
    check(runner->hitpointsLeft()==runner->data()->HitPoints && std::abs(actor->position().y-480)<2,"Stand Ground continues patrol without pursuing visible enemy");
    actor->actions.clearActionQueue();const auto stop=actor->position();actor->update(128100);
    check(actor->position()==stop && !actor->actions.currentAction(),"Stop cancels patrol and its child");
    manager->setHumanPlayer(human);manager->setSelectedUnits({actor});
    actor->stance=Unit::Stance::NoAttack;actor->setPosition(MapPos(480,480));
    auto camera=std::make_shared<Camera>();camera->setViewportSize(Size(800,600));camera->setTargetPosition(MapPos(600,600));
    manager->selectPatrolTarget();
    manager->onLeftClick(camera->absoluteScreenPos(MapPos(720,480)),camera,true);
    check(!actor->actions.currentAction() && manager->state()==UnitManager::State::SelectingPatrolTarget,
          "Shift waypoint input keeps route pending until final click");
    manager->onLeftClick(camera->absoluteScreenPos(MapPos(720,720)),camera,false);
    check(actor->actions.currentAction() && actor->actions.currentAction()->type==IAction::Type::Patrol && manager->state()==UnitManager::State::Default,
          "final ground click starts original patrol command");
    bool first=false,last=false,retraced=false;
    for(Time t=128200;t<180000;t+=100) {
        actor->update(t);const auto p=actor->position();
        if(p.distance(MapPos(720,480))<3){if(last)retraced=true;else first=true;}
        if(p.distance(MapPos(720,720))<3)last=true;
        if(retraced)break;
    }
    check(first && last && retraced,"multi-waypoint patrol visits points in order then retraces");
    actor->actions.clearActionQueue();actor->setPosition(MapPos(480,480));
    auto loop=std::make_shared<ActionPatrol>(actor,std::vector<MapPos>{MapPos(480,480),MapPos(720,480),MapPos(720,720)},true);
    actor->actions.setCurrentAction(loop);bool loopEnd=false,loopHome=false;
    for(Time t=180100;t<230000;t+=100) {
        actor->update(t);const auto p=actor->position();
        if(p.distance(MapPos(720,720))<3)loopEnd=true;
        if(loopEnd && p.distance(MapPos(480,480))<3){loopHome=true;break;}
    }
    check(loopEnd && loopHome,"loop route returns directly to origin after last waypoint");
    manager->selectPatrolTarget();manager->onLeftClick(camera->absoluteScreenPos(MapPos(700,500)),camera,true);
    manager->cancelPendingCommand();
    check(manager->state()==UnitManager::State::Default && manager->m_patrolPoints.empty(),"cancel clears unfinished patrol points");
    std::cout << "patrol_checks=" << checks << " errors=0\n";
    return 0;
} catch(const std::exception &error){std::cerr << error.what() << '\n';return 1;}
