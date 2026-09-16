#include "global/Config.h"
#include "resource/DataManager.h"
#include "resource/AssetManager.h"
#include "resource/LanguageManager.h"
#include "resource/Resource.h"
#include <genie/resource/SlpFile.h>
#include <genie/script/ScnFile.h>
#include <SFML/Graphics/Image.hpp>
#include <iostream>
#include "ui/CampaignScreen.h"
#include "core/CampaignProgress.h"
#include "core/SaveFingerprint.h"
#include <SFML/Graphics/RenderWindow.hpp>
#include <SFML/Graphics/Sprite.hpp>
#include <SFML/Graphics/Texture.hpp>
#include <SFML/Window/Event.hpp>
#include <sstream>
#include <unistd.h>
class CampaignCapture : public CampaignScreen {
public: using CampaignScreen::CampaignScreen;
 void capture(const std::string&path) {m_renderWindow->clear();m_renderWindow->draw(sf::Sprite(m_background));render();sf::Texture image;image.create(m_backgroundSize.width,m_backgroundSize.height);image.update(*m_renderWindow);image.copyToImage().saveToFile(path);m_renderWindow->setVisible(false);}
 float sx()const{return m_backgroundSize.width/1366.f;} float sy()const{return m_backgroundSize.height/768.f;}
};
int main(int argc,char**argv) try {
 if(argc!=3)return 2;
 Config::Inst().testMode=true;Config::Inst().setValue(Config::GamePath,argv[1]);
 auto &data=DataManager::Inst();if(!data.initialize())return 3;
 AssetManager::create(data.isHd());if(!AssetManager::Inst()->initialize(data.gameVersion()))return 4;
 LanguageManager::Inst()->initialize();
 auto slp=AssetManager::Inst()->getSlp("cam8_32.slp",AssetManager::ResourceType::Interface);
 if(!slp || !Resource::convertFrameToImage(slp->getFrame(0)).saveToFile(argv[2]))return 5;
 genie::CpxFile campaign;campaign.load(AssetManager::Inst()->campaignsPath()+"/cam8.cpn");
 std::cout<<"campaign="<<campaign.name<<" count="<<campaign.getFilecount()<<'\n';
 for(auto &name:campaign.getFilenames())std::cout<<name<<'\n';
 int checks=0;auto check=[&](bool ok,const char *why){++checks;if(!ok)throw std::runtime_error(why);};
 check(campaign.getFilecount()==7,"seven authentic Wallace missions");
 std::vector<std::string> labels,ids;
 for(std::size_t i=0;i<7;++i){auto scenario=campaign.getScnFile(i);check(bool(scenario),"mission decodes");std::ostringstream stream(std::ios::binary);scenario->writeObject(stream);const auto bytes=stream.str();ids.push_back(agepad::SaveFingerprint::bytes(agepad::SaveBytes(bytes.begin(),bytes.end())));labels.push_back(LanguageManager::getString(35139+i));check(!labels.back().empty(),"localized mission name");}
 char temporary[]="/tmp/agepad-campaign-test-XXXXXX";const auto directory=mkdtemp(temporary);if(!directory)throw std::runtime_error("temporary directory");
 const std::filesystem::path root(directory);const agepad::SaveIdentity identity{"fixture-input","agepad-native-world-v1",1};
 {agepad::CampaignProgress saved(root/"progress.agepad",identity);saved.markCompleted(ids[0]);}
 agepad::CampaignProgress loaded(root/"progress.agepad",identity);std::vector<bool> completed;
 for(auto&id:ids)completed.push_back(loaded.completed(id));
 check(completed[0]&&!completed[1]&&!completed[6],"reopened completion maps to exact archive mission");
 CampaignCapture screen(labels,completed);check(screen.init(),"original campaign map initializes");
 screen.capture((std::filesystem::path(argv[2]).parent_path()/"campaign-screen.png").string());
 const ScreenPos points[]={{210,75},{340,195},{350,305},{460,395},{720,480},{650,570},{810,655}};
 for(int i=0;i<7;++i){sf::Event e{};e.type=sf::Event::MouseButtonPressed;e.mouseButton={sf::Mouse::Left,int(points[i].x*screen.sx()),int(points[i].y*screen.sy())};check(!screen.handleMouseEvent(e),"press alone does not launch");e.type=sf::Event::MouseButtonReleased;check(screen.handleMouseEvent(e)&&screen.selection()==i,"mission click selects matching archive index");check(!screen.handleMouseEvent(e),"duplicate release cannot relaunch");}
 sf::Event e{};e.type=sf::Event::MouseButtonPressed;e.mouseButton={sf::Mouse::Left,int(210*screen.sx()),int(75*screen.sy())};screen.handleMouseEvent(e);screen.cancelInteraction();e.type=sf::Event::MouseButtonReleased;check(!screen.handleMouseEvent(e),"focus cancellation clears armed mission");
 e.type=sf::Event::MouseButtonPressed;e.mouseButton.button=sf::Mouse::Right;screen.handleMouseEvent(e);e.type=sf::Event::MouseButtonReleased;check(!screen.handleMouseEvent(e),"secondary click does not launch a mission");
 e.type=sf::Event::MouseButtonPressed;e.mouseButton={sf::Mouse::Left,int(100*screen.sx()),int(710*screen.sy())};screen.handleMouseEvent(e);e.type=sf::Event::MouseButtonReleased;check(screen.handleMouseEvent(e)&&screen.selection()==-1,"Main Menu returns without mission launch");
 std::filesystem::remove_all(root);
 std::cout<<"campaign_checks="<<checks<<" errors=0\n";
 return 0;
}catch(const std::exception&e){std::cerr<<e.what()<<'\n';return 1;}
