#include "global/Config.h"
#include "ui/UnitInfoPanel.h"
#include "ui/ActionPanel.h"
#include "ui/Minimap.h"
#include "ui/Dialog.h"
#include "actions/ActionMove.h"
#include "resource/LanguageManager.h"
#include <SFML/Graphics/RenderTexture.hpp>
#include <SFML/Graphics/Image.hpp>
#include <filesystem>
#include "core/SaveArchive.h"
#include "render/GraphicRender.h"
#include "resource/Sprite.h"
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

class PanelTarget : public SfmlRenderTarget {
public: using SfmlRenderTarget::SfmlRenderTarget; Size getSize() const override {return Size(800,600);}
};
int main(int argc, char **argv) try {
    if (argc != 3) throw std::runtime_error("Expected verified snapshot path");
    Config::Inst().testMode = true;
    Config::Inst().setValue(Config::GamePath, argv[1]);
    auto &data = DataManager::Inst();
    if (!data.initialize()) throw std::runtime_error("DAT load failed");
    AssetManager::create(data.isHd());
    if (!AssetManager::Inst()->initialize(data.gameVersion())) throw std::runtime_error("Asset init failed");
    if(!LanguageManager::Inst()->initialize())throw std::runtime_error("language init failed");
    int checks=0;
    auto check=[&](bool ok,const char *name){++checks;if(!ok)throw std::runtime_error(name);};
    auto rejected=[](auto action){try{action();return false;}catch(const agepad::SaveError &){return true;}};
    auto map=std::make_shared<Map>();map->setupBasic();map->updateMapData();
    auto manager=std::make_shared<UnitManager>();manager->setMap(map);
    if(!manager->init())throw std::runtime_error("manager init");
    auto owner=std::make_shared<Player>(1,1,map,ResourceMap{});
    owner->name="Scots";
    sf::RenderTexture texture;if(!texture.create(800,700))throw std::runtime_error("capture texture failed");
    auto target=std::make_shared<PanelTarget>(texture);
    UnitInfoPanel panel(target);if(!panel.init())throw std::runtime_error("panel init failed");
    panel.setUnitManager(manager);
    std::filesystem::create_directories(argv[2]);
    for(int id:{74,4,123,109,82}) {
        auto unit=UnitFactory::createUnit(id,owner,*manager);
        if(id==123)for(auto resource:{genie::ResourceType::WoodStorage,genie::ResourceType::StoneStorage,genie::ResourceType::FoodStorage,genie::ResourceType::GoldStorage})unit->resources[resource]=10;
        manager->setSelectedUnits({unit});panel.update(0);
        const sf::Color background(225,205,160);texture.clear(background);panel.draw();texture.display();
        const auto image=texture.getTexture().copyToImage();
        const auto bounds=panel.rect();unsigned outside=0,painted=0;
        for(unsigned y=0;y<700;++y)for(unsigned x=0;x<800;++x)if(image.getPixel(x,y)!=background){
            ++painted;if(x<bounds.x || x>=bounds.x+bounds.width || y<bounds.y || y>=bounds.y+bounds.height)++outside;
        }
        const auto file=std::filesystem::path(argv[2])/(std::to_string(id)+".png");
        if(!image.saveToFile(file.string()))throw std::runtime_error("capture failed");
        std::cout<<"unit="<<id<<" painted="<<painted<<" outside_panel="<<outside<<"\n";
        check(painted>0 && outside==0,"all selected-unit content remains inside the panel");
    }
    auto town=Building::fromUnit(UnitFactory::createUnit(109,owner,*manager));
    owner->setAvailableResource(genie::ResourceType::FoodStorage,1000);
    owner->setAvailableResource(genie::ResourceType::PopulationHeadroom,100);
    auto guest=UnitFactory::createUnit(83,owner,*manager);
    town->garrisonedUnits.push_back(guest);guest->garrisonedIn=town;
    const auto &villager=owner->civilization.unitData(83);
    check(town->enqueueProduceUnit(&villager) && town->enqueueProduceUnit(&villager),"producing occupied town fixture");
    manager->setSelectedUnits({town});panel.update(0);texture.clear();panel.draw();texture.display();
    const auto queueBefore=town->saveProductionRuntime();
    const auto foodBefore=owner->resourcesAvailable(genie::ResourceType::FoodStorage);
    const auto panelBounds=panel.rect();
    sf::Event click{};click.type=sf::Event::MouseButtonPressed;click.mouseButton.button=sf::Mouse::Left;
    click.mouseButton.x=panelBounds.x+110;click.mouseButton.y=panelBounds.y+42;
    click.mouseButton.button=sf::Mouse::Right;
    check(!panel.handleEvent(click) && !guest->garrisonedIn.expired() && town->saveProductionRuntime()==queueBefore,
          "secondary click cannot ungarrison or alter production");
    click.mouseButton.button=sf::Mouse::Left;
    check(panel.handleEvent(click),"garrison icon click handled while producing");
    check(guest->garrisonedIn.expired() && town->garrisonedUnits.empty(),"garrison icon releases the selected guest");
    check(town->saveProductionRuntime()==queueBefore && owner->resourcesAvailable(genie::ResourceType::FoodStorage)==foodBefore,
          "garrison click neither cancels production nor refunds resources");
    panel.update(0);texture.clear();panel.draw();texture.display();
    click.mouseButton.x=panelBounds.x+24;click.mouseButton.y=panelBounds.y+42;
    const auto beforeCancel=town->productionQueueLength();
    click.mouseButton.button=sf::Mouse::Right;
    check(!panel.handleEvent(click) && town->productionQueueLength()==beforeCancel && owner->resourcesAvailable(genie::ResourceType::FoodStorage)==foodBefore,
          "secondary click cannot cancel or refund production");
    click.mouseButton.button=sf::Mouse::Left;
    check(panel.handleEvent(click),"production icon remains clickable");
    check(town->productionQueueLength()+1==beforeCancel && owner->resourcesAvailable(genie::ResourceType::FoodStorage)==foodBefore+50,
          "production click removes one villager and refunds its paid cost");
    check(!panel.handleEvent(click) && town->productionQueueLength()+1==beforeCancel,
          "stale icon cannot cancel another item before redraw");
    while(town->isProducing())town->abortProduction(0);
    owner->setAvailableResource(genie::ResourceType::FoodStorage,5000);
    owner->setAvailableResource(genie::ResourceType::WoodStorage,5000);
    for(int i=0;i<8;++i)check(town->enqueueProduceUnit(&villager),"long queue villager added");
    check(town->enqueueProduceResearch(&data.getTech(8)),"mixed research added to queue");
    check(town->productIsResearch(8) && !town->productIsResearch(0),"each queue item exposes its own icon kind");
    panel.update(0);texture.clear();panel.draw();texture.display();
    click.mouseButton.x=panelBounds.x+panelBounds.width-30;click.mouseButton.y=panelBounds.y+100;
    check(panel.handleEvent(click),"next page is reachable by touch-sized control");
    panel.update(0);texture.clear(sf::Color(225,205,160));panel.draw();texture.display();
    texture.getTexture().copyToImage().saveToFile((std::filesystem::path(argv[2])/"queue-page-2.png").string());
    click.mouseButton.x=panelBounds.x+4+2*44+20;click.mouseButton.y=panelBounds.y+42;
    check(panel.handleEvent(click),"last research icon can be clicked on second page");
    check(town->productionQueueLength()==8 && !town->productIsResearch(7),"paged cancellation uses original queue index");
    Minimap minimap(target);minimap.setMap(map);minimap.setUnitManager(manager);
    manager->setPlayers({owner});manager->setHumanPlayer(owner);
    auto mover=UnitFactory::createUnit(74,owner,*manager);manager->add(mover,MapPos(480,480));manager->setSelectedUnits({mover});
    const auto cameraBefore=target->camera()->targetPosition();
    const auto miniBounds=minimap.rect();
    click.mouseButton.button=sf::Mouse::Right;click.mouseButton.x=miniBounds.x+miniBounds.width/2;
    click.mouseButton.y=miniBounds.y+miniBounds.height/2;
    check(minimap.handleEvent(click) && !mover->actions.currentAction(),"minimap secondary press arms without issuing an order");
    click.type=sf::Event::MouseButtonReleased;
    check(minimap.handleEvent(click) && bool(std::dynamic_pointer_cast<ActionMove>(mover->actions.currentAction())),"minimap secondary release issues movement");
    check(target->camera()->targetPosition()==cameraBefore,"secondary minimap order preserves camera");
    auto firstOrder=mover->actions.currentAction();
    click.type=sf::Event::MouseButtonPressed;minimap.handleEvent(click,true);
    click.type=sf::Event::MouseButtonReleased;minimap.handleEvent(click,true);
    check(mover->actions.currentAction()==firstOrder && mover->actions.m_actionQueue.size()==1,"minimap append preserves active order and queues another");
    click.type=sf::Event::MouseButtonPressed;minimap.handleEvent(click);minimap.mouseExited();
    click.type=sf::Event::MouseButtonReleased;minimap.handleEvent(click);
    check(mover->actions.currentAction()==firstOrder,"cancelled minimap press cannot emit stale order");
    // A loaded world reuses player ID 1, but owns a different Player instance.
    ActionPanel commands(target);commands.init();commands.setUnitManager(manager);
    auto retiredPlayer=std::make_shared<Player>(1,1,map,ResourceMap{});
    commands.setHumanPlayer(retiredPlayer);manager->setSelectedUnits({town});commands.update(0);
    auto restoredMap=std::make_shared<Map>();restoredMap->setupBasic();restoredMap->updateMapData();
    auto restoredManager=std::make_shared<UnitManager>();restoredManager->setMap(restoredMap);
    check(restoredManager->init(),"restored command manager initializes");
    auto restoredOwner=std::make_shared<Player>(1,1,restoredMap,ResourceMap{});
    restoredOwner->setAvailableResource(genie::ResourceType::FoodStorage,1000);
    restoredOwner->setAvailableResource(genie::ResourceType::PopulationHeadroom,100);
    restoredManager->setPlayers({restoredOwner});restoredManager->setHumanPlayer(restoredOwner);
    auto restoredTown=Building::fromUnit(UnitFactory::createUnit(109,restoredOwner,*restoredManager));
    restoredManager->add(restoredTown,MapPos(960,960));restoredManager->setSelectedUnits({restoredTown});
    const auto oldQueue=town->productionQueueLength();
    // The previous world no longer owns its Player after the load commits.
    retiredPlayer.reset();
    commands.setUnitManager(restoredManager);commands.setHumanPlayer(restoredOwner);commands.update(0);
    const auto actionBounds=commands.rect();
    const auto trainIndex=std::max(0,int(restoredOwner->civilization.unitData(83).Creatable.ButtonID)-1);
    sf::Event train{};train.type=sf::Event::MouseButtonPressed;
    train.mouseButton={sf::Mouse::Left,int(actionBounds.x)+10+(trainIndex%5)*40,
        int(actionBounds.y)+10+(trainIndex/5)*40};
    commands.handleEvent(train);train.type=sf::Event::MouseButtonReleased;commands.handleEvent(train);
    check(restoredTown->productionQueueLength()==1 && restoredOwner->resourcesAvailable(genie::ResourceType::FoodStorage)==950,
        "same-ID world replacement trains through restored player and selected town");
    check(town->productionQueueLength()==oldQueue,"restored command panel cannot train in old world");
    restoredTown->abortProduction(0);
    restoredOwner->setAvailableResource(genie::ResourceType::GoldStorage,1000);
    restoredOwner->applyResearch(104);
    commands.update(0);
    const int loomIndex=data.getTech(22).ButtonID-1;
    auto clickLoom=[&] {
        sf::Event event{};event.type=sf::Event::MouseButtonPressed;
        event.mouseButton={sf::Mouse::Left,int(actionBounds.x)+10+(loomIndex%5)*40,
            int(actionBounds.y)+10+(loomIndex/5)*40};
        commands.handleEvent(event);event.type=sf::Event::MouseButtonReleased;commands.handleEvent(event);
    };
    clickLoom();
    check(restoredTown->productionQueueLength()==1 && restoredTown->productIsResearch(0),
        "available Loom button starts actual research");
    restoredTown->abortProduction(0);
    restoredOwner->applyResearch(22);
    commands.update(0); // Keep the same selected Town Center.
    const auto goldAfterLoom=restoredOwner->resourcesAvailable(genie::ResourceType::GoldStorage);
    clickLoom();
    check(restoredTown->productionQueueLength()==0 && restoredOwner->resourcesAvailable(genie::ResourceType::GoldStorage)==goldAfterLoom,
        "completed Loom button disappears without reselecting the Town Center");
    texture.clear(sf::Color(225,205,160));commands.draw();texture.display();
    check(texture.getTexture().copyToImage().saveToFile((std::filesystem::path(argv[2])/"completed-loom-commands.png").string()),
        "capture filtered completed-research command panel");
    restoredOwner->applyResearch(101);
    std::cout<<"upgraded_town id="<<restoredTown->data()->ID<<" base="<<restoredTown->data()->BaseID<<" copy="<<restoredTown->data()->CopyID<<"\n";
    const auto &feudalProducts=restoredOwner->civilization.creatableUnits(restoredTown->data()->ID);
    check(std::any_of(feudalProducts.begin(),feudalProducts.end(),[](const auto *u){return u->ID==83;}),
        "upgraded Town Center retains villager training catalog");
    commands.update(0);
    train.type=sf::Event::MouseButtonPressed;commands.handleEvent(train);
    train.type=sf::Event::MouseButtonReleased;commands.handleEvent(train);
    check(restoredTown->productionQueueLength()==1,"upgraded Town Center trains a villager through the visible command panel");
    restoredTown->abortProduction(0);
    const int watchIndex=data.getTech(8).ButtonID-1;
    sf::Event watch{};watch.type=sf::Event::MouseButtonPressed;
    watch.mouseButton={sf::Mouse::Left,int(actionBounds.x)+10+(watchIndex%5)*40,
        int(actionBounds.y)+10+(watchIndex/5)*40};
    commands.handleEvent(watch);watch.type=sf::Event::MouseButtonReleased;commands.handleEvent(watch);
    check(restoredTown->productionQueueLength()==1 && restoredTown->productIsResearch(0),
        "upgraded Town Center offers available Town Watch research");
    restoredTown->abortProduction(0);
    auto militaryBuilding=Building::fromUnit(UnitFactory::createUnit(12,restoredOwner,*restoredManager));
    restoredManager->add(militaryBuilding,MapPos(1200,1200));
    restoredManager->setSelectedUnits({militaryBuilding});commands.update(0);
    check(restoredOwner->researchAvailable(222),"Feudal owner has Man-at-Arms available before command selection");
    const int militaryResearchIndex=data.getTech(222).ButtonID-1;
    sf::Event militaryResearch{};militaryResearch.type=sf::Event::MouseButtonPressed;
    militaryResearch.mouseButton={sf::Mouse::Left,int(actionBounds.x)+10+(militaryResearchIndex%5)*40,
        int(actionBounds.y)+10+(militaryResearchIndex/5)*40};
    commands.handleEvent(militaryResearch);militaryResearch.type=sf::Event::MouseButtonReleased;
    commands.handleEvent(militaryResearch);
    check(militaryBuilding->productionQueueLength()==1 && militaryBuilding->productIsResearch(0),
        "military building command panel starts Man-at-Arms research");
    militaryBuilding->abortProduction(0);
    auto patroller=UnitFactory::createUnit(74,restoredOwner,*restoredManager);
    restoredManager->add(patroller,MapPos(480,480));restoredManager->setSelectedUnits({patroller});restoredManager->update(0);
    restoredManager->moveUnitTo(patroller,MapPos(600,480));const auto ongoing=patroller->actions.currentAction();
    restoredManager->selectPatrolTarget();commands.update(0);
    texture.clear(sf::Color(30,50,30));commands.draw();texture.display();
    check(texture.getTexture().copyToImage().saveToFile((std::filesystem::path(argv[2])/"patrol-cancel.png").string()),
          "original cancel icon captured from imported command SLP");
    sf::Event cancel{};cancel.type=sf::Event::MouseButtonReleased;
    cancel.mouseButton={sf::Mouse::Left,int(actionBounds.x)+10,int(actionBounds.y)+10};
    commands.handleEvent(cancel);
    check(restoredManager->state()==UnitManager::State::SelectingPatrolTarget,"unmatched cancel release does not cancel route entry");
    cancel.type=sf::Event::MouseButtonPressed;commands.handleEvent(cancel);
    cancel.type=sf::Event::MouseButtonReleased;commands.handleEvent(cancel);commands.update(0);
    check(restoredManager->state()==UnitManager::State::Default && patroller->actions.currentAction()==ongoing,
          "original cancel button abandons destination entry without cancelling ongoing order");
    sf::Event followButton{};followButton.type=sf::Event::MouseButtonPressed;
    followButton.mouseButton={sf::Mouse::Left,int(actionBounds.x)+90,int(actionBounds.y)+10};
    commands.handleEvent(followButton);followButton.type=sf::Event::MouseButtonReleased;
    commands.handleEvent(followButton);commands.update(0);
    check(restoredManager->state()==UnitManager::State::SelectingFollowTarget,"original Follow icon starts target selection");
    texture.clear(sf::Color(30,50,30));commands.draw();texture.display();
    check(texture.getTexture().copyToImage().saveToFile((std::filesystem::path(argv[2])/"follow-cancel.png").string()),
          "Follow uses original cancel artwork");
    cancel.type=sf::Event::MouseButtonPressed;commands.handleEvent(cancel);
    cancel.type=sf::Event::MouseButtonReleased;commands.handleEvent(cancel);commands.update(0);
    check(restoredManager->state()==UnitManager::State::Default && patroller->actions.currentAction()==ongoing,
          "Follow cancel preserves ongoing movement");
    sf::Event guardButton{};guardButton.type=sf::Event::MouseButtonPressed;
    guardButton.mouseButton={sf::Mouse::Left,int(actionBounds.x)+50,int(actionBounds.y)+10};
    commands.handleEvent(guardButton);guardButton.type=sf::Event::MouseButtonReleased;
    commands.handleEvent(guardButton);commands.update(0);
    check(restoredManager->state()==UnitManager::State::SelectingGuardTarget,"original Guard icon starts target selection");
    cancel.type=sf::Event::MouseButtonPressed;commands.handleEvent(cancel);
    cancel.type=sf::Event::MouseButtonReleased;commands.handleEvent(cancel);commands.update(0);
    check(restoredManager->state()==UnitManager::State::Default && patroller->actions.currentAction()==ongoing,
          "Guard cancel preserves ongoing order");
    restoredManager->selectPatrolTarget();restoredManager->m_patrolPoints.push_back(MapPos(600,500));
    restoredManager->setSelectedUnits({militaryBuilding});
    check(restoredManager->state()==UnitManager::State::Default && restoredManager->m_patrolPoints.empty(),
          "changing selection cannot transfer unfinished patrol to another unit");
    restoredManager->selectPatrolTarget();restoredManager->m_patrolPoints.push_back(MapPos(600,500));
    restoredManager->selectAttackTarget();
    check(restoredManager->state()==UnitManager::State::SelectingAttackTarget && restoredManager->m_patrolPoints.empty(),
          "switching command clears earlier patrol points");
    restoredManager->cancelPendingCommand();
    Dialog dialog(nullptr);dialog.layout(Size(800,600));
    auto menuClick=[&](int x,int y,sf::Mouse::Button button=sf::Mouse::Left) {
        sf::Event event{};event.type=sf::Event::MouseButtonPressed;
        event.mouseButton={button,x,y};dialog.handleEvent(event);
        event.type=sf::Event::MouseButtonReleased;return dialog.handleEvent(event);
    };
    check(menuClick(400,348)==Dialog::Invalid && dialog.showingOptions(),"Options opens supported settings page");
    dialog.layout(Size(800,600));
    Config::Inst().setValue(Config::MusicVolume,"0.5");Config::Inst().setValue(Config::SoundVolume,"0.6");
    menuClick(268,246);
    check(std::stof(Config::Inst().getValue(Config::MusicVolume))==0.4f && std::stof(Config::Inst().getValue(Config::SoundVolume))==0.6f,"music adjustment leaves sound gain unchanged");
    menuClick(532,334);
    check(std::stof(Config::Inst().getValue(Config::SoundVolume))==0.7f,"sound increase changes persistent configuration");
    menuClick(532,334,sf::Mouse::Right);
    check(std::stof(Config::Inst().getValue(Config::SoundVolume))==0.7f,"secondary click cannot change audio settings");
    sf::Event release{};release.type=sf::Event::MouseButtonReleased;release.mouseButton={sf::Mouse::Left,532,334};dialog.handleEvent(release);
    check(std::stof(Config::Inst().getValue(Config::SoundVolume))==0.7f,"duplicate release cannot repeat adjustment");
    for(int i=0;i<12;++i)menuClick(268,246);
    check(std::stof(Config::Inst().getValue(Config::MusicVolume))==0.f,"volume clamps at silence");
    menuClick(318,436);
    check(std::stof(Config::Inst().getValue(Config::MusicVolume))==1.f && std::stof(Config::Inst().getValue(Config::SoundVolume))==1.f,"defaults restores both gains");
    menuClick(532,246);
    check(std::stof(Config::Inst().getValue(Config::MusicVolume))==1.f,"volume cannot exceed full gain");
    check(dialog.back() && !dialog.showingOptions() && !dialog.back(),"Escape backs out one menu level");
    std::cout<<"unit_panel_checks="<<checks<<" errors=0\n";return 0;
}catch(const std::exception &e){std::cerr<<e.what()<<'\n';return 1;}
