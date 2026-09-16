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
#include "render/UnitsRenderer.h"
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
    auto manager=std::make_shared<UnitManager>();manager->setMap(map);
    if(!manager->init())throw std::runtime_error("manager init");
    auto human=std::make_shared<Player>(1,1,map,ResourceMap{});
    auto enemy=std::make_shared<Player>(2,2,map,ResourceMap{});
    manager->setPlayers({human,enemy});manager->setHumanPlayer(human);
    auto add=[&](int id,auto owner,int x){auto u=UnitFactory::createUnit(id,owner,*manager);manager->add(u,MapPos(x,480));return u;};
    check(sizeof(ActionMove)<4096,"pending action does not embed full-map path caches");
    auto actor=add(74,human,480);
    actor->stance=Unit::Stance::NoAttack;
    auto camera=std::make_shared<Camera>();camera->setViewportSize(Size(800,600));camera->setTargetPosition(MapPos(480,480));
    auto click=[&](MapPos pos,bool append){manager->onRightClick(camera->absoluteScreenPos(pos),camera,append);};
    manager->setSelectedUnits({actor});
    auto resources=human->saveEconomyDiplomacy();
    click(MapPos(600,480),false);
    auto first=actor->actions.currentAction();
    check(first && first->type==IAction::Type::Move,"ordinary move starts");
    click(MapPos(600,600),true);
    check(actor->actions.currentAction()==first && actor->actions.m_actionQueue.size()==1,"append preserves current move");
    auto second=actor->actions.m_actionQueue.front();
    bool transitioned=false,done=false;
    Time now=100;
    for(;now<20000;now+=100) {
        actor->update(now);
        if(actor->actions.currentAction()==second && !transitioned) {
            check(actor->position().distance(MapPos(600,480))<2,"first waypoint reached before second starts");
            transitioned=true;
        }
        if(!actor->actions.currentAction()) {done=true;break;}
    }
    check(transitioned && done && actor->position().distance(MapPos(600,600))<2,"both ordered waypoints complete");
    click(MapPos(720,600),true);
    check(actor->actions.currentAction() && actor->actions.m_actionQueue.empty(),"append on idle starts immediately");
    click(MapPos(720,720),true);
    auto old=actor->actions.currentAction();
    click(MapPos(600,720),false);
    check(actor->actions.currentAction()!=old && actor->actions.m_actionQueue.empty(),"ordinary command replaces current and pending orders");
    check(human->saveEconomyDiplomacy()==resources,"movement orders do not spend resources");
    actor->actions.clearActionQueue();actor->setPosition(MapPos(480,480),true);
    auto target=add(74,enemy,605);target->stance=Unit::Stance::NoAttack;
    click(MapPos(600,480),false);
    first=actor->actions.currentAction();
    auto renderer=std::make_shared<SfmlRenderTarget>(Size(800,600));
    renderer->camera()->setViewportSize(Size(800,600));renderer->camera()->setTargetPosition(MapPos(480,480));
    UnitsRenderer unitsRenderer;unitsRenderer.setUnitManager(manager);unitsRenderer.setVisibilityMap(human->visibility);
    unitsRenderer.begin(renderer);unitsRenderer.render(renderer,{actor,target});unitsRenderer.display(renderer);
    const auto rect=target->screenRect()+camera->absoluteScreenPos(target->position());
    ScreenPos targetClick;bool found=false;
    for(int y=rect.y;y<rect.y+rect.height && !found;++y)
        for(int x=rect.x;x<rect.x+rect.width && !found;++x)
            if(manager->clickedUnitAt(ScreenPos(x,y),camera)==target) {targetClick=ScreenPos(x,y);found=true;}
    check(found,"rendered target hit pixel found");
    manager->onRightClick(targetClick,camera,true);
    check(actor->actions.currentAction()==first && actor->actions.m_actionQueue.size()==1 &&
          actor->actions.m_actionQueue.front()->type==IAction::Type::Attack,"context attack appends behind movement");
    const float health=target->healthLeft();
    bool hit=false;now+=100;
    for(Time limit=now+20000;now<limit;now+=100) {
        actor->update(now);
        if(target->healthLeft()<health) {hit=true;break;}
    }
    check(hit,"queued context attack eventually damages target");
    click(MapPos(480,480),true);
    check(!actor->actions.m_actionQueue.empty(),"command can queue behind ongoing attack");
    actor->actions.clearActionQueue();
    check(!actor->actions.currentAction() && actor->actions.m_actionQueue.empty(),"stop clears current and pending orders");
    manager->setSelectedUnits({target});click(MapPos(720,720),true);
    check(!target->actions.currentAction() && target->actions.m_actionQueue.empty(),"cannot queue enemy orders");
    std::cout << "queued_order_checks=" << checks << " errors=0\n";
    return 0;
} catch(const std::exception &error){std::cerr << error.what() << '\n';return 1;}
