#include "global/Config.h"
#include "actions/ActionMove.h"
#include "render/GraphicRender.h"
#include "resource/Sprite.h"
#include "mechanics/Map.h"
#include "mechanics/Building.h"
#include "mechanics/Farm.h"
#include "mechanics/UnitGraphSave.h"
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
    auto original=UnitFactory::createUnit(74,owner,*manager);
    auto restored=UnitFactory::createUnit(74,owner,*manager);
    original->setPosition(MapPos(480,528,3),true);original->setAngle(1.25f);
    original->spawnId=1234;original->isVisible=true;
    original->stance=Unit::Stance::StandGround;
    original->resources[genie::ResourceType::WoodStorage]=7.5f;
    original->activeMissiles=2;original->lastAttackTime=1250;
    original->takeDamage(7.25f);
    original->Entity::update(1000);original->Entity::update(1500);
    auto saved=original->saveBaseRuntime();
    auto economy=owner->saveEconomyDiplomacy();
    restored->restoreBaseRuntime(saved,1500);
    check(restored->saveBaseRuntime()==saved,"base and recursive animation state roundtrip exactly");
    check(restored->position()==original->position() && restored->angle()==original->angle(),"position and orientation restored");
    check(restored->hitpointsLeft()==original->hitpointsLeft(),"fractional damage restored");
    check(restored->resources==original->resources && restored->spawnId==1234,"resource amounts and scenario identity retained");
    check(restored->activeMissiles==2 && restored->lastAttackTime==1250,"combat accounting and timestamp retained");
    check(owner->saveEconomyDiplomacy()==economy,"base restore does not change owner economy");
    check(restored->renderer().spriteId()==restored->renderer().sprite()->m_spriteId,"spriteId returns asset identity rather than frame count");
    bool animation=true;
    for(Time time=1600;time<=2500;time+=100){
        original->Entity::update(time);restored->Entity::update(time);
        animation &= original->renderer().saveRuntime()==restored->renderer().saveRuntime();
    }
    check(animation,"animation deadlines continue equivalently");
    const auto before=restored->saveBaseRuntime();
    bool truncated=true;
    for(std::size_t n=0;n<saved.size();++n){agepad::SaveBytes partial(saved.begin(),saved.begin()+n);truncated &= rejected([&]{restored->restoreBaseRuntime(partial,1500);});}
    check(truncated && restored->saveBaseRuntime()==before,"every truncated section rejected without mutation");
    check(rejected([&]{restored->restoreBaseRuntime(saved,1249);}),"future combat timestamp refused");
    auto bad=saved;bad.push_back(0);
    check(rejected([&]{restored->restoreBaseRuntime(bad,1500);}),"trailing data rejected");
    bad=saved;bad[4]=0;bad[5]=0;bad[6]=0;bad[7]=0;
    check(rejected([&]{restored->restoreBaseRuntime(bad,1500);}),"different unit baseline refused");
    // Sight starts at byte56 in version1. Negative sentinels belong only to
    // catalog entries that actually initialize that value.
    bad=saved;for(int i=56;i<60;++i)bad[i]=255;
    check(rejected([&]{restored->restoreBaseRuntime(bad,1500);}),"negative sight on military unit rejected");
    auto gaia=std::make_shared<Player>(0,0,map,ResourceMap{});
    auto scenery=UnitFactory::createUnit(264,gaia,*manager);
    auto sceneryCopy=UnitFactory::createUnit(264,gaia,*manager);
    check(int(scenery->data()->LineOfSight)==-1,"actual scenery DAT sight sentinel is minus one");
    const auto sceneryBytes=scenery->saveBaseRuntime();
    sceneryCopy->restoreBaseRuntime(sceneryBytes,0);
    check(sceneryCopy->saveBaseRuntime()==sceneryBytes,"scenery sight sentinel restores exactly");
    bad=sceneryBytes;bad[56]=254;for(int i=57;i<60;++i)bad[i]=255;
    check(rejected([&]{sceneryCopy->restoreBaseRuntime(bad,0);}) && sceneryCopy->saveBaseRuntime()==sceneryBytes,"different negative scenery sight rejected without mutation");
    // Death completion is simulation state, not merely decorative animation.
    original->kill();original->renderer().setCurrentFrame(0);
    original->Entity::update(3000);
    saved=original->saveBaseRuntime();restored->restoreBaseRuntime(saved,3000);
    check(original->isDying()==restored->isDying() && original->isDead()==restored->isDead(),"death phase restored");
    bool death=true;
    for(Time time=3100;time<=10000;time+=100){
        original->Entity::update(time);restored->Entity::update(time);
        death &= original->isDying()==restored->isDying() && original->isDead()==restored->isDead();
    }
    check(death && original->isDead() && restored->isDead(),"death animation finishes at same update");
    // Playback policy belongs to each renderer, even with a shared asset.
    GraphicRender oneShot,looping;
    auto shared=AssetManager::Inst()->getGraphic(original->data()->Combat.AttackGraphic);
    check(shared && shared->isValid() && shared->frameCount()>1,"actual multi-frame attack asset available");
    const bool baseline=shared->runOnce();
    oneShot.setSprite(shared);looping.setSprite(shared);
    oneShot.setRunOnce(true);looping.setRunOnce(false);
    oneShot.setCurrentFrame(shared->frameCount()-1);looping.setCurrentFrame(shared->frameCount()-1);
    check(!oneShot.isRunning() && looping.isRunning() && shared->runOnce()==baseline,"independent playback policies leave shared asset unchanged");
    auto savedShot=oneShot.saveRuntime(),savedLoop=looping.saveRuntime();
    auto shotLoaded=GraphicRender::fromRuntime(savedShot,10000),loopLoaded=GraphicRender::fromRuntime(savedLoop,10000);
    check(!shotLoaded->isRunning() && loopLoaded->isRunning(),"save retains differing per-renderer playback policies");
    oneShot.update(11000,true);shotLoaded->update(11000,true);
    looping.update(11000,true);loopLoaded->update(11000,true);
    check(oneShot.saveRuntime()==shotLoaded->saveRuntime() && looping.saveRuntime()==loopLoaded->saveRuntime(),"one-shot and looping animations continue identically after restore");
    auto oldGraphic=savedShot;oldGraphic[0]=1;
    check(rejected([&]{GraphicRender::fromRuntime(oldGraphic,11000);}),"old incomplete graphic schema refused");
    manager->add(restored,restored->position());
    check(rejected([&]{restored->restoreBaseRuntime(saved,10000);}),"live mapped unit restore refused");
    const auto liveCount=owner->unitsInGroup(0).size();
    const auto liveEconomy=owner->saveEconomyDiplomacy();
    const auto liveVisibility=owner->visibility->saveRuntime();
    const auto liveTechnology=owner->civilization.saveUnitAttributes();
    auto staged=UnitFactory::restoreUnitBase(saved,owner,*manager,10000);
    check(staged->isRestoreStaging() && !staged->map() && staged->saveBaseRuntime()==saved,"factory reconstructs exact detached unit state");
    check(!staged->actions.currentAction() && staged->annexes.empty(),"restore factory invents no actions or annexes");
    check(owner->unitsInGroup(0).size()==liveCount && owner->saveEconomyDiplomacy()==liveEconomy,"staging grants no resources or group membership");
    staged.reset();
    check(owner->visibility->saveRuntime()==liveVisibility && owner->civilization.saveUnitAttributes()==liveTechnology && owner->saveEconomyDiplomacy()==liveEconomy,"discarding staged unit leaves live state intact");
    auto broken=saved;broken.push_back(0);
    check(rejected([&]{UnitFactory::restoreUnitBase(broken,owner,*manager,10000);}) && owner->unitsInGroup(0).size()==liveCount && owner->saveEconomyDiplomacy()==liveEconomy && owner->visibility->saveRuntime()==liveVisibility,"rejected factory restore has no membership, economy or visibility effects");
    auto anotherOwner=std::make_shared<Player>(2,1,map,ResourceMap{});
    check(rejected([&]{UnitFactory::restoreUnitBase(saved,anotherOwner,*manager,10000);}),"factory rejects mismatched owner");
    owner->setAvailableResource(genie::ResourceType::FoodStorage,500);
    owner->setAvailableResource(genie::ResourceType::PopulationHeadroom,100);
    auto sourceTown=Building::fromUnit(UnitFactory::createUnit(109,owner,*manager));
    const auto &villager=owner->civilization.unitData(83);
    check(sourceTown->enqueueProduceUnit(&villager) && sourceTown->enqueueProduceUnit(&villager),"staged-building fixture has paid production queue");
    const auto townEconomy=owner->saveEconomyDiplomacy();const auto townMembers=owner->unitsInGroup(0).size();
    auto stagedTown=Building::fromUnit(UnitFactory::restoreUnitBase(sourceTown->saveBaseRuntime(),owner,*manager,10000));
    stagedTown->restoreProductionRuntime(sourceTown->saveProductionRuntime(),10000);
    check(stagedTown->isRestoreStaging() && stagedTown->productionQueueLength()==2 && stagedTown->annexes.empty(),"building staging restores saved production without auto-generated annexes");
    stagedTown.reset();
    check(owner->saveEconomyDiplomacy()==townEconomy && owner->unitsInGroup(0).size()==townMembers,"discarding staged paid queue does not refund or alter player membership");
    auto sourceFarm=UnitFactory::createUnit(Unit::Farm,owner,*manager);
    auto stagedFarm=UnitFactory::restoreUnitBase(sourceFarm->saveBaseRuntime(),owner,*manager,10000);
    check(bool(std::dynamic_pointer_cast<Farm>(stagedFarm)) && stagedFarm->isRestoreStaging(),"farm records reconstruct the actual specialized class");
    auto annex=std::make_shared<Unit>(owner->civilization.unitData(109),owner,*manager);
    auto stagedAnnex=UnitFactory::restoreUnitBase(annex->saveBaseRuntime(),owner,*manager,10000);
    check(!stagedAnnex->isBuilding() && stagedAnnex->data()->ID==109,"annex record preserves Unit class despite building catalog data");
    auto guest=UnitFactory::createUnit(74,owner,*manager);
    sourceTown->garrisonedUnits.push_back(guest);guest->garrisonedIn=sourceTown;
    auto mover=UnitFactory::createUnit(74,owner,*manager);manager->add(mover,MapPos(768,768));
    mover->actions.setCurrentAction(ActionMove::moveUnitTo(mover,MapPos(912,768)));
    mover->actions.queueAction(ActionMove::moveUnitTo(mover,MapPos(912,912)));
    mover->update(1000);mover->update(1500);
    const std::vector<Unit::Ptr> graphRoots{sourceTown,guest,mover,sourceFarm};
    auto stagingMap=Map::fromTerrainSave(map->saveTerrain());
    auto stagingManager=std::make_shared<UnitManager>();stagingManager->setMap(stagingMap);stagingManager->init();
    guest->receiveAttack(mover->data()->Combat.Attacks.front(),1.f,mover);
    const auto graphBytes=agepad::UnitGraphSave::save(graphRoots);
    const auto graphEconomy=owner->saveEconomyDiplomacy(),graphVisibility=owner->visibility->saveRuntime();
    const auto graphMembers=owner->unitsInGroup(0).size();
    {
        auto graph=agepad::UnitGraphSave::stage(graphBytes,{owner},*stagingManager,10000);
        check(graph.roots.size()==4 && graph.records.size()==4+sourceTown->annexes.size()+sourceFarm->annexes.size(),"unit graph preserves root sequence and annex records");
        check(graph.roots[1]->lastAttacker.lock()==graph.roots[2] && graph.roots[1]->attackRevision==guest->attackRevision,"graph remaps damage source and hit revision");
        auto townCopy=Building::fromUnit(graph.roots[0]);
        check(townCopy && townCopy->garrisonedUnits.front().lock()==graph.roots[1] && graph.roots[1]->garrisonedIn.lock()==townCopy,"garrison relationship remaps both directions");
        bool links=true;
        for(std::size_t j=0;j<sourceTown->annexes.size();++j)links &= townCopy->annexes[j].unit==graph.index.unit(sourceTown->annexes[j].unit->id) && townCopy->annexes[j].offset==sourceTown->annexes[j].offset;
        check(links && !townCopy->annexes.empty(),"annex ownership order and offsets use reconstructed records");
        auto movingCopy=std::dynamic_pointer_cast<ActionMove>(graph.roots[2]->actions.currentAction());
        check(movingCopy && movingCopy->owner()==graph.roots[2] && graph.roots[2]->actions.m_actionQueue.size()==1,"graph restores active and queued movement with remapped owner");
        check(townCopy->saveProductionRuntime()==sourceTown->saveProductionRuntime(),"graph restores paid production state");
        check(std::dynamic_pointer_cast<Farm>(graph.roots[3])->saveFarmRuntime()==std::dynamic_pointer_cast<Farm>(sourceFarm)->saveFarmRuntime(),"graph preserves farm terrain cache state");
        bool detached=true;for(const auto &u:graph.records)detached &= u->isRestoreStaging() && u->map()==stagingMap;
        check(detached,"all records bind restored terrain while remaining outside live membership");
    }
    check(owner->saveEconomyDiplomacy()==graphEconomy && owner->visibility->saveRuntime()==graphVisibility && owner->unitsInGroup(0).size()==graphMembers,"discarding complete staged graph preserves live player state");
    agepad::SaveWriter legacyGraph;legacyGraph.u32(1);legacyGraph.u32(1);legacyGraph.u64(mover->id);legacyGraph.u32(1);
    legacyGraph.u64(mover->id);legacyGraph.blob(mover->saveBaseRuntime());legacyGraph.blob(mover->actions.saveRuntime());
    legacyGraph.u32(0);legacyGraph.u64(agepad::EntitySaveIndex::nullID);
    auto oldGraph=agepad::UnitGraphSave::stage(legacyGraph.bytes,{owner},*stagingManager,10000);
    check(oldGraph.roots.size()==1 && oldGraph.roots[0]->attackRevision==0 && oldGraph.roots[0]->lastAttacker.expired(),
          "previous graph version reads with no historical attacker");
    broken=graphBytes;broken.push_back(0);
    check(rejected([&]{agepad::UnitGraphSave::stage(broken,{owner},*stagingManager,10000);}) && owner->saveEconomyDiplomacy()==graphEconomy,"malformed graph rejected without production refunds");
    guest->garrisonedIn.reset();
    check(rejected([&]{agepad::UnitGraphSave::save(graphRoots);}),"inconsistent garrison links refused");
    guest->garrisonedIn=sourceTown;
    sourceTown->annexes.push_back({sourceTown,MapPos()});
    check(rejected([&]{agepad::UnitGraphSave::save(graphRoots);}),"cyclic annex ownership refused");
    sourceTown->annexes.pop_back();
    check(rejected([&]{agepad::UnitGraphSave::stage(graphBytes,{},*stagingManager,10000);}),"missing graph player refused");
    check(rejected([&]{agepad::UnitGraphSave::stage(graphBytes,{owner},*manager,10000);}),"live populated manager cannot be used for staging");
    agepad::SaveWriter cycle;cycle.u32(1);cycle.u32(1);cycle.u64(original->id);cycle.u32(1);
    cycle.u64(original->id);cycle.blob(original->saveBaseRuntime());cycle.blob(original->actions.saveRuntime());
    cycle.u32(1);cycle.u64(original->id);cycle.f32(0);cycle.f32(0);cycle.f32(0);cycle.u64(agepad::EntitySaveIndex::nullID);
    check(rejected([&]{agepad::UnitGraphSave::stage(cycle.bytes,{owner},*stagingManager,10000);}) && owner->saveEconomyDiplomacy()==graphEconomy,"decoder rejects self-owning annex graph without live-state changes");
    auto memberMap=Map::fromTerrainSave(map->saveTerrain());
    auto memberManager=std::make_shared<UnitManager>();memberManager->setMap(memberMap);memberManager->init();
    auto memberOwner=std::make_shared<Player>(3,1,memberMap,ResourceMap{});
    auto loadedOwner=std::make_shared<Player>(3,1,memberMap,ResourceMap{});
    std::vector<Unit::Ptr> members;
    for(int n=0;n<4;++n)members.push_back(UnitFactory::createUnit(74,memberOwner,*memberManager));
    memberOwner->setUnitGroup(members[0].get(),2);
    check(memberOwner->unitGroupCount()==3 && memberOwner->unitsInGroup(2).contains(members[0].get()),"group array grows by group index even with more units than groups");
    memberOwner->setUnitGroup(members[1].get(),1);
    auto membership=memberOwner->saveUnitMembership();
    memberOwner->setUnitGroup(guest.get(),1);memberOwner->setUnitGroup(nullptr,1);
    check(memberOwner->saveUnitMembership()==membership,"foreign and null unit group assignments leave membership intact");
    agepad::EntitySaveIndex memberIndex;std::vector<Unit::Ptr> memberCopies;
    for(const auto &u:members){auto copy=UnitFactory::restoreUnitBase(u->saveBaseRuntime(),loadedOwner,*memberManager,10000);memberIndex.add(u->id,copy);memberCopies.push_back(copy);}
    memberIndex.seal();
    const auto loadedEconomy=loadedOwner->saveEconomyDiplomacy();
    auto prepared=loadedOwner->prepareUnitMembership(membership,memberIndex);
    check(prepared.records.size()==4 && prepared.groups.size()==3 && prepared.groups[2].contains(memberCopies[0].get()) && prepared.groups[1].contains(memberCopies[1].get()) && prepared.groups[0].size()==2,"prepared membership resolves original group assignments to new unit identities");
    check(loadedOwner->unitGroupCount()==0 && loadedOwner->saveEconomyDiplomacy()==loadedEconomy,"membership preparation does not register units or charge population");
    broken=membership;broken.push_back(0);
    check(rejected([&]{loadedOwner->prepareUnitMembership(broken,memberIndex);}) && loadedOwner->unitGroupCount()==0,"trailing membership data refused without commit");
    agepad::EntitySaveIndex absentMembers;absentMembers.seal();
    check(rejected([&]{loadedOwner->prepareUnitMembership(membership,absentMembers);}),"missing saved unit member refused");
    check(rejected([&]{memberOwner->prepareUnitMembership(membership,memberIndex);}),"membership cannot resolve units owned by another player object");
    broken=membership;std::copy(broken.begin()+12,broken.begin()+20,broken.begin()+20);
    check(rejected([&]{loadedOwner->prepareUnitMembership(broken,memberIndex);}),"duplicate membership IDs refused");
    agepad::SaveWriter noGroup;noGroup.u32(1);noGroup.i32(3);noGroup.u32(1);noGroup.u64(members[0]->id);noGroup.u32(0);
    check(rejected([&]{loadedOwner->prepareUnitMembership(noGroup.bytes,memberIndex);}),"member omitted from all groups refused");
    auto emptyOwner=std::make_shared<Player>(4,1,memberMap,ResourceMap{});
    auto emptyPrepared=emptyOwner->prepareUnitMembership(emptyOwner->saveUnitMembership(),absentMembers);
    check(emptyPrepared.units.empty() && emptyPrepared.groups.empty(),"empty player's membership is preserved");
    auto resumeMap=std::make_shared<Map>();resumeMap->setupBasic();resumeMap->updateMapData();
    auto resumeManager=std::make_shared<UnitManager>();resumeManager->setMap(resumeMap);resumeManager->init();
    auto resumeOwner=std::make_shared<Player>(5,1,resumeMap,ResourceMap{});
    resumeManager->setPlayers({resumeOwner});resumeManager->setHumanPlayer(resumeOwner);
    resumeOwner->setAvailableResource(genie::ResourceType::FoodStorage,500);
    resumeOwner->setAvailableResource(genie::ResourceType::PopulationHeadroom,100);
    auto resumeTown=Building::fromUnit(UnitFactory::createUnit(109,resumeOwner,*resumeManager));resumeManager->add(resumeTown,MapPos(480,480));
    auto resumeSoldier=UnitFactory::createUnit(74,resumeOwner,*resumeManager);resumeManager->add(resumeSoldier,MapPos(480,768));
    resumeSoldier->stance=Unit::Stance::NoAttack;
    resumeSoldier->actions.setCurrentAction(ActionMove::moveUnitTo(resumeSoldier,MapPos(720,768)));
    resumeSoldier->actions.queueAction(ActionMove::moveUnitTo(resumeSoldier,MapPos(720,912)));
    resumeManager->setSelectedUnits({resumeSoldier});resumeManager->assignControlGroup(2);
    resumeOwner->setUnitGroup(resumeSoldier.get(),3);
    check(resumeTown->enqueueProduceUnit(&resumeOwner->civilization.unitData(83)),"activation fixture starts paid villager production");
    resumeManager->update(1000);resumeManager->update(1500);
    auto finalMap=Map::fromTerrainSave(resumeMap->saveTerrain());
    auto finalManager=std::make_shared<UnitManager>();finalManager->setMap(finalMap);finalManager->init();
    auto finalOwner=std::make_shared<Player>(5,1,finalMap,ResourceMap{});
    finalOwner->civilization.restoreUnitAttributes(resumeOwner->civilization.saveUnitAttributes());
    finalOwner->restoreResearchState(resumeOwner->saveResearchState());
    finalOwner->restoreEconomyDiplomacy(resumeOwner->saveEconomyDiplomacy());
    finalOwner->visibility->restoreRuntime(resumeOwner->visibility->saveRuntime());
    auto resumeGraph=agepad::UnitGraphSave::stage(agepad::UnitGraphSave::save(resumeManager->units()),{finalOwner},*finalManager,1500);
    auto finalSoldier=resumeGraph.index.unit(resumeSoldier->id);auto finalTown=Building::fromUnit(resumeGraph.index.unit(resumeTown->id));
    const auto managerBytes=agepad::UnitGraphSave::saveManager(*resumeManager);
    const std::vector<agepad::SaveBytes> memberships{resumeOwner->saveUnitMembership()};
    auto badManager=managerBytes;badManager.push_back(0);
    check(rejected([&]{agepad::UnitGraphSave::activate(resumeGraph,*finalManager,{finalOwner},memberships,badManager,1500);}) && finalManager->units().empty() && finalOwner->unitGroupCount()==0 && finalSoldier->isRestoreStaging(),"activation validates complete manager section before membership commit");
    const auto beforeActivation=finalOwner->saveEconomyDiplomacy(),beforeVisibility=finalOwner->visibility->saveRuntime(),beforeTerrain=finalMap->saveTerrain();
    agepad::UnitGraphSave::activate(resumeGraph,*finalManager,{finalOwner},memberships,managerBytes,1500);
    check(finalManager->units().size()==2 && !finalSoldier->isRestoreStaging() && resumeGraph.records.empty(),"activation transfers ownership to normal manager and consumes staging graph");
    check(finalOwner->saveEconomyDiplomacy()==beforeActivation && finalOwner->visibility->saveRuntime()==beforeVisibility && finalMap->saveTerrain()==beforeTerrain,"activation emits no resource, visibility or foundation changes");
    check(finalOwner->unitsInGroup(3).contains(finalSoldier.get()) && finalManager->selected().first()==finalSoldier && finalManager->controlGroupSize(2)==1,"activation restores player groups, selection and keyboard control groups");
    bool occupied=false;for(const auto &weak:finalMap->entitiesAt(int(finalSoldier->position().x)/48,int(finalSoldier->position().y)/48))occupied |= weak.lock()==finalSoldier;
    check(occupied,"restored map occupancy resolves the new unit object");
    bool resumedEqual=true;
    for(Time t=1600;t<=25000;t+=100) {
        resumeManager->update(t);finalManager->update(t);
        resumedEqual &= resumeSoldier->position()==finalSoldier->position() && resumeTown->productionQueueLength()==finalTown->productionQueueLength() &&
            resumeManager->units().size()==finalManager->units().size() && resumeOwner->resourcesAvailable(genie::ResourceType::FoodStorage)==finalOwner->resourcesAvailable(genie::ResourceType::FoodStorage) &&
            resumeOwner->resourcesUsed(genie::ResourceType::PopulationHeadroom)==finalOwner->resourcesUsed(genie::ResourceType::PopulationHeadroom);
    }
    check(resumedEqual && finalManager->units().size()==3 && !finalSoldier->actions.currentAction(),"resumed normal manager matches queued movement and one trained villager through completion");
    std::cout << "unit_base_save_checks=" << checks << " errors=0\n";
    return 0;
} catch(const std::exception &error){std::cerr << error.what() << '\n';return 1;}
