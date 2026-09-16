#include "core/SimulationClock.h"
#include <iostream>
#include <stdexcept>
int main() try {
    int checks=0;
    auto check=[&](bool ok,const char *name) { ++checks; if (!ok) throw std::runtime_error(name); };
    auto rejected=[](auto action) { try {action();return false;} catch (const agepad::SaveError &) {return true;} };
    agepad::SimulationClock clock;
    check(clock.sample(4000,true)==4000,"fresh game advances");
    check(clock.sample(5000,false)==4000,"pause freezes simulation");
    check(clock.sample(100000,false)==4000,"long pause never accrues game time");
    check(clock.sample(100100,true)==4100,"resume advances only next interval");
    const auto saved=clock.time();
    agepad::SimulationClock restored;
    restored.reset(saved,900000);
    check(restored.sample(900000,true)==saved,"new platform origin retains saved game time");
    check(restored.sample(900500,true)==4600,"restored simulation advances normally");
    check(rejected([&]{restored.sample(900400,true);}),"backward wall clock refused");
    check(restored.time()==4600,"clock rejection preserves saved timeline");
    check(rejected([&]{restored.reset(-1,0);}),"negative saved time refused");
    check(rejected([&]{restored.reset(0,-1);}),"negative platform origin refused");
    check(restored.time()==4600,"failed reset preserves timeline");
    restored.reset(std::numeric_limits<std::int64_t>::max()-1,0);
    check(rejected([&]{restored.sample(2,true);}),"time overflow refused");
    check(restored.sample(1,true)==std::numeric_limits<std::int64_t>::max(),"failed sample preserves wall baseline");
    restored.reset(0,0);
    check(restored.sample(10,true)==10,"fresh session resets cleanly");
    std::cout << "simulation_clock_checks=" << checks << " errors=0\n";
    return 0;
} catch(const std::exception &e) { std::cerr << e.what() << '\n'; return 1; }
