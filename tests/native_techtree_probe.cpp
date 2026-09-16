#include "resource/AssetManager.h"
#include "resource/Resource.h"
#include <genie/resource/SlpFile.h>
#include <filesystem>
#include "global/Config.h"
#include "resource/DataManager.h"
#include <fstream>
#include <iostream>
#include <stdexcept>
int main(int argc,char **argv) try {
    if(argc!=3)throw std::runtime_error("Expected input root and report path");
    Config::Inst().testMode=true;Config::Inst().setValue(Config::GamePath,argv[1]);
    auto &data=DataManager::Inst();if(!data.initialize())throw std::runtime_error("DAT load failed");
    std::ofstream out(argv[2]);if(!out)throw std::runtime_error("Report open failed");
    const auto &tree=data.techTree();
    auto list=[&](const char *name,const auto &values){out<<" "<<name<<":";for(auto v:values)out<<int(v)<<",";};
    auto common=[&](const auto &c){out<<" common:";for(int i=0;i<c.SlotsUsed;++i)out<<c.Mode.at(i)<<"/"<<c.UnitResearch.at(i)<<",";};
    for(const auto &n:tree.TechTreeAges){out<<"age "<<n.ID;list("buildings",n.Buildings);list("units",n.Units);list("techs",n.Techs);common(n.Common);out<<"\n";}
    for(const auto &n:tree.BuildingConnections){out<<"building "<<n.ID<<" enable:"<<n.EnablingResearch<<" location:"<<int(n.LocationInAge);list("buildings",n.Buildings);list("units",n.Units);list("techs",n.Techs);common(n.Common);out<<"\n";}
    for(const auto &n:tree.UnitConnections){out<<"unit "<<n.ID<<" building:"<<n.UpperBuilding<<" enable:"<<n.EnablingResearch<<" upgrade:"<<n.RequiredResearch<<" line:"<<n.VerticalLine<<" location:"<<n.LocationInAge;list("units",n.Units);common(n.Common);out<<"\n";}
    for(const auto &n:tree.ResearchConnections){out<<"research "<<n.ID<<" building:"<<n.UpperBuilding<<" line:"<<n.VerticalLine<<" location:"<<n.LocationInAge;list("buildings",n.Buildings);list("units",n.Units);list("techs",n.Techs);common(n.Common);out<<"\n";}
    for(const auto &c:data.civilizations()) {
        out<<"civ "<<c.Name<<" techTreeEffect:"<<c.TechTreeID<<" teamBonus:"<<c.TeamBonusID<<"\n";
        if(c.TechTreeID>=0)for(const auto &e:data.getEffect(c.TechTreeID).EffectCommands)
            out<<"effect "<<c.Name<<" type:"<<int(e.Type)<<" unit:"<<e.TargetUnit<<" class:"<<e.UnitClassID<<" attr:"<<e.AttributeID<<" amount:"<<e.Amount<<"\n";
    }
    for(int id:{12,222,235,265,127,140,63}){const auto &t=data.getTech(id);out<<"detail "<<id<<" name:"<<t.Name<<" help:"<<t.LanguageDLLHelp<<" tree:"<<t.LanguageDLLTechTree<<" location:"<<t.ResearchLocation<<" count:"<<t.RequiredTechCount;list("requires",t.RequiredTechs);out<<"\n";}
    for(const auto &u:data.civilization(1).Units)if(u.ID>=0 && u.Type==genie::Unit::BuildingType && u.Building.TechID==127)out<<"marker127 building:"<<u.ID<<" enabled:"<<int(u.Enabled)<<" name:"<<u.Name<<"\n";
    for(int id:{74,75,109}){const auto &u=data.civilization(1).Units.at(id);out<<"unithelp "<<id<<" help:"<<u.LanguageDLLHelp<<"\n";}
    const auto &units=data.civilization(1).Units;
    for(const auto &u:units)if(u.ID>=0 && u.LanguageDLLName==units.at(109).LanguageDLLName){out<<"tcvariant "<<u.ID<<" name:"<<u.Name<<" enabled:"<<int(u.Enabled)<<" stack:"<<u.Building.StackUnitID<<" train:"<<u.Creatable.TrainLocationID<<" button:"<<int(u.Creatable.ButtonID)<<"\n";for(auto c:u.Creatable.ResourceCosts)out<<"cost "<<u.ID<<" resource:"<<c.Type<<" amount:"<<c.Amount<<" paid:"<<c.Paid<<"\n";}
    for(std::size_t effect=0;effect<data.effectCount();++effect)for(const auto &c:data.getEffect(effect).EffectCommands)
        if((c.Type==genie::EffectCommand::UpgradeUnit || c.Type==genie::EffectCommand::EnableUnit) && c.TargetUnit>=0 && std::size_t(c.TargetUnit)<units.size() && units[c.TargetUnit].LanguageDLLName==units.at(109).LanguageDLLName)
            out<<"tceffect "<<effect<<" type:"<<int(c.Type)<<" target:"<<c.TargetUnit<<" modeOrTo:"<<c.UnitClassID<<" amount:"<<c.Amount<<"\n";
    for(std::size_t id=0;id<data.allTechs().size();++id){const auto &t=data.getTech(id);if(t.Civ>=0)out<<"ownedtech "<<id<<" civ:"<<t.Civ<<" name:"<<t.Name<<" effect:"<<t.EffectID<<"\n";}
    AssetManager::create(data.isHd());
    if(!AssetManager::Inst()->initialize(data.gameVersion()))throw std::runtime_error("Assets failed");
    for(const char *name:{"techages.slp","techback.slp","technodex.slp","tech_tile.slp"}){
        auto slp=AssetManager::Inst()->getSlp(name);if(!slp)continue;
        for(unsigned i=0;i<slp->getFrameCount();++i){
            auto image=Resource::convertFrameToImage(slp->getFrame(i));
            out<<"asset "<<name<<" frame:"<<i<<" width:"<<image.getSize().x<<" height:"<<image.getSize().y<<"\n";
            image.saveToFile((std::filesystem::path(argv[2]).parent_path()/(std::string(name)+"-"+std::to_string(i)+".png")).string());
        }
    }
    std::cout<<"ages="<<tree.TechTreeAges.size()<<" buildings="<<tree.BuildingConnections.size()<<" units="<<tree.UnitConnections.size()<<" research="<<tree.ResearchConnections.size()<<"\n";
    return 0;
} catch(const std::exception &e){std::cerr<<e.what()<<"\n";return 1;}
