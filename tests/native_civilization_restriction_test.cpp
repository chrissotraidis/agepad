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
    auto briton=std::make_shared<Player>(1,1,map,ResourceMap{});
    auto persian=std::make_shared<Player>(2,8,map,ResourceMap{});
    for(auto p:{briton,persian}){p->applyResearch(103);p->applyResearch(13);}
    std::cout<<"briton_crop_rotation_available="<<briton->researchAvailable(12)<<"\n";
    check(!briton->researchAvailable(12),"Briton forbidden Crop Rotation offered");
    check(persian->researchAvailable(12),"Persian allowed Crop Rotation missing");
    briton->applyResearch(102);persian->applyResearch(102);
    check(!briton->researchCompleted(235),"Briton forbidden automatic Camel unlock fired");
    check(persian->researchCompleted(235),"Persian Camel unlock missing");
    const auto saved=briton->saveResearchState();
    auto restored=std::make_shared<Player>(1,1,map,ResourceMap{});restored->restoreResearchState(saved);
    check(!restored->researchAvailable(12),"Restored forbidden technology offered");
    agepad::SaveWriter oldAvailable;
    oldAvailable.u32(2);oldAvailable.i32(1);oldAvailable.i32(1);
    oldAvailable.u32(0);oldAvailable.u32(0);oldAvailable.u32(1);oldAvailable.i32(12);
    restored->restoreResearchState(oldAvailable.bytes);
    check(!restored->researchAvailable(12),"Old save re-offered forbidden purchase");
    agepad::SaveWriter oldCompleted;
    oldCompleted.u32(2);oldCompleted.i32(1);oldCompleted.i32(1);
    oldCompleted.u32(0);oldCompleted.u32(1);oldCompleted.i32(12);oldCompleted.u32(0);
    restored->restoreResearchState(oldCompleted.bytes);
    check(restored->researchCompleted(12),"Old completed history was rewritten");
    check(briton->civilization.researchDisabled(12) && !persian->civilization.researchDisabled(12),"Tree query disagrees with native restrictions");
    std::cout<<"civilization_restriction_checks="<<checks<<" errors=0\n";
    return 0;
} catch(const std::exception &e){std::cerr<<e.what()<<"\n";return 1;}
