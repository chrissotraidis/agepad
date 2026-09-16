#include "global/Config.h"
#include "actions/ActionBuild.h"
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
    auto renderer = std::make_shared<SfmlRenderTarget>(Size(800, 600));
    GameState state(renderer);
    if (!state.init()) throw std::runtime_error("Basic fixture init failed");
    int checks=0;
    auto check=[&](bool ok,const char *name){++checks;if(!ok)throw std::runtime_error(name);};
    auto rejected=[](auto action){try{action();return false;}catch(const agepad::SaveError &){return true;}};
    auto manager=state.unitManager();auto player=state.humanPlayer();
    auto source=std::static_pointer_cast<Building>(UnitFactory::createUnit(70,player,*manager));
    auto destination=std::static_pointer_cast<Building>(UnitFactory::createUnit(70,player,*manager));
    source->setCreationProgress(0);destination->setCreationProgress(0);
    std::vector<std::shared_ptr<Unit>> oldWorkers,newWorkers;
    std::vector<std::shared_ptr<ActionBuild>> actions,restored;
    std::vector<agepad::SaveBytes> saved;
    Task task;
    for(const auto &definition:data.getTasks(118))if(definition.ID>=0 && definition.ActionType==genie::ActionType::Build){task=Task(&definition,118);break;}
    check(task.data!=nullptr,"actual builder task found");
    task.target=source;
    agepad::EntitySaveIndex index;
    index.add(source->id,destination);
    for(int i=0;i<2;++i){
        oldWorkers.push_back(UnitFactory::createUnit(118,player,*manager));
        newWorkers.push_back(UnitFactory::createUnit(118,player,*manager));
        index.add(oldWorkers.back()->id,newWorkers.back());
        actions.push_back(std::make_shared<ActionBuild>(oldWorkers.back(),task));
        actions.back()->requiredUnitID=118;
        actions.back()->update(1000);
    }
    index.seal();
    check(source->constructors==2,"two builders registered before save");
    for(auto &action:actions){action->update(2000);saved.push_back(action->saveRuntime());}
    check(source->creationProgress()>0 && source->creationProgress()<1,"meaningful partial construction fixture");
    // Entity-state restoration is a separate pending component. Initialize its
    // equivalent progress here to isolate resumed action timing/accounting.
    destination->setCreationProgress(source->creationProgress()*source->data()->Creatable.TrainTime);
    for(const auto &bytes:saved)restored.push_back(ActionBuild::fromRuntime(bytes,index,2000));
    check(destination->constructors==2,"restore rebuilds active builder count exactly once");
    check(restored[0]->requiredUnitID==118 && restored[1]->requiredUnitID==118,"required worker type preserved");
    for(auto &action:actions)action->update(2500);
    for(auto &action:restored)action->update(2500);
    check(std::abs(source->creationProgress()-destination->creationProgress())<0.000001f,"restored work matches uninterrupted two-builder work");
    restored[0].reset();
    check(destination->constructors==1,"destroying one restored action removes one worker");
    restored[1].reset();
    check(destination->constructors==0,"destroying all restored actions balances count");
    auto pending=std::make_shared<ActionBuild>(oldWorkers[0],task);
    auto pendingRestored=ActionBuild::fromRuntime(pending->saveRuntime(),index,2500);
    check(destination->constructors==0,"unstarted restored action does not register early");
    pendingRestored->update(3000);
    check(destination->constructors==1,"unstarted action registers on first resumed update");
    pendingRestored.reset();
    check(destination->constructors==0,"unstarted-then-active action removal balances count");
    bool truncations=true;
    for(std::size_t n=0;n<saved[0].size();++n){agepad::SaveBytes partial(saved[0].begin(),saved[0].begin()+n);truncations &= rejected([&]{ActionBuild::fromRuntime(partial,index,2000);});}
    check(truncations && destination->constructors==0,"truncated loads never register workers");
    check(rejected([&]{ActionBuild::fromRuntime(saved[0],index,1999);}),"future action time refused");
    auto bad=saved[0];bad.push_back(0);
    check(rejected([&]{ActionBuild::fromRuntime(bad,index,2000);}),"trailing action bytes refused");
    bad=saved[0];for(int i=24;i<28;++i)bad[i]=255;
    check(rejected([&]{ActionBuild::fromRuntime(bad,index,2000);}),"oversized nested task refused");
    agepad::EntitySaveIndex missing;missing.seal();
    check(rejected([&]{ActionBuild::fromRuntime(saved[0],missing,2000);}),"missing actor refused");
    agepad::EntitySaveIndex wrong;
    wrong.add(source->id,newWorkers[1]);wrong.add(oldWorkers[0]->id,newWorkers[0]);wrong.seal();
    check(rejected([&]{ActionBuild::fromRuntime(saved[0],wrong,2000);}),"nonbuilding target refused");
    check(destination->constructors==0,"failed loads leave constructor count unchanged");
    Task gone=task;gone.target.reset();
    auto expired=std::make_shared<ActionBuild>(oldWorkers[0],gone);
    auto completed=ActionBuild::fromRuntime(expired->saveRuntime(),index,2000);
    check(completed->update(2500)==IAction::UpdateResult::Completed,"missing former target completes safely");
    std::cout << "build_action_save_checks=" << checks << " errors=0\n";
    return 0;
} catch (const std::exception &error) {
    std::cerr << error.what() << '\n';
    return 1;
}
