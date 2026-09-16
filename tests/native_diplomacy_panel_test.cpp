#include "mechanics/Diplomacy.h"
#include "mechanics/GameState.h"
#include "mechanics/UnitFactory.h"
#include "mechanics/UnitManager.h"
#include "mechanics/Unit.h"
#include "ui/DiplomacyPanel.h"
#include "global/Config.h"
#include "resource/DataManager.h"
#include "resource/AssetManager.h"
#include "render/SfmlRenderTarget.h"
#include <genie/script/ScnFile.h>
#include <SFML/Window/Event.hpp>
#include <iostream>
#include <cmath>
#include <stdexcept>
int main(int argc,char **argv) try {
    if(argc!=2)throw std::runtime_error("Expected verified input root");
    Config::Inst().testMode=true;Config::Inst().setValue(Config::GamePath,argv[1]);Config::Inst().setValue(Config::GameSample,"combat");
    auto &data=DataManager::Inst();if(!data.initialize())throw std::runtime_error("DAT load failed");
    AssetManager::create(data.isHd());if(!AssetManager::Inst()->initialize(data.gameVersion()))throw std::runtime_error("Asset load failed");
    auto renderer=std::make_shared<SfmlRenderTarget>(Size(800,600));
    auto state=std::make_shared<GameState>(renderer);if(!state->init())throw std::runtime_error("Fixture init failed");
    int checks=0;auto check=[&](bool ok,const char *name){++checks;if(!ok)throw std::runtime_error(name);};
    auto human=state->humanPlayer(),other=state->player(2);
    // Victory is directional diplomacy plus consent from both participants.
    human->alliedVictory=true;other->alliedVictory=true;
    human->setDiplomaticStance(2,Player::Allied);other->setDiplomaticStance(human->playerId,Player::Allied);
    check(state->sharesVictory(1,2) && !state->sharesVictory(0,1),"mutual consent shares victory and Gaia is excluded");
    state->onPlayerWin(2);check(state->result==GameState::Result::Won,"allied winner grants human victory");
    other->alliedVictory=false;state->onPlayerWin(2);
    check(state->result==GameState::Result::Lost,"ally without consent wins alone");
    other->alliedVictory=true;other->setDiplomaticStance(1,Player::Enemy);
    check(!state->sharesVictory(1,2),"one-sided alliance cannot share victory");
    state->result=GameState::Result::Running;
    const auto alliedSave=human->saveEconomyDiplomacy();human->alliedVictory=false;human->restoreEconomyDiplomacy(alliedSave);
    check(human->alliedVictory,"allied victory persists");
    auto legacy=alliedSave;legacy[0]=1;legacy.resize(legacy.size()-4);human->alliedVictory=false;human->restoreEconomyDiplomacy(legacy);
    check(!human->alliedVictory,"legacy economy retains authored baseline without inventing consent");
    human->alliedVictory=true;human->restoreEconomyDiplomacy(legacy);
    check(human->alliedVictory,"legacy economy retains true authored consent as well");human->alliedVictory=false;
    auto corrupt=alliedSave;corrupt[corrupt.size()-4]=2;bool rejected=false;
    try {human->restoreEconomyDiplomacy(corrupt);}catch(const std::exception &){rejected=true;}
    check(rejected && !human->alliedVictory,"invalid consent rejected atomically");
    {DiplomacySession draft(state);draft.setAlliedVictory(true);check(!human->alliedVictory,"allied victory edit is staged");}
    check(!human->alliedVictory,"cancelled consent leaves world unchanged");
    human->setDiplomaticStance(2,Player::Enemy);other->setDiplomaticStance(human->playerId,Player::Neutral);
    {
        DiplomacySession draft(state);
        check(draft.rows().size()==state->playerCount()-1,"diplomacy lists players excluding Gaia");
        check(draft.rows()[1].theirs==Player::Neutral && draft.rows()[1].stance==Player::Enemy,"directional stances remain distinct");
        check(draft.setStance(2,Player::Allied) && human->diplomaticStance(2)==Player::Enemy,"stance edit remains staged");
        check(!draft.setStance(human->playerId,Player::Enemy) && !draft.setStance(250,Player::Allied),"self and absent player edits rejected");
        check(!draft.hasMarket() && !draft.setTribute(2,2,100),"tribute requires a market");
    }
    check(human->diplomaticStance(2)==Player::Enemy,"cancelled session leaves world unchanged");
    auto market=UnitFactory::createUnit(84,human,*state->unitManager());
    state->unitManager()->add(market,MapPos(400,400,0));market->setCreationProgress(market->data()->Creatable.TrainTime*.5f);
    DiplomacySession transaction(state);
    check(!transaction.hasMarket(),"unfinished market cannot tribute");market->setCreationProgress(market->data()->Creatable.TrainTime);
    check(transaction.hasMarket(),"completed market permits tribute");
    const auto gold=genie::ResourceType::GoldStorage,wood=genie::ResourceType::WoodStorage;
    check(std::abs(transaction.taxRate()-.3f)<.0001f,"original DAT supplies starting tribute tax");
    human->setAvailableResource(genie::ResourceType::TributeInefficiency,.3f);
    human->setAvailableResource(gold,130);human->setAvailableResource(wood,0);other->setAvailableResource(gold,20);other->setAvailableResource(wood,10);
    transaction.setAlliedVictory(true);transaction.setStance(2,Player::Allied);transaction.setTribute(2,2,100);transaction.setTribute(2,0,100);
    std::string error;
    check(!transaction.commit(error) && !error.empty(),"unaffordable aggregate rejected");
    check(human->diplomaticStance(2)==Player::Enemy && human->resourcesAvailable(gold)==130 && other->resourcesAvailable(gold)==20,"failed transaction changes neither stances nor resources");
    check(!human->alliedVictory,"unaffordable tribute cannot partially commit consent");
    transaction.setTribute(2,0,0);
    check(transaction.costs()[2]==130 && transaction.commit(error),"exact taxed balance accepted");
    check(human->resourcesAvailable(gold)==0 && other->resourcesAvailable(gold)==120,"tribute recipient gets requested amount while sender pays tax");
    check(human->diplomaticStance(2)==Player::Allied && other->diplomaticStance(human->playerId)==Player::Neutral,"commit changes only our stance");
    check(human->resourcesAvailable(genie::ResourceType::P2Tribute)==100 && other->resourcesAvailable(genie::ResourceType::TributefromP1)==100,"tribute updates per-player scenario counters");
    check(human->alliedVictory,"successful transaction commits consent");
    const auto humanSave=human->saveEconomyDiplomacy(),otherSave=other->saveEconomyDiplomacy();
    check(transaction.commit(error) && human->saveEconomyDiplomacy()==humanSave && other->saveEconomyDiplomacy()==otherSave,"repeated confirm cannot duplicate tribute");
    human->setAvailableResource(gold,999);human->setDiplomaticStance(2,Player::Enemy);human->restoreEconomyDiplomacy(humanSave);
    check(human->resourcesAvailable(gold)==0 && human->diplomaticStance(2)==Player::Allied,"new diplomacy and tribute persist in existing economy format");
    human->applyResearch(23);
    check(std::abs(transaction.taxRate()-.2f)<.0001f,"actual Coinage research lowers tribute tax");
    human->applyResearch(17);
    check(transaction.taxRate()==0,"actual Banking research removes tribute tax");
    human->setAvailableResource(gold,50);human->setAvailableResource(genie::ResourceType::TributeInefficiency,.3f);
    DiplomacySession remainder(state);
    check(remainder.incrementTribute(2,2) && remainder.rows()[1].tribute[2]==38 && remainder.remaining()[2]>=0,
          "click stages affordable remainder including tax when under100");
    check(!remainder.incrementTribute(2,2),"additional click cannot overspend remaining stockpile");
    remainder.clearTributes();check(remainder.remaining()[2]==50,"clear tribute restores displayed remaining stockpile");
    human->setAvailableResource(genie::ResourceType::TributeInefficiency,0);
    human->setAvailableResource(gold,1000);
    // Original HD option bytes are packed into genieutils' unused1. Classic
    // scenarios don't carry that field; do not interpret unrelated high bytes.
    auto definition=std::make_shared<genie::ScnFile>();definition->playerData.playerDataVersion=1.23f;definition->playerData.unused1=0x010100;
    state->setScenario(definition);check(!state->diplomacyLocked(),"other HD option bytes do not lock diplomacy");
    definition->playerData.unused1|=1;
    DiplomacySession locked(state);check(locked.locked() && !locked.setStance(2,Player::Enemy),"HD lock-team flag prevents stance edit");
    human->setDiplomaticStance(2,Player::Enemy);
    check(!locked.setTribute(2,2,100),"locked teams cannot tribute to non-allies");human->setDiplomaticStance(2,Player::Allied);
    check(locked.setTribute(2,2,100),"locked teams can tribute to allies");locked.clearTributes();
    definition->playerData.playerDataVersion=1.22f;check(!state->diplomacyLocked(),"classic format does not interpret nonexistent lock byte");
    definition->playerData.playerDataVersion=1.23f;
    state->setGameType(GameType::WonderRace);check(state->diplomacyLocked(),"Wonder Race keeps teams locked");state->setGameType(GameType::Default);
    definition->playerData.unused1=0;
    DiplomacySession lockAtCommit(state);lockAtCommit.setStance(2,Player::Enemy);definition->playerData.unused1=1;
    check(!lockAtCommit.commit(error) && human->diplomaticStance(2)==Player::Allied,"commit rechecks lock state");definition->playerData.unused1=0;
    human->setDiplomaticStance(2,Player::Enemy);
    DiplomacyPanel panel(nullptr,state);panel.layout(Size(800,600));
    const bool originalConsent=human->alliedVictory;
    sf::Event checkbox{};checkbox.type=sf::Event::MouseButtonPressed;checkbox.mouseButton={sf::Mouse::Left,85,435};panel.handleEvent(checkbox);
    checkbox.type=sf::Event::MouseButtonReleased;panel.handleEvent(checkbox);
    check(panel.session().alliedVictory()!=originalConsent && human->alliedVictory==originalConsent,"original checkbox stages consent by matched click");
    // P2 ally radio: panel origin22,45 +345,166 +second row32.
    sf::Event e{};e.type=sf::Event::MouseButtonPressed;e.mouseButton={sf::Mouse::Left,380,255};panel.handleEvent(e);
    e.type=sf::Event::MouseButtonReleased;e.mouseButton.x=20;panel.handleEvent(e);
    check(panel.session().rows()[1].stance==Player::Enemy,"drag outside cancels radio activation");
    e.type=sf::Event::MouseButtonPressed;e.mouseButton.x=380;panel.handleEvent(e);e.type=sf::Event::MouseButtonReleased;panel.handleEvent(e);
    check(panel.session().rows()[1].stance==Player::Allied && human->diplomaticStance(2)==Player::Enemy,"radio click stages requested stance");
    // P2 gold tribute cell is origin22,45 +611,198. Modifier state
    // comes from the engine's key events, including on iPad.
    e.type=sf::Event::MouseButtonPressed;e.mouseButton={sf::Mouse::Left,650,255};panel.handleEvent(e);
    e.type=sf::Event::MouseButtonReleased;panel.handleEvent(e);
    check(panel.session().rows()[1].tribute[2]==100,"tribute cell adds100");
    e.type=sf::Event::MouseButtonPressed;panel.handleEvent(e,true);
    e.type=sf::Event::MouseButtonReleased;panel.handleEvent(e,true);
    check(panel.session().rows()[1].tribute[2]==0,"tracked Shift modifier subtracts100");
    e.type=sf::Event::KeyPressed;e.key.code=sf::Keyboard::Return;
    check(panel.handleEvent(e) && human->diplomaticStance(2)==Player::Allied,"Enter commits diplomacy and closes panel");
    check(human->alliedVictory!=originalConsent,"Return commits checkbox along with stance");
    state->setScenario(nullptr);other->alive=true;human->alive=true;state->player(0)->alive=true;
    human->alliedVictory=true;other->alliedVictory=false;
    other->setDiplomaticStance(1,Player::Allied);state->result=GameState::Result::Running;state->update(1000);
    check(state->result==GameState::Result::Running,"two allied survivors without mutual consent keep playing");
    other->alliedVictory=true;state->update(1100);
    check(state->result==GameState::Result::Won,"mutually consenting surviving team wins despite living Gaia");
    state->result=GameState::Result::Running;other->alive=false;human->alliedVictory=false;state->update(1200);
    check(state->result==GameState::Result::Won,"single surviving competitor wins despite living Gaia");
    std::cout<<"diplomacy_panel_checks="<<checks<<" errors=0\n";
    return 0;
} catch(const std::exception &error) {std::cerr<<error.what()<<'\n';return 1;}
