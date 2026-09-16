#include "ai/ScriptLoader.h"
#include "ai/AiScript.h"
#include "ai/AiPlayer.h"
#include "mechanics/Map.h"
#include "resource/DataManager.h"
#include "resource/AssetManager.h"
#include "global/Config.h"
#include <fstream>
#include <iostream>
#include <stdexcept>
int main(int argc,char **argv) try {
    if(argc==2) {
        if(std::string(argv[1])=="timer-suite") {
            ai::AiScript script(nullptr);int checks=0;
            auto check=[&](bool ok){++checks;if(!ok)throw std::runtime_error("Timer check "+std::to_string(checks));};
            script.addTimer(7,100);script.addTimer(8,200);
            script.update(50);check(!script.hasTimerExpired(7) && !script.hasTimerExpired(8));
            script.update(100);check(script.hasTimerExpired(7) && !script.hasTimerExpired(8));
            script.update(250);check(script.hasTimerExpired(8));
            script.addTimer(7,300);check(!script.hasTimerExpired(7));
            script.disableTimer(7);script.update(400);check(!script.hasTimerExpired(7));
            std::cout<<"ai_timer_checks="<<checks<<" errors=0"<<std::endl;return 0;
        }
        ai::AiScript script(nullptr);script.addTimer(7,100);
        script.update(std::string(argv[1])=="timer-future"?50:150);
        std::cout<<"timer_expired="<<script.hasTimerExpired(7)<<std::endl;
        return 0;
    }
    if(argc!=3)throw std::runtime_error("Expected input root and PER path, or timer-future/timer-past");
    Config::Inst().testMode=true;Config::Inst().setValue(Config::GamePath,argv[1]);
    if(!DataManager::Inst().initialize())throw std::runtime_error("DAT failed");
    AssetManager::create(DataManager::Inst().isHd());
    if(!AssetManager::Inst()->initialize(DataManager::Inst().gameVersion()))throw std::runtime_error("Assets failed");
    auto map=std::make_shared<Map>();map->setupBasic();map->updateMapData();
    auto player=std::make_shared<AiPlayer>(1,1,map,ResourceMap{});
    std::ifstream in(argv[2]);if(!in)throw std::runtime_error("Script open failed");
    ai::ScriptLoader loader(player.get());
    const int result=loader.parse(in,std::cout);
    std::cout<<"parse_result="<<result<<std::endl;
    return result;
} catch(const std::exception &e){std::cerr<<e.what()<<std::endl;return 2;}
