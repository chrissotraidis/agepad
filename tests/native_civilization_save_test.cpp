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
    auto check=[&](bool ok,const char *name) {++checks;if (!ok) throw std::runtime_error(name);};
    auto rejected=[](auto action) {try {action();return false;} catch(const agepad::SaveError &) {return true;}};
    auto original=std::make_unique<Civilization>(1);
    auto change=[&](genie::EffectCommand::Attributes attribute,genie::EffectCommand::EffectType type,float amount) {
        genie::EffectCommand effect;
        effect.TargetUnit=74;effect.AttributeID=attribute;effect.Type=type;effect.Amount=amount;
        original->applyUnitAttributeModifier(effect);
    };
    float initialFoodCost=0;
    for (const auto &cost : original->unitData(74).Creatable.ResourceCosts)
        if (cost.Type==0) initialFoodCost=cost.Amount;
    const auto initialHP=original->unitData(74).HitPoints;
    const auto initialSpeed=original->unitData(74).Speed;
    const auto initialSight=original->unitData(74).LineOfSight;
    change(genie::EffectCommand::HitPoints,genie::EffectCommand::RelativeAttributeModifier,13);
    change(genie::EffectCommand::MovementSpeed,genie::EffectCommand::AttributeMultiplier,1.25f);
    change(genie::EffectCommand::LineOfSight,genie::EffectCommand::RelativeAttributeModifier,2);
    change(genie::EffectCommand::FoodCosts,genie::EffectCommand::RelativeAttributeModifier,7);
    int enabledID=-1,creator=-1;
    for (const auto &u : data.civilization(1).Units) {
        if (u.ID>=0 && !u.Enabled && u.Creatable.TrainLocationID>0) {enabledID=u.ID;creator=u.Creatable.TrainLocationID;break;}
    }
    check(enabledID>=0,"fixture finds disabled trainable unit");
    original->enableUnit(enabledID);
    const auto availability=original->creatableUnits(creator).size();
    original->enableUnit(enabledID);
    check(original->creatableUnits(creator).size()==availability,"repeated enable does not duplicate creation entry");
    const auto expectedCosts=original->unitData(74).Creatable.ResourceCosts;
    bool foodChanged=false;
    for (const auto &cost : expectedCosts) if (cost.Type==0) foodChanged=cost.Amount==initialFoodCost+7;
    check(foodChanged,"fixture modifies actual food cost");
    auto saved=original->saveUnitAttributes();
    original.reset();
    Civilization restored(1);
    const auto *unitAddress=&restored.unitData(74);
    const auto *attackAddress=restored.unitData(74).Combat.Attacks.data();
    restored.restoreUnitAttributes(saved);
    check(restored.saveUnitAttributes()==saved,"exact attribute section round trip");
    check(restored.unitData(74).HitPoints==initialHP+13,"researched hit points preserved");
    check(restored.unitData(74).Speed==initialSpeed*1.25f,"researched movement speed preserved");
    check(restored.unitData(74).LineOfSight==initialSight+2,"researched line of sight preserved");
    bool costs=true;
    for (std::size_t i=0;i<expectedCosts.size();++i) costs &= restored.unitData(74).Creatable.ResourceCosts[i].Amount==expectedCosts[i].Amount;
    check(costs,"modified production costs preserved");
    check(restored.unitData(enabledID).Enabled,"newly enabled unit stays enabled");
    int occurrences=0;
    for (auto u : restored.creatableUnits(creator)) occurrences += u->ID==enabledID;
    check(occurrences==1,"restored creation cache contains enabled unit exactly once");
    check(unitAddress==&restored.unitData(74) && attackAddress==restored.unitData(74).Combat.Attacks.data(),"live record and array addresses remain stable");
    const auto before=restored.saveUnitAttributes();
    for (std::size_t n : {std::size_t(0),std::size_t(12),std::size_t(24),saved.size()/2,saved.size()-1}) {
        agepad::SaveBytes partial(saved.begin(),saved.begin()+n);
        check(rejected([&]{restored.restoreUnitAttributes(partial);}),"truncated attributes refused");
    }
    auto bad=saved;bad[4]=2;
    check(rejected([&]{restored.restoreUnitAttributes(bad);}),"different civilization refused");
    bad=saved;bad[12]^=1;
    check(rejected([&]{restored.restoreUnitAttributes(bad);}),"different baseline record refused");
    bad=saved;bad[24]=9;
    check(rejected([&]{restored.restoreUnitAttributes(bad);}),"invalid availability refused");
    bad=saved;
    for (int i=32;i<39;++i) bad[i]=255;
    bad[39]=127;
    check(rejected([&]{restored.restoreUnitAttributes(bad);}),"out of range integral attribute refused");
    bad=saved;bad[40]=0;bad[41]=0;bad[42]=128;bad[43]=127;
    check(rejected([&]{restored.restoreUnitAttributes(bad);}),"nonfinite attribute refused");
    bad=saved;bad.push_back(0);
    check(rejected([&]{restored.restoreUnitAttributes(bad);}),"trailing data refused");
    check(restored.saveUnitAttributes()==before,"failed loads preserve all attributes");
    check(restored.creatableUnits(creator).size()==availability,"failed loads preserve availability cache");
    std::cout << "civilization_attribute_checks=" << checks << " errors=0\n";
    return 0;
} catch (const std::exception &error) {
    std::cerr << error.what() << '\n';
    return 1;
}
