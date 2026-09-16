#include "settings/PinchInput.h"
#include "settings/TouchInput.h"
#include <iostream>
#include <stdexcept>
sf::Event touch(sf::Event::EventType type,int x,int y,unsigned finger) {
    sf::Event e{};e.type=type;e.touch={finger,x,y};return e;
}
int main() try {
    int checks=0;auto check=[&](bool ok,const char *why){++checks;if(!ok)throw std::runtime_error(why);};
    PinchInput pinch;TouchInput single;std::int64_t now=0;
    auto feed=[&](sf::Event e,bool world=true){single.translate(e,now+=100,true);return pinch.translate(e,world);};
    check(!feed(touch(sf::Event::TouchBegan,100,100,0)),"one contact does not zoom");
    check(!feed(touch(sf::Event::TouchBegan,200,100,1)) && single.takeCancellation(),"second contact cancels pending world gesture");
    auto out=feed(touch(sf::Event::TouchMoved,300,100,1));
    check(out && out->ratio==2 && out->x==200 && out->y==100,"spread gives ratio and midpoint");
    out=feed(touch(sf::Event::TouchMoved,200,100,1));
    check(out && out->ratio==0.5f,"pinch inward shrinks");
    feed(touch(sf::Event::TouchBegan,150,150,2));
    check(!feed(touch(sf::Event::TouchMoved,350,100,1)),"third contact blocks zoom");
    feed(touch(sf::Event::TouchEnded,150,150,2));
    check(!feed(touch(sf::Event::TouchMoved,300,100,1)),"third contact removal does not resume old gesture");
    feed(touch(sf::Event::TouchEnded,100,100,0));feed(touch(sf::Event::TouchEnded,300,100,1));
    feed(touch(sf::Event::TouchBegan,100,100,0),false);feed(touch(sf::Event::TouchBegan,200,100,1));
    check(!feed(touch(sf::Event::TouchMoved,300,100,1)),"HUD start cannot become world pinch");
    sf::Event loss{};loss.type=sf::Event::LostFocus;feed(loss);
    check(!feed(touch(sf::Event::TouchMoved,400,100,1)),"focus loss clears contacts");
    feed(touch(sf::Event::TouchBegan,100,100,0));feed(touch(sf::Event::TouchBegan,200,100,1));
    check(bool(feed(touch(sf::Event::TouchMoved,250,100,1))),"fresh gesture after focus loss works");
    check(!feed(touch(sf::Event::TouchMoved,300,100,1),false),"leaving world blocks pinch");
    check(!feed(touch(sf::Event::TouchMoved,250,100,1)),"returning from HUD does not resume gesture");
    std::cout<<"pinch_checks="<<checks<<" errors=0\n";
    return 0;
} catch(const std::exception &e){std::cerr<<e.what()<<'\n';return 1;}
