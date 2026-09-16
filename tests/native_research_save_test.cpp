#include "global/Config.h"
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
    auto renderer = std::make_shared<SfmlRenderTarget>(Size(800, 600));
    GameState state(renderer);
    if (!state.init()) throw std::runtime_error("Basic fixture init failed");
    int checks=0;
    auto check=[&](bool ok,const char *name) {++checks;if(!ok)throw std::runtime_error(name);};
    auto rejected=[](auto action){try{action();return false;}catch(const agepad::SaveError &){return true;}};
    auto original=state.humanPlayer();
    for (int id : {8,22,101,102,104,120,202,220,222}) {
        const auto &tech=data.getTech(id);
        std::cout<<"catalog id="<<id<<" name="<<tech.Name<<" effect="<<tech.EffectID<<" location="<<tech.ResearchLocation<<" count="<<tech.RequiredTechCount<<" requires=";
        for(int req:tech.RequiredTechs)std::cout<<req<<",";
        std::cout<<"\n";
    }
    auto techPlayer=std::make_shared<Player>(original->playerId,original->civilization.id(),state.map());
    techPlayer->applyResearch(104);
    check(techPlayer->researchCompleted(220),"Dark Age completes Barracks research by its own identity");
    check(techPlayer->researchAvailable(22),"Dark Age unlocks Loom");
    check(!techPlayer->researchAvailable(202),"Double Bit Axe unavailable before Feudal Age");
    techPlayer->applyResearch(110);
    check(!techPlayer->researchCompleted(120),"one of five age-building prerequisites is insufficient");
    techPlayer->applyResearch(258);
    check(techPlayer->researchCompleted(120),"two of five age-building prerequisites complete the shadow node");
    check(techPlayer->researchAvailable(101),"shadow-node closure unlocks the next age");
    techPlayer->applyResearch(101);
    check(techPlayer->researchAvailable(202),"Feudal Age unlocks Double Bit Axe");
    techPlayer->applyResearch(202);
    check(techPlayer->researchCompleted(202),"distinct effect ID records the actual completed research");
    check(!techPlayer->researchCompleted(195),"effect ID does not fabricate another completed research");
    check(!techPlayer->researchAvailable(202),"completed Double Bit Axe removed from available upgrades");
    const auto techState=techPlayer->saveResearchState();
    techPlayer->applyResearch(202);
    check(techPlayer->saveResearchState()==techState,"distinct-ID research cannot be completed twice");
    auto agingOwner=std::make_shared<Player>(original->playerId,original->civilization.id(),state.map());
    auto agingTown=UnitFactory::createUnit(109,agingOwner,*state.unitManager());
    agingOwner->civilization.enableUnit(621);
    agingOwner->applyResearch(101);
    check(agingTown->data()->ID==71,"existing Town Center reaches Feudal variant");
    check(agingOwner->civilization.unitData(617).Enabled && !agingOwner->civilization.unitData(621).Enabled,"construction availability follows Feudal variant");
    agingOwner->applyResearch(102);
    check(agingTown->data()->ID==141,"existing Feudal Town Center reaches Castle variant through original reference");
    check(agingOwner->civilization.unitData(484).Enabled && !agingOwner->civilization.unitData(617).Enabled && !agingOwner->civilization.unitData(621).Enabled,"construction availability follows Castle variant through original reference");
    agingOwner->applyResearch(103);
    check(agingTown->data()->ID==142,"existing Castle Town Center reaches Imperial variant");
    check(agingOwner->civilization.unitData(597).Enabled && !agingOwner->civilization.unitData(484).Enabled,"construction availability follows Imperial variant");
    auto agingAvailability=agingOwner->civilization.saveUnitAttributes();
    Civilization restoredAvailability(agingOwner->civilization.id());restoredAvailability.restoreUnitAttributes(agingAvailability);
    check(restoredAvailability.unitData(597).Enabled && !restoredAvailability.unitData(484).Enabled,"upgraded construction availability survives attribute restore");
    auto lateTownOwner=std::make_shared<Player>(original->playerId,original->civilization.id(),state.map());
    lateTownOwner->applyResearch(101);lateTownOwner->applyResearch(102);
    check(lateTownOwner->civilization.unitData(484).Enabled && !lateTownOwner->civilization.unitData(621).Enabled,"Town Center unlocked after Castle upgrade uses current construction variant");
    int townChoices=0;for(const auto *choice:lateTownOwner->civilization.creatableUnits(118))if(choice->LanguageDLLName==lateTownOwner->civilization.unitData(109).LanguageDLLName)++townChoices;
    check(townChoices==1,"villager has one Town Center construction choice");
    auto lateBuilt=UnitFactory::createUnit(484,lateTownOwner,*state.unitManager());
    check(lateBuilt->data()->ID==484,"fresh construction uses current variant");
    check(!lateBuilt->annexes.empty() && lateBuilt->annexes.front().unit->data()->ID==141,"new Castle Town Center stack uses researched age variant");
    lateTownOwner->applyResearch(103);
    check(lateBuilt->data()->ID==597 && lateTownOwner->civilization.unitData(597).Enabled,"newly built Town Center advances to Imperial");
    check(lateBuilt->annexes.front().unit->data()->ID==142,"Town Center stack advances with parent into Imperial Age");
    auto militaryOwner=std::make_shared<Player>(original->playerId,original->civilization.id(),state.map());
    auto militia=UnitFactory::createUnit(74,militaryOwner,*state.unitManager());
    for(int id:{74,75,109,71,12,20}) {
        const auto &u=militaryOwner->civilization.unitData(id);
        std::cout<<"upgrade_catalog id="<<id<<" enabled="<<int(u.Enabled)<<" trainer="<<u.Creatable.TrainLocationID<<" base="<<u.BaseID<<"\n";
    }
    militaryOwner->applyResearch(222);
    check(militia->data()->ID==75,"Man-at-Arms research upgrades an existing Militia");
    const auto militaryProducts=militaryOwner->civilization.creatableUnits(12);
    check(std::any_of(militaryProducts.begin(),militaryProducts.end(),[](const auto *u){return u->ID==75;}) &&
          std::none_of(militaryProducts.begin(),militaryProducts.end(),[](const auto *u){return u->ID==74;}),
          "Man-at-Arms research replaces Militia in the Barracks training catalog");
    auto trainedAfterUpgrade=UnitFactory::createUnit(74,militaryOwner,*state.unitManager());
    check(trainedAfterUpgrade->data()->ID==75,"creation requested through old Militia ID yields researched Man-at-Arms");
    auto militaryCopy=std::make_shared<Player>(militaryOwner->playerId,militaryOwner->civilization.id(),state.map());
    militaryCopy->civilization.restoreUnitAttributes(militaryOwner->civilization.saveUnitAttributes());
    militaryCopy->restoreResearchState(militaryOwner->saveResearchState());
    auto trainedAfterRestore=UnitFactory::createUnit(74,militaryCopy,*state.unitManager());
    check(trainedAfterRestore->data()->ID==75,"completed upgrade resolves new unit creation after restore without effect replay");
    militaryOwner->applyResearch(207);
    check(militaryOwner->upgradedUnitId(74)==77,"later Long Swordsman research follows the completed upgrade chain");
    auto ageOwner=std::make_shared<Player>(original->playerId,original->civilization.id(),state.map());
    ageOwner->applyResearch(104);ageOwner->applyResearch(101);
    auto newBarracks=UnitFactory::createUnit(12,ageOwner,*state.unitManager());
    const auto &manAtArms=data.getTech(222);
    for (int required:manAtArms.RequiredTechs) if(required>=0) {
        const auto &dependency=data.getTech(required);
        std::cout<<"man_at_arms_dependency id="<<required<<" name="<<dependency.Name
                 <<" completed="<<ageOwner->researchCompleted(required)<<" count="<<dependency.RequiredTechCount
                 <<" location="<<dependency.ResearchLocation<<"\n";
    }
    check(ageOwner->researchAvailable(222),"Feudal Barracks makes Man-at-Arms research available");
    std::cout<<"new_barracks id="<<newBarracks->data()->ID<<" resolved="<<ageOwner->upgradedUnitId(12)
             <<" interface="<<int(newBarracks->data()->InterfaceKind)
             <<" building_interface="<<int(genie::Unit::BuildingsInterface)<<"\n";
    for(std::size_t id=0;id<data.allTechs().size();++id) if(ageOwner->researchCompleted(id)) {
        const auto &tech=data.getTech(id);if(tech.EffectID<0)continue;
        for(const auto &command:data.getEffect(tech.EffectID).EffectCommands)
            if(command.Type==genie::EffectCommand::UpgradeUnit && (command.TargetUnit==12 || command.TargetUnit==20 || command.TargetUnit==132))
                std::cout<<"barracks_upgrade research="<<id<<" from="<<command.TargetUnit<<" to="<<command.UnitClassID<<"\n";
    }
    check(newBarracks->data()->ID==498,"newly constructed Barracks uses the researched Feudal variant");
    const auto ageBuildings=ageOwner->civilization.creatableUnits(83);
    check(std::any_of(ageBuildings.begin(),ageBuildings.end(),[](const auto *u){return u->ID==498;}) &&
          std::none_of(ageBuildings.begin(),ageBuildings.end(),[](const auto *u){return u->ID==12;}),
          "Feudal building catalog replaces enabled Dark Age Barracks without adding its obsolete version");
    const auto priorSight=original->civilization.unitData(109).LineOfSight;
    original->applyResearch(8);
    check(original->civilization.unitData(109).LineOfSight!=priorSight,"actual Town Watch effect changes sight");
    const auto research=original->saveResearchState();
    const auto attributes=original->civilization.saveUnitAttributes();
    const auto economy=original->saveEconomyDiplomacy();
    auto restored=std::make_shared<Player>(original->playerId,original->civilization.id(),state.map());
    restored->civilization.restoreUnitAttributes(attributes);
    restored->restoreEconomyDiplomacy(economy);
    restored->restoreResearchState(research);
    check(restored->saveResearchState()==research,"exact research state round trip");
    bool availability=true;
    for(std::size_t id=0;id<data.allTechs().size();++id) availability &= restored->researchAvailable(id)==original->researchAvailable(id);
    check(availability,"all research availability matches original player");
    check(restored->civilization.saveUnitAttributes()==attributes,"research restoration does not replay attribute effects");
    check(restored->saveEconomyDiplomacy()==economy,"research restoration does not replay resource effects");
    restored->applyResearch(8);
    check(restored->civilization.saveUnitAttributes()==attributes,"completed research cannot grant sight twice after restore");
    check(restored->saveEconomyDiplomacy()==economy,"repeat completed research preserves economy");
    check(restored->saveResearchState()==research,"repeat completed research preserves bookkeeping");
    const auto before=restored->saveResearchState();
    bool truncated=true;
    for(std::size_t n=0;n<research.size();++n){
        agepad::SaveBytes partial(research.begin(),research.begin()+n);
        truncated &= rejected([&]{restored->restoreResearchState(partial);});
        truncated &= restored->saveResearchState()==before;
    }
    check(truncated,"every truncated prefix rejected without mutation");
    auto bad=research;bad[0]=1;
    check(rejected([&]{restored->restoreResearchState(bad);}),"legacy effect-only research state explicitly refused");
    bad=research;bad[0]=255;
    check(rejected([&]{restored->restoreResearchState(bad);}),"unsupported research schema refused");
    bad=research;bad[4]^=1;
    check(rejected([&]{restored->restoreResearchState(bad);}),"different player refused");
    bad=research;bad[8]^=1;
    check(rejected([&]{restored->restoreResearchState(bad);}),"different civilization refused");
    bad=research;for(int i=12;i<16;++i)bad[i]=255;
    check(rejected([&]{restored->restoreResearchState(bad);}),"excessive effect count refused");
    bad=research;for(int i=16;i<20;++i)bad[i]=255;
    check(rejected([&]{restored->restoreResearchState(bad);}),"invalid effect ID refused");
    bad=research;bad.push_back(0);
    check(rejected([&]{restored->restoreResearchState(bad);}),"trailing research bytes refused");
    check(restored->saveResearchState()==before,"failed loads preserve research state");
    std::cout << "research_save_checks=" << checks << " errors=0\n";
    return 0;
} catch (const std::exception &error) {
    std::cerr << error.what() << '\n';
    return 1;
}
