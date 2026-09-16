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
    auto rejected=[](auto action){try{action();return false;}catch(const agepad::SaveError &){return true;}};
    auto map=std::make_shared<Map>();map->setupBasic();map->updateMapData();
    auto restoredMap=Map::fromTerrainSave(map->saveTerrain());
    auto makeManager=[](auto map){auto manager=std::make_shared<UnitManager>();manager->setMap(map);if(!manager->init())throw std::runtime_error("manager init");return manager;};
    auto manager=makeManager(map),restoredManager=makeManager(restoredMap);
    auto player=std::make_shared<Player>(1,1,map,ResourceMap{});
    auto restoredPlayer=std::make_shared<Player>(1,1,restoredMap,ResourceMap{});
    auto actor=UnitFactory::createUnit(74,player,*manager);
    auto restoredActor=UnitFactory::createUnit(74,restoredPlayer,*restoredManager);
    manager->add(actor,MapPos(480,480));
    restoredManager->add(restoredActor,MapPos(480,480));
    auto action=ActionMove::moveUnitTo(actor,MapPos(720,480));
    action->requiredUnitID=74;
    action->update(1000);action->update(1500);
    check(!action->path().empty(),"partially travelled route exists");
    check(actor->position().x>480 && actor->position().x<720,"actor has moved partway");
    auto bytes=action->saveRuntime();
    // Entity restoration is not implemented yet: initialize equivalent position
    // manually, on a separately restored terrain map, to isolate action state.
    restoredActor->setPosition(actor->position(),true);
    agepad::EntitySaveIndex index;index.add(actor->id,restoredActor);index.seal();
    auto restored=ActionMove::fromRuntime(bytes,index,1500);
    check(restored->path()==action->path(),"exact saved route preserved");
    check(restored->requiredUnitID==74,"required unit retained");
    bool equal=true,completed=false;
    for(Time t=1600;t<=10000;t+=100){
        auto a=action->update(t),b=restored->update(t);
        equal &= a==b && actor->position()==restoredActor->position() && action->path()==restored->path();
        if(a==IAction::UpdateResult::Completed){completed=true;break;}
    }
    check(equal,"every resumed movement step matches uninterrupted run");
    check(completed,"both routes complete");
    auto done=ActionMove::fromRuntime(action->saveRuntime(),index,10000);
    check(done->update(10100)==IAction::UpdateResult::Completed,"completed movement remains completed");
    done.reset();
    bool truncated=true;
    for(std::size_t n=0;n<bytes.size();++n){agepad::SaveBytes partial(bytes.begin(),bytes.begin()+n);truncated &= rejected([&]{ActionMove::fromRuntime(partial,index,1500);});}
    check(truncated,"all truncations refused");
    check(rejected([&]{ActionMove::fromRuntime(bytes,index,1499);}),"future update time refused");
    auto bad=bytes;bad.push_back(0);
    check(rejected([&]{ActionMove::fromRuntime(bad,index,1500);}),"trailing data refused");
    bad=bytes;for(int i=24;i<28;++i)bad[i]=255;
    check(rejected([&]{ActionMove::fromRuntime(bad,index,1500);}),"oversized nested descriptor refused");
    agepad::EntitySaveIndex missing;missing.seal();
    check(rejected([&]{ActionMove::fromRuntime(bytes,missing,1500);}),"missing actor refused");
    check(actor->position()==restoredActor->position(),"rejected restores leave actors unchanged");
    action.reset();restored.reset();
    actor->setPosition(MapPos(480,480),true);restoredActor->setPosition(MapPos(480,480),true);
    auto target=UnitFactory::createUnit(74,player,*manager);
    auto restoredTarget=UnitFactory::createUnit(74,restoredPlayer,*restoredManager);
    manager->add(target,MapPos(720,480));restoredManager->add(restoredTarget,MapPos(720,480));
    agepad::EntitySaveIndex tracking;
    tracking.add(actor->id,restoredActor);tracking.add(target->id,restoredTarget);tracking.seal();
    action=ActionMove::moveUnitTo(actor,target);action->maxDistance=30;
    action->update(11000);action->update(11200);
    restoredActor->setPosition(actor->position(),true);
    restored=ActionMove::fromRuntime(action->saveRuntime(),tracking,11200);
    check(restored->maxDistance==30,"target stopping distance preserved");
    target->setPosition(MapPos(720,576),true);restoredTarget->setPosition(MapPos(720,576),true);
    auto oldPath=action->path();
    auto a=action->update(11300),b=restored->update(11300);
    check(a==b && action->path()==restored->path() && action->path()!=oldPath,"remapped moving target triggers equivalent new route");
    bool trackedEqual=true;
    for(Time t=11400;t<=12500;t+=100){
        a=action->update(t);b=restored->update(t);
        trackedEqual &= a==b && actor->position()==restoredActor->position() && action->path()==restored->path();
    }
    check(trackedEqual,"recomputed route continues equivalently after restore");
    auto queued=UnitFactory::createUnit(74,player,*manager);
    auto queuedRestored=UnitFactory::createUnit(74,restoredPlayer,*restoredManager);
    manager->add(queued,MapPos(768,768));
    queued->stance=Unit::Stance::NoAttack;
    queued->actions.setCurrentAction(ActionMove::moveUnitTo(queued,MapPos(912,768)));
    queued->actions.queueAction(ActionMove::moveUnitTo(queued,MapPos(912,912)));
    queued->actions.autoConvert=true;
    queued->update(1000);queued->update(1500);
    const auto handlerBytes=queued->actions.saveRuntime();
    queuedRestored->restoreBaseRuntime(queued->saveBaseRuntime(),1500);
    restoredManager->add(queuedRestored,queuedRestored->position());
    agepad::EntitySaveIndex queueIndex;queueIndex.add(queued->id,queuedRestored);queueIndex.seal();
    queuedRestored->actions.restoreRuntime(handlerBytes,queueIndex,1500);
    check(queuedRestored->actions.currentAction() && queuedRestored->actions.m_actionQueue.size()==1 && queuedRestored->actions.autoConvert,
          "handler restores current, queued action and automatic conversion flag");
    check(queuedRestored->actions.currentAction()->owner()==queuedRestored && queuedRestored->actions.m_actionQueue.front()->owner()==queuedRestored,
          "all action owners resolve to reconstructed unit");
    auto retained=queuedRestored->actions.currentAction();
    auto corrupt=handlerBytes;corrupt.push_back(0);
    check(rejected([&]{queuedRestored->actions.restoreRuntime(corrupt,queueIndex,1500);}) && queuedRestored->actions.currentAction()==retained && queuedRestored->actions.m_actionQueue.size()==1,
          "malformed handler refuses without replacing active queue");
    corrupt=handlerBytes;corrupt[16]=255;
    check(rejected([&]{queuedRestored->actions.restoreRuntime(corrupt,queueIndex,1500);}) && queuedRestored->actions.currentAction()==retained,
          "unknown action tag refuses transactionally");
    check(rejected([&]{restoredActor->actions.restoreRuntime(handlerBytes,queueIndex,1500);}),"wrong handler owner refused");
    bool queueEqual=true,queueDone=false;
    for(Time t=1600;t<=20000;t+=100) {
        queued->update(t);queuedRestored->update(t);
        queueEqual &= queued->position()==queuedRestored->position() &&
            bool(queued->actions.currentAction())==bool(queuedRestored->actions.currentAction()) &&
            queued->actions.m_actionQueue.size()==queuedRestored->actions.m_actionQueue.size();
        if(!queued->actions.currentAction()) {queueDone=true;break;}
    }
    check(queueEqual && queueDone && queued->position().distance(MapPos(912,912))<2,
          "restored unit crosses both waypoints on identical ticks through normal update");
    const auto idleBytes=queued->actions.saveRuntime();
    queuedRestored->actions.restoreRuntime(idleBytes,queueIndex,20000);
    check(!queuedRestored->actions.currentAction() && queuedRestored->actions.m_actionQueue.empty(),"idle handler restores without invented actions");
    std::cout << "move_action_save_checks=" << checks << " errors=0\n";
    return 0;
} catch (const std::exception &error) {
    std::cerr << error.what() << '\n';
    return 1;
}
