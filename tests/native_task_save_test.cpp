#include "global/Config.h"
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
    auto renderer = std::make_shared<SfmlRenderTarget>(Size(800, 600));
    GameState state(renderer);
    if (!state.init()) throw std::runtime_error("Basic fixture init failed");
    int checks=0;
    auto check=[&](bool ok,const char *name){++checks;if(!ok)throw std::runtime_error(name);};
    auto rejected=[](auto action){try{action();return false;}catch(const agepad::SaveError &){return true;}};
    auto originalTarget=UnitFactory::createUnit(74,state.player(2),*state.unitManager());
    auto restoredTarget=UnitFactory::createUnit(74,state.player(2),*state.unitManager());
    check(originalTarget->id!=restoredTarget->id,"fixture uses different runtime identities");
    Task catalog;
    for(const auto &definition:data.getTasks(4)) if(definition.ID>=0 && definition.ActionType==genie::ActionType::Combat){catalog=Task(&definition,4);break;}
    check(catalog.data!=nullptr,"actual archer combat task found");
    catalog.target=originalTarget;
    const auto saved=catalog.saveDescriptor();
    agepad::EntitySaveIndex entities;
    entities.add(originalTarget->id,restoredTarget);
    entities.seal();
    auto loaded=Task::fromDescriptor(saved,entities);
    check(loaded.data==catalog.data && loaded.taskId==catalog.taskId && loaded.unitId==catalog.unitId,"catalog definition reconstructed exactly");
    check(loaded.target.lock()==restoredTarget,"target resolves to restored unit, not original");
    auto move=Task::move();move.target=originalTarget;
    const auto movement=move.saveDescriptor();
    auto loadedMove=Task::fromDescriptor(movement,entities);
    check(loadedMove.data==Task::move().data && loadedMove.data->ActionType==genie::ActionType::MoveTo,"built-in movement definition restored");
    check(loadedMove.target.lock()==restoredTarget,"movement target relinked");
    auto empty=Task::fromDescriptor(Task().saveDescriptor(),entities);
    check(empty.data==nullptr && empty.taskId==-1 && empty.unitId==-1 && empty.target.expired(),"empty task remains empty");
    agepad::EntitySaveIndex missing;missing.seal();
    check(rejected([&]{Task::fromDescriptor(saved,missing);}),"missing target refused");
    agepad::EntitySaveIndex unsealed;
    check(rejected([&]{Task::fromDescriptor(saved,unsealed);}),"unregistered graph cannot resolve task");
    bool truncations=true;
    for(std::size_t n=0;n<saved.size();++n){agepad::SaveBytes part(saved.begin(),saved.begin()+n);truncations &= rejected([&]{Task::fromDescriptor(part,entities);});}
    check(truncations,"all truncated descriptors refused");
    auto bad=saved;bad[0]=2;
    check(rejected([&]{Task::fromDescriptor(bad,entities);}),"unsupported descriptor schema refused");
    bad=saved;bad[4]=9;
    check(rejected([&]{Task::fromDescriptor(bad,entities);}),"unknown task kind refused");
    bad=saved;for(int i=8;i<12;++i)bad[i]=255;
    check(rejected([&]{Task::fromDescriptor(bad,entities);}),"invalid catalog unit refused");
    bad=saved;for(int i=12;i<16;++i)bad[i]=255;
    check(rejected([&]{Task::fromDescriptor(bad,entities);}),"missing task ordinal refused");
    bad=saved;bad[16]^=1;
    check(rejected([&]{Task::fromDescriptor(bad,entities);}),"mismatched task ID refused");
    bad=saved;bad[20]^=1;
    check(rejected([&]{Task::fromDescriptor(bad,entities);}),"mismatched action type refused");
    bad=saved;bad.push_back(0);
    check(rejected([&]{Task::fromDescriptor(bad,entities);}),"trailing descriptor bytes refused");
    genie::Task synthetic;synthetic.ID=0;
    Task unsupported(&synthetic,4);
    check(rejected([&]{unsupported.saveDescriptor();}),"unknown external task definition is not silently replaced");
    Task inconsistent;inconsistent.unitId=4;
    check(rejected([&]{inconsistent.saveDescriptor();}),"inconsistent empty task refused");
    check(catalog.target.lock()==originalTarget && loaded.target.lock()==restoredTarget,"failed loads do not change existing task links");
    std::cout << "task_descriptor_checks=" << checks << " errors=0\n";
    return 0;
} catch (const std::exception &error) {
    std::cerr << error.what() << '\n';
    return 1;
}
