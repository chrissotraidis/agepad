#include <algorithm>
#include "ui/TechnologyTreeModel.h"
#include "ui/TechnologyTreeLayout.h"
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
    TechnologyTreeModel british(*briton),persians(*persian);
    using K=TechnologyTreeModel::Kind;
    auto node=[&](const auto &model,K kind,int id)->const TechnologyTreeModel::Node&{auto p=model.find(kind,id);if(!p)throw std::runtime_error("Missing expected tree node");return *p;};
    check(british.nodes().size()==218,"Complete imported tree inventory");
    auto saracen=std::make_shared<Player>(3,9,map,ResourceMap{});
    TechnologyTreeModel saracens(*saracen);
    check(node(saracens,K::Unit,282).visible && node(saracens,K::Unit,556).visible,"Saracen Castle retains Mameluke and elite upgrade");
    check(!node(saracens,K::Unit,8).visible && !node(saracens,K::Unit,530).visible,"Saracen Castle omits foreign Longbow line");
    check(node(british,K::Unit,8).visible && !node(british,K::Unit,282).visible,"British Castle retains its own unique line");
    check(node(saracens,K::Unit,440).visible && node(saracens,K::Unit,331).visible,"Shared Petard and Trebuchet remain visible");
    check(node(saracens,K::Unit,569).visible && node(saracens,K::Unit,569).disabled,"Unavailable shared Paladin remains crossed out");
    check(node(saracens,K::Unit,250).visible && node(saracens,K::Unit,250).disabled,"Foreign dock Longboat remains listed as in supplied chart");

    const TechnologyTreeLayout layout(british);
    const auto &positions=layout.positions();
    auto pos=[&](K kind,int id){return positions.at({kind,id});};
    std::size_t visible=0;for(const auto &n:british.nodes())if(n.visible && n.key.first!=K::Age)++visible;
    check(positions.size()==visible,"Every visible icon has a layout position");
    bool overlap=false;for(auto a=positions.begin();a!=positions.end();++a)for(auto b=std::next(a);b!=positions.end();++b)
        if(std::abs(a->second.x-b->second.x)<64 && std::abs(a->second.y-b->second.y)<64)overlap=true;
    check(!overlap,"No icons overlap in any age");
    check(pos(K::Unit,74).x==pos(K::Unit,75).x && pos(K::Unit,75).x==pos(K::Unit,77).x && pos(K::Unit,77).x==pos(K::Unit,567).x,"Militia through Champion remain in one upgrade lane");
    check(pos(K::Unit,38).x==pos(K::Unit,283).x && pos(K::Unit,283).x==pos(K::Unit,569).x,"Knight through Paladin remain aligned");
    check(pos(K::Research,14).x==pos(K::Research,13).x && pos(K::Research,13).x==pos(K::Research,12).x,"Farm technologies remain aligned");
    check(pos(K::Building,12).x<pos(K::Unit,74).x && pos(K::Unit,74).x<pos(K::Building,45).x,"Barracks branch stays together before Dock");
    check(pos(K::Building,109).x==0,"Town Center begins the tree");

    check(british.find(K::Building,12)!=british.find(K::Research,12),"Building and research IDs are separate namespaces");
    check(node(british,K::Unit,74).age==1 && node(british,K::Unit,75).age==2 && node(british,K::Unit,567).age==4,"Militia ages match authored tree");
    check(node(british,K::Unit,75).upgradeResearch==222 && node(british,K::Unit,75).building==12,"Man-at-Arms upgrade and producer metadata");
    check(node(british,K::Research,12).disabled && !node(persians,K::Research,12).disabled,"Permanent Crop Rotation availability");
    check(node(british,K::Unit,329).disabled && !node(persians,K::Unit,329).disabled,"Camel civilization unlock exclusions");
    check(node(british,K::Unit,569).disabled && !node(persians,K::Unit,569).disabled,"Paladin civilization upgrade exclusions");
    check(!node(british,K::Unit,75).disabled && !node(british,K::Unit,75).unlocked,"Future unit is not permanently excluded");
    check(!node(british,K::Research,104).visible,"Hidden age marker stays hidden");
    check(!british.find(K::Unit,-1),"Missing lookup is safe");
    briton->applyResearch(101);briton->applyResearch(222);
    TechnologyTreeModel upgraded(*briton);
    check(node(upgraded,K::Unit,75).unlocked,"Tree reflects live unit upgrade");
    check(node(upgraded,K::Research,101).researched,"Tree reflects completed age research");
    auto linked=[&](K a,int from,K b,int to){return std::find(british.edges().begin(),british.edges().end(),TechnologyTreeModel::Edge{{a,from},{b,to}})!=british.edges().end();};
    check(linked(K::Unit,21,K::Unit,528) && linked(K::Unit,21,K::Unit,532),"War Galley research links resolve to its displayed unit");
    check(linked(K::Unit,558,K::Research,7),"Unique unit upgrade link resolves to Mahouts");
    check(british.unresolvedEdges().empty(),"Every authored link resolves in this imported tree");
    briton->civilization.enableUnit(329);
    TechnologyTreeModel scenarioOverride(*briton);
    check(node(scenarioOverride,K::Unit,329).disabled && node(scenarioOverride,K::Unit,329).unlocked,"Civilization exclusion and scenario/current enablement remain separate");
    for(std::size_t civ=1;civ<data.civilizations().size();++civ){
        auto player=std::make_shared<Player>(int(civ),int(civ),map,ResourceMap{});
        TechnologyTreeModel model(*player);
        int unknown=0,disabled=0;
        for(const auto &n:model.nodes()){unknown+=n.visible && !n.availabilityKnown;disabled+=n.disabled;}
        std::cout<<"civilization="<<civ<<" nodes="<<model.nodes().size()<<" disabled="<<disabled<<" visible_unknown="<<unknown<<"\n";
        check(model.nodes().size()==218 && model.unresolvedEdges().empty() && unknown==0,"Civilization graph completeness");
    }
    check(node(british,K::Building,79).availabilityKnown && !node(british,K::Building,79).disabled && node(british,K::Research,140).availabilityKnown,"Watch Tower normal prerequisite avoids its construction-marker cycle");
    std::cout<<"nodes="<<british.nodes().size()<<" edges="<<british.edges().size()<<" unresolved="<<british.unresolvedEdges().size()<<"\n";
    for(const auto &e:british.unresolvedEdges())std::cout<<"unresolved "<<int(e.first.first)<<"/"<<e.first.second<<" -> "<<int(e.second.first)<<"/"<<e.second.second<<"\n";
    std::cout<<"techtree_model_checks="<<checks<<" errors=0\n";
    return 0;
} catch(const std::exception &e){std::cerr<<e.what()<<"\n";return 1;}
