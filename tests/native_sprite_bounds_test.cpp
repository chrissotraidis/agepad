#include "global/Config.h"
#include "resource/DataManager.h"
#include "resource/AssetManager.h"
#include "resource/Sprite.h"
#include <genie/dat/Civ.h>
#include <genie/dat/Unit.h>
#include <SFML/Graphics/RenderTexture.hpp>
#include <SFML/Graphics/Sprite.hpp>
#include <SFML/Graphics/Image.hpp>
#include <cstring>
#include <iostream>
#include <stdexcept>
int main(int argc,char **argv) try {
    if(argc!=2)throw std::runtime_error("snapshot required");
    Config::Inst().testMode=true;Config::Inst().setValue(Config::GamePath,argv[1]);
    auto &data=DataManager::Inst();if(!data.initialize())throw std::runtime_error("DAT");
    AssetManager::create(data.isHd());if(!AssetManager::Inst()->initialize(data.gameVersion()))throw std::runtime_error("assets");
    sf::RenderTexture full,cropped;
    if(!full.create(640,640)||!cropped.create(640,640))throw std::runtime_error("render target");
    size_t checks=0;uint64_t fullArea=0,cropArea=0;
    std::vector<std::pair<int,int>> ids{{1,74},{1,83},{1,72},{1,109}};
    for(const auto &unit:data.civilization(0).Units) {
        if(unit.Class==genie::Unit::Tree && unit.StandingGraphic.first>=0 && ids.size()<7) ids.push_back({0,unit.ID});
    }
    if(ids.size()!=7) throw std::runtime_error("three actual tree fixtures required");
    for(const auto &[civilization,id]:ids) {
        std::cout<<"fixture="<<id<<'\n';
        const auto &unit=data.civilization(civilization).Units.at(id);
        const auto gid=unit.StandingGraphic.first;
        if(gid<0)throw std::runtime_error("fixture graphic");
        Sprite sprite(data.getGraphic(gid),gid);
        if(!sprite.isValid())throw std::runtime_error("sprite unavailable");
        for(float angle:{0.f,3.14159265f}) for(auto type:{ImageType::Base,ImageType::Shadow,ImageType::InTheShadows,ImageType::Construction}) {
            const auto &texture=sprite.texture(0,angle,0,type);
            const auto size=texture.getSize();
            const auto bounds=sprite.textureBounds(0,angle,0,type);
            fullArea+=uint64_t(size.x)*size.y;cropArea+=uint64_t(bounds.width)*bounds.height;
            const auto source=texture.copyToImage();
            for(unsigned y=0;y<size.y;++y)for(unsigned x=0;x<size.x;++x)
                if(source.getPixel(x,y).a && !bounds.contains(x,y))throw std::runtime_error("bounds omit visible pixel");
            for(float scale:{0.5f,0.73f,1.f,1.25f,1.37f,1.5625f,2.f}) {
                const sf::Color background(47,83,29);
                full.clear(background);cropped.clear(background);
                sf::Sprite a(texture),b(texture);
                const auto hotspot=sprite.getHotspot(0,angle);
                const sf::Vector2f origin(320-hotspot.x*scale,320-hotspot.y*scale);
                a.setPosition(origin);a.setScale(scale,scale);full.draw(a);
                b.setTextureRect(bounds);b.setScale(scale,scale);
                b.setPosition(origin+sf::Vector2f(bounds.left*scale,bounds.top*scale));
                if(bounds.width>0&&bounds.height>0)cropped.draw(b);
                full.display();cropped.display();
                const auto expected=full.getTexture().copyToImage(),actual=cropped.getTexture().copyToImage();
                if(std::memcmp(expected.getPixelsPtr(),actual.getPixelsPtr(),640*640*4)) {
                    size_t changed=0;int maxDelta=0;
                    for(size_t i=0;i<640*640*4;++i){int diff=std::abs(int(expected.getPixelsPtr()[i])-int(actual.getPixelsPtr()[i]));changed+=diff!=0;maxDelta=std::max(maxDelta,diff);}
                    std::cerr<<"unit="<<id<<" type="<<int(type)<<" scale="<<scale<<" angle="<<angle<<" changed="<<changed<<" max_delta="<<maxDelta<<" bounds="<<bounds.left<<","<<bounds.top<<","<<bounds.width<<","<<bounds.height<<'\n';
                    throw std::runtime_error("pixel mismatch");
                }
                ++checks;
            }
        }
    }
    std::cout<<"sprite_pixel_comparisons="<<checks<<" full_quad_pixels="<<fullArea<<" cropped_quad_pixels="<<cropArea<<" errors=0\n";
    return 0;
}catch(const std::exception&e){std::cerr<<e.what()<<'\n';return 1;}
