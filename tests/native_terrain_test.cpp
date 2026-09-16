#include "global/Config.h"
#include "resource/DataManager.h"
#include "resource/AssetManager.h"
#include "resource/TerrainSprite.h"
#include "render/SfmlRenderTarget.h"
#include <genie/dat/Terrain.h>
#include <genie/resource/SlpTemplate.h>
#include <SFML/Graphics/Texture.hpp>
#include <SFML/Graphics/Image.hpp>
#include <iostream>
#include <stdexcept>

static sf::Image pixels(const Drawable::Image::Ptr &image) {
    const auto native = std::dynamic_pointer_cast<SfmlImage>(image);
    if (!native || !native->isValid()) throw std::runtime_error("Terrain render unavailable");
    return native->texture->copyToImage();
}

static size_t differences(const sf::Image &a, const sf::Image &b) {
    if (a.getSize() != b.getSize()) throw std::runtime_error("Terrain dimensions differ");
    size_t count = 0;
    for (unsigned y = 0; y < a.getSize().y; ++y)
        for (unsigned x = 0; x < a.getSize().x; ++x)
            count += a.getPixel(x, y) != b.getPixel(x, y);
    return count;
}

int main(int argc, char **argv) try {
    if (argc != 2) throw std::runtime_error("Expected verified snapshot path");
    Config::Inst().testMode = true;
    Config::Inst().setValue(Config::GamePath, argv[1]);
    auto &data = DataManager::Inst();
    if (!data.initialize()) throw std::runtime_error("DAT load failed");
    AssetManager::create(data.isHd());
    if (!AssetManager::Inst()->initialize(data.gameVersion())) throw std::runtime_error("Asset init failed");
    if (AssetManager::Inst()->missingData()) throw std::runtime_error("Supported terrain assets incorrectly reported missing");
    const auto &alias = data.getTerrain(20);
    const int target = alias.TerrainToDraw;
    if (target < 0 || target == 20) throw std::runtime_error("Fixture is not a terrain alias");
    std::cout << "alias=20 target=" << target << " alias_name=" << alias.Name2
              << " target_name=" << data.getTerrain(target).Name2 << '\n';
    for (int id : {0, 10, 20}) {
        const auto &record = data.getTerrain(id);
        std::cout << "terrain=" << id << " dimensions=" << record.TerrainDimensions.first
                  << "," << record.TerrainDimensions.second << '\n';
    }
    auto renderer = std::make_shared<SfmlRenderTarget>(Size(97, 49));
    TerrainSprite terrain(0);
    MapTile base;
    base.terrainId = 0;
    const auto baseImage = pixels(terrain.texture(base, renderer));
    size_t frameErrors = 0;
    sf::Image previous = baseImage;
    for (int x = 0; x < 10; ++x) {
        for (int y = 0; y < 10; ++y) {
            const int frame = terrain.coordinatesToFrame(x, y);
            frameErrors += frame != x * 10 + y;
            MapTile selected = base;
            selected.frame = frame;
            const auto current = pixels(terrain.texture(selected, renderer));
            if (x || y) frameErrors += differences(previous, current) == 0;
            previous = current;
        }
    }
    frameErrors += terrain.coordinatesToFrame(10, 0) != 0;
    frameErrors += terrain.coordinatesToFrame(0, 10) != 0;
    std::cout << "terrain_frames=100 frame_errors=" << frameErrors << '\n';
    size_t coverageErrors = 0;
    if (baseImage.getSize() != sf::Vector2u(97, 49)) {
        ++coverageErrors;
    } else {
        for (unsigned y = 0; y < 49; ++y) {
            const int extent = 2 * std::min(y, 48 - y);
            for (unsigned x = 0; x < 97; ++x) {
                const bool covered = std::abs(int(x) - 48) <= extent;
                coverageErrors += (baseImage.getPixel(x, y).a != 0) != covered;
            }
        }
    }
    std::cout << "terrain_size=" << baseImage.getSize().x << "," << baseImage.getSize().y
              << " diamond_coverage_errors=" << coverageErrors << '\n';
    size_t mismatches = 0, effective = 0;
    for (unsigned bit = 0; bit < Blend::BlendTileCount; ++bit) {
        Blend blend;
        blend.bits = 1u << bit;
        blend.terrainId = target;
        MapTile direct = base;
        direct.blends.push_back(blend);
        MapTile indirect = direct;
        indirect.blends[0].terrainId = 20;
        const auto expected = pixels(terrain.texture(direct, renderer));
        const auto actual = pixels(terrain.texture(indirect, renderer));
        effective += differences(baseImage, expected) > 0;
        mismatches += differences(expected, actual);
    }
    std::cout << "blend_masks=" << Blend::BlendTileCount << " effective_masks=" << effective
              << " alias_pixel_mismatches=" << mismatches << '\n';
    size_t slopeErrors=0,slopeCount=0;
    for(auto direction:{Slope::SouthUp,Slope::NorthUp,Slope::WestUp,Slope::EastUp,
        Slope::SouthWestUp,Slope::NorthWestUp,Slope::SouthEastUp,Slope::NorthEastUp,
        Slope::SouthWestEastUp,Slope::NorthWestEastUp,Slope::NorthSouthEastUp,Slope::NorthSouthWestUp}) {
        auto tile=base;tile.slopes.self=direction;
        const auto image=pixels(terrain.texture(tile,renderer));
        const auto slope=tile.slopes.self.toGenie();
        const auto &filter=AssetManager::Inst()->filtermapFile()->maps[slope];
        const auto &shape=AssetManager::Inst()->getSlpTemplateFile()->templates[slope];
        ++slopeCount;
        if(image.getSize()!=sf::Vector2u(97,filter.height)){++slopeErrors;continue;}
        for(unsigned y=0;y<filter.height;++y)for(unsigned x=0;x<97;++x) {
            const bool covered=int(x)>=shape.left_edges_[y] && int(x)<shape.left_edges_[y]+filter.lines[y].width;
            slopeErrors+=(image.getPixel(x,y).a==255)!=covered;
        }
    }
    std::cout<<"slope_shapes="<<slopeCount<<" slope_coverage_errors="<<slopeErrors<<'\n';
    return slopeErrors == 0 && frameErrors == 0 && coverageErrors == 0 && effective == Blend::BlendTileCount && mismatches == 0 ? 0 : 1;
} catch (const std::exception &error) {
    std::cerr << error.what() << '\n';
    return 1;
}
