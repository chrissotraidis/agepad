#include "core/TextWrap.h"
#include <iostream>
#include <stdexcept>
#include <sstream>
int main()try {
    int checks=0;
    auto check=[&](bool b){++checks;if(!b)throw std::runtime_error("text wrap regression");};
    auto measure=[](const std::string&s){unsigned n=0;for(unsigned char c:s)if((c&0xc0)!=0x80)++n;return float(n);};
    const std::string message="In the status area at the bottom of the screen, you can see how much food the villager is carrying. The villager continues to gather food.";
    auto lines=agepad::wrapText(message,40,measure);
    check(lines.size()>1);std::string joined;
    for(const auto &line:lines){check(measure(line)<=40);if(!joined.empty())joined+=' ';joined+=line;}
    check(joined==message);
    check(agepad::wrapText("one\ntwo",40,measure)==std::vector<std::string>({"one","two"}));
    check(agepad::wrapText("abcdefgh",3,measure)==std::vector<std::string>({"abc","def","gh"}));
    check(agepad::wrapText("ééé",2,measure)==std::vector<std::string>({"éé","é"}));
    check(agepad::wrapText("",40,measure).empty());
    std::cout<<"text_wrap_checks="<<checks<<" errors=0\n";
}catch(const std::exception&e){std::cerr<<e.what()<<'\n';return 1;}
