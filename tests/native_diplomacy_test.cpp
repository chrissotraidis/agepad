#include "core/CampaignCatalog.h"
#include "resource/Resource.h"
#include <genie/resource/SlpFile.h>
#include "global/Config.h"
#include "global/EventManager.h"
#include "resource/DataManager.h"
#include "resource/AssetManager.h"
#include "render/SfmlRenderTarget.h"
#include "mechanics/GameState.h"
#include "mechanics/UnitManager.h"
#include "mechanics/UnitFactory.h"
#include "mechanics/Unit.h"
#include "mechanics/Player.h"
#include <genie/script/ScnFile.h>
#include <genie/dat/UnitCommand.h>
#include <genie/dat/ResourceUsage.h>
#include <iostream>
#include <stdexcept>
int main(int argc,char **argv) try {
 if(argc!=2 && argc!=3)throw std::runtime_error("Expected snapshot path");
 Config::Inst().testMode=true;Config::Inst().setValue(Config::GamePath,argv[1]);Config::Inst().setValue(Config::GameSample,"combat");
 auto &data=DataManager::Inst();if(!data.initialize())throw std::runtime_error("DAT load failed");
 AssetManager::create(data.isHd());if(!AssetManager::Inst()->initialize(data.gameVersion()))throw std::runtime_error("Asset init failed");
 if(argc==3) {
 auto art=AssetManager::Inst()->getSlp("dlg_dip.slp");
 if(!art)throw std::runtime_error("Missing original diplomacy artwork");
 auto image=Resource::convertFrameToImage(art->getFrame(0));
 image.saveToFile(std::string(argv[2])+"/dlg_dip.png");
 std::cout<<"diplomacy_art="<<image.getSize().x<<"x"<<image.getSize().y<<'\n';
 size_t missions=0,tribute=0,negative=0,gaia=0;
 for(const auto &entry:agepad::campaignCatalog(argv[1],data.isHd())) {
  genie::CpxFile archive;archive.setFileName(entry.archive.string());archive.load();
  for(unsigned m=0;m<entry.missionCount;++m) {
   auto scn=archive.getScnFile(m);++missions;
   const auto &gr=scn->playerData.resourcesPlusPlayerInfo[8];
   std::cout<<"gaia_initial "<<entry.key<<":"<<m<<" food="<<gr.food<<" wood="<<gr.wood<<" gold="<<gr.gold<<" stone="<<gr.stone<<'\n';
   for(const auto &trigger:scn->triggers)for(const auto &effect:trigger.effects)
    if(effect.type==genie::TriggerEffect::SendTribute) {
     ++tribute;negative+=effect.amount<0;gaia+=effect.sourcePlayer==0 || effect.targetPlayer==0;
     std::cout<<"authored_tribute "<<entry.key<<":"<<m<<" trigger="<<trigger.name
              <<" source="<<effect.sourcePlayer<<" target="<<effect.targetPlayer
              <<" resource="<<effect.resource<<" amount="<<effect.amount<<'\n';
    }
  }
 }
 std::cout<<"tribute_inventory missions="<<missions<<" effects="<<tribute<<" negative="<<negative<<" gaia="<<gaia<<'\n';
}
 size_t errors=0,checks=0;auto check=[&](const char *name,bool ok){++checks;errors+=!ok;std::cout<<name<<"="<<ok<<'\n';};
 auto renderer=std::make_shared<SfmlRenderTarget>(Size(800,600));
 {
 GameState state(renderer);if(!state.init())throw std::runtime_error("Fixture failed");
 auto human=state.humanPlayer(),enemy=state.player(2);auto target=UnitFactory::createUnit(74,enemy,*state.unitManager());
 const auto gold=genie::ResourceType::GoldStorage;
 human->setAvailableResource(gold,100);enemy->setAvailableResource(gold,20);
 human->sendTribute(enemy,gold,100);
 check("tribute-exact-balance-debited",human->resourcesAvailable(gold)==0);
 check("tribute-exact-balance-credited",enemy->resourcesAvailable(gold)==120);
 human->setAvailableResource(gold,100.5f);enemy->setAvailableResource(gold,20);
 human->sendTribute(enemy,gold,100);
 check("tribute-retains-fraction",human->resourcesAvailable(gold)==0.5f && enemy->resourcesAvailable(gold)==120);
 const auto population=genie::ResourceType::PopulationHeadroom;
 const float gaiaCapacity=state.player(0)->resourcesAvailable(population),humanCapacity=human->resourcesAvailable(population);
 auto claimable=UnitFactory::createUnit(70,state.player(0),*state.unitManager());
 check("house-has-original-auto-convert-task",claimable->actions.autoConvert);
 EventManager::unitDiscovered(human.get(),claimable.get());
 check("gaia-first-claim",claimable->playerId()==human->playerId);
 check("claimed-capacity-removed-from-gaia",state.player(0)->resourcesAvailable(population)==gaiaCapacity);
 check("claimed-capacity-added-to-human",human->resourcesAvailable(population)==humanCapacity+5);
 EventManager::unitDiscovered(enemy.get(),claimable.get());
 check("discovery-cannot-steal-owned-building",claimable->playerId()==human->playerId);
 claimable->kill();
 check("claimed-house-death-removes-capacity",human->resourcesAvailable(population)==humanCapacity);
 // Synthetic storage mode fixture: ownership changes must not repeat a creation gift.
 auto giftData=*claimable->data();
 for(auto &storage:giftData.ResourceStorages)storage.Type=-1;
 auto &gift=giftData.ResourceStorages[0];gift.Type=int(genie::ResourceType::WoodStorage);gift.Amount=7;gift.Paid=genie::ResourceStoreMode::GiveResourceType;
 const float humanWood=human->resourcesAvailable(genie::ResourceType::WoodStorage),enemyWood=enemy->resourcesAvailable(genie::ResourceType::WoodStorage);
 auto giftUnit=std::make_shared<Unit>(giftData,human,*state.unitManager());
 check("creation-gift-once",human->resourcesAvailable(genie::ResourceType::WoodStorage)==humanWood+7);
 giftUnit->setPlayer(enemy);
 check("transfer-does-not-repeat-gift",enemy->resourcesAvailable(genie::ResourceType::WoodStorage)==enemyWood);
 giftUnit->setPlayer(human);
 check("return-does-not-repeat-gift",human->resourcesAvailable(genie::ResourceType::WoodStorage)==humanWood+7);
 genie::Task raw;raw.ID=0;raw.ActionType=genie::ActionType::Combat;raw.TargetDiplomacy=genie::Task::TargetNeutralsEnemies;
 TaskSet tasks;tasks.add(Task(&raw,0));
 for(bool fallback:{false,true}) {
 raw.UnitID=fallback?9999:74;raw.ClassID=9999;
 human->setDiplomaticStance(2,Player::Allied);
 check(fallback?"fallback-reject-ally":"direct-reject-ally",!UnitActionHandler::findMatchingTask(human,target,tasks).isValid());
 human->setDiplomaticStance(2,Player::Enemy);
 check(fallback?"fallback-allow-enemy":"direct-allow-enemy",UnitActionHandler::findMatchingTask(human,target,tasks).isValid());
 }
 }
 genie::CpxFile campaign;campaign.setFileName(std::string(argv[1])+"/resources/_common/drs/retail-campaigns/dlc0/kings/cam8.cpn");campaign.load();auto scenario=campaign.getScnFile(0);
 // Deliberate test-only asymmetric alliance in an in-memory scenario copy.
 scenario->players[0].diplomacy1[2]=0;scenario->players[1].diplomacy1[1]=3;
 {
 GameState state(renderer);state.setScenario(scenario);if(!state.init())throw std::runtime_error("Scenario init failed");
 check("import-forward-alliance",state.player(1)->isAllied(2));
 check("import-reverse-enemy",!state.player(2)->isAllied(1));
 }
 std::cout<<"diplomacy_checks="<<checks<<" errors="<<errors<<'\n';return errors?1:0;
} catch(const std::exception &e){std::cerr<<e.what()<<'\n';return 1;}
