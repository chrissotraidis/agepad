#include "global/Config.h"
#include "actions/ActionGather.h"
#include "actions/ActionMove.h"
#include "core/SaveArchive.h"
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
    auto owner=std::make_shared<Player>(1,1,map,ResourceMap{});
    auto otherOwner=std::make_shared<Player>(1,1,map,ResourceMap{});
    Task task;
    for (const auto &definition:data.getTasks(123))
        if (definition.ActionType==genie::ActionType::Hunt && definition.ResourceIn==int(genie::ResourceType::WoodStorage)) {
            task=Task(&definition,123); break;
        }
    check(task.data!=nullptr,"actual wood gathering task exists");
    auto worker=UnitFactory::createUnit(123,owner,*manager);
    auto restoredWorker=UnitFactory::createUnit(123,otherOwner,*manager);
    auto tree=UnitFactory::createUnit(349,owner,*manager);
    auto restoredTree=UnitFactory::createUnit(349,otherOwner,*manager);
    worker->setPosition(MapPos(480,480,0),true);
    tree->setPosition(MapPos(528,480,0),true);
    tree->resources[genie::ResourceType::WoodStorage]=100;
    task.target=tree;
    auto action=std::make_shared<ActionGather>(worker,task);
    action->requiredUnitID=123;
    action->update(1000); action->update(2000);
    check(worker->resources[genie::ResourceType::WoodStorage]>0,"worker gathered before snapshot");
    const auto saved=action->saveRuntime();
    restoredWorker->restoreBaseRuntime(worker->saveBaseRuntime(),2000);
    const auto treeSaved=tree->saveBaseRuntime();
    check(tree->data()->Creatable.TrainTime<0,"static tree has non-creatable train-time sentinel");
    restoredTree->restoreBaseRuntime(treeSaved,2000);
    check(restoredTree->saveBaseRuntime()==treeSaved,"static tree state roundtrips exactly");
    auto withCreation=[](agepad::SaveBytes bytes,float creation) {
        agepad::SaveWriter value;value.f32(creation);
        std::copy(value.bytes.begin(),value.bytes.end(),bytes.begin()+40);
        return bytes;
    };
    check(rejected([&]{restoredTree->restoreBaseRuntime(withCreation(treeSaved,-2),2000);}),
          "arbitrary negative scenery progress refused");
    check(rejected([&]{restoredTree->restoreBaseRuntime(withCreation(treeSaved,0),2000);}),
          "non-sentinel scenery progress refused");
    check(restoredTree->saveBaseRuntime()==treeSaved,"invalid scenery snapshot leaves restored tree intact");
    check(rejected([&]{restoredWorker->restoreBaseRuntime(withCreation(worker->saveBaseRuntime(),-1),2000);}),
          "negative progress still refused for trainable worker");
    agepad::EntitySaveIndex index;index.add(worker->id,restoredWorker);index.add(tree->id,restoredTree);index.seal();
    auto resumed=ActionGather::fromRuntime(saved,index,2000);
    check(resumed->requiredUnitID==123,"worker task type retained");
    for (Time time: {2100,2300,2600,3000}) {
        check(action->update(time)==resumed->update(time),"resumed gathering update result matches");
        check(worker->resources==restoredWorker->resources && tree->resources==restoredTree->resources,
              "carried and remaining wood match uninterrupted gathering");
    }
    auto bad=saved;bad.push_back(0);
    check(rejected([&]{ActionGather::fromRuntime(bad,index,3000);}),"trailing data refused");
    bad=saved;bad[24]^=1;
    check(rejected([&]{ActionGather::fromRuntime(bad,index,3000);}),"resource mismatch refused");
    check(rejected([&]{ActionGather::fromRuntime(saved,index,1000);}),"future update time refused");
    agepad::EntitySaveIndex empty;empty.seal();
    check(rejected([&]{ActionGather::fromRuntime(saved,empty,3000);}),"missing owner refused");
    auto town=UnitFactory::createUnit(109,owner,*manager);
    auto restoredTown=UnitFactory::createUnit(109,otherOwner,*manager);
    Task dropTask=task;dropTask.target=town;
    ActionDropOff drop(worker,dropTask);
    drop.requiredUnitID=123;
    const auto dropBytes=drop.saveRuntime();
    agepad::EntitySaveIndex dropIndex;dropIndex.add(worker->id,restoredWorker);dropIndex.add(town->id,restoredTown);dropIndex.seal();
    auto restoredDrop=ActionDropOff::fromRuntime(dropBytes,dropIndex,3000);
    const auto before=owner->resourcesAvailable(genie::ResourceType::WoodStorage);
    const auto otherBefore=otherOwner->resourcesAvailable(genie::ResourceType::WoodStorage);
    const auto carried=worker->resources[genie::ResourceType::WoodStorage];
    check(drop.update(3000)==restoredDrop->update(3000),"restored deposit completes normally");
    check(owner->resourcesAvailable(genie::ResourceType::WoodStorage)-before==carried &&
          otherOwner->resourcesAvailable(genie::ResourceType::WoodStorage)-otherBefore==carried,
          "both owners receive identical carried amount");
    check(worker->resources[genie::ResourceType::WoodStorage]==0 && restoredWorker->resources==worker->resources,
          "both carried resource stores cleared");
    restoredDrop->update(3100);
    check(otherOwner->resourcesAvailable(genie::ResourceType::WoodStorage)-otherBefore==carried,"repeated completed deposit cannot double credit");
    bad=dropBytes;bad[24]^=1;
    check(rejected([&]{ActionDropOff::fromRuntime(bad,dropIndex,3000);}),"dropoff resource mismatch refused");
    Task gone=task;gone.target.reset();
    ActionGather noTarget(worker,gone);
    check(noTarget.update(3200)==IAction::UpdateResult::Completed,"missing gathering target with no cargo completes safely");
    ActionDropOff noSite(worker,gone);
    check(noSite.update(3200)==IAction::UpdateResult::Completed,"missing drop site completes safely");
    auto upgradedMap=std::make_shared<Map>();upgradedMap->setupBasic();upgradedMap->updateMapData();
    auto upgradedManager=std::make_shared<UnitManager>();upgradedManager->setMap(upgradedMap);
    check(upgradedManager->init(),"upgraded drop-site manager initializes");
    auto upgradedOwner=std::make_shared<Player>(1,1,upgradedMap,ResourceMap{});
    upgradedManager->setPlayers({upgradedOwner});upgradedManager->setHumanPlayer(upgradedOwner);
    auto upgradedTown=UnitFactory::createUnit(109,upgradedOwner,*upgradedManager);
    upgradedManager->add(upgradedTown,MapPos(960,960));
    auto upgradedWorker=UnitFactory::createUnit(123,upgradedOwner,*upgradedManager);
    upgradedManager->add(upgradedWorker,MapPos(720,960));
    upgradedOwner->applyResearch(101);
    check(upgradedTown->data()->ID!=109,"actual age research changes Town Center variant identity");
    check(upgradedOwner->civilization.matchesBuildingReference(upgradedTown->data()->ID,109),
        "upgraded Town Center matches canonical drop-site reference");
    check(!upgradedOwner->civilization.matchesBuildingReference(upgradedTown->data()->ID,68),
        "Town Center lineage does not match Mill reference");
    check(!upgradedOwner->civilization.matchesBuildingReference(75,74),
        "building aliases do not merge military unit types");
    upgradedWorker->resources[genie::ResourceType::WoodStorage]=10;
    Task cargoTask=task;cargoTask.target.reset();
    ActionGather returnCargo(upgradedWorker,cargoTask);
    returnCargo.update(4000);
    check(!upgradedWorker->actions.m_actionQueue.empty() || upgradedWorker->actions.currentAction(),
        "carrying worker finds upgraded Town Center and schedules deposit");
    upgradedWorker->actions.clearActionQueue();upgradedWorker->actions.setCurrentAction({});
    upgradedTown->setCreationProgress(0);
    ActionGather unfinishedSite(upgradedWorker,cargoTask);unfinishedSite.update(4100);
    check(upgradedWorker->actions.m_actionQueue.empty() && !upgradedWorker->actions.currentAction(),
        "unfinished upgraded building cannot accept a planned deposit");
    upgradedManager->remove(upgradedTown);
    auto enemy=std::make_shared<Player>(2,1,upgradedMap,ResourceMap{});
    auto enemyTown=UnitFactory::createUnit(109,enemy,*upgradedManager);
    upgradedManager->add(enemyTown,MapPos(960,960));
    ActionGather foreignSite(upgradedWorker,cargoTask);foreignSite.update(4200);
    check(upgradedWorker->actions.m_actionQueue.empty() && !upgradedWorker->actions.currentAction(),
        "enemy Town Center cannot accept a planned deposit");
    auto patchMap=std::make_shared<Map>();patchMap->setupBasic();patchMap->updateMapData();
    auto patchManager=std::make_shared<UnitManager>();patchManager->setMap(patchMap);patchManager->init();
    auto patchOwner=std::make_shared<Player>(1,1,patchMap,ResourceMap{});
    patchManager->setPlayers({patchOwner});patchManager->setHumanPlayer(patchOwner);
    auto patchWorker=UnitFactory::createUnit(123,patchOwner,*patchManager);
    auto patchGaia=std::make_shared<Player>(0,0,patchMap,ResourceMap{});
    auto exhaustedTree=UnitFactory::createUnit(349,patchGaia,*patchManager);
    auto nextTree=UnitFactory::createUnit(349,patchGaia,*patchManager);
    patchManager->add(patchWorker,MapPos(480,480));patchManager->add(exhaustedTree,MapPos(528,480));
    patchManager->add(nextTree,MapPos(576,528));
    exhaustedTree->resources[genie::ResourceType::WoodStorage]=0;
    nextTree->resources[genie::ResourceType::WoodStorage]=100;
    Task patchTask=task;patchTask.target=exhaustedTree;
    std::cout<<"retarget_task search="<<int(patchTask.data->AutoSearchTargets)<<" radius="<<patchWorker->data()->Action.SearchRadius<<" los="<<patchWorker->data()->LineOfSight<<" class="<<patchTask.data->ClassID<<" unit="<<patchTask.data->UnitID<<"\n";
    TaskSet patchAllowed;patchAllowed.add(patchTask);
    std::cout<<"retarget_candidate visible="<<patchOwner->visibility->visibilityAt(nextTree->position())<<" match="<<UnitActionHandler::findMatchingTask(patchOwner,nextTree,patchAllowed).isValid()<<" diplomacy="<<int(patchTask.data->TargetDiplomacy)<<" progress="<<nextTree->creationProgress()<<" distance="<<patchWorker->distanceTo(nextTree)<<"\n";
    patchWorker->actions.setCurrentAction(std::make_shared<ActionGather>(patchWorker,patchTask));
    for(Time t=1000;t<=30000;t+=100)patchWorker->update(t);
    check(nextTree->resources[genie::ResourceType::WoodStorage]<100,
        "worker automatically moves from depleted tree to nearby matching resource and gathers");
    patchWorker->actions.clearActionQueue();patchWorker->resources[genie::ResourceType::WoodStorage]=0;
    nextTree->resources[genie::ResourceType::WoodStorage]=100;
    patchWorker->setPosition(MapPos(480,480),true);
    patchWorker->actions.setCurrentAction(std::make_shared<ActionGather>(patchWorker,patchTask));
    auto explicitMove=ActionMove::moveUnitTo(patchWorker,MapPos(480,720));
    patchWorker->actions.queueAction(explicitMove);patchWorker->update(31000);
    check(patchWorker->actions.currentAction()==explicitMove && patchWorker->actions.m_actionQueue.empty(),
        "explicit queued command takes precedence over automatic resource search");
    patchWorker->actions.clearActionQueue();
    genie::Task manualOnly=*patchTask.data;manualOnly.AutoSearchTargets=0;
    Task manualTask(&manualOnly,patchTask.unitId);manualTask.target=exhaustedTree;
    patchWorker->actions.setCurrentAction(std::make_shared<ActionGather>(patchWorker,manualTask));
    patchWorker->update(32000);
    check(!patchWorker->actions.currentAction() && patchWorker->actions.m_actionQueue.empty(),
        "task with automatic search disabled stays idle after exhaustion");
    auto patchTown=UnitFactory::createUnit(109,patchOwner,*patchManager);
    patchManager->add(patchTown,MapPos(768,480));
    patchWorker->resources[genie::ResourceType::WoodStorage]=10;
    const auto beforeContinuation=patchOwner->resourcesAvailable(genie::ResourceType::WoodStorage);
    patchWorker->actions.setCurrentAction(std::make_shared<ActionGather>(patchWorker,patchTask));
    for(Time t=33000;t<=110000;t+=100)patchWorker->update(t);
    check(patchOwner->resourcesAvailable(genie::ResourceType::WoodStorage)>=beforeContinuation+10,
        "full cargo from exhausted resource is deposited before continuation");
    check(nextTree->resources[genie::ResourceType::WoodStorage]<100,
        "worker continues on replacement resource after depositing full cargo");
    patchWorker->actions.clearActionQueue();patchWorker->resources[genie::ResourceType::WoodStorage]=0;
    patchWorker->setPosition(MapPos(480,480),true);
    nextTree->setPosition(MapPos(1104,816),true);nextTree->resources[genie::ResourceType::WoodStorage]=100;
    patchWorker->actions.setCurrentAction(std::make_shared<ActionGather>(patchWorker,patchTask));
    patchWorker->update(111000);
    check(!patchWorker->actions.currentAction() && patchWorker->actions.m_actionQueue.empty(),
        "automatic search does not order a trip to a resource outside local search radius");
    auto resourceEnemy=std::make_shared<Player>(2,1,patchMap,ResourceMap{});
    auto foreignTree=UnitFactory::createUnit(349,resourceEnemy,*patchManager);
    patchManager->add(foreignTree,MapPos(576,528));foreignTree->resources[genie::ResourceType::WoodStorage]=100;
    patchWorker->actions.setCurrentAction(std::make_shared<ActionGather>(patchWorker,patchTask));
    patchWorker->update(112000);
    check(!patchWorker->actions.currentAction() && patchWorker->actions.m_actionQueue.empty(),
        "automatic search respects Gaia-only task diplomacy");
    std::cout << "gather_dropoff_save_checks=" << checks << " errors=0\n";
    return 0;
} catch(const std::exception &e) { std::cerr << e.what() << '\n'; return 1; }
