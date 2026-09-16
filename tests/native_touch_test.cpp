#ifdef NDEBUG
#undef NDEBUG
#endif
#include "settings/TouchInput.h"
#include <cassert>
#include <iostream>
sf::Event touch(sf::Event::EventType type, int x, int y, unsigned finger=0) {
    sf::Event e{}; e.type=type; e.touch={finger,x,y}; return e;
}
int main() {
    TouchInput input;
    assert(input.translate(touch(sf::Event::TouchBegan,10,20),0,true).empty());
    auto tap=input.translate(touch(sf::Event::TouchEnded,10,20),100,true);
    assert(tap.size()==2 && tap[0].type==sf::Event::MouseButtonPressed && tap[1].type==sf::Event::MouseButtonReleased && tap[1].mouseButton.button==sf::Mouse::Left);
    input.translate(touch(sf::Event::TouchBegan,10,20),200,true);
    auto order=input.translate(touch(sf::Event::TouchEnded,10,20),700,true);
    assert(order.size()==2 && order[0].mouseButton.button==sf::Mouse::Right && order[1].mouseButton.button==sf::Mouse::Right);
    input.translate(touch(sf::Event::TouchBegan,10,20),800,true);
    auto drag=input.translate(touch(sf::Event::TouchMoved,50,80),900,true);
    assert(drag.size()==2 && drag[0].mouseButton.x==10 && drag[1].mouseMove.x==50);
    auto end=input.translate(touch(sf::Event::TouchEnded,60,90),1400,true);
    assert(end.size()==2 && end[1].mouseButton.button==sf::Mouse::Left);
    input.translate(touch(sf::Event::TouchBegan,10,20),1500,false);
    auto panel=input.translate(touch(sf::Event::TouchEnded,10,20),2100,false);
    assert(panel.size()==2 && panel[1].mouseButton.button==sf::Mouse::Left);
    input.translate(touch(sf::Event::TouchBegan,10,20),2200,true);
    sf::Event loss{}; loss.type=sf::Event::LostFocus; input.translate(loss,2250,true);
    assert(input.translate(touch(sf::Event::TouchEnded,10,20),3000,true).empty());
    assert(input.translate(touch(sf::Event::TouchBegan,10,20,1),3100,true).empty());
    assert(input.translate(touch(sf::Event::TouchEnded,10,20,1),3200,true).empty());
    input.takeCancellation();
    input.translate(touch(sf::Event::TouchBegan,10,20),4000,true);
    auto startedDrag=input.translate(touch(sf::Event::TouchMoved,50,80),4100,true);
    assert(startedDrag.size()==2);
    assert(input.translate(touch(sf::Event::TouchBegan,80,80,1),4200,true).empty());
    assert(input.takeCancellation() && !input.takeCancellation());
    assert(input.translate(touch(sf::Event::TouchEnded,50,80),4700,true).empty());
    assert(input.translate(touch(sf::Event::TouchEnded,80,80,1),4800,true).empty());
    // The primary may lift first and touch again while the other finger stays.
    input.translate(touch(sf::Event::TouchBegan,10,20),5000,true);
    input.translate(touch(sf::Event::TouchBegan,80,80,1),5100,true);
    input.translate(touch(sf::Event::TouchEnded,10,20),5200,true);
    assert(input.translate(touch(sf::Event::TouchBegan,30,40),5300,true).empty());
    input.translate(touch(sf::Event::TouchEnded,80,80,1),5400,true);
    assert(input.translate(touch(sf::Event::TouchEnded,30,40),6000,true).empty());
    input.takeCancellation();
    input.translate(touch(sf::Event::TouchBegan,10,20),6100,true);
    assert(input.translate(touch(sf::Event::TouchEnded,10,20),6200,true).size()==2);
    // Focus loss also clears all contact IDs, so the next gesture is usable.
    input.translate(touch(sf::Event::TouchBegan,10,20),6300,true);
    input.translate(touch(sf::Event::TouchBegan,80,80,1),6400,true);
    input.translate(loss,6500,true);assert(input.takeCancellation());
    assert(input.translate(touch(sf::Event::TouchEnded,10,20),6600,true).empty());
    input.translate(touch(sf::Event::TouchBegan,10,20),6700,true);
    assert(input.translate(touch(sf::Event::TouchEnded,10,20),6800,true).size()==2);
    std::cout << "tap, hold-order, drag, panel hold, focus cancellation, secondary contact, interrupted drag, contact overlap, fresh gesture recovery: passed\n";
}
