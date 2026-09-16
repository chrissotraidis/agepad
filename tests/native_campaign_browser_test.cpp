#include "ui/CampaignBrowser.h"
#include "global/Config.h"
#include "resource/DataManager.h"
#include "resource/AssetManager.h"
#include "resource/LanguageManager.h"
#include "core/SaveFingerprint.h"
#include <SFML/Graphics/RenderWindow.hpp>
#include <SFML/Graphics/Sprite.hpp>
#include <SFML/Graphics/Image.hpp>
#include <SFML/Window/Event.hpp>
#include <sstream>
#include <iostream>

class BrowserProbe : public CampaignBrowser {
public:
    using CampaignBrowser::CampaignBrowser;
    bool capture(const std::string &path) {
        m_renderWindow->clear();m_renderWindow->draw(sf::Sprite(m_background));render();m_renderWindow->display();
        sf::Texture image;image.create(m_renderWindow->getSize().x,m_renderWindow->getSize().y);
        image.update(*m_renderWindow);return image.copyToImage().saveToFile(path);
    }
};
static std::string identity(const genie::ScnFilePtr &scenario) {
    if(!scenario)return {};
    std::ostringstream stream(std::ios::binary);scenario->writeObject(stream);const auto bytes=stream.str();
    return agepad::SaveFingerprint::bytes(agepad::SaveBytes(bytes.begin(),bytes.end()));
}
int main(int argc,char **argv) try {
    if(argc!=3)throw std::runtime_error("Expected input and evidence roots");
    Config::Inst().testMode=true;Config::Inst().setValue(Config::GamePath,argv[1]);
    auto &data=DataManager::Inst();if(!data.initialize())throw std::runtime_error("DAT load failed");
    AssetManager::create(data.isHd());
    if(!AssetManager::Inst()->initialize(data.gameVersion()) || !LanguageManager::Inst()->initialize())throw std::runtime_error("Asset initialization failed");
    const auto catalog=agepad::campaignCatalog(argv[1],true);
    agepad::CampaignProgress progress(std::filesystem::path(argv[2])/"fixture-progress.agepad",{std::string(64,'a'),"browser-test",1});
    BrowserProbe browser(catalog,progress);if(!browser.init())throw std::runtime_error("Browser initialization failed");
    auto event=[&](sf::Event::EventType type,int x,int y) {sf::Event e{};e.type=type;e.mouseButton={sf::Mouse::Left,x,y};return browser.handleMouseEvent(e);};
    auto click=[&](int x,int y){event(sf::Event::MouseButtonPressed,x,y);return event(sf::Event::MouseButtonReleased,x,y);};
    event(sf::Event::MouseButtonPressed,850,140);event(sf::Event::MouseButtonReleased,20,20);
    if(browser.scenario())throw std::runtime_error("Cancelled drag launched a mission");
    unsigned checked=0;
    for(std::size_t campaign=0;campaign<catalog.size();++campaign) {
        click(campaign<5?300:600,35);
        const int slot=campaign<5?campaign:campaign-5;click(240+(slot%2)*290,90+(slot/2)*132);
        if(campaign==0 || campaign==8)if(!browser.capture((std::filesystem::path(argv[2])/(campaign==0?"kings.png":"conquerors.png")).string()))throw std::runtime_error("Capture failed");
        genie::CpxFile archive;archive.setFileName(catalog[campaign].archive.string());archive.load();
        for(unsigned mission=0;mission<archive.getFilecount();++mission) {
            const bool launched=click(850,140+mission*62);
            const auto actual=identity(browser.scenario()),expected=identity(archive.getScnFile(mission));
            if(!launched || actual!=expected) {
                std::cerr<<"campaign="<<campaign<<" mission="<<mission<<" launched="<<launched<<" actual="<<actual<<" expected="<<expected<<"\n";
                throw std::runtime_error("Campaign click selected a different original scenario");
            }
            ++checked;
        }
    }
    std::cout<<"campaign_browser_mission_selections="<<checked<<" cancelled_drag_checks=1 errors=0\n";return 0;
} catch(const std::exception &error){std::cerr<<error.what()<<"\n";return 1;}
