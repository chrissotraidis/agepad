#include "global/Config.h"
#include "resource/DataManager.h"
#include "resource/AssetManager.h"
#include "render/MapRenderer.h"
#include "render/UnitsRenderer.h"
#include "render/SfmlRenderTarget.h"
#include "mechanics/GameState.h"
#include "mechanics/Map.h"
#include "mechanics/Unit.h"
#include "mechanics/UnitManager.h"
#include "mechanics/Player.h"
#include <genie/script/ScnFile.h>
#include <SFML/Graphics/RenderTexture.hpp>
#include <SFML/Graphics/Image.hpp>
#include <filesystem>
#include <iostream>
#include <set>
int main(int argc,char**argv)try{
 if(argc!=3)return 2;Config::Inst().testMode=true;Config::Inst().setValue(Config::GamePath,argv[1]);
 auto&data=DataManager::Inst();if(!data.initialize())return 3;AssetManager::create(data.isHd());if(!AssetManager::Inst()->initialize(data.gameVersion()))return 4;
 genie::CpxFile campaign;campaign.load(AssetManager::Inst()->campaignsPath()+"/cam8.cpn");
 sf::RenderTexture texture;if(!texture.create(800,600))return 5;auto target=std::make_shared<SfmlRenderTarget>(texture);target->setSize(Size(800,600));
 auto state=std::make_shared<GameState>(target);state->setScenario(campaign.getScnFile(1));if(!state->init())return 6;
 state->ensureInitialUnitsVisible(ScreenRect(20,35,760,405));state->update(1000);
 std::set<std::pair<int,int>> expected;
 for(const auto&unit:state->unitManager()->units())if(unit->player().lock()==state->humanPlayer()){
   std::cout<<unit->debugName<<" pos="<<unit->position().x<<","<<unit->position().y<<" los="<<unit->data()->LineOfSight<<'\n';
   const int radius=unit->data()->LineOfSight,cx=unit->position().x/Constants::TILE_SIZE,cy=unit->position().y/Constants::TILE_SIZE;
   for(int y=-radius;y<=radius;++y)for(int x=-radius;x<=radius;++x)if(x*x+y*y<radius*radius)expected.emplace(cx+x,cy+y);
 }
 unsigned missing=0;for(auto [x,y]:expected)if(x>=0 && y>=0 && x<state->map()->columnCount() && y<state->map()->rowCount() && state->humanPlayer()->visibility->visibilityAt(x,y)!=VisibilityMap::Visible)++missing;
 std::cout<<"expected_visible="<<expected.size()<<" missing="<<missing<<'\n';
 std::filesystem::create_directories(argv[2]);
 MapRenderer renderer;renderer.setRenderTarget(target);renderer.setMap(state->map());renderer.setVisibilityMap(state->humanPlayer()->visibility);
 auto capture=[&](const char*name){texture.clear();renderer.update(1000);renderer.display();texture.display();auto image=texture.getTexture().copyToImage();image.saveToFile((std::filesystem::path(argv[2])/name).string());return image;};
 state->humanPlayer()->visibility->isDirty=true;
 renderer.update(1000);
 if(state->humanPlayer()->visibility->isDirty)throw std::runtime_error("terrain update must consume visibility invalidation");
 const auto first=capture("normal.png");
 state->humanPlayer()->visibility->isDirty=true;
 const auto redrawn=capture("redrawn.png");
 unsigned initialDifferences=0;
 for(unsigned y=0;y<600;++y)for(unsigned x=0;x<800;++x)initialDifferences+=first.getPixel(x,y)!=redrawn.getPixel(x,y);
 std::cout<<"initial_redraw_pixel_differences="<<initialDifferences<<'\n';
 for(Time t=1100;t<=30000;t+=100)state->update(t);
 capture("normal-late.png");
 UnitsRenderer units;units.setUnitManager(state->unitManager());units.setVisibilityMap(state->humanPlayer()->visibility);units.begin(target);
 std::vector<EntityPtr> visible;
 for(int x=renderer.firstVisibleColumn();x<renderer.lastVisibleColumn();++x)for(int y=renderer.firstVisibleRow();y<renderer.lastVisibleRow();++y)for(auto&e:state->map()->entitiesAt(x,y))visible.push_back(e.lock());
 units.render(target,visible);units.display(target);texture.display();texture.getTexture().copyToImage().saveToFile((std::filesystem::path(argv[2])/"with-units.png").string());
 auto revealed=std::make_shared<VisibilityMap>(-1);
 for(int y=0;y<state->map()->rowCount();++y)for(int x=0;x<state->map()->columnCount();++x)revealed->addUnitLookingAt(x,y);
 renderer.setVisibilityMap(revealed);const auto image=capture("revealed.png");
 unsigned holes=0;for(unsigned y=100;y<200;++y)for(unsigned x=320;x<550;++x)holes+=image.getPixel(x,y)==sf::Color::Black;
 std::cout<<"interior_terrain_holes="<<holes<<"\n";if(holes)return 1;
 return missing || initialDifferences?1:0;
}catch(const std::exception&e){std::cerr<<e.what()<<'\n';return 1;}
