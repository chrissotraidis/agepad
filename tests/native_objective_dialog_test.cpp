#include "global/Config.h"
#include "resource/DataManager.h"
#include "resource/AssetManager.h"
#include "resource/Resource.h"
#include "ui/Dialog.h"
#include <genie/resource/UIFile.h>
#include <genie/resource/SlpFile.h>
#include <SFML/Window/Event.hpp>
#include <filesystem>
#include <iostream>
int main(int argc,char **argv) try {
    if(argc!=3)throw std::runtime_error("Expected input and output roots");
    Config::Inst().testMode=true;Config::Inst().setValue(Config::GamePath,argv[1]);
    auto &data=DataManager::Inst();if(!data.initialize())throw std::runtime_error("DAT load failed");
    AssetManager::create(data.isHd());if(!AssetManager::Inst()->initialize(data.gameVersion()))throw std::runtime_error("Asset load failed");
    for(const char *name:{"dlg_obj.sin","dlg_objx.sin"}) {
        const auto ui=AssetManager::Inst()->getUIFile(name);if(!ui)throw std::runtime_error("Missing objective UI");
        const auto slp=AssetManager::Inst()->getSlp(ui->backgroundSmall.fileId);if(!slp)throw std::runtime_error("Missing objective art");
        const auto image=Resource::convertFrameToImage(slp->getFrame(0));
        if(!image.saveToFile((std::filesystem::path(argv[2])/(std::string(name)+".png")).string()))throw std::runtime_error("Export failed");
        std::cout << "buttons=" << ui->buttonFile.id << " name=" << ui->buttonFile.filename << std::endl;
        std::cout << name << " asset=" << ui->backgroundSmall.fileId << " size=" << image.getSize().x << "x" << image.getSize().y << '\n';
    }
    const auto tabs=AssetManager::Inst()->getSlp(50606);
    for(unsigned i=0;i<tabs->getFrameCount();++i)Resource::convertFrameToImage(tabs->getFrame(i)).saveToFile((std::filesystem::path(argv[2])/("tab-"+std::to_string(i)+".png")).string());
    const auto buttons=AssetManager::Inst()->getSlp("btngame2x.shp");
    for(unsigned i=0;i<buttons->getFrameCount();i+=2)
        Resource::convertFrameToImage(buttons->getFrame(i)).saveToFile((std::filesystem::path(argv[2])/("button-"+std::to_string(i)+".png")).string());
    Dialog dialog(nullptr);dialog.layout(Size(800,600));
    sf::Event e{};e.type=sf::Event::MouseButtonPressed;e.mouseButton={sf::Mouse::Left,400,295};dialog.handleEvent(e);
    e.type=sf::Event::MouseButtonReleased;
    if(dialog.handleEvent(e)!=Dialog::Objectives)throw std::runtime_error("Objectives menu activation failed");
    dialog.showDocument("Original instructions");
    if(!dialog.back() || dialog.back())throw std::runtime_error("Document back navigation failed");
    std::cout << "objective_dialog_checks=2 errors=0\n";
    return 0;
} catch(const std::exception &error) {std::cerr<<error.what()<<'\n';return 1;}
