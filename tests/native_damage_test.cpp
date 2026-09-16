#include "global/Config.h"
#include "actions/ActionMove.h"
#include "actions/ActionAttack.h"
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
    auto actor=UnitFactory::createUnit(74,human,*manager),target=UnitFactory::createUnit(74,enemy,*manager);
    actor->setPosition(MapPos(480,480),true);target->setPosition(MapPos(485,480),true);
    Task task;for(const auto &definition:data.getTasks(74))if(definition.ActionType==genie::ActionType::Combat){task=Task(&definition,74);break;}
    task.target=target;auto strike=std::make_shared<ActionAttack>(actor,task);
    const auto hp=target->hitpointsLeft();
    for(Time t=100;t<=10000 && target->hitpointsLeft()==hp;t+=100)strike->update(t);
    std::cout << "militia_strike_damage=" << hp-target->hitpointsLeft() << "\n";
    check(hp-target->hitpointsLeft()==4,"actual unupgraded militia deals four damage per strike to militia");
    check(target->attackRevision==1 && target->lastAttacker.lock()==actor,"one strike records one damage event");
    auto fresh=[&]{return UnitFactory::createUnit(74,enemy,*manager);};
    auto damage=[&](std::vector<genie::unit::AttackOrArmor> classes,float multiplier=1.f){auto victim=fresh();const auto before=victim->hitpointsLeft();victim->receiveAttack(classes,multiplier,actor);return before-victim->hitpointsLeft();};
    check(damage({{4,4},{123,25}})==4,"unmatched bonus class does not add minimum damage");
    check(damage({{4,0},{3,0},{123,25}})==1,"fully blocked multichannel strike deals one total damage");
    check(damage({{4,4},{1,7}})==11,"matching infantry bonus adds to melee damage");
    check(damage({{4,4},{1,2}},1.5f)==9,"multiplier applies after combining damage classes");
    check(damage({{4,0},{3,0}},1.5f)==1,"minimum floor applies after multiplier");
    check(fresh()->data()->Combat.BaseArmor==1000 && damage({{123,1005}})==5,"unmatched class uses DAT base armor");
    auto untouched=fresh();untouched->receiveAttack(std::span<const genie::unit::AttackOrArmor>{},1.f,actor);
    check(untouched->hitpointsLeft()==untouched->data()->HitPoints && untouched->attackRevision==0,"empty attack does not cause damage or a hit event");
    std::cout << "damage_checks=" << checks << " errors=0\n";return 0;
} catch(const std::exception &error){std::cerr << error.what() << '\n';return 1;}
