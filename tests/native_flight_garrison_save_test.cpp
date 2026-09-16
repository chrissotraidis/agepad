#include "global/Config.h"
#include "actions/ActionFly.h"
#include "actions/ActionGarrison.h"
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
#include <limits>
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
    auto secondManager=std::make_shared<UnitManager>();secondManager->setMap(map);
    if(!secondManager->init())throw std::runtime_error("second manager init");
    auto secondOwner=std::make_shared<Player>(1,1,map,ResourceMap{});
    Task flyTask;int birdID=-1;
    for(int id=0;id<1500 && birdID<0;++id)for(const auto &d:data.getTasks(id))
        if(d.ActionType==genie::ActionType::Fly){birdID=id;flyTask=Task(&d,id);break;}
    check(birdID>=0,"actual flying unit task found");
    auto bird=UnitFactory::createUnit(birdID,owner,*manager);
    auto restoredBird=UnitFactory::createUnit(birdID,secondOwner,*secondManager);
    manager->add(bird,MapPos(800,800,0));
    ActionFly flight(bird,flyTask);
    for(Time time=1000;time<=12000;time+=100)flight.update(time);
    const auto saved=flight.saveRuntime();
    restoredBird->restoreBaseRuntime(bird->saveBaseRuntime(),12000);
    secondManager->add(restoredBird,restoredBird->position());
    secondManager->random().restoreRuntime(manager->random().saveRuntime());
    agepad::EntitySaveIndex index;index.add(bird->id,restoredBird);index.seal();
    auto resumed=ActionFly::fromRuntime(saved,index,12000);
    bool identical=true;
    for(Time time=12100;time<=70000;time+=100) {
        identical &= flight.update(time)==resumed->update(time);
        identical &= bird->position()==restoredBird->position() && bird->angle()==restoredBird->angle();
        identical &= flight.unitState()==resumed->unitState();
        identical &= manager->random().saveRuntime()==secondManager->random().saveRuntime();
    }
    check(identical,"flight position altitude turns state and random stream match for 58 seconds");
    auto bad=saved;bad.push_back(0);
    check(rejected([&]{ActionFly::fromRuntime(bad,index,12000);}),"trailing flight bytes refused");
    check(rejected([&]{ActionFly::fromRuntime(saved,index,1000);}),"future flight timing refused");
    bad=saved;bad[bad.size()-1]=127;
    check(rejected([&]{ActionFly::fromRuntime(bad,index,12000);}),"unknown flight state refused");
    auto soldier=UnitFactory::createUnit(74,owner,*manager);
    auto newSoldier=UnitFactory::createUnit(74,secondOwner,*secondManager);
    auto town=std::static_pointer_cast<Building>(UnitFactory::createUnit(109,owner,*manager));
    auto newTown=std::static_pointer_cast<Building>(UnitFactory::createUnit(109,secondOwner,*secondManager));
    for(auto unit:{soldier,newSoldier,std::static_pointer_cast<Unit>(town),std::static_pointer_cast<Unit>(newTown)})
        unit->Entity::setPosition(MapPos(600,600,0),true);
    Task garrisonTask;
    for(const auto &d:data.getTasks(74))if(d.ActionType==genie::ActionType::Garrison){garrisonTask=Task(&d,74);break;}
    check(garrisonTask.data!=nullptr,"actual garrison task found");garrisonTask.target=town;
    ActionGarrison garrison(soldier,garrisonTask);garrison.requiredUnitID=74;
    const auto garrisonSaved=garrison.saveRuntime();
    agepad::EntitySaveIndex garrisonIndex;garrisonIndex.add(soldier->id,newSoldier);garrisonIndex.add(town->id,newTown);garrisonIndex.seal();
    auto loaded=ActionGarrison::fromRuntime(garrisonSaved,garrisonIndex,70000);
    check(newTown->garrisonedUnits.empty() && newSoldier->garrisonedIn.expired(),"loading pending garrison does not enter building early");
    check(loaded->requiredUnitID==74,"garrison worker requirement retained");
    check(garrison.update(70000)==IAction::UpdateResult::Completed && loaded->update(70000)==IAction::UpdateResult::Completed,"both pending garrisons complete");
    check(town->garrisonedUnits.size()==1 && newTown->garrisonedUnits.size()==1 && newTown->garrisonedUnits.front().lock()==newSoldier && newSoldier->garrisonedIn.lock()==newTown,"restored garrison uses remapped unit and building links");
    agepad::EntitySaveIndex wrong;wrong.add(soldier->id,newSoldier);wrong.add(town->id,restoredBird);wrong.seal();
    check(rejected([&]{ActionGarrison::fromRuntime(garrisonSaved,wrong,70000);}),"non-building garrison target refused");
    bad=garrisonSaved;bad.push_back(0);
    check(rejected([&]{ActionGarrison::fromRuntime(bad,garrisonIndex,70000);}),"trailing garrison bytes refused");
    const auto &corpseData=owner->civilization.unitData(soldier->data()->DeadUnitID);
    auto corpse=std::make_shared<DecayingEntity>(corpseData.StandingGraphic.first,2.f,Size(corpseData.Size));
    corpse->isVisible=true;corpse->spawnId=123;
    corpse->setPosition(MapPos(480,480,1),true);
    corpse->update(60000);
    check(!corpse->shouldBeRemoved(),"new late-game corpse retains its full lifetime");
    for(Time t=60100;t<=61000;t+=100)corpse->update(t);
    const auto decayBytes=corpse->saveRuntime();
    auto restoredCorpse=DecayingEntity::fromRuntime(decayBytes,61000);
    check(restoredCorpse->saveRuntime()==decayBytes && !restoredCorpse->map(),"decay timer, animation and geometry roundtrip into detached entity");
    auto beforeReverse=corpse->saveRuntime();corpse->update(60000);
    check(corpse->saveRuntime()==beforeReverse,"backward simulation time cannot extend corpse lifetime");
    bool decayEqual=true,expired=false;
    for(Time t=61100;t<=100000;t+=100) {
        corpse->update(t);restoredCorpse->update(t);
        decayEqual &= corpse->saveRuntime()==restoredCorpse->saveRuntime();
        if(corpse->shouldBeRemoved()){expired=true;break;}
    }
    std::cout<<"decay_equal="<<decayEqual<<" expired="<<expired<<" frame="<<corpse->renderer().currentFrame()<<"/"<<corpse->renderer().frameCount()<<" rate="<<corpse->renderer().sprite()->framerate()<<"\n";
    check(decayEqual && expired && restoredCorpse->shouldBeRemoved(),"resumed corpse expires with uninterrupted corpse on identical tick");
    auto expiredCopy=DecayingEntity::fromRuntime(corpse->saveRuntime(),100000);
    check(expiredCopy->shouldBeRemoved(),"expired corpse cannot reappear after restore");
    auto forever=std::make_shared<DecayingEntity>(corpseData.StandingGraphic.first,0.f,Size(corpseData.Size),true);
    forever->update(1000);auto foreverCopy=DecayingEntity::fromRuntime(forever->saveRuntime(),1000);
    forever->update(1000000);foreverCopy->update(1000000);
    check(!foreverCopy->shouldBeRemoved() && foreverCopy->saveRuntime()==forever->saveRuntime(),"infinite rubble lifetime uses explicit roundtrippable sentinel");
    bad=decayBytes;bad.push_back(0);
    check(rejected([&]{DecayingEntity::fromRuntime(bad,61000);}),"trailing decay data refused");
    check(rejected([&]{DecayingEntity::fromRuntime(decayBytes,60999);}),"future decay timer refused");
    bool truncations=true;
    for(std::size_t n=0;n<decayBytes.size();++n){agepad::SaveBytes shortBytes(decayBytes.begin(),decayBytes.begin()+n);truncations &= rejected([&]{DecayingEntity::fromRuntime(shortBytes,61000);});}
    check(truncations,"every truncated decay snapshot refused");
    bad=decayBytes;for(int j=36;j<40;++j)bad[j]=255;
    check(rejected([&]{DecayingEntity::fromRuntime(bad,61000);}),"non-finite decay scalar refused");
    auto cleanupManager=std::make_shared<UnitManager>();cleanupManager->setMap(map);cleanupManager->init();
    cleanupManager->addStaticEntity(DecayingEntity::fromRuntime(decayBytes,61000));
    for(Time t=61100;t<=100000 && !cleanupManager->staticEntities().empty();t+=100)cleanupManager->update(t);
    check(cleanupManager->staticEntities().empty(),"normal manager update removes restored expired corpse");
    std::cout << "flight_garrison_save_checks=" << checks << " errors=0\n";return 0;
} catch(const std::exception &e){std::cerr << e.what() << '\n';return 1;}
