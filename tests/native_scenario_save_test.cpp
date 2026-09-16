#include "global/Config.h"
#include "core/SaveFingerprint.h"
#include <sstream>
#include "global/EventManager.h"
#include "mechanics/StateManager.h"
#include "mechanics/Map.h"
#include "render/Camera.h"
#include "render/GraphicRender.h"
#include "core/SimulationClock.h"
#include "resource/DataManager.h"
#include "resource/AssetManager.h"
#include "render/SfmlRenderTarget.h"
#include "mechanics/GameState.h"
#include "mechanics/ScenarioController.h"
#include "mechanics/UnitManager.h"
#include "mechanics/UnitFactory.h"
#include "mechanics/Unit.h"
#include "mechanics/Building.h"
#include "mechanics/Player.h"
#include <genie/script/ScnFile.h>
#include <iostream>
#include <stdexcept>

int main(int argc, char **argv) try {
    if (argc != 2) throw std::runtime_error("Expected verified snapshot path");
    Config::Inst().testMode = true;
    Config::Inst().setValue(Config::GamePath, argv[1]);
    Config::Inst().setValue(Config::GameSample, "combat");
    auto &data = DataManager::Inst();
    if (!data.initialize()) throw std::runtime_error("DAT load failed");
    AssetManager::create(data.isHd());
    if (!AssetManager::Inst()->initialize(data.gameVersion())) throw std::runtime_error("Asset init failed");
    auto renderer = std::make_shared<SfmlRenderTarget>(Size(800, 600));
    GameState state(renderer);
    if (!state.init()) throw std::runtime_error("Fixture init failed");
    auto scenario = std::make_shared<genie::ScnFile>();
    for (auto &player : scenario->players) player.victoryConditions.clear();
    auto &victory = scenario->playerData.victoryConditions;
    victory.victoryMode = genie::ScnVictory::Custom;
    victory.allConditionsRequired = 0;
    victory.conquestRequired = 0;
    victory.numRelicsRequired = 0;
    victory.exploredPerCentRequired = 0;
    genie::Trigger trigger{};
    trigger.startingState = 1;
    trigger.looping = 0;
    genie::TriggerCondition timer;
    timer.type = genie::TriggerCondition::Timer;
    timer.timer = 10;
    trigger.conditions = {timer};
    scenario->triggers = {trigger};
    int checks=0;
    auto check=[&](bool ok, const char *name) {
        ++checks;
        if (!ok) throw std::runtime_error(name);
    };
    auto rejected=[&](auto action) {
        try { action(); return false; } catch (const agepad::SaveError &) { return true; }
    };
    agepad::SaveBytes saved;
    {
        ScenarioController original(&state);
        original.setScenario(scenario);
        check(!original.update(4000), "timer should still be running at save");
        saved=original.saveRuntime();
    }
    ScenarioController restored(&state);
    restored.setScenario(scenario);
    restored.restoreRuntime(saved,4000);
    check(restored.saveRuntime()==saved, "exact runtime round trip");
    agepad::SimulationClock timeline;
    timeline.reset(4000,100000);
    check(timeline.sample(200000,false)==4000,"pause after load excludes wall time");
    check(!restored.update(timeline.sample(205999,true)), "timer must not fire early after restore");
    check(restored.update(timeline.sample(206000,true)), "timer fires at original deadline");
    auto completed=restored.saveRuntime();
    ScenarioController finished(&state);
    finished.setScenario(scenario);
    finished.restoreRuntime(completed,10000);
    check(!finished.update(20000), "completed nonlooping trigger does not replay");
    const auto before=restored.saveRuntime();
    bool allTruncated=true;
    for (std::size_t i=0; i<saved.size(); ++i) {
        const agepad::SaveBytes truncated(saved.begin(),saved.begin()+i);
        allTruncated &= rejected([&] { restored.restoreRuntime(truncated,4000); });
        allTruncated &= restored.saveRuntime()==before;
    }
    check(allTruncated,"truncation must reject without partial mutation");
    check(rejected([&] { restored.restoreRuntime(saved,3999); }), "future update time refused");
    check(restored.saveRuntime()==before,"time refusal preserves state");
    auto bad=saved; bad.push_back(0);
    check(rejected([&] { restored.restoreRuntime(bad,4000); }), "trailing bytes refused");
    bad=saved; bad[12]=255;
    check(rejected([&] { restored.restoreRuntime(bad,4000); }), "trigger shape mismatch refused");
    bad=saved; bad[16]=2;
    check(rejected([&] { restored.restoreRuntime(bad,4000); }), "invalid boolean refused");
    bad=saved; bad[20]=255;
    check(rejected([&] { restored.restoreRuntime(bad,4000); }), "condition shape mismatch refused");
    bad=saved; bad[24]=0; bad[25]=0; bad[26]=128; bad[27]=127;
    check(rejected([&] { restored.restoreRuntime(bad,4000); }), "infinite countdown refused under fast math");
    bad[24]=1;
    check(rejected([&] { restored.restoreRuntime(bad,4000); }), "NaN countdown refused under fast math");
    check(restored.saveRuntime()==before,"malformed restores never mutate controller");
    state.setWorldEventsEnabled(false);restored.setEventsEnabled(false);finished.setEventsEnabled(false);
    check(agepad::SaveFingerprint::bytes(agepad::SaveBytes{'a','b','c'})=="ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad","SHA256 known vector matches");
    genie::CpxFile campaign;campaign.setFileName(std::string(argv[1])+"/resources/_common/drs/retail-campaigns/dlc0/kings/cam8.cpn");campaign.load();
    auto definitionScenario=campaign.getScnFile(0);
    auto fingerprint=[&](){std::ostringstream stream(std::ios::binary);definitionScenario->writeObject(stream);const auto bytes=stream.str();return agepad::SaveFingerprint::bytes(agepad::SaveBytes(bytes.begin(),bytes.end()));};
    const auto firstFingerprint=fingerprint();
    check(fingerprint()==firstFingerprint,"actual tutorial definition serialization has stable fingerprint");
    definitionScenario->scenarioInstructions+="changed";
    check(fingerprint()!=firstFingerprint,"changed tutorial definition changes fingerprint");
    StateManager worlds;
    auto original=std::make_shared<GameState>(renderer);
    check(worlds.addActiveState(original),"full-world fixture initializes");
    original->setScenario(scenario);original->scenarioController()->setScenario(scenario);
    original->moveCameraTo(MapPos(600,700,0));
    original->humanPlayer()->name="Saved Commander";original->humanPlayer()->playerColor=3;
    original->setTradingPrice(genie::ResourceType::FoodStorage,150);
    original->update(1000);original->update(4000);
    const std::string definition="fixture-timer-definition-v1";
    const auto worldBytes=original->saveRuntime(4000,definition);
    Time resumeTime=-1;
    auto pending=GameState::fromRuntime(worldBytes,renderer,scenario,definition,resumeTime);
    check(resumeTime==4000 && pending->readyForResume() && pending->map()->saveTerrain()==original->map()->saveTerrain() && pending->unitManager()->units().size()==original->unitManager()->units().size() && pending->scenarioController()->saveRuntime()==original->scenarioController()->saveRuntime(),"complete world snapshot roundtrips before exposure");
    check(pending->humanPlayer()->name=="Saved Commander" && pending->humanPlayer()->playerColor==3 && pending->buyPrice(genie::ResourceType::FoodStorage)==195,"restored roster metadata and trading price preserved");
    const auto pendingBefore=pending->saveRuntime(resumeTime,definition);
    EventManager::resourceBought(genie::ResourceType::FoodStorage,100);
    check(pending->saveRuntime(resumeTime,definition)==pendingBefore,"inactive restored world ignores old-world trading events");
    auto brokenWorld=worldBytes;brokenWorld.push_back(0);Time failedTime=777;
    const auto originalBefore=original->saveRuntime(4000,definition);
    check(rejected([&]{GameState::fromRuntime(brokenWorld,renderer,scenario,definition,failedTime);}) && failedTime==777 && original->saveRuntime(4000,definition)==originalBefore,"failed complete load leaves old world and output clock unchanged");
    check(rejected([&]{GameState::fromRuntime(worldBytes,renderer,scenario,"other-definition",failedTime);}),"wrong verified scenario identity refused");
    check(worlds.resumeState(pending) && worlds.getActiveState()==pending && !original->eventsEnabled() && pending->eventsEnabled(),"state manager replaces world without running scenario initialization");
    check(renderer->camera()->targetPosition()==MapPos(600,700,0),"camera applies only at world replacement");
    check(!worlds.resumeState(pending),"already-active state cannot be resumed twice");
    const auto oldBefore=original->saveRuntime(4000,definition);
    EventManager::resourceBought(genie::ResourceType::FoodStorage,100);
    check(original->saveRuntime(4000,definition)==oldBefore,"retained old-world listeners ignore new-world events");
    bool worldEqual=true;
    for(Time t=4050;t<=12000;t+=50) {
        pending->setWorldEventsEnabled(false);original->setWorldEventsEnabled(true);original->update(t);
        original->setWorldEventsEnabled(false);pending->setWorldEventsEnabled(true);pending->update(t);
        const auto &a=original->unitManager()->units(),&b=pending->unitManager()->units();
        worldEqual &= a.size()==b.size() && original->result==pending->result && original->scenarioController()->saveRuntime()==pending->scenarioController()->saveRuntime();
        for(std::size_t i=0;i<std::min(a.size(),b.size());++i)
            worldEqual &= a[i]->position()==b[i]->position() && a[i]->hitpointsLeft()==b[i]->hitpointsLeft() && a[i]->activeMissiles==b[i]->activeMissiles;
    }
    check(worldEqual,"resumed normal GameState updates match uninterrupted combat and scenario timers through12 seconds");
    const auto newBeforeDisposal=pending->saveRuntime(12000,definition);original.reset();
    check(pending->saveRuntime(12000,definition)==newBeforeDisposal,"old-world destruction emits no lifecycle changes into resumed world");
    pending->setWorldEventsEnabled(false);
    definitionScenario=campaign.getScnFile(0);
    auto tutorialWorld=std::make_shared<GameState>(renderer);tutorialWorld->setScenario(definitionScenario);check(tutorialWorld->init(),"actual tutorial save fixture initializes");
    tutorialWorld->update(1000);
    for(const auto &unit:tutorialWorld->unitManager()->units())unit->renderer();
    const auto tutorialBytes=tutorialWorld->saveRuntime(1000,firstFingerprint);
    auto tutorialCopy=GameState::fromRuntime(tutorialBytes,renderer,definitionScenario,firstFingerprint,resumeTime);
    check(tutorialCopy->unitManager()->units().size()==tutorialWorld->unitManager()->units().size() && tutorialCopy->player(0)->playerColor==-1,"actual tutorial with neutral Gaia graphics restores");
    // A non-combat authored tutorial cannot win from an empty conquest predicate.
    tutorialWorld->setWorldEventsEnabled(false);tutorialCopy->setWorldEventsEnabled(false);
    auto feedingDefinition=campaign.getScnFile(1);
    auto feeding=std::make_shared<GameState>(renderer);feeding->setScenario(feedingDefinition);
    check(feeding->init(),"Feeding the Army initializes");
    for(Time t=0;t<=20000;t+=100)feeding->update(t);
    check(feeding->result==GameState::Result::Running,"food tutorial stays running before gathering its objective");
    const auto feedingBytes=feeding->saveRuntime(20000,"feeding-fixture");
    auto feedingCopy=GameState::fromRuntime(feedingBytes,renderer,feedingDefinition,"feeding-fixture",resumeTime);
    feeding->setWorldEventsEnabled(false);feedingCopy->setWorldEventsEnabled(true);
    feedingCopy->update(20100);
    check(feedingCopy->result==GameState::Result::Running,"restored food tutorial retains authored victory rules");
    auto foodPlayer=feedingCopy->humanPlayer();
    auto humanCount=[&](){return std::count_if(feedingCopy->unitManager()->units().begin(),feedingCopy->unitManager()->units().end(),[&](const auto&u){return u->playerId()==foodPlayer->playerId;});};
    const auto startingCount=humanCount();
    check(bool(feedingCopy->unitManager()->selectNextIdleVillager()),"actual tutorial villager selected for authored instruction trigger");
    foodPlayer->setAvailableResource(genie::ResourceType::FoodStorage,50);
    for(Time t=20200;t<=120200;t+=100)feedingCopy->update(t);
    check(humanCount()>=startingCount+4,"actual food objective grants four authored villagers");
    check(feedingCopy->result==GameState::Result::Running,"food alone cannot win three-resource objective");
    foodPlayer->setAvailableResource(genie::ResourceType::WoodStorage,50);
    foodPlayer->setAvailableResource(genie::ResourceType::GoldStorage,49);
    feedingCopy->update(120300);
    check(feedingCopy->result==GameState::Result::Running,"49 gold cannot satisfy 50 gold objective");
    foodPlayer->setAvailableResource(genie::ResourceType::GoldStorage,50);
    foodPlayer->setAvailableResource(genie::ResourceType::FoodStorage,49);
    feedingCopy->update(120400);
    check(feedingCopy->result==GameState::Result::Running,"spent food is not retained as cumulative objective credit");
    foodPlayer->setAvailableResource(genie::ResourceType::FoodStorage,50);
    for(Time t=120500;t<=140500;t+=100)feedingCopy->update(t);
    check(feedingCopy->result==GameState::Result::Won,"actual three-resource mission reaches authored victory");
    feedingCopy->setWorldEventsEnabled(false);
    auto trainingDefinition=campaign.getScnFile(2);
    auto training=std::make_shared<GameState>(renderer);training->setScenario(trainingDefinition);
    check(training->init(),"Training the Troops initializes");
    for(const auto &trigger:trainingDefinition->triggers) {
        for(const auto &condition:trigger.conditions) if(condition.type==genie::TriggerCondition::OwnObjects)
            std::cout << "training_own_objects " << trigger.name << " amount=" << condition.amount << " unit=" << condition.object << " group=" << condition.objectGroup << " player=" << condition.sourcePlayer << '\n';
    }
    for(int id:{12,70,72,83,118}) {
        const auto &u=training->humanPlayer()->civilization.unitData(id);
        std::cout << "training_catalog id=" << id << " enabled=" << int(u.Enabled) << " creator=" << u.Creatable.TrainLocationID << " page=" << int(u.InterfaceKind) << " button=" << int(u.Creatable.ButtonID) << '\n';
    }
    std::cout << "authored_start_age=" << trainingDefinition->playerData.startingAge[0] << " current_age=" << training->humanPlayer()->resourcesAvailable(genie::ResourceType::CurrentAge) << " dark_age_effect=" << training->humanPlayer()->civilization.startingResource(genie::ResourceType::DarkAgeTechID) << '\n';
    for(std::size_t i=0;i<data.allTechs().size();++i) {
        const auto &tech=data.allTechs()[i];if(tech.EffectID<0)continue;
        for(const auto &effect:data.getEffect(tech.EffectID).EffectCommands)
            if(effect.Type==2 && effect.TargetUnit==12) {
                std::cout << "barracks_enable tech=" << i << " effect=" << tech.EffectID << " civ=" << tech.Civ << " location=" << tech.ResearchLocation << " required=" << tech.RequiredTechCount;
                for(auto req:tech.RequiredTechs)std::cout << " " << req;std::cout << '\n';
            }
    }
    const auto &initialBuildings=training->humanPlayer()->civilization.creatableUnits(83);
    check(std::any_of(initialBuildings.begin(),initialBuildings.end(),[](const auto *unit){return unit->ID==12;}),
          "authored Dark Age initializes Barracks prerequisite technology and build catalog");
    const auto &trainingResources=trainingDefinition->playerResources[0];
    std::cout << "training_authored_resources food=" << trainingResources.food << " wood=" << trainingResources.wood << " gold=" << trainingResources.gold << " stone=" << trainingResources.stone << '\n';
    check(trainingResources.food>=50,"actual training scenario supplies villager food");
    check(training->humanPlayer()->resourcesAvailable(genie::ResourceType::FoodStorage)==trainingResources.food &&
          training->humanPlayer()->resourcesAvailable(genie::ResourceType::WoodStorage)==trainingResources.wood &&
          training->humanPlayer()->resourcesAvailable(genie::ResourceType::GoldStorage)==trainingResources.gold &&
          training->humanPlayer()->resourcesAvailable(genie::ResourceType::StoneStorage)==trainingResources.stone,
          "scenario player one receives its own authored starting resources");
    Building::Ptr trainingTown;
    for(const auto &unit:training->unitManager()->units())
        if(unit->playerId()==training->humanPlayer()->playerId && unit->data()->ID==109) trainingTown=Building::fromUnit(unit);
    check(bool(trainingTown),"actual training Town Center exists");
    const auto &trainingVillager=training->humanPlayer()->civilization.unitData(83);
    check(trainingTown->enqueueProduceUnit(&trainingVillager) && trainingTown->productionQueueLength()==1 &&
          training->humanPlayer()->resourcesAvailable(genie::ResourceType::FoodStorage)==trainingResources.food-50,
          "authored starting stockpile funds first villager at actual 50 food cost");
    auto countDefinition=std::make_shared<genie::ScnFile>();
    for(auto &player:countDefinition->players) player.victoryConditions.clear();
    countDefinition->playerData.victoryConditions=scenario->playerData.victoryConditions;
    genie::Trigger countTrigger{};countTrigger.startingState=1;countTrigger.looping=0;
    for(const auto &trigger:trainingDefinition->triggers) if(trigger.name=="Make another Villager")
        for(const auto &condition:trigger.conditions) if(condition.type==genie::TriggerCondition::OwnObjects) countTrigger.conditions.push_back(condition);
    check(countTrigger.conditions.size()==1 && countTrigger.conditions[0].amount==5,"actual next-instruction condition requires five villagers");
    countDefinition->triggers={countTrigger};
    ScenarioController counts(training.get());counts.setScenario(countDefinition);
    check(!counts.update(0),"four starting villagers cannot satisfy authored five-villager condition");
    const auto beforeFifth=counts.saveRuntime();
    for(Time t=0;t<=60000;t+=100) training->update(t);
    check(counts.update(60000),"first trained villager plus four starting villagers satisfies authored condition");
    ScenarioController restoredCounts(training.get());restoredCounts.setScenario(countDefinition);
    restoredCounts.restoreRuntime(beforeFifth,60000);
    check(restoredCounts.update(60000),"restored ownership condition counts current units without replaying creation events");
    training->setWorldEventsEnabled(false);
    auto eightDefinition=campaign.getScnFile(2);
    eightDefinition->enabledPlayerCount=8;
    for(std::size_t i=0;i<8;++i) {
        eightDefinition->playerData.resourcesPlusPlayerInfo[i].civilizationID=1;
        eightDefinition->playerData.resourcesPlusPlayerInfo[i].isHuman=(i==0);
        eightDefinition->playerResources[i].food=100+i;
        eightDefinition->playerResources[i].wood=200+i;
        eightDefinition->playerResources[i].gold=300+i;
        eightDefinition->playerResources[i].stone=400+i;
    }
    auto eight=std::make_shared<GameState>(renderer);eight->setScenario(eightDefinition);
    check(eight->init(),"eight-player resource fixture initializes without out-of-range indexing");
    bool correctlyMapped=eight->player(0)->resourcesAvailable(genie::ResourceType::FoodStorage)==0;
    for(int i=1;i<=8;++i) correctlyMapped &=
        eight->player(i)->resourcesAvailable(genie::ResourceType::FoodStorage)==99+i &&
        eight->player(i)->resourcesAvailable(genie::ResourceType::WoodStorage)==199+i &&
        eight->player(i)->resourcesAvailable(genie::ResourceType::GoldStorage)==299+i &&
        eight->player(i)->resourcesAvailable(genie::ResourceType::StoneStorage)==399+i;
    check(correctlyMapped,"all eight players receive distinct own stockpiles and Gaia receives none");
    auto researchDefinition=campaign.getScnFile(3);
    for(const auto &authored:researchDefinition->triggers)
        for(const auto &condition:authored.conditions)
            if(condition.type==genie::TriggerCondition::ResearchTechnology)
                std::cout<<"authored_research_condition trigger="<<authored.name<<" player="<<condition.sourcePlayer<<" tech="<<condition.technology<<"\n";
    auto researchWorld=std::make_shared<GameState>(renderer);researchWorld->setScenario(researchDefinition);
    check(researchWorld->init(),"Research and Technology initializes");
    auto researchPlayer=researchWorld->humanPlayer();
    for(int id:{104,110,258,108,122,282,120,101})
        std::cout<<"research_mission_initial tech="<<id<<" completed="<<researchPlayer->researchCompleted(id)<<" available="<<researchPlayer->researchAvailable(id)<<"\n";
    auto researchTriggerDefinition=campaign.getScnFile(3);
    genie::Trigger researchTrigger{};researchTrigger.looping=0;researchTrigger.startingState=1;
    genie::TriggerCondition researched;researched.type=genie::TriggerCondition::ResearchTechnology;
    researched.sourcePlayer=researchPlayer->playerId;researched.technology=202;
    researchTrigger.conditions={researched};researchTriggerDefinition->triggers={researchTrigger};
    ScenarioController researchConditions(researchWorld.get());researchConditions.setScenario(researchTriggerDefinition);
    check(!researchConditions.update(1),"research condition remains false before completion");
    researchPlayer->applyResearch(195);
    check(!researchConditions.update(2),"matching effect ID cannot satisfy another research condition");
    researchPlayer->applyResearch(202);
    check(researchConditions.update(3),"research condition observes completed research identity");
    check(!researchConditions.update(4),"completed nonlooping research trigger fires once");
    auto authoredLoomDefinition=campaign.getScnFile(3);
    genie::Trigger authoredLoom{};
    bool foundAuthoredLoom=false;
    for(const auto &candidate:authoredLoomDefinition->triggers)
        if(candidate.name=="Pause between Loom and Advance") {
            authoredLoom=candidate;foundAuthoredLoom=true;
        }
    check(foundAuthoredLoom,"actual authored Loom research trigger found");
    authoredLoom.startingState=1;authoredLoom.effects.clear();
    authoredLoomDefinition->triggers={authoredLoom};
    ScenarioController loomConditions(researchWorld.get());loomConditions.setScenario(authoredLoomDefinition);
    check(!loomConditions.update(10),"authored Loom trigger does not pass before research");
    const auto beforeLoom=loomConditions.saveRuntime();
    researchPlayer->applyResearch(22);
    check(loomConditions.update(11),"authored Loom trigger detects completed Loom");
    ScenarioController resumedLoom(researchWorld.get());resumedLoom.setScenario(authoredLoomDefinition);
    resumedLoom.restoreRuntime(beforeLoom,10);
    check(resumedLoom.update(11),"restored trigger reads completed research without needing a new event");
    const auto afterLoom=loomConditions.saveRuntime();
    resumedLoom.restoreRuntime(afterLoom,11);
    check(!resumedLoom.update(12),"restored completed authored trigger does not replay");
    auto indexedDefinition=campaign.getScnFile(3);
    genie::Trigger unsupported{};unsupported.looping=0;unsupported.startingState=1;
    genie::TriggerCondition unsupportedCondition;unsupportedCondition.type=genie::TriggerCondition::AISignal;
    unsupported.conditions={unsupportedCondition};
    genie::Trigger activate{};activate.looping=0;activate.startingState=1;
    genie::TriggerEffect activateLast;activateLast.type=genie::TriggerEffect::ActivateTrigger;activateLast.trigger=2;
    activate.effects={activateLast};
    genie::Trigger indexedTarget{};indexedTarget.looping=0;indexedTarget.startingState=0;indexedTarget.conditions={researched};
    genie::TriggerEffect win;win.type=genie::TriggerEffect::DeclareVictory;win.sourcePlayer=researchPlayer->playerId;
    indexedTarget.effects={win};indexedDefinition->triggers={unsupported,activate,indexedTarget};
    auto unsupportedOnly=campaign.getScnFile(3);unsupportedOnly->triggers={unsupported};
    ScenarioController unsupportedController(researchWorld.get());unsupportedController.setScenario(unsupportedOnly);
    check(!unsupportedController.update(19),"unsupported condition remains unsatisfied instead of firing");
    ScenarioController indexed(researchWorld.get());indexed.setScenario(indexedDefinition);
    researchWorld->result=GameState::Result::Running;
    indexed.update(20);
    check(researchWorld->result==GameState::Result::Won,"unsupported earlier trigger does not shift authored activation IDs");
    researchWorld->setWorldEventsEnabled(false);
    genie::CpxFile cidCampaign;
    cidCampaign.setFileName(std::string(argv[1])+"/resources/_common/drs/retail-campaigns/dlc0/conquerors/xcam2.cpx");
    cidCampaign.load();
    auto cidDefinition=cidCampaign.getScnFile(2);
    for(const auto &tr:cidDefinition->triggers) for(const auto &e:tr.effects) if(e.type==genie::TriggerEffect::ChangeOwnership) {
        std::cout << "cid_transfer trigger=" << tr.name << " source=" << e.sourcePlayer << " target=" << e.targetPlayer << " object=" << e.object << " type=" << e.objectType << " group=" << e.objectGroup << " area=" << e.areaFrom.x << "," << e.areaFrom.y << ":" << e.areaTo.x << "," << e.areaTo.y << " selected=";
        for(auto id:e.selectedUnits)std::cout << id << ",";std::cout << std::endl;
    }
    auto cidWorld=std::make_shared<GameState>(renderer);
    cidWorld->setScenario(cidDefinition);
    check(cidWorld->init(),"actual El Cid third mission initializes");
    check(!cidDefinition->playerData.instructions.empty() && cidWorld->missionInstructions().find(cidDefinition->playerData.instructions)!=std::string::npos,"original El Cid objectives exposed without truncation");
    const auto cidReport=cidWorld->missionReports()[0];
    const auto briefingAt=cidReport.find(cidDefinition->playerData.instructions);
    check(briefingAt!=std::string::npos && cidReport.find(cidDefinition->playerData.instructions,briefingAt+1)==std::string::npos,"identical briefing and trigger objective displayed once");
    const auto instructionsBefore=cidDefinition->playerData.instructions;
    cidDefinition->playerData.instructions="First\\nSecond";
    check(cidWorld->missionInstructions().find("First\nSecond")!=std::string::npos,"HD escaped paragraph breaks decoded for display");
    cidDefinition->playerData.instructions=instructionsBefore;
    cidWorld->update(1000);
    const bool authoredConsent=cidDefinition->players[cidWorld->humanPlayer()->playerId-1].alliedVictory!=0;
    check(cidWorld->humanPlayer()->alliedVictory==authoredConsent,"actual El Cid allied victory baseline imported");
    cidWorld->humanPlayer()->alliedVictory=!authoredConsent;
    const auto cidBytes=cidWorld->saveRuntime(1000,"cid-third-fixture");
    auto cidCopy=GameState::fromRuntime(cidBytes,renderer,cidDefinition,"cid-third-fixture",resumeTime);
    check(cidCopy->humanPlayer()->alliedVictory==!authoredConsent,"world restore preserves edited consent over authored baseline");
    const auto &cidUnits=cidWorld->unitManager()->units(),&copyUnits=cidCopy->unitManager()->units();
    bool cidEqual=cidUnits.size()==copyUnits.size();
    for(std::size_t i=0;i<std::min(cidUnits.size(),copyUnits.size());++i)
        cidEqual &= cidUnits[i]->saveBaseRuntime()==copyUnits[i]->saveBaseRuntime();
    check(cidEqual && cidWorld->scenarioController()->saveRuntime()==cidCopy->scenarioController()->saveRuntime(),
          "actual El Cid third mission restores all unit base states and scenario timers");
    auto boundary=std::find_if(cidUnits.begin(),cidUnits.end(),[](const auto &u){return u->spawnId==3609;});
    check(boundary!=cidUnits.end() && !cidWorld->map()->isValidPosition((*boundary)->position()),"initialized wall snaps onto excluded map edge");
    const auto oldPosition=(*boundary)->position();
    (*boundary)->Entity::setPosition(MapPos(oldPosition.x+1,oldPosition.y,oldPosition.z),true);
    const auto movedBoundaryBytes=cidWorld->saveRuntime(1000,"cid-third-fixture");
    check(rejected([&]{GameState::fromRuntime(movedBoundaryBytes,renderer,cidDefinition,"cid-third-fixture",resumeTime);}),
          "out-of-map unit at nonauthored position remains rejected");
    (*boundary)->Entity::setPosition(oldPosition,true);
    cidWorld->setWorldEventsEnabled(false);
    cidCopy->setWorldEventsEnabled(false);
    const auto foodResource=genie::ResourceType::FoodStorage;
    const auto woodResource=genie::ResourceType::WoodStorage;
    const auto goldResource=genie::ResourceType::GoldStorage;
    check(cidWorld->player(0)->resourcesAvailable(foodResource)==9999 &&
          cidWorld->player(0)->resourcesAvailable(woodResource)==9999 &&
          cidWorld->player(0)->resourcesAvailable(goldResource)==9999,
          "actual El Cid Gaia treasury uses authored ninth resource record");
    genie::Trigger rewards{};rewards.startingState=1;
    for(const auto &tr:cidDefinition->triggers)if(tr.name=="C - Moor village")
        for(const auto &effect:tr.effects)if(effect.type==genie::TriggerEffect::SendTribute)rewards.effects.push_back(effect);
    const float foodBefore=cidWorld->player(1)->resourcesAvailable(foodResource);
    const float woodBefore=cidWorld->player(1)->resourcesAvailable(woodResource);
    const float goldBefore=cidWorld->player(1)->resourcesAvailable(goldResource);
    auto rewardsDefinition=cidCampaign.getScnFile(2);rewardsDefinition->triggers={rewards};
    ScenarioController rewardsController(cidWorld.get());rewardsController.setScenario(rewardsDefinition);rewardsController.update(1001);
    check(rewards.effects.size()==3 && cidWorld->player(1)->resourcesAvailable(foodResource)==foodBefore+800 &&
          cidWorld->player(1)->resourcesAvailable(woodResource)==woodBefore+950 &&
          cidWorld->player(1)->resourcesAvailable(goldResource)==goldBefore+1200,
          "authored Moor village tribute effects pay food wood and gold");
    check(cidWorld->player(0)->resourcesAvailable(foodResource)==9199 &&
          cidWorld->player(0)->resourcesAvailable(woodResource)==9049 &&
          cidWorld->player(0)->resourcesAvailable(goldResource)==8799,
          "authored Moor village tribute debits Gaia treasury");
    genie::TriggerEffect claimGaia;
    bool foundClaim=false;
    for(const auto &tr:cidDefinition->triggers) if(tr.name=="C - Moor village")
        for(const auto &effect:tr.effects) if(effect.type==genie::TriggerEffect::ChangeOwnership) {
            claimGaia=effect;foundClaim=true;
        }
    check(foundClaim && claimGaia.sourcePlayer==0 && claimGaia.targetPlayer==1,"actual Moor village transfers Gaia to human");
    std::vector<int> cidOwners;
    for(const auto &unit:cidUnits)cidOwners.push_back(unit->playerId());
    genie::Trigger ownershipTrigger{};ownershipTrigger.startingState=1;ownershipTrigger.looping=0;
    ownershipTrigger.effects={claimGaia};
    auto ownershipDefinition=cidCampaign.getScnFile(2);ownershipDefinition->triggers={ownershipTrigger};
    ScenarioController ownershipController(cidWorld.get());ownershipController.setScenario(ownershipDefinition);
    ownershipController.update(1001);
    bool ownersCorrect=true;std::size_t claimed=0;
    for(std::size_t i=0;i<cidUnits.size();++i) {
        const int expected=cidOwners[i]==0 && (claimGaia.objectType<0 || cidUnits[i]->data()->CombatLevel==claimGaia.objectType)?1:cidOwners[i];
        ownersCorrect &= cidUnits[i]->playerId()==expected;
        if(expected==1 && cidOwners[i]==0)++claimed;
    }
    check(claimed>0 && ownersCorrect,"authored Gaia transfer respects object-type filter and preserves other owners");
    const auto claimedBytes=cidWorld->saveRuntime(1001,"cid-third-fixture");
    auto claimedCopy=GameState::fromRuntime(claimedBytes,renderer,cidDefinition,"cid-third-fixture",resumeTime);
    bool claimedEqual=claimedCopy->unitManager()->units().size()==cidUnits.size();
    for(std::size_t i=0;i<std::min(cidUnits.size(),claimedCopy->unitManager()->units().size());++i)
        claimedEqual &= cidUnits[i]->playerId()==claimedCopy->unitManager()->units()[i]->playerId();
    check(claimedEqual,"transferred original scenario restores owners after save");
    check(claimedCopy->player(0)->resourcesAvailable(foodResource)==9199 &&
          claimedCopy->player(0)->resourcesAvailable(woodResource)==9049 &&
          claimedCopy->player(0)->resourcesAvailable(goldResource)==8799 &&
          claimedCopy->player(1)->resourcesAvailable(goldResource)==goldBefore+1200,
          "post-tribute save restores remaining treasury without regranting initial resources");
    claimedCopy->setWorldEventsEnabled(false);
    auto areaUnit=UnitFactory::createUnit(74,cidWorld->player(3),*cidWorld->unitManager());
    auto outsideUnit=UnitFactory::createUnit(74,cidWorld->player(3),*cidWorld->unitManager());
    areaUnit->spawnId=900001;outsideUnit->spawnId=900002;
    cidWorld->unitManager()->add(areaUnit,MapPos(50*48,60*48,0));
    cidWorld->unitManager()->add(outsideUnit,MapPos(51*48,60*48,0));
    auto executeEffect=[&](const genie::TriggerEffect &effect) {
        ownershipTrigger.effects={effect};ownershipDefinition->triggers={ownershipTrigger};
        ownershipController.setScenario(ownershipDefinition);ownershipController.update(1002);
    };
    genie::TriggerEffect areaTransfer;areaTransfer.type=genie::TriggerEffect::ChangeOwnership;
    areaTransfer.sourcePlayer=3;areaTransfer.targetPlayer=1;areaTransfer.object=74;
    areaTransfer.areaFrom={60,50};areaTransfer.areaTo={60,50};
    executeEffect(areaTransfer);
    check(areaUnit->playerId()==1 && outsideUnit->playerId()==3,"single-tile inclusive SCN area swaps axes and excludes adjacent unit");
    genie::TriggerEffect selectedTransfer;selectedTransfer.type=genie::TriggerEffect::ChangeOwnership;
    selectedTransfer.sourcePlayer=3;selectedTransfer.targetPlayer=1;
    selectedTransfer.selectedUnits={outsideUnit->spawnId,outsideUnit->spawnId};
    selectedTransfer.location={1,1};
    selectedTransfer.objectGroup=int(areaUnit->data()->Class)+1;
    executeEffect(selectedTransfer);
    check(outsideUnit->playerId()==3,"explicit spawn selection still honors object group");
    selectedTransfer.objectGroup=int(areaUnit->data()->Class);
    executeEffect(selectedTransfer);
    check(outsideUnit->playerId()==1,"explicit spawn selection works independently of destination location");
    check(outsideUnit->data()==&cidWorld->player(1)->civilization.unitData(74),"ownership rebinds the destination civilization catalog");
    selectedTransfer.sourcePlayer=1;selectedTransfer.targetPlayer=9999;
    executeEffect(selectedTransfer);
    check(outsideUnit->playerId()==1,"invalid ownership destination leaves selected unit unchanged");
    cidWorld->unitManager()->moveUnitTo(areaUnit,MapPos(52*48,60*48,0));
    cidWorld->unitManager()->moveUnitTo(areaUnit,MapPos(53*48,60*48,0),true);
    cidWorld->unitManager()->moveUnitTo(outsideUnit,MapPos(52*48,60*48,0));
    check(areaUnit->actions.currentAction() && !areaUnit->actions.m_actionQueue.empty(),
          "stop fixture has an active order and queued waypoint");
    genie::TriggerEffect stopSelected;stopSelected.type=genie::TriggerEffect::StopUnit;
    stopSelected.sourcePlayer=3;stopSelected.selectedUnits={areaUnit->spawnId};
    executeEffect(stopSelected);
    check(areaUnit->actions.currentAction() && !areaUnit->actions.m_actionQueue.empty(),
          "scripted stop respects ownership selector");
    stopSelected.sourcePlayer=1;executeEffect(stopSelected);
    check(!areaUnit->actions.currentAction() && areaUnit->actions.m_actionQueue.empty() &&
          outsideUnit->actions.currentAction(),"scripted stop cancels selected current and queued orders only");
    const auto stoppedBytes=cidWorld->saveRuntime(1002,"cid-third-fixture");
    auto stoppedCopy=GameState::fromRuntime(stoppedBytes,renderer,cidDefinition,"cid-third-fixture",resumeTime);
    bool stoppedRestored=false,otherRestored=false;
    for(const auto &unit:stoppedCopy->unitManager()->units()) {
        if(unit->spawnId==areaUnit->spawnId)
            stoppedRestored=!unit->actions.currentAction() && unit->actions.m_actionQueue.empty();
        if(unit->spawnId==outsideUnit->spawnId)otherRestored=bool(unit->actions.currentAction());
    }
    check(stoppedRestored && otherRestored,"stopped state and unaffected order survive world save/load");
    stoppedCopy->setWorldEventsEnabled(false);
    genie::TriggerEffect patrolSelected;patrolSelected.type=genie::TriggerEffect::Patrol;
    patrolSelected.sourcePlayer=1;patrolSelected.selectedUnits={areaUnit->spawnId};patrolSelected.location={60,55};
    executeEffect(patrolSelected);
    check(areaUnit->actions.currentAction() && areaUnit->actions.currentAction()->type==IAction::Type::Patrol &&
          outsideUnit->actions.currentAction()->type==IAction::Type::Move,"scripted patrol targets selected spawn only");
    auto patrolCopy=GameState::fromRuntime(cidWorld->saveRuntime(1002,"cid-third-fixture"),renderer,cidDefinition,"cid-third-fixture",resumeTime);
    bool patrolRestored=false;
    for(const auto &unit:patrolCopy->unitManager()->units())if(unit->spawnId==areaUnit->spawnId)
        patrolRestored=unit->actions.currentAction() && unit->actions.currentAction()->type==IAction::Type::Patrol;
    check(patrolRestored,"scripted patrol survives complete world save/load");
    patrolCopy->setWorldEventsEnabled(false);executeEffect(stopSelected);
    check(!areaUnit->actions.currentAction(),"scripted Stop cancels persistent patrol");
    genie::TriggerEffect removeSelected;removeSelected.type=genie::TriggerEffect::RemoveObject;
    removeSelected.selectedUnits={areaUnit->spawnId,outsideUnit->spawnId};
    const auto beforeRemove=cidUnits.size();executeEffect(removeSelected);
    check(cidUnits.size()+2==beforeRemove,"multi-object removal snapshots selection before mutating unit vector");
    auto objectiveDefinition=std::make_shared<genie::ScnFile>();
    for(auto &player:objectiveDefinition->players)player.victoryConditions.clear();
    objectiveDefinition->playerData.victoryConditions.victoryMode=genie::ScnVictory::Custom;
    objectiveDefinition->playerData.victoryConditions.conquestRequired=0;
    objectiveDefinition->playerData.victoryConditions.numRelicsRequired=0;
    objectiveDefinition->playerData.victoryConditions.exploredPerCentRequired=0;
    genie::Trigger secondObjective{};secondObjective.startingState=1;secondObjective.isObjective=1;
    secondObjective.stringTableID=-1;secondObjective.description="Finish the wait";secondObjective.descriptionOrder=20;
    genie::TriggerCondition fiveSeconds;fiveSeconds.type=genie::TriggerCondition::Timer;fiveSeconds.timer=5;
    secondObjective.conditions={fiveSeconds};
    auto firstObjective=secondObjective;firstObjective.description="Earlier display order";firstObjective.descriptionOrder=10;
    firstObjective.conditions[0].timer=20;
    auto hiddenObjective=firstObjective;hiddenObjective.description="Newly activated objective";hiddenObjective.startingState=0;hiddenObjective.descriptionOrder=30;
    genie::TriggerEffect disableFirst;disableFirst.type=genie::TriggerEffect::DeactivateTrigger;disableFirst.trigger=1;
    genie::TriggerEffect activateHidden;activateHidden.type=genie::TriggerEffect::ActivateTrigger;activateHidden.trigger=2;
    secondObjective.effects={disableFirst,activateHidden};
    objectiveDefinition->triggers={secondObjective,firstObjective,hiddenObjective};
    ScenarioController objectiveController(&state);objectiveController.setScenario(objectiveDefinition);
    auto objectiveReport=objectiveController.objectiveReport();
    check(objectiveReport.find("Earlier display order")<objectiveReport.find("Finish the wait") && objectiveReport.find("Newly activated")==std::string::npos,
          "objectives honor description order and hide disabled uncompleted triggers");
    objectiveController.update(5000);objectiveReport=objectiveController.objectiveReport();
    check(objectiveReport.find("[x] Finish the wait")!=std::string::npos && objectiveReport.find("[ ] Newly activated objective")!=std::string::npos && objectiveReport.find("Earlier display order")==std::string::npos,
          "firing completes objective while activation and deactivation update visibility");
    auto objectiveBytes=objectiveController.saveRuntime();
    ScenarioController objectiveCopy(&state);objectiveCopy.setScenario(objectiveDefinition);objectiveCopy.restoreRuntime(objectiveBytes,5000);
    check(objectiveCopy.objectiveReport()==objectiveReport && objectiveCopy.saveRuntime()==objectiveBytes,"completed objective history roundtrips exactly");
    auto invalidHistory=objectiveBytes;invalidHistory.back()=2;
    check(rejected([&]{objectiveCopy.restoreRuntime(invalidHistory,5000);}) && objectiveCopy.objectiveReport()==objectiveReport,"invalid completion flag rejected without mutation");
    agepad::SaveReader header(objectiveBytes);header.u32();header.i64();const auto triggerCount=header.u32();
    auto legacyObjectives=objectiveBytes;legacyObjectives[0]=1;legacyObjectives.resize(legacyObjectives.size()-4*triggerCount);
    objectiveCopy.restoreRuntime(legacyObjectives,5000);
    check(objectiveCopy.objectiveReport().find("[x]")==std::string::npos && objectiveCopy.objectiveReport().find("[ ] Newly activated objective")!=std::string::npos,
          "version1 restores active objectives without inventing past completion history");
    std::cout << "scenario_runtime_checks=" << checks << " errors=0\n";
    return 0;
} catch (const std::exception &error) {
    std::cerr << error.what() << '\n';
    return 1;
}
