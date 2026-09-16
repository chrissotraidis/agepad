#include "core/SimulationRandom.h"
#include <random>
#include <iostream>
#include <stdexcept>
int main() try {
    int checks=0;
    auto check=[&](bool ok,const char *name){++checks;if(!ok)throw std::runtime_error(name);};
    agepad::SimulationRandom stream;
    std::minstd_rand reference(1);
    bool equal=true;for(int i=0;i<10000;++i)equal &= stream.next()==reference();
    check(equal,"explicit generator agrees with standard transition for 10000 draws");
    const auto saved=stream.saveRuntime();agepad::SimulationRandom restored;restored.restoreRuntime(saved);
    bool resumed=true;for(int i=0;i<10000;++i)resumed &= stream.bounded(i%2 ? 100 : 2)==restored.bounded(i%2 ? 100 : 2);
    check(resumed,"saved stream resumes exact bounded draws");
    agepad::SimulationRandom first,second,control;
    bool isolated=true;for(int i=0;i<100;++i){second.next();second.next();isolated &= first.next()==control.next();}
    check(isolated,"independent game streams cannot disturb one another");
    const auto before=restored.saveRuntime();
    auto rejected=[&](const agepad::SaveBytes &bytes){try{restored.restoreRuntime(bytes);return false;}catch(const agepad::SaveError &){return restored.saveRuntime()==before;}};
    bool truncated=true;for(std::size_t n=0;n<saved.size();++n)truncated &= rejected(agepad::SaveBytes(saved.begin(),saved.begin()+n));
    check(truncated,"all truncations rejected without advancing stream");
    auto bad=saved;bad[0]=2;check(rejected(bad),"unknown generator schema refused");
    bad=saved;for(int i=4;i<8;++i)bad[i]=0;check(rejected(bad),"zero absorbing state refused");
    bad=saved;for(int i=4;i<8;++i)bad[i]=255;check(rejected(bad),"out-of-domain state refused");
    bad=saved;bad.push_back(0);check(rejected(bad),"trailing state bytes refused");
    bool bounds=false;try{restored.bounded(0);}catch(const std::invalid_argument &){bounds=true;}
    check(bounds && restored.saveRuntime()==before,"invalid bound does not consume randomness");
    std::cout << "random_save_checks=" << checks << " errors=0\n";return 0;
} catch(const std::exception &error){std::cerr << error.what() << '\n';return 1;}
