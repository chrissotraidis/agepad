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
    auto enemyVillager=add(83,enemy,200);
    auto soldier=add(74,human,250);
    auto busy=add(83,human,300);
    auto first=add(83,human,350);
    auto second=add(293,human,400);
    auto queued=add(83,human,450);
    busy->actions.m_currentAction=ActionMove::moveUnitTo(busy,MapPos(300,600));
    queued->actions.m_actionQueue.push_back(ActionMove::moveUnitTo(queued,MapPos(450,600)));
    auto resources=human->saveEconomyDiplomacy();
    check(manager->selectNextIdleVillager()==first,"skips enemy military and active worker");
    check(manager->selected().size()==1 && manager->selected().first()==first,"one idle worker selected");
    check(manager->selectNextIdleVillager()==second,"cycles through male and female villagers");
    check(manager->selectNextIdleVillager()==first,"wraps and skips queued worker");
    check(human->saveEconomyDiplomacy()==resources && !first->actions.currentAction(),"selection neither spends resources nor issues an order");
    first->kill();
    check(manager->selectNextIdleVillager()==second,"dying worker excluded");
    second->actions.m_currentAction=ActionMove::moveUnitTo(second,MapPos(400,600));
    check(!manager->selectNextIdleVillager(),"no eligible worker returns no target");
    check(manager->selected().first()==second,"no idle worker preserves current selection");
    std::cout << "idle_villager_checks=" << checks << " errors=0\n";
    return 0;
} catch(const std::exception &error){std::cerr << error.what() << '\n';return 1;}
