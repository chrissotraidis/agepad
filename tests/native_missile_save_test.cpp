#include "global/Config.h"
#include "actions/ActionMove.h"
#include "mechanics/Missile.h"
#include "render/GraphicRender.h"
#include "resource/Sprite.h"
#include "mechanics/Map.h"
#include "mechanics/Building.h"
#include "mechanics/EntitySaveIndex.h"
#include "mechanics/UnitGraphSave.h"
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
    struct Fixture {std::shared_ptr<Map> map;std::shared_ptr<UnitManager> manager;std::shared_ptr<Player> owner,enemy;Unit::Ptr source,target;};
    auto make=[](){
        Fixture f;f.map=std::make_shared<Map>();f.map->setupBasic();f.map->updateMapData();
        f.manager=std::make_shared<UnitManager>();f.manager->setMap(f.map);if(!f.manager->init())throw std::runtime_error("manager init");
        f.owner=std::make_shared<Player>(1,1,f.map,ResourceMap{});f.enemy=std::make_shared<Player>(2,2,f.map,ResourceMap{});
        f.source=UnitFactory::createUnit(4,f.owner,*f.manager);f.target=UnitFactory::createUnit(72,f.enemy,*f.manager);
        f.source->setPosition(MapPos(480,480),true);f.target->Entity::setPosition(MapPos(720,480),true);return f;
    };
    auto original=make(),loaded=make();
    const auto &arrow=original.owner->civilization.unitData(original.source->data()->Combat.ProjectileUnitID);
    check(arrow.ID>=0 && arrow.Moving.TrackingUnit==-1,"actual arrow with no random smoke fixture");
    auto missile=std::make_shared<Missile>(arrow,original.source,original.target->position(),original.target);
    missile->setMap(original.map);missile->setPosition(MapPos(480,480,20),true);
    missile->update(100);missile->update(120);
    check(missile->isFlying() && missile->position().x>480 && missile->position().x<720,"projectile has travelled partway");
    const auto saved=missile->saveRuntime();
    loaded.source->restoreBaseRuntime(original.source->saveBaseRuntime(),120);
    loaded.target->restoreBaseRuntime(original.target->saveBaseRuntime(),120);
    agepad::EntitySaveIndex index;index.add(original.source->id,loaded.source);index.add(original.target->id,loaded.target);index.seal();
    auto restored=Missile::fromRuntime(saved,loaded.owner,*loaded.manager,loaded.map,index,120);
    check(restored->position()==missile->position() && restored->renderer().saveRuntime()==missile->renderer().saveRuntime(),"flight position and animation restored");
    check(loaded.source->activeMissiles==1,"restoration does not double source projectile count");
    bool occupancy=false;for(const auto &entity:loaded.map->entitiesAt(int(restored->position().x/48),int(restored->position().y/48)))occupancy |= entity.lock()==restored;
    check(occupancy,"restored missile registered in map occupancy");
    const float before=original.target->hitpointsLeft();bool equal=true;
    for(Time time=140;time<=5000;time+=20){
        missile->update(time);restored->update(time);
        equal &= missile->position()==restored->position() && missile->isFlying()==restored->isFlying() && original.target->hitpointsLeft()==loaded.target->hitpointsLeft();
        if(!missile->isFlying())break;
    }
    check(equal && !missile->isFlying() && original.target->hitpointsLeft()<before,"resumed flight and impact damage match uninterrupted arrow");
    bool truncated=true;
    for(std::size_t n=0;n<saved.size();++n){agepad::SaveBytes partial(saved.begin(),saved.begin()+n);truncated &= rejected([&]{Missile::fromRuntime(partial,loaded.owner,*loaded.manager,loaded.map,index,120);});}
    check(truncated && loaded.source->activeMissiles==1,"all truncations leave source count unchanged");
    check(rejected([&]{Missile::fromRuntime(saved,loaded.owner,*loaded.manager,loaded.map,index,119);}),"future missile update time refused");
    auto bad=saved;bad.push_back(0);
    check(rejected([&]{Missile::fromRuntime(bad,loaded.owner,*loaded.manager,loaded.map,index,120);}),"trailing missile data refused");
    missile.reset();restored.reset();
    check(original.source->activeMissiles==0 && loaded.source->activeMissiles==0,"destroyed source and restored missiles balance counters");
    auto orphan=std::make_shared<Missile>(arrow,original.source,original.target->position(),original.target);
    orphan->setMap(original.map);orphan->setPosition(MapPos(480,480,20),true);orphan->update(6000);orphan->update(6020);
    original.source.reset();
    const auto orphanBytes=orphan->saveRuntime();
    auto orphanLoaded=Missile::fromRuntime(orphanBytes,loaded.owner,*loaded.manager,loaded.map,index,6020);
    check(loaded.source->activeMissiles==0,"expired source restores without inventing owner count");
    for(Time time=6040;time<=10000 && orphan->isFlying();time+=20){orphan->update(time);orphanLoaded->update(time);}
    check(!orphan->isFlying() && !orphanLoaded->isFlying() && original.target->hitpointsLeft()==loaded.target->hitpointsLeft(),"projectile survives source removal and reaches matching impact");
    auto ground=std::make_shared<Missile>(loaded.owner->civilization.unitData(arrow.ID),loaded.source,MapPos(600,600),nullptr);
    check(bool(ground),"targetless projectile construction no longer dereferences null");
    auto ordered=make();
    ordered.manager->setPlayers({ordered.owner,ordered.enemy});ordered.manager->setHumanPlayer(ordered.owner);
    std::vector<Unit::Ptr> orderTargets;
    auto create=[&](MapPos destination) {
        auto target=UnitFactory::createUnit(72,ordered.enemy,*ordered.manager);
        target->Entity::setPosition(destination,true);orderTargets.push_back(target);
        auto result=std::make_shared<Missile>(ordered.owner->civilization.unitData(arrow.ID),ordered.source,destination,target);
        result->setMap(ordered.map);result->setPosition(MapPos(480,480,20),true);return result;
    };
    auto longFlight=create(MapPos(1000,480));
    auto shortFlight=create(MapPos(520,480));
    auto otherLongFlight=create(MapPos(1100,480));
    ordered.manager->addMissile(longFlight);ordered.manager->addMissile(shortFlight);ordered.manager->addMissile(otherLongFlight);
    ordered.manager->addMissile(shortFlight);ordered.manager->addMissile(nullptr);
    check(ordered.manager->missiles()==std::vector<Missile::Ptr>{longFlight,shortFlight,otherLongFlight},"firing order preserved; duplicate and null registration ignored");
    bool removedMiddle=false;
    Time resumeAt=11000;
    for(Time t=11000;t<16000;t+=20) {
        ordered.manager->update(t);
        const auto &active=ordered.manager->missiles();
        if(active.size()==2) {
            check(active==std::vector<Missile::Ptr>{longFlight,otherLongFlight},"finished middle projectile removed without reordering survivors");
            removedMiddle=true;resumeAt=t;break;
        }
    }
    check(removedMiddle,"short projectile finishes before longer flights");
    shortFlight.reset();
    check(ordered.source->activeMissiles==2,"finished projectile releases source count");
    // Simulate loader construction in reverse order, then registration in save order.
    auto restoredOrder=make();
    restoredOrder.source->restoreBaseRuntime(ordered.source->saveBaseRuntime(),resumeAt);
    agepad::EntitySaveIndex orderIndex;orderIndex.add(ordered.source->id,restoredOrder.source);
    std::vector<Unit::Ptr> restoredTargets;
    for(const auto &target:orderTargets) {
        auto copy=UnitFactory::createUnit(72,restoredOrder.enemy,*restoredOrder.manager);
        copy->restoreBaseRuntime(target->saveBaseRuntime(),resumeAt);
        orderIndex.add(target->id,copy);restoredTargets.push_back(copy);
    }
    orderIndex.seal();
    auto restoredSecond=Missile::fromRuntime(otherLongFlight->saveRuntime(),restoredOrder.owner,*restoredOrder.manager,restoredOrder.map,orderIndex,resumeAt);
    auto restoredFirst=Missile::fromRuntime(longFlight->saveRuntime(),restoredOrder.owner,*restoredOrder.manager,restoredOrder.map,orderIndex,resumeAt);
    restoredOrder.manager->addMissile(restoredFirst);restoredOrder.manager->addMissile(restoredSecond);
    check(restoredOrder.manager->missiles()==std::vector<Missile::Ptr>{restoredFirst,restoredSecond},"saved order wins over reconstruction allocation order");
    auto battle=make();
    battle.manager->setPlayers({battle.owner,battle.enemy});battle.manager->setHumanPlayer(battle.owner);
    battle.manager->add(battle.source,MapPos(480,480));battle.manager->add(battle.target,MapPos(720,480));
    battle.source->stance=Unit::Stance::NoAttack;battle.target->stance=Unit::Stance::NoAttack;
    auto shot=std::make_shared<Missile>(battle.owner->civilization.unitData(arrow.ID),battle.source,battle.target->position(),battle.target);
    shot->setMap(battle.map);shot->setPosition(MapPos(480,480,20),true);battle.manager->addMissile(shot);shot.reset();
    const auto &corpseData=battle.owner->civilization.unitData(battle.owner->civilization.unitData(74).DeadUnitID);
    auto effect=std::make_shared<DecayingEntity>(corpseData.StandingGraphic.first,2.f,Size(corpseData.Size));
    effect->setMap(battle.map);effect->setPosition(MapPos(576,576),true);battle.manager->addStaticEntity(effect);effect.reset();
    battle.target->isVisible=false;
    auto memory=UnitFactory::createDopplegangerFor(battle.target);battle.manager->addStaticEntity(memory);
    battle.manager->update(100);battle.manager->update(120);
    check(battle.manager->missiles().size()==1 && battle.source->activeMissiles==1,"battle snapshot contains an in-flight arrow");
    const auto graphBytes=agepad::UnitGraphSave::save(battle.manager->units());
    const auto effectsBytes=agepad::UnitGraphSave::saveEffects(*battle.manager);
    const auto managerBytes=agepad::UnitGraphSave::saveManager(*battle.manager);
    auto destination=std::make_shared<UnitManager>();auto terrain=Map::fromTerrainSave(battle.map->saveTerrain());
    destination->setMap(terrain);destination->init();
    std::vector<Player::Ptr> players;
    std::vector<agepad::SaveBytes> memberships;
    for(const auto &owner:std::vector<Player::Ptr>{battle.owner,battle.enemy}) {
        auto copy=std::make_shared<Player>(owner->playerId,owner->playerId,terrain,ResourceMap{});
        copy->civilization.restoreUnitAttributes(owner->civilization.saveUnitAttributes());
        copy->restoreResearchState(owner->saveResearchState());copy->restoreEconomyDiplomacy(owner->saveEconomyDiplomacy());
        copy->visibility->restoreRuntime(owner->visibility->saveRuntime());
        players.push_back(copy);memberships.push_back(owner->saveUnitMembership());
    }
    auto graph=agepad::UnitGraphSave::stage(graphBytes,players,*destination,120);
    auto newSource=graph.index.unit(battle.source->id),newTarget=graph.index.unit(battle.target->id);
    auto corrupt=effectsBytes;corrupt.push_back(0);
    check(rejected([&]{agepad::UnitGraphSave::stageEffects(graph,corrupt,players,*destination,120);}) && graph.missiles.empty() && graph.effects.empty() && newSource->activeMissiles==1,"failed effect staging preserves unit counts and graph");
    corrupt=effectsBytes;std::copy(graphBytes.begin()+8,graphBytes.begin()+16,corrupt.begin()+8);
    check(rejected([&]{agepad::UnitGraphSave::stageEffects(graph,corrupt,players,*destination,120);}) && newSource->activeMissiles==1,"effect ID colliding with unit ID is rejected transactionally");
    agepad::UnitGraphSave::stageEffects(graph,effectsBytes,players,*destination,120);
    check(graph.missiles.size()==1 && graph.effects.size()==2 && destination->missiles().empty() && newSource->activeMissiles==1,"effect staging binds graph without registering or recounting projectiles");
    bool emptyTerrain=true;
    for(int y=0;y<terrain->rowCount();++y)for(int x=0;x<terrain->columnCount();++x)
        for(const auto &weak:terrain->entitiesAt(x,y))emptyTerrain &= weak.expired();
    check(emptyTerrain,"staged effects leave destination occupancy untouched");
    agepad::UnitGraphSave::activate(graph,*destination,players,memberships,managerBytes,120);
    check(destination->missiles().size()==1 && destination->staticEntities().size()==2 && newSource->activeMissiles==1,"activation transfers battle effects and preserves source count");
    bool battleEqual=true;const float health=battle.target->hitpointsLeft();
    for(Time t=140;t<=22000;t+=20) {
        battle.manager->update(t);destination->update(t);
        battleEqual &= battle.source->activeMissiles==newSource->activeMissiles && battle.target->hitpointsLeft()==newTarget->hitpointsLeft() &&
            battle.manager->missiles().size()==destination->missiles().size() && battle.manager->staticEntities().size()==destination->staticEntities().size();
        if(!destination->missiles().empty() && !battle.manager->missiles().empty())battleEqual &= destination->missiles()[0]->position()==battle.manager->missiles()[0]->position();
    }
    check(battleEqual && newTarget->hitpointsLeft()<health && newSource->activeMissiles==0 && destination->missiles().empty() && destination->staticEntities().size()==1,"normal resumed battle matches arrow impact, counter release and corpse expiration while retaining fog memory");
    auto newMemory=DopplegangerEntity::fromEntity(*destination->staticEntities().begin());
    check(newMemory && newMemory->ownerID==memory->ownerID && newMemory->position()==memory->position() &&
        newMemory->renderer().saveRuntime()==memory->renderer().saveRuntime(),"fog memory appearance, owner and geometry survive graph activation");
    battle.target->isVisible=true;newTarget->isVisible=true;
    battle.manager->update(22020);destination->update(22020);
    check(battle.manager->staticEntities().empty() && destination->staticEntities().empty(),"rediscovered original removes both source and resumed fog memory");
    auto hidden=UnitFactory::createUnit(109,players[1],*destination);
    hidden->isVisible=false;hidden->Entity::setPosition(MapPos(672,672),true);
    auto ruin=std::make_shared<DopplegangerEntity>(hidden);ruin->setPosition(hidden->position(),true);
    hidden.reset();
    agepad::EntitySaveIndex empty;empty.seal();
    const auto fogBytes=ruin->saveRuntime();
    auto restoredRuin=DopplegangerEntity::fromRuntime(fogBytes,players[1],*destination,empty,22020);
    check(restoredRuin->saveRuntime()==fogBytes && !restoredRuin->map(),"expired original link restores detached remembered building without recreating a unit");
    ruin->isVisible=true;restoredRuin->isVisible=true;ruin->update(22040);restoredRuin->update(22040);
    check(ruin->saveRuntime()==restoredRuin->saveRuntime() && ruin->shouldBeRemoved()==restoredRuin->shouldBeRemoved(),"destroyed building memory follows identical rubble transition");
    check(rejected([&]{DopplegangerEntity::fromRuntime(fogBytes,players[0],*destination,empty,22020);}),"wrong remembered owner is rejected");
    bool fogTruncations=true;
    for(std::size_t n=0;n<fogBytes.size();++n) {
        agepad::SaveBytes partial(fogBytes.begin(),fogBytes.begin()+n);
        fogTruncations &= rejected([&]{DopplegangerEntity::fromRuntime(partial,players[1],*destination,empty,22020);});
    }
    check(fogTruncations,"all truncated fog memory records rejected");
    auto badFog=fogBytes;badFog.push_back(0);
    check(rejected([&]{DopplegangerEntity::fromRuntime(badFog,players[1],*destination,empty,22020);}),"trailing fog memory bytes rejected");
    std::cout << "missile_save_checks=" << checks << " errors=0\n";
    return 0;
} catch(const std::exception &error){std::cerr << error.what() << '\n';return 1;}
