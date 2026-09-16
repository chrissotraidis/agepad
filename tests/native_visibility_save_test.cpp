#include "mechanics/Player.h"
#include <iostream>
#include <stdexcept>

struct Observer : EventListener {
    int discovered = 0, hidden = 0;
    Observer() {
        EventManager::registerListener(this, EventManager::TileDiscovered);
        EventManager::registerListener(this, EventManager::TileHidden);
    }
    void onTileDiscovered(int, int, int) override { ++discovered; }
    void onTileHidden(int, int, int) override { ++hidden; }
};
int main() try {
    int checks=0;
    auto check=[&](bool ok, const char *name) {
        ++checks;
        if (!ok) throw std::runtime_error(name);
    };
    auto rejected=[](auto action) {
        try { action(); return false; } catch (const agepad::SaveError &) { return true; }
    };
    auto original=std::make_unique<VisibilityMap>(1);
    original->setExplored(10,10);
    original->addUnitLookingAt(20,20);
    original->addUnitLookingAt(20,20);
    original->addUnitLookingAt(254,254);
    auto saved=original->saveRuntime();
    original.reset();
    auto restored=std::make_unique<VisibilityMap>(1);
    restored->isDirty=false;
    Observer observer;
    restored->restoreRuntime(saved);
    check(restored->saveRuntime()==saved,"exact visibility round trip");
    check(restored->isDirty,"render invalidated on restore");
    check(observer.discovered==0 && observer.hidden==0,"restore emits no gameplay visibility events");
    check(restored->visibilityAt(0,0)==VisibilityMap::Unexplored,"unexplored preserved");
    check(restored->visibilityAt(10,10)==VisibilityMap::Explored,"explored fog preserved");
    check(restored->visibilityAt(20,20)==VisibilityMap::Visible,"visible tile preserved");
    check(restored->visibilityAt(254,254)==VisibilityMap::Visible,"last map cell preserved");
    restored->removeUnitLookingAt(20,20);
    check(restored->visibilityAt(20,20)==VisibilityMap::Visible && observer.hidden==0,"one observer still sees tile");
    restored->removeUnitLookingAt(20,20);
    check(restored->visibilityAt(20,20)==VisibilityMap::Explored && observer.hidden==1,"last observer removal hides tile exactly once");
    restored->addUnitLookingAt(20,20);
    check(restored->visibilityAt(20,20)==VisibilityMap::Visible && observer.discovered==1,"continued sight can rediscover tile");
    const auto before=restored->saveRuntime();
    const auto discovered=observer.discovered, hidden=observer.hidden;
    for (std::size_t size : {std::size_t(0),std::size_t(4),std::size_t(8),std::size_t(12),std::size_t(16),std::size_t(19),saved.size()/2,saved.size()-1}) {
        agepad::SaveBytes partial(saved.begin(),saved.begin()+size);
        check(rejected([&] { restored->restoreRuntime(partial); }),"truncated section refused");
    }
    auto bad=saved; bad.push_back(0);
    check(rejected([&] { restored->restoreRuntime(bad); }),"trailing section bytes refused");
    bad=saved;bad[0]=2;
    check(rejected([&] { restored->restoreRuntime(bad); }),"unknown section version refused");
    bad=saved;bad[4]=2;
    check(rejected([&] { restored->restoreRuntime(bad); }),"different player refused");
    bad=saved;bad[8]=254;
    check(rejected([&] { restored->restoreRuntime(bad); }),"different dimensions refused");
    bad=saved;bad[12]=0;
    check(rejected([&] { restored->restoreRuntime(bad); }),"wrong count refused");
    bad=saved;
    for (int i=16;i<20;++i) bad[i]=255;
    check(rejected([&] { restored->restoreRuntime(bad); }),"negative reference count refused");
    check(restored->saveRuntime()==before,"malformed restoration leaves all cells unchanged");
    check(observer.discovered==discovered && observer.hidden==hidden,"failed restoration emits no events");
    std::cout << "visibility_save_checks=" << checks << " errors=0\n";
    return 0;
} catch (const std::exception &error) {
    std::cerr << error.what() << '\n'; return 1;
}
