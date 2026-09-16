#include "global/Config.h"
#include "actions/ActionMove.h"
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
    auto map=std::make_shared<Map>();map->setupBasic();map->updateMapData();
    auto manager=std::make_shared<UnitManager>();manager->setMap(map);
    if(!manager->init())throw std::runtime_error("manager init");
    auto human=std::make_shared<Player>(1,1,map,ResourceMap{});
    auto enemy=std::make_shared<Player>(2,2,map,ResourceMap{});
    manager->setPlayers({human,enemy});manager->setHumanPlayer(human);
    auto add=[&](int id,auto owner,int x){auto u=UnitFactory::createUnit(id,owner,*manager);manager->add(u,MapPos(x,480));return u;};
    auto soldier=add(74,human,250);
    auto first=add(83,human,350);
    auto second=add(293,human,400);
    auto enemyVillager=add(83,enemy,200);
    auto resources=human->saveEconomyDiplomacy();
    manager->setSelectedUnits({soldier,first,first,enemyVillager});
    check(manager->assignControlGroup(0) && manager->controlGroupSize(0)==2,"deduplicates and excludes enemies");
    manager->setSelectedUnits({second});
    check(manager->recallControlGroup(0) && manager->selected().size()==2 && manager->selected().first()==soldier,"recall replaces selection in assigned order");
    manager->setSelectedUnits({second});
    check(manager->recallControlGroup(0,true) && manager->selected().size()==3 && manager->selected().first()==second,"extend preserves selection then adds group");
    check(manager->assignControlGroup(0,true) && manager->controlGroupSize(0)==3,"add members avoids duplicates");
    manager->setSelectedUnits({second});
    check(manager->assignControlGroup(1) && manager->controlGroupSize(0)==3 && manager->controlGroupSize(1)==1,"groups independent");
    check(manager->assignControlGroup(0) && manager->controlGroupSize(0)==1,"set replaces old membership");
    manager->setSelectedUnits({enemyVillager});
    check(!manager->assignControlGroup(0) && manager->controlGroupSize(0)==1,"enemy only assignment preserves group");
    check(!manager->recallControlGroup(9) && manager->selected().first()==enemyVillager,"empty recall preserves selection");
    check(!manager->assignControlGroup(-1) && !manager->recallControlGroup(10),"invalid slots safe");
    manager->setSelectedUnits({soldier,first});manager->assignControlGroup(2);
    check(human->saveEconomyDiplomacy()==resources && !second->actions.currentAction(),"group actions issue no orders or charges");
    first->kill();
    check(manager->recallControlGroup(2) && manager->selected().size()==1 && manager->selected().first()==soldier,"dead members excluded");
    manager->remove(soldier);
    check(!manager->recallControlGroup(2),"removed member with surviving pointer excluded");
    manager->setSelectedUnits({second});manager->assignControlGroup(3);
    auto shelter=std::dynamic_pointer_cast<Building>(UnitFactory::createUnit(109,human,*manager));
    check(bool(shelter),"garrison fixture building");
    second->garrisonedIn=shelter;
    check(!manager->recallControlGroup(3),"garrisoned member unavailable");
    second->garrisonedIn.reset();
    check(manager->recallControlGroup(3),"ungarrisoned member remains assigned");
    second->setPlayer(enemy);
    check(!manager->recallControlGroup(3),"converted member cannot be recalled by former owner");
    second->setPlayer(human);
    manager->startPlaceBuilding(70,human);
    check(manager->recallControlGroup(3) && manager->state()==UnitManager::State::Default && manager->buildingsToPlace().empty(),"recall cancels pending placement");
    std::cout << "control_group_checks=" << checks << " errors=0\n";
    return 0;
} catch(const std::exception &error){std::cerr << error.what() << '\n';return 1;}
