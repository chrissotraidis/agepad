#include "global/Config.h"
#include "core/SaveArchive.h"
#include "mechanics/Map.h"
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

int main(int argc, char **argv) try {
    if (argc != 2) throw std::runtime_error("Expected verified snapshot path");
    Config::Inst().testMode = true;
    Config::Inst().setValue(Config::GamePath, argv[1]);
    auto &data = DataManager::Inst();
    if (!data.initialize()) throw std::runtime_error("DAT load failed");
    AssetManager::create(data.isHd());
    if (!AssetManager::Inst()->initialize(data.gameVersion())) throw std::runtime_error("Asset init failed");
    auto renderer = std::make_shared<SfmlRenderTarget>(Size(800, 600));
    GameState state(renderer);
    if (!state.init()) throw std::runtime_error("Basic fixture init failed");
    int checks=0;
    auto check=[&](bool ok,const char *name){++checks;if(!ok)throw std::runtime_error(name);};
    auto rejected=[](auto action){try{action();return false;}catch(const agepad::SaveError &){return true;}};
    auto original=state.map();
    original->setTileAt(8,8,2);
    original->getTileAt(8,8).elevation=2;
    original->updateMapData();
    auto saved=original->saveTerrain();
    auto restored=Map::fromTerrainSave(saved);
    check(restored->saveTerrain()==saved,"exact terrain round trip");
    check(restored->rowCount()==original->rowCount() && restored->columnCount()==original->columnCount(),"map dimensions preserved");
    bool tiles=true,occupancyEmpty=true;
    for(int y=0;y<original->rowCount();++y)for(int x=0;x<original->columnCount();++x){
        const auto &a=original->getTileAt(x,y), &b=restored->getTileAt(x,y);
        tiles &= a==b && a.elevation==b.elevation && a.yOffset==b.yOffset;
        occupancyEmpty &= restored->entitiesAt(x,y).empty();
    }
    check(tiles,"all tile values and derived slopes/blends/frames match");
    check(occupancyEmpty,"detached map awaits entity reconstruction");
    check(restored->tilesUpdated(),"restored map render invalidated");
    check(restored->elevationAt(MapPos(8*48+24,8*48+24))==original->elevationAt(MapPos(8*48+24,8*48+24)),"elevation query agrees after restore");
    agepad::SaveWriter rectangle;
    rectangle.u32(1);rectangle.u32(6);rectangle.u32(4);
    for(int y=0;y<4;++y)for(int x=0;x<6;++x){rectangle.u32(x==5 && y==3 ? 2 : 0);rectangle.i32(0);}
    auto rectangular=Map::fromTerrainSave(rectangle.bytes);
    check(rectangular->columnCount()==6 && rectangular->rowCount()==4,"rectangular map orientation preserved");
    check(rectangular->getTileAt(5,3).terrainId==2 && rectangular->getTileAt(0,0).terrainId==0,"rectangular landmark preserved");
    // An invalid column must not alias the next row after flattening x/y.
    check(!rectangular->isValidTile(6,0) && !rectangular->isValidTile(unsigned(-1),1),
          "positive and negative column overflow cannot alias valid row tiles");
    check(!rectangular->isValidTile(0,4) && !rectangular->isValidTile(0,unsigned(-1)),
          "row bounds validated independently");
#ifdef NDEBUG
    const Map &constRectangle=*rectangular;
    check(&rectangular->getTileAt(6,0)==&MapTile::null &&
          &constRectangle.getTileAt(unsigned(-1),1)==&MapTile::null,
          "release tile access returns sentinel instead of an aliased terrain tile");
#endif
    auto edgeManager=std::make_shared<UnitManager>();edgeManager->setMap(rectangular);
    auto edgePlayer=std::make_shared<Player>(1,1,rectangular,ResourceMap{});
    auto edgeUnit=UnitFactory::createUnit(74,edgePlayer,*edgeManager);
    rectangular->addEntityAt(0,1,edgeUnit,-1);
    check(rectangular->entitiesAt(0,1).size()==1 && rectangular->entitiesAt(6,0).empty(),
          "out-of-bounds entity read does not wrap to next row");
    rectangular->removeEntityAt(6,0,edgeUnit->id);
    check(rectangular->entitiesAt(0,1).size()==1,"invalid removal preserves valid tile occupant");
    rectangular->addEntityAt(-1,1,edgeUnit,-1);
    check(rectangular->entitiesAt(5,0).empty(),"negative column insertion cannot wrap into previous row");
    rectangular->addEntityAt(6,0,edgeUnit,-1);
    check(rectangular->entitiesAt(0,1).size()==1,"invalid positive insertion cannot alter next row");
    const auto edgeTerrain=rectangular->saveTerrain();
    rectangular->setTileAt(6,0,2);rectangular->setTileAt(unsigned(-1),1,2);
    check(!rectangular->updateTileAt(6,0,2) && !rectangular->updateTileAt(-1,1,2),
          "terrain updates reject either column overflow");
    check(rectangular->saveTerrain()==edgeTerrain,"invalid terrain writes leave map unchanged");
    const auto before=original->saveTerrain();
    for(std::size_t n : {std::size_t(0),std::size_t(4),std::size_t(8),std::size_t(12),saved.size()/2,saved.size()-1}){
        agepad::SaveBytes partial(saved.begin(),saved.begin()+n);
        check(rejected([&]{Map::fromTerrainSave(partial);}),"truncated terrain refused");
    }
    auto bad=saved;bad[4]=0;bad[5]=0;bad[6]=0;bad[7]=0;
    check(rejected([&]{Map::fromTerrainSave(bad);}),"zero dimensions refused");
    bad=saved;bad[4]=0;bad[5]=1;
    check(rejected([&]{Map::fromTerrainSave(bad);}),"oversized dimensions refused");
    bad=saved;for(int i=12;i<16;++i)bad[i]=255;
    check(rejected([&]{Map::fromTerrainSave(bad);}),"unknown terrain ID refused");
    bad=saved;for(int i=16;i<20;++i)bad[i]=255;
    check(rejected([&]{Map::fromTerrainSave(bad);}),"negative elevation refused");
    bad=saved;bad.push_back(0);
    check(rejected([&]{Map::fromTerrainSave(bad);}),"trailing terrain bytes refused");
    check(original->saveTerrain()==before,"failed detached loads never alter original map");
    std::cout << "map_save_checks=" << checks << " errors=0\n";
    return 0;
} catch (const std::exception &error) {
    std::cerr << error.what() << '\n';
    return 1;
}
