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
    auto check=[&](bool ok,const char *name) { ++checks; if (!ok) throw std::runtime_error(name); };
    auto rejected=[](auto action) { try { action(); return false; } catch (const agepad::SaveError &) { return true; } };
    auto player=state.humanPlayer();
    player->setAvailableResource(genie::ResourceType::WoodStorage,123.5f);
    player->setAvailableResource(genie::ResourceType::FoodStorage,456.25f);
    player->setDiplomaticStance(2,Player::Allied);
    player->setDiplomaticStance(3,Player::Enemy);
    player->setDiplomaticStance(4,Player::Neutral);
    const auto saved=player->saveEconomyDiplomacy();
    auto restored=std::make_shared<Player>(player->playerId,player->civilization.id(),state.map());
    struct Observer : EventListener {
        int events=0;
        void onPlayerResourceChanged(Player *,genie::ResourceType,float) override { ++events; }
    } observer;
    EventManager::registerListener(&observer,EventManager::PlayerResourceChanged);
    restored->restoreEconomyDiplomacy(saved);
    check(restored->saveEconomyDiplomacy()==saved,"exact canonical economy and diplomacy round trip");
    check(observer.events==0,"restore emits no resource events");
    check(restored->resourcesAvailable(genie::ResourceType::WoodStorage)==123.5f,"fractional wood preserved");
    check(restored->resourcesAvailable(genie::ResourceType::FoodStorage)==456.25f,"fractional food preserved");
    bool usageFound=false;
    for (int id=-1;id<int(genie::ResourceType::NumberOfTypes);++id) {
        const auto type=static_cast<genie::ResourceType>(id);
        check(restored->resourcesAvailable(type)==player->resourcesAvailable(type),"all source resources preserved");
        check(restored->resourcesUsed(type)==player->resourcesUsed(type),"all used resources preserved");
        usageFound |= player->resourcesUsed(type)!=0;
    }
    check(usageFound,"fixture actually exercises used-resource accounting");
    check(restored->isAllied(2) && !restored->isAllied(3) && !restored->isAllied(4),"alliances preserved");
    restored->removeResource(genie::ResourceType::WoodStorage,10.25f);
    check(restored->resourcesAvailable(genie::ResourceType::WoodStorage)==113.25f && observer.events==1,"continued spending works with one normal event");
    const auto before=restored->saveEconomyDiplomacy();
    bool truncations=true;
    for (std::size_t n=0;n<saved.size();++n) {
        agepad::SaveBytes partial(saved.begin(),saved.begin()+n);
        truncations &= rejected([&]{restored->restoreEconomyDiplomacy(partial);});
        truncations &= restored->saveEconomyDiplomacy()==before;
    }
    check(truncations,"all truncations reject without changing live player");
    auto bad=saved;bad[4]^=1;
    check(rejected([&]{restored->restoreEconomyDiplomacy(bad);}),"player mismatch refused");
    bad=saved;bad[8]^=1;
    check(rejected([&]{restored->restoreEconomyDiplomacy(bad);}),"civilization mismatch refused");
    bad=saved;bad.push_back(0);
    check(rejected([&]{restored->restoreEconomyDiplomacy(bad);}),"trailing data refused");
    bad=saved; for (int i=12;i<16;++i) bad[i]=255;
    check(rejected([&]{restored->restoreEconomyDiplomacy(bad);}),"oversized resource map refused");
    bad=saved;bad[20]=0;bad[21]=0;bad[22]=128;bad[23]=127;
    check(rejected([&]{restored->restoreEconomyDiplomacy(bad);}),"infinite resource refused under fast math");
    bad=saved; for (int i=0;i<4;++i) bad[24+i]=bad[16+i];
    check(rejected([&]{restored->restoreEconomyDiplomacy(bad);}),"duplicate resource key refused");
    bad=saved;bad[bad.size()-4]=99;
    check(rejected([&]{restored->restoreEconomyDiplomacy(bad);}),"invalid stance refused");
    check(restored->saveEconomyDiplomacy()==before && observer.events==1,"malformed loads preserve all fields without events");
    std::cout << "player_economy_save_checks=" << checks << " errors=0\n";
    return 0;
} catch (const std::exception &error) {
    std::cerr << error.what() << '\n';
    return 1;
}
