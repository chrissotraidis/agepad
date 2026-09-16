#include "global/Config.h"
#include "resource/DataManager.h"
#include "resource/AssetManager.h"
#include "resource/Sprite.h"
#include "render/GraphicRender.h"
#include <genie/dat/Civ.h>
#include <genie/dat/Unit.h>
#include <SFML/Graphics/Texture.hpp>
#include <SFML/Graphics/Image.hpp>
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
    size_t checked = 0, mismatches = 0, boundsErrors = 0;
    for (int unitId : {74, 83}) {
        const auto &unit = data.civilization(1).Units.at(unitId);
        const int graphicId = unit.StandingGraphic.first;
        const auto &graphic = data.getGraphic(graphicId);
        if (graphic.TransparentSelection != genie::Graphic::SelectOnPixels)
            throw std::runtime_error("Fixture does not use pixel selection");
        Sprite sprite(graphic, graphicId);
        if (!sprite.isValid()) throw std::runtime_error("Sprite unavailable");
        const size_t before = mismatches;
        for (unsigned orientation = 0; orientation < graphic.AngleCount; ++orientation) {
            const float angle = sprite.orientationToAngle(orientation);
            for (unsigned frame = 0; frame < graphic.FrameCount; ++frame) {
                const sf::Image image = sprite.texture(frame, angle, 0, ImageType::Base).copyToImage();
                for (unsigned y = 0; y < image.getSize().y; ++y) {
                    for (unsigned x = 0; x < image.getSize().x; ++x) {
                        const bool rendered = image.getPixel(x, y).a != 0;
                        const bool hit = sprite.containsCursorPos(ScreenPos(x, y), frame, angle);
                        mismatches += rendered != hit;
                        ++checked;
                    }
                }
                for (const ScreenPos &edge : {ScreenPos(-1, 0), ScreenPos(0, -1),
                        ScreenPos(image.getSize().x, 0), ScreenPos(0, image.getSize().y)}) {
                    mismatches += sprite.containsCursorPos(edge, frame, angle);
                    ++checked;
                }
            }
            GraphicRender renderer;
            if (!renderer.setSprite(graphicId)) throw std::runtime_error("Renderer sprite unavailable");
            renderer.setAngle(angle);
            const auto rect = renderer.rect();
            const auto size = sprite.size(0, angle);
            boundsErrors += rect.width < size.width || rect.height < size.height;
        }
        std::cout << "unit=" << unitId << " graphic=" << graphicId
                  << " pixel_mismatches=" << mismatches - before << '\n';
    }
    std::cout << "checked=" << checked << " mismatches=" << mismatches
              << " bounding_errors=" << boundsErrors << '\n';
    return checked > 0 && mismatches == 0 && boundsErrors == 0 ? 0 : 1;
} catch (const std::exception &error) {
    std::cerr << error.what() << '\n';
    return 1;
}
