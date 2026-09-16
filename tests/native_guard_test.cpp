#include "global/Config.h"
#include "actions/ActionMove.h"
#include "actions/ActionAttack.h"
#include "actions/ActionGuard.h"
#include "render/GraphicRender.h"
#include "resource/Sprite.h"
#include "mechanics/Map.h"
#include "mechanics/Building.h"
#include "mechanics/EntitySaveIndex.h"
#include "mechanics/UnitGraphSave.h"
#include "mechanics/Missile.h"
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
    auto protectedUnit=UnitFactory::createUnit(74,human,*manager);
    manager->add(protectedUnit,MapPos(850,480));map->updateMapData();
    actor->stance=Unit::Stance::NoAttack;
    auto guard=std::make_shared<ActionGuard>(actor,protectedUnit);actor->actions.setCurrentAction(guard);
    actor->update(100);actor->update(200);
    check(actor->position().x>480,"guard approaches protected unit");
    agepad::EntitySaveIndex index;index.add(actor->id,actor);index.add(protectedUnit->id,protectedUnit);index.seal();
    auto bytes=guard->saveRuntime();auto restored=IAction::fromRuntime(IAction::Type::Guard,bytes,index,200);
    check(restored->saveRuntime()==bytes,"moving guard and protected target roundtrip");
    actor->actions.setCurrentAction(restored);
    for(Time t=300;t<=15000;t+=100)actor->update(t);
    const auto waiting=actor->position();
    protectedUnit->setPosition(MapPos(950,700));map->updateMapData();
    for(Time t=15100;t<=25000;t+=100)actor->update(t);
    check(actor->position()!=waiting && actor->actions.currentAction()==restored,"guard tracks protected unit after load");
    actor->actions.clearActionQueue();actor->setPosition(MapPos(480,480));protectedUnit->setPosition(MapPos(560,480));
    auto threat=UnitFactory::createUnit(74,enemy,*manager);manager->add(threat,MapPos(620,530));map->updateMapData();
    human->setDiplomaticStance(2,Player::Enemy);actor->stance=Unit::Stance::Aggressive;
    guard=std::make_shared<ActionGuard>(actor,protectedUnit);actor->actions.setCurrentAction(guard);
    actor->update(25100);actor->update(25200);
    agepad::EntitySaveIndex combatIndex;combatIndex.add(actor->id,actor);combatIndex.add(protectedUnit->id,protectedUnit);combatIndex.add(threat->id,threat);combatIndex.seal();
    bytes=guard->saveRuntime();restored=IAction::fromRuntime(IAction::Type::Guard,bytes,combatIndex,25200);
    check(restored->saveRuntime()==bytes,"guard combat child survives exact save roundtrip");
    actor->actions.setCurrentAction(restored);bool stayedNear=true;
    for(Time t=25300;t<=65000;t+=100){actor->update(t);stayedNear &= actor->distanceTo(protectedUnit)<=actor->data()->LineOfSight*48;}
    check(threat->healthLeft()<=0 && stayedNear && actor->actions.currentAction()==restored,"guard defeats nearby threat while retaining protected target");
    auto runner=UnitFactory::createUnit(74,enemy,*manager);manager->add(runner,MapPos(620,530));map->updateMapData();
    actor->update(65100);const auto runnerHealth=runner->healthLeft();runner->setPosition(MapPos(1000,950));map->updateMapData();
    for(Time t=65200;t<=75000;t+=100)actor->update(t);
    check(actor->distanceTo(protectedUnit)<=actor->data()->LineOfSight*48 && runner->healthLeft()==runnerHealth,
          "guard abandons enemy leaving protected area");
    actor->actions.clearActionQueue();actor->setPosition(MapPos(480,480));runner->setPosition(MapPos(620,530));map->updateMapData();
    actor->stance=Unit::Stance::StandGround;guard=std::make_shared<ActionGuard>(actor,protectedUnit);actor->actions.setCurrentAction(guard);
    const auto stand=actor->position();const auto standHealth=runner->healthLeft();for(Time t=75100;t<=80000;t+=100)actor->update(t);
    check(actor->position()==stand && runner->healthLeft()==standHealth,"Stand Ground guard does not pursue");
    runner->setPosition(MapPos(485,480));map->updateMapData();
    for(Time t=80100;t<=85000;t+=100)actor->update(t);
    check(actor->position()==stand && runner->healthLeft()<standHealth,"Stand Ground guard attacks within reach without moving");
    actor->stance=Unit::Stance::NoAttack;const auto health=runner->healthLeft();
    for(Time t=85100;t<=90000;t+=100)actor->update(t);
    check(runner->healthLeft()==health,"No Attack cancels active guard combat");
    bool truncations=true;for(std::size_t i=0;i<bytes.size();++i){agepad::SaveBytes partial(bytes.begin(),bytes.begin()+i);truncations &= rejected([&]{ActionGuard::fromRuntime(partial,combatIndex,90000);});}
    check(truncations,"all guard save truncations rejected");
    auto mismatched=bytes;for(unsigned i=0;i<8;++i)mismatched[12+i]=(std::uint64_t(threat->id)>>(i*8))&255;
    check(rejected([&]{ActionGuard::fromRuntime(mismatched,combatIndex,90000);}),"guard rejects inconsistent protected target in nested follow");
    actor->actions.clearActionQueue();const auto stop=actor->position();actor->update(90100);
    check(actor->position()==stop && !actor->actions.currentAction(),"Stop cancels guard and children");
    auto building=UnitFactory::createUnit(109,human,*manager);manager->add(building,MapPos(850,700));map->updateMapData();
    actor->setPosition(MapPos(480,480));actor->stance=Unit::Stance::NoAttack;
    guard=std::make_shared<ActionGuard>(actor,building);actor->actions.setCurrentAction(guard);
    for(Time t=90200;t<=105000;t+=100)actor->update(t);
    check(actor->position()!=MapPos(480,480) && actor->distanceTo(building)<=actor->data()->LineOfSight*48,
          "guard approaches and remains within sight of a building");
    auto lost=std::make_shared<ActionGuard>(actor,std::shared_ptr<Unit>{});
    check(lost->update(105100)==IAction::UpdateResult::Completed,"guard ends safely when protected target disappears");
    auto reactionMap=std::make_shared<Map>();reactionMap->setupBasic();reactionMap->updateMapData();
    auto reactionManager=std::make_shared<UnitManager>();reactionManager->setMap(reactionMap);reactionManager->init();
    auto defender=std::make_shared<Player>(1,1,reactionMap,ResourceMap{}),invader=std::make_shared<Player>(2,2,reactionMap,ResourceMap{});
    defender->setDiplomaticStance(2,Player::Enemy);
    auto rangedGuard=UnitFactory::createUnit(7,defender,*reactionManager),ward=UnitFactory::createUnit(74,defender,*reactionManager),shooter=UnitFactory::createUnit(74,invader,*reactionManager);
    reactionManager->add(rangedGuard,MapPos(600,650));reactionManager->add(ward,MapPos(500,650));reactionManager->add(shooter,MapPos(740,650));reactionMap->updateMapData();
    check(ward->distanceTo(shooter)>ward->data()->LineOfSight*48,"attacker fixture is outside protected unit sight");
    auto reactive=std::make_shared<ActionGuard>(rangedGuard,ward);rangedGuard->actions.setCurrentAction(reactive);
    for(Time t=100;t<=3000;t+=100)rangedGuard->update(t);
    check(reactionManager->missiles().empty(),"guard does not acquire out-of-sight enemy before attack");
    ward->receiveAttack(shooter->data()->Combat.Attacks.front(),1.f,shooter);
    check(ward->lastAttacker.lock()==shooter && ward->attackRevision==1,"damage records attacker identity and hit revision");
    rangedGuard->update(3100);
    agepad::EntitySaveIndex reactionIndex;reactionIndex.add(rangedGuard->id,rangedGuard);reactionIndex.add(ward->id,ward);reactionIndex.add(shooter->id,shooter);reactionIndex.seal();
    const auto reactionBytes=reactive->saveRuntime();
    auto resumedReaction=ActionGuard::fromRuntime(reactionBytes,reactionIndex,3100);
    check(resumedReaction->saveRuntime()==reactionBytes,"guard retaliation phase and seen hit persist exactly");
    rangedGuard->actions.setCurrentAction(resumedReaction);
    for(Time t=3200;t<=10000;t+=100)rangedGuard->update(t);
    check(!reactionManager->missiles().empty() && rangedGuard->distanceTo(ward)<=rangedGuard->data()->LineOfSight*48,
          "restored guard fires at attacker outside protected sight while keeping ward in sight");
    const auto shotTime=rangedGuard->lastAttackTime;
    ward->stance=shooter->stance=Unit::Stance::NoAttack;
    for(Time t=10100;t<=15000;t+=100){ward->receiveAttack(shooter->data()->Combat.Attacks.front(),0.f,shooter);reactionManager->update(t);if(ward->hitpointsLeft()<=5)break;}
    check(rangedGuard->lastAttackTime>shotTime,"repeated hits do not restart guard firing indefinitely");
    auto graphMap=Map::fromTerrainSave(reactionMap->saveTerrain());auto graphManager=std::make_shared<UnitManager>();graphManager->setMap(graphMap);graphManager->init();
    const auto graphBytes=agepad::UnitGraphSave::save(reactionManager->units());
    auto graph=agepad::UnitGraphSave::stage(graphBytes,{defender,invader},*graphManager,15000);
    check(graph.index.unit(ward->id)->lastAttacker.lock()==graph.index.unit(shooter->id) &&
          graph.index.unit(ward->id)->attackRevision==ward->attackRevision,"unit graph restores attacker link to reconstructed unit");
    auto legacy=reactionBytes;legacy[0]=1;legacy.resize(legacy.size()-12);
    check(bool(ActionGuard::fromRuntime(legacy,reactionIndex,15000)),"previous Guard saves remain readable");
    std::cout << "guard_checks=" << checks << " errors=0\n";return 0;
} catch(const std::exception &error){std::cerr << error.what() << '\n';return 1;}
