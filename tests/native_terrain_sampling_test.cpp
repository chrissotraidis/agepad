#include "resource/HdTerrainSampling.h"
#include <iostream>

int main() try {
    sf::Image labelled;
    labelled.create(512, 512);
    for (unsigned y = 0; y < 512; ++y)
        for (unsigned x = 0; x < 512; ++x)
            labelled.setPixel(x, y, sf::Color(x % 256, y % 256, (x / 256) + 2 * (y / 256)));
    HdTerrainSampling sampler(labelled, 10, 10);
    size_t errors = 0, edges = 0;
    // Explicit corner landmarks establish orientation, scale, border and last cell.
    errors += sampler.sample(0, 0, 24) != labelled.getPixel(1, 1);
    errors += sampler.sample(0, 48, 0) != labelled.getPixel(52, 1);
    errors += sampler.sample(0, 96, 24) != labelled.getPixel(52, 52);
    errors += sampler.sample(0, 48, 48) != labelled.getPixel(1, 52);
    errors += sampler.sample(99, 0, 24) != labelled.getPixel(460, 460);
    errors += sampler.sample(99, 96, 24) != labelled.getPixel(511, 511);
    for (int x = 0; x < 10; ++x) {
        for (int y = 0; y < 10; ++y) {
            const int frame = x * 10 + y;
            for (int i = 0; i <= 24; ++i) {
                if (x < 9) {
                    errors += sampler.sample(frame, 48 + 2*i, i)
                           != sampler.sample(frame + 10, 2*i, 24 + i);
                    ++edges;
                }
                if (y < 9) {
                    errors += sampler.sample(frame, 48 + 2*i, 48 - i)
                           != sampler.sample(frame + 1, 2*i, 24 - i);
                    ++edges;
                }
            }
        }
    }
    for (int frame : {-1, 100}) {
        try { sampler.sample(frame, 48, 24); ++errors; }
        catch (const std::out_of_range &) {}
    }
    try { sampler.sample(0, 0, 0); ++errors; }
    catch (const std::out_of_range &) {}
    try { HdTerrainSampling invalid(labelled, 0, 10); ++errors; }
    catch (const std::runtime_error &) {}
    std::cout << "corner_landmarks=6 shared_edge_pixels=" << edges << " errors=" << errors << '\n';
    return errors ? 1 : 0;
} catch (const std::exception &error) {
    std::cerr << error.what() << '\n';
    return 1;
}
