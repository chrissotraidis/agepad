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
    auto loadedActor=UnitFactory::createUnit(74,human,*manager),loadedTarget=UnitFactory::createUnit(74,enemy,*manager);
    actor->setPosition(MapPos(480,480),true);target->setPosition(MapPos(485,480),true);
    Task task;
    for(const auto &definition:data.getTasks(74))if(definition.ActionType==genie::ActionType::Combat){task=Task(&definition,74);break;}
    check(task.data!=nullptr,"actual militia combat task found");task.target=target;
    auto action=std::make_shared<ActionAttack>(actor,task);action->requiredUnitID=74;
    for(Time time=100;time<=3000;time+=100)action->update(time);
    check(target->hitpointsLeft()>0 && target->hitpointsLeft()<target->data()->HitPoints,"mid-combat damage fixture");
    check(target->lastAttacker.lock()==actor && target->attackRevision>0,"melee damage records actual attacker");
    // Unit base sections are restored; graph membership/occupancy remains a
    // separate loader dependency. This close-range melee test needs neither.
    loadedActor->restoreBaseRuntime(actor->saveBaseRuntime(),3000);
    loadedTarget->restoreBaseRuntime(target->saveBaseRuntime(),3000);
    agepad::EntitySaveIndex index;index.add(actor->id,loadedActor);index.add(target->id,loadedTarget);index.seal();
    const auto bytes=action->saveRuntime();
    auto legacy=bytes;legacy[0]=1;legacy.resize(legacy.size()-4);
    check(ActionAttack::fromRuntime(legacy,index,3000)->unitState()==action->unitState(),
          "version one attacks remain readable without nested pursuit");
    auto restored=ActionAttack::fromRuntime(bytes,index,3000);
    check(restored->requiredUnitID==74 && restored->unitState()==action->unitState(),"action worker type and firing phase restored");
    bool equal=true;bool completed=false;
    for(Time time=3100;time<=60000;time+=100){
        auto a=action->update(time),b=restored->update(time);
        equal &= a==b && actor->lastAttackTime==loadedActor->lastAttackTime && target->hitpointsLeft()==loadedTarget->hitpointsLeft() && action->unitState()==restored->unitState();
        if(a==IAction::UpdateResult::Completed){completed=true;break;}
    }
    check(equal && completed,"every resumed melee damage/cooldown step matches uninterrupted fight");
    check(loadedTarget->hitpointsLeft()<=0,"restored fight reaches defeated target");
    const auto before=loadedTarget->saveBaseRuntime();
    bool truncated=true;
    for(std::size_t n=0;n<bytes.size();++n){agepad::SaveBytes partial(bytes.begin(),bytes.begin()+n);truncated &= rejected([&]{ActionAttack::fromRuntime(partial,index,3000);});}
    check(truncated && loadedTarget->saveBaseRuntime()==before,"all truncations rejected without damaging target");
    auto bad=bytes;bad.push_back(0);
    check(rejected([&]{ActionAttack::fromRuntime(bad,index,3000);}),"trailing action data refused");
    bad=bytes;for(int i=24;i<28;++i)bad[i]=255;
    check(rejected([&]{ActionAttack::fromRuntime(bad,index,3000);}),"oversized nested task refused");
    agepad::EntitySaveIndex missing;missing.add(actor->id,loadedActor);missing.seal();
    check(rejected([&]{ActionAttack::fromRuntime(bytes,missing,3000);}),"unresolved saved target refused");
    Task gone=task;gone.target.reset();
    auto finished=std::make_shared<ActionAttack>(actor,gone);
    check(ActionAttack::fromRuntime(finished->saveRuntime(),index,60000)->update(60100)==IAction::UpdateResult::Completed,"expired former target completes safely");
    // A ground-attack move has no target entity: preserve the coordinate when
    // approaching, instead of passing a null unit into the movement factory.
    manager->add(actor,actor->position());manager->add(loadedActor,loadedActor->position());
    Task groundTask=task;groundTask.target.reset();
    auto ground=std::make_shared<ActionAttack>(actor,MapPos(800,800),groundTask);
    auto groundLoaded=ActionAttack::fromRuntime(ground->saveRuntime(),index,60000);
    actor->actions.setCurrentAction(ground);loadedActor->actions.setCurrentAction(groundLoaded);
    check(ground->update(61000)==IAction::UpdateResult::NotUpdated && groundLoaded->update(61000)==IAction::UpdateResult::NotUpdated,"out-of-range ground attack plans approach safely");
    check(actor->actions.currentAction()==ground && loadedActor->actions.currentAction()==groundLoaded &&
          ground->unitState()==IAction::Moving && groundLoaded->unitState()==IAction::Moving &&
          actor->actions.m_actionQueue.empty(),"approach belongs to attack without inserting standalone queued moves");
    actor->actions.clearActionQueue();loadedActor->actions.clearActionQueue();
    auto diplomaticTarget=UnitFactory::createUnit(74,enemy,*manager);
    manager->add(diplomaticTarget,MapPos(485,480));map->updateMapData();
    human->setDiplomaticStance(2,Player::Neutral);enemy->setDiplomaticStance(1,Player::Enemy);
    check(!actor->actions.checkForAutoTargets().isValid(),"neutral target is ignored despite its hostile stance toward us");
    auto explicitTask=actor->actions.findTaskWithTarget(diplomaticTarget);
    check(explicitTask.isValid(),"neutral target still accepts explicit combat order");
    human->setDiplomaticStance(2,Player::Enemy);
    check(actor->actions.checkForAutoTargets().target.lock()==diplomaticTarget,"enemy target is acquired automatically");
    const auto acquisitionOrigin=actor->position();
    const float sight=actor->data()->LineOfSight*Constants::TILE_SIZE;
    for(const MapPos offset:{MapPos(sight,0),MapPos(-sight,0),MapPos(0,sight),MapPos(0,-sight)}) {
        diplomaticTarget->setPosition(acquisitionOrigin+offset);map->updateMapData();
        check(actor->actions.checkForAutoTargets().target.lock()==diplomaticTarget,
              "equal-distance cardinal enemies are all acquired at sight boundary");
    }
    for(const MapPos offset:{MapPos(sight+96,0),MapPos(-sight-96,0),MapPos(0,sight+96),MapPos(0,-sight-96)}) {
        diplomaticTarget->setPosition(acquisitionOrigin+offset);map->updateMapData();
        check(!actor->actions.checkForAutoTargets().isValid(),"outside-sight cardinal enemies stay ignored");
    }
    diplomaticTarget->setPosition(MapPos(485,480));map->updateMapData();
    auto ongoing=std::make_shared<ActionAttack>(actor,explicitTask);
    agepad::EntitySaveIndex diplomacyIndex;diplomacyIndex.add(actor->id,actor);diplomacyIndex.add(diplomaticTarget->id,diplomaticTarget);diplomacyIndex.seal();
    auto loadedAttack=ActionAttack::fromRuntime(ongoing->saveRuntime(),diplomacyIndex,61000);
    const float diplomacyHealth=diplomaticTarget->hitpointsLeft();
    human->setDiplomaticStance(2,Player::Allied);
    check(ongoing->update(100000)==IAction::UpdateResult::Completed && loadedAttack->update(100000)==IAction::UpdateResult::Completed &&
          diplomaticTarget->hitpointsLeft()==diplomacyHealth,"live and restored attacks stop before damaging newly allied target");
    human->setDiplomaticStance(2,Player::Neutral);
    auto neutralAttack=std::make_shared<ActionAttack>(actor,explicitTask);neutralAttack->update(100000);
    check(diplomaticTarget->hitpointsLeft()<diplomacyHealth,"explicit neutral attack still deals damage");
    human->setDiplomaticStance(2,Player::Enemy);
    diplomaticTarget->setPosition(MapPos(800,480),true);map->updateMapData();
    auto pursuit=std::make_shared<ActionAttack>(actor,explicitTask);
    actor->actions.setCurrentAction(pursuit);
    const auto start=actor->position();
    for(Time time=100100;time<=100600;time+=100)pursuit->update(time);
    check(actor->position().distance(start)>0 && pursuit->unitState()==IAction::Moving,
          "attack advances a real pursuit before save");
    const auto pursuitBytes=pursuit->saveRuntime();
    auto resumedPursuit=ActionAttack::fromRuntime(pursuitBytes,diplomacyIndex,100600);
    check(resumedPursuit->saveRuntime()==pursuitBytes && resumedPursuit->unitState()==IAction::Moving,
          "mid-pursuit path and movement phase roundtrip exactly");
    const auto beforeAlliance=actor->position();
    human->setDiplomaticStance(2,Player::Allied);
    check(pursuit->update(100700)==IAction::UpdateResult::Completed &&
          resumedPursuit->update(100700)==IAction::UpdateResult::Completed &&
          actor->position()==beforeAlliance,"live and restored pursuit cancel before moving toward new ally");
    bool pursuitTruncated=true;
    for(std::size_t n=0;n<pursuitBytes.size();++n) {
        agepad::SaveBytes partial(pursuitBytes.begin(),pursuitBytes.begin()+n);
        pursuitTruncated &= rejected([&]{ActionAttack::fromRuntime(partial,diplomacyIndex,100600);});
    }
    check(pursuitTruncated,"all nested pursuit truncations rejected");
    human->setDiplomaticStance(2,Player::Enemy);
    actor->actions.setCurrentAction(resumedPursuit);
    bool defeatedAfterPursuit=false;
    for(Time time=100700;time<=160000;time+=100) {
        actor->update(time);
        if(diplomaticTarget->healthLeft()<=0) { defeatedAfterPursuit=true;break; }
    }
    check(defeatedAfterPursuit,"restored pursuit reaches melee range and defeats target");
    auto farTarget=UnitFactory::createUnit(74,enemy,*manager);
    manager->add(farTarget,MapPos(960,480));map->updateMapData();
    auto farTask=explicitTask;farTask.target=farTarget;
    auto interrupted=std::make_shared<ActionAttack>(actor,farTask);
    actor->actions.setCurrentAction(interrupted);actor->update(160100);
    check(interrupted->unitState()==IAction::Moving,"stop fixture is pursuing a distant target");
    actor->actions.clearActionQueue();const auto stoppedPosition=actor->position();actor->update(160200);
    check(actor->position()==stoppedPosition && !actor->actions.currentAction() && actor->actions.m_actionQueue.empty(),
          "ordinary stop cancels entire pursuit without orphaned movement");
    auto skirmisher=UnitFactory::createUnit(7,human,*manager);
    auto closeTarget=UnitFactory::createUnit(74,enemy,*manager);
    manager->add(skirmisher,MapPos(600,650));manager->add(closeTarget,MapPos(620,650));map->updateMapData();
    check(skirmisher->data()->Combat.MinRange==1 && skirmisher->actions.findAnyTask(genie::ActionType::RetreatToShootingRage,-1).data,
          "actual skirmisher supplies minimum range and retreat task");
    auto retreatTask=skirmisher->actions.findTaskWithTarget(closeTarget);
    check(retreatTask.isValid(),"skirmisher finds enemy combat task");
    auto retreat=std::make_shared<ActionAttack>(skirmisher,retreatTask);skirmisher->actions.setCurrentAction(retreat);
    const auto retreatStart=skirmisher->position();
    const float initialSeparation=retreatStart.distance(closeTarget->position());
    skirmisher->update(200100);skirmisher->update(200200);
    check(skirmisher->position().distance(closeTarget->position())>initialSeparation && skirmisher->position().x<retreatStart.x,
          "minimum-range retreat moves away from enemy rather than tracking toward it");
    agepad::EntitySaveIndex retreatIndex;retreatIndex.add(skirmisher->id,skirmisher);retreatIndex.add(closeTarget->id,closeTarget);retreatIndex.seal();
    const auto retreatBytes=retreat->saveRuntime();auto resumedRetreat=ActionAttack::fromRuntime(retreatBytes,retreatIndex,200200);
    check(resumedRetreat->saveRuntime()==retreatBytes && resumedRetreat->unitState()==IAction::Moving,
          "mid-retreat destination and path survive save/load");
    skirmisher->actions.setCurrentAction(resumedRetreat);const auto missileCount=manager->missiles().size();bool fired=false;
    for(Time time=200300;time<=210000;time+=100) {
        skirmisher->update(time);
        if(manager->missiles().size()>missileCount){fired=true;break;}
    }
    check(fired && skirmisher->position().distance(closeTarget->position())>=skirmisher->data()->Combat.MinRange*Constants::TILE_SIZE,
          "restored retreat creates separation then resumes projectile attack");
    std::cout << "attack_action_save_checks=" << checks << " errors=0\n";
    return 0;
} catch(const std::exception &error){std::cerr << error.what() << '\n';return 1;}
