#include "global/Config.h"
#include "actions/ActionMove.h"
#include "render/GraphicRender.h"
#include "resource/Sprite.h"
#include "mechanics/Map.h"
#include "mechanics/Building.h"
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
    struct Fixture {
        std::shared_ptr<Map> map;
        std::shared_ptr<UnitManager> manager;
        std::shared_ptr<Player> owner;
        Building::Ptr town;
    };
    auto make=[](){
        Fixture f;f.map=std::make_shared<Map>();f.map->setupBasic();f.map->updateMapData();
        f.manager=std::make_shared<UnitManager>();f.manager->setMap(f.map);
        if(!f.manager->init())throw std::runtime_error("manager init");
        f.owner=std::make_shared<Player>(1,1,f.map,ResourceMap{});
        f.owner->setAvailableResource(genie::ResourceType::FoodStorage,500);
        f.owner->setAvailableResource(genie::ResourceType::WoodStorage,500);
        f.owner->setAvailableResource(genie::ResourceType::PopulationHeadroom,100);
        f.manager->setPlayers({f.owner});f.manager->setHumanPlayer(f.owner);
        f.town=Building::fromUnit(UnitFactory::createUnit(109,f.owner,*f.manager));
        f.manager->add(f.town,MapPos(480,480));return f;
    };
    auto original=make(),restored=make();
    const auto &villager=original.owner->civilization.unitData(83);
    const auto &watch=data.getTech(8);
    check(original.town->enqueueProduceUnit(&villager) && original.town->enqueueProduceResearch(&watch),"unit and research queued with actual costs");
    original.town->waypoint=MapPos(720,600);
    original.town->update(2000);
    check(original.town->productionProgress()>0 && original.town->productionProgress()<1,"partly trained unit fixture");
    const auto saved=original.town->saveProductionRuntime();
    restored.owner->restoreEconomyDiplomacy(original.owner->saveEconomyDiplomacy());
    const auto economy=restored.owner->saveEconomyDiplomacy();
    restored.town->restoreProductionRuntime(saved,2000);
    check(restored.town->saveProductionRuntime()==saved,"queue progress costs and waypoint roundtrip");
    check(restored.owner->saveEconomyDiplomacy()==economy,"restore does not charge costs again");
    bool equal=true;bool researchStarted=false;
    for(Time time=2100;time<=25000;time+=100){
        original.town->update(time);restored.town->update(time);
        equal &= original.town->productionQueueLength()==restored.town->productionQueueLength() && original.town->productionProgress()==restored.town->productionProgress();
        if(original.town->isResearching()){researchStarted=true;break;}
    }
    check(equal && researchStarted,"unit completion and queued research start match uninterrupted run");
    check(original.manager->units().size()==restored.manager->units().size() && original.manager->units().size()==2,"one trained unit spawned on each timeline");
    original.town->update(27000);restored.town->update(27000);
    auto midResearch=original.town->saveProductionRuntime();
    auto researchRestored=make();
    researchRestored.owner->restoreEconomyDiplomacy(original.owner->saveEconomyDiplomacy());
    researchRestored.town->restoreProductionRuntime(midResearch,27000);
    check(researchRestored.town->isResearching() && researchRestored.town->productionProgress()==original.town->productionProgress(),"mid-research progress restored");
    const auto food=genie::ResourceType::FoodStorage;
    const float beforeRefund=researchRestored.owner->resourcesAvailable(food);
    researchRestored.town->abortProduction(0);
    check(researchRestored.owner->resourcesAvailable(food)==beforeRefund+75 && !researchRestored.town->isProducing(),"restored active research cancellation refunds original payment");
    auto cancelled=make();cancelled.owner->restoreEconomyDiplomacy(economy);cancelled.town->restoreProductionRuntime(saved,2000);
    const float beforeBoth=cancelled.owner->resourcesAvailable(food);
    cancelled.town->abortProduction(1);cancelled.town->abortProduction(0);
    check(cancelled.owner->resourcesAvailable(food)==beforeBoth+125,"queued research and active unit refunds match saved costs");
    auto invalid=make();const auto before=invalid.town->saveProductionRuntime();const auto beforeEconomy=invalid.owner->saveEconomyDiplomacy();
    bool truncated=true;
    for(std::size_t n=0;n<saved.size();++n){agepad::SaveBytes partial(saved.begin(),saved.begin()+n);truncated &= rejected([&]{invalid.town->restoreProductionRuntime(partial,2000);});}
    check(truncated && invalid.town->saveProductionRuntime()==before && invalid.owner->saveEconomyDiplomacy()==beforeEconomy,"truncated queues refuse without mutation or refunds");
    check(rejected([&]{invalid.town->restoreProductionRuntime(saved,1999);}),"future queue timestamp refused");
    auto bad=saved;bad.push_back(0);
    check(rejected([&]{invalid.town->restoreProductionRuntime(bad,2000);}),"trailing production bytes refused");
    check(rejected([&]{original.town->restoreProductionRuntime(saved,27000);}),"nonempty queue cannot be silently replaced");
    const float originalSight=original.town->data()->LineOfSight;
    const float restoredSight=restored.town->data()->LineOfSight;
    bool researchEqual=true;
    for(Time time=27100;time<=100000;time+=100){
        original.town->update(time);restored.town->update(time);
        researchEqual &= original.town->isProducing()==restored.town->isProducing() && original.town->productionProgress()==restored.town->productionProgress();
        if(!original.town->isProducing())break;
    }
    check(researchEqual && !original.town->isProducing() && !restored.town->isProducing(),"queued research completes on same simulation update");
    check(original.town->data()->LineOfSight==originalSight+4 && restored.town->data()->LineOfSight==restoredSight+4,"research completion applies matching sight bonus");
    auto catalogSource=make(),catalogDestination=make();
    auto found=catalogSource.owner->civilization.availableTechs().find(8);
    check(found!=catalogSource.owner->civilization.availableTechs().end() && catalogSource.town->enqueueProduceResearch(&found->second),"actual civilization research catalog queue available");
    catalogDestination.town->restoreProductionRuntime(catalogSource.town->saveProductionRuntime(),100000);
    check(catalogDestination.town->saveProductionRuntime()==catalogSource.town->saveProductionRuntime(),"civilization research origin remapped to destination catalog");
    auto housed=make();
    housed.owner->setAvailableResource(genie::ResourceType::PopulationHeadroom,1);
    housed.manager->add(UnitFactory::createUnit(83,housed.owner,*housed.manager),MapPos(600,600));
    const auto &housedVillager=housed.owner->civilization.unitData(83);
    check(housed.town->enqueueProduceUnit(&housedVillager),"housing-full villager can be paid and queued");
    for(Time t=0;t<=30000;t+=100) housed.town->update(t);
    check(housed.manager->units().size()==2 && housed.town->productionQueueLength()==1 && housed.town->productionProgress()==0,
          "full housing blocks training without discarding paid queue");
    const auto blockedQueue=housed.town->saveProductionRuntime();
    auto resumedHousing=make();resumedHousing.owner->restoreEconomyDiplomacy(housed.owner->saveEconomyDiplomacy());
    resumedHousing.town->restoreProductionRuntime(blockedQueue,30000);
    resumedHousing.town->update(31000);
    check(resumedHousing.town->productionProgress()==0 && resumedHousing.manager->units().size()==1,"restored blocked queue still waits for housing");
    resumedHousing.owner->setAvailableResource(genie::ResourceType::PopulationHeadroom,2);
    for(Time t=31100;t<=60000;t+=100) resumedHousing.town->update(t);
    check(resumedHousing.manager->units().size()==2 && !resumedHousing.town->isProducing() && resumedHousing.owner->resourcesAvailable(food)==450,
          "added housing resumes saved queue and charges no second cost");
    auto lostHouse=make();lostHouse.owner->setAvailableResource(genie::ResourceType::PopulationHeadroom,1);
    check(lostHouse.town->enqueueProduceUnit(&lostHouse.owner->civilization.unitData(83)),"housing-loss fixture starts training");
    lostHouse.town->update(2000);const auto beforeLoss=lostHouse.town->productionProgress();
    lostHouse.owner->setAvailableResource(genie::ResourceType::PopulationHeadroom,0);
    lostHouse.town->update(30000);
    check(lostHouse.manager->units().size()==1 && lostHouse.town->productionProgress()==beforeLoss,"housing loss pauses active training without spawning over capacity");
    lostHouse.town->abortProduction(0);
    check(lostHouse.owner->resourcesAvailable(food)==500,"blocked active cancellation refunds original food");
    const int distinctResearchId=202;
    const auto &distinctResearch=data.getTech(distinctResearchId);
    std::cout << "research_identity id=" << distinctResearchId << " effect=" << distinctResearch.EffectID << " location=" << distinctResearch.ResearchLocation << '\n';
    check(distinctResearch.EffectID!=distinctResearchId,"actual research fixture has distinct research and effect IDs");
    auto expectedResearch=make(),queuedResearch=make();
    expectedResearch.owner->applyResearch(distinctResearchId);
    auto researchBuilding=Building::fromUnit(UnitFactory::createUnit(distinctResearch.ResearchLocation,queuedResearch.owner,*queuedResearch.manager));
    check(bool(researchBuilding),"actual research building exists");
    check(researchBuilding->enqueueProduceResearch(&distinctResearch),"distinct-ID research queues in its building");
    for(Time t=0;t<=200000;t+=100)researchBuilding->update(t);
    check(!researchBuilding->isProducing() && queuedResearch.owner->civilization.saveUnitAttributes()==expectedResearch.owner->civilization.saveUnitAttributes(),
          "completed production applies requested research instead of treating effect ID as research ID");
    auto catalogResearch=make(),resumedResearch=make();
    auto catalogBuilding=Building::fromUnit(UnitFactory::createUnit(distinctResearch.ResearchLocation,catalogResearch.owner,*catalogResearch.manager));
    auto resumedBuilding=Building::fromUnit(UnitFactory::createUnit(distinctResearch.ResearchLocation,resumedResearch.owner,*resumedResearch.manager));
    const auto &catalogTech=catalogResearch.owner->civilization.availableTechs().at(distinctResearchId);
    check(catalogBuilding->enqueueProduceResearch(&catalogTech),"distinct-ID civilization catalog research queues");
    catalogBuilding->update(1000);
    const auto midUpgrade=catalogBuilding->saveProductionRuntime();
    resumedResearch.owner->restoreEconomyDiplomacy(catalogResearch.owner->saveEconomyDiplomacy());
    resumedBuilding->restoreProductionRuntime(midUpgrade,1000);
    for(Time t=1100;t<=200000;t+=100)resumedBuilding->update(t);
    check(!resumedBuilding->isProducing() && resumedResearch.owner->civilization.saveUnitAttributes()==expectedResearch.owner->civilization.saveUnitAttributes(),
          "restored civilization-catalog queue retains requested research identity through completion");
    auto foreignTech=distinctResearch;
    const auto beforeForeign=catalogResearch.owner->saveEconomyDiplomacy();
    check(!catalogBuilding->enqueueProduceResearch(&foreignTech) && catalogResearch.owner->saveEconomyDiplomacy()==beforeForeign,
          "research outside stable catalogs is rejected before charging resources");
    auto queuedUpgrade=make();
    queuedUpgrade.owner->setAvailableResource(genie::ResourceType::GoldStorage,500);
    auto barracks=Building::fromUnit(UnitFactory::createUnit(12,queuedUpgrade.owner,*queuedUpgrade.manager));
    queuedUpgrade.manager->add(barracks,MapPos(1200,1200));
    const auto &oldMilitia=queuedUpgrade.owner->civilization.unitData(74);
    check(barracks->enqueueProduceResearch(&data.getTech(222)) && barracks->enqueueProduceUnit(&oldMilitia),
        "Man-at-Arms research followed by an already-paid Militia queues normally");
    const auto paidFood=queuedUpgrade.owner->resourcesAvailable(genie::ResourceType::FoodStorage);
    const auto paidGold=queuedUpgrade.owner->resourcesAvailable(genie::ResourceType::GoldStorage);
    for(Time t=0;t<=200000;t+=100)barracks->update(t);
    bool manAtArms=false,obsoleteMilitia=false;
    for(const auto &unit:queuedUpgrade.manager->units()) {
        manAtArms |= unit->data()->ID==75;obsoleteMilitia |= unit->data()->ID==74;
    }
    check(manAtArms && !obsoleteMilitia && !barracks->isProducing(),
        "unit paid before upgrade completion emerges as Man-at-Arms");
    check(queuedUpgrade.owner->resourcesAvailable(genie::ResourceType::FoodStorage)==paidFood &&
          queuedUpgrade.owner->resourcesAvailable(genie::ResourceType::GoldStorage)==paidGold,
        "upgraded queued product does not charge another unit cost");
    std::cout << "production_save_checks=" << checks << " errors=0\n";
    return 0;
} catch(const std::exception &error){std::cerr << error.what() << '\n';return 1;}
