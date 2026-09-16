#include "ui/TechnologyTreePanel.h"
#include "ui/TechnologyTreeDescription.h"
#include "ui/Dialog.h"
#include "resource/LanguageManager.h"
#include "mechanics/GameState.h"
#include "global/Config.h"
#include "resource/DataManager.h"
#include "resource/AssetManager.h"
#include "render/SfmlRenderTarget.h"
#include <SFML/Window/Event.hpp>
#include <iostream>
#include <stdexcept>
int main(int argc,char **argv) try {
 if(argc!=2)throw std::runtime_error("Expected input root");
 Config::Inst().testMode=true;Config::Inst().setValue(Config::GamePath,argv[1]);Config::Inst().setValue(Config::GameSample,"combat");
 auto &data=DataManager::Inst();if(!data.initialize())throw std::runtime_error("DAT failed");
 AssetManager::create(data.isHd());if(!AssetManager::Inst()->initialize(data.gameVersion()))throw std::runtime_error("Assets failed");
 auto renderer=std::make_shared<SfmlRenderTarget>(Size(800,600));auto state=std::make_shared<GameState>(renderer);if(!state->init())throw std::runtime_error("Fixture failed");
 Config::Inst().setValue(Config::Language,"en");if(!LanguageManager::Inst()->initialize())throw std::runtime_error("Language failed");
 TechnologyTreePanel panel(nullptr,state);int checks=0;auto check=[&](bool ok,const char *name){++checks;if(!ok)throw std::runtime_error(name);};
 using K=TechnologyTreeModel::Kind;
 auto infantry=agepad::technologyTreeDescription(*state->humanPlayer(),{K::Unit,75});
 check(infantry.find("Stronger than Militia")!=std::string::npos,"original infantry help resolves encoded ID");
 check(infantry.find("60 food")!=std::string::npos && infantry.find("20 gold")!=std::string::npos,"unit cost placeholders use DAT costs");
 check(infantry.find("\\n")==std::string::npos && infantry.find("\nStronger")!=std::string::npos,"escaped original line breaks become actual paragraphs");
 check(infantry.find("population space")!=std::string::npos && infantry.find("resource 4")==std::string::npos,"population requirement is named");
 check(infantry.find("<cost>")==std::string::npos && infantry.find("<b>")==std::string::npos && infantry.find("<hp>")==std::string::npos,"help markup resolves before presentation");
 auto crop=agepad::technologyTreeDescription(*state->humanPlayer(),{K::Research,12});
 check(crop.find("+175 food")!=std::string::npos && crop.find("250 food")!=std::string::npos && crop.find("250 wood")!=std::string::npos,"original research help and actual costs");
 check(crop.find("Research time:")!=std::string::npos,"research duration included");
 auto town=agepad::technologyTreeDescription(*state->humanPlayer(),{K::Building,109});
 check(town.find("100 stone")!=std::string::npos && town.find("275 wood")!=std::string::npos,"Town Center help uses construction record cost rather than visible stack cost");
 check(town.find("Garrison: 15")!=std::string::npos && town.find("Base attack: 5")!=std::string::npos,"Town Center combat and garrison values come from its displayed stack");
 check(town.find("Town Center")!=std::string::npos && town.find("<garrison>")==std::string::npos,"building help resolves");
 Dialog info(nullptr);info.showInfo("Details",infantry);info.layout(Size(800,600));
 sf::Event e{};e.type=sf::Event::MouseButtonPressed;e.mouseButton={sf::Mouse::Left,600,520};info.handleEvent(e);e.type=sf::Event::MouseButtonReleased;check(info.handleEvent(e)==Dialog::Cancel,"information Back signals return to parent");
 e={};e.type=sf::Event::KeyPressed;e.key.code=sf::Keyboard::Left;panel.handleEvent(e);check(panel.scrollOffset()==0,"left edge clamps");
 e.key.code=sf::Keyboard::End;panel.handleEvent(e);const float end=panel.scrollOffset();check(end>1000,"end reaches remaining tree");
 e.key.code=sf::Keyboard::Right;panel.handleEvent(e);check(panel.scrollOffset()==end,"right edge clamps");
 e.key.code=sf::Keyboard::Home;panel.handleEvent(e);check(panel.scrollOffset()==0,"home returns to first branches");
 e.type=sf::Event::MouseButtonPressed;e.mouseButton={sf::Mouse::Left,400,200};panel.handleEvent(e);
 e.type=sf::Event::MouseMoved;e.mouseMove={200,200};panel.handleEvent(e);check(panel.scrollOffset()>200,"touch drag pans tree");
 e.type=sf::Event::MouseButtonReleased;e.mouseButton={sf::Mouse::Left,200,200};panel.handleEvent(e);check(panel.selectedIndex()==-1,"drag does not accidentally select");
 const float before=panel.scrollOffset();e.type=sf::Event::MouseButtonPressed;e.mouseButton={sf::Mouse::Left,400,200};panel.handleEvent(e);panel.cancelInteraction();e.type=sf::Event::MouseMoved;e.mouseMove={100,200};panel.handleEvent(e);check(panel.scrollOffset()==before,"focus cancellation releases drag");
 e.type=sf::Event::MouseButtonPressed;e.mouseButton={sf::Mouse::Left,720,575};panel.handleEvent(e);e.type=sf::Event::MouseButtonReleased;e.mouseButton.x=300;check(!panel.handleEvent(e),"close drag outside cancels");
 e.type=sf::Event::MouseButtonPressed;e.mouseButton.x=720;panel.handleEvent(e);e.type=sf::Event::MouseButtonReleased;check(panel.handleEvent(e),"close matched click exits");
 e.type=sf::Event::KeyPressed;e.key.code=sf::Keyboard::Escape;check(panel.handleEvent(e),"escape exits tree");
 std::cout<<"techtree_panel_checks="<<checks<<" errors=0\n";
 return 0;
} catch(const std::exception &e){std::cerr<<e.what()<<'\n';return 1;}
