#include <SFML/Window/iOS/KeyboardMapping.hpp>
#include <iostream>
#include <stdexcept>
int main() try {
    using K=sf::Keyboard;
    int checks=0;
    auto check=[&](int hid,K::Key expected){++checks;if(sf::priv::keyFromHIDUsage(hid)!=expected)throw std::runtime_error("Unexpected mapping for HID "+std::to_string(hid));};
    check(74,K::Home);check(77,K::End);check(75,K::PageUp);check(78,K::PageDown);
    check(73,K::Insert);check(76,K::Delete);check(42,K::Backspace);
    for(int i=0;i<12;++i)check(58+i,K::Key(K::F1+i));
    for(int i=0;i<3;++i)check(104+i,K::Key(K::F13+i));
    check(72,K::Pause);
    for(int i=0;i<9;++i)check(89+i,K::Key(K::Numpad1+i));
    check(98,K::Numpad0);check(88,K::Enter);check(84,K::Divide);check(85,K::Multiply);check(86,K::Subtract);check(87,K::Add);
    check(45,K::Hyphen);check(46,K::Equal);check(47,K::LBracket);check(48,K::RBracket);check(49,K::Backslash);
    check(51,K::Semicolon);check(52,K::Apostrophe);check(53,K::Grave);check(54,K::Comma);check(55,K::Period);check(56,K::Slash);
    check(99,K::Period);check(101,K::Menu);check(103,K::Equal);
    for(int i=0;i<26;++i)check(4+i,K::Key(K::A+i));
    for(int i=0;i<9;++i)check(30+i,K::Key(K::Num1+i));
    check(39,K::Num0);check(40,K::Enter);check(41,K::Escape);check(43,K::Tab);check(44,K::Space);
    check(79,K::Right);check(80,K::Left);check(81,K::Down);check(82,K::Up);
    check(224,K::LControl);check(225,K::LShift);check(226,K::LAlt);check(227,K::LSystem);
    check(228,K::RControl);check(229,K::RShift);check(230,K::RAlt);check(231,K::RSystem);
    check(0,K::Unknown);check(57,K::Unknown);check(107,K::Unknown);check(4096,K::Unknown);
    std::cout<<"ios_keyboard_mapping_checks="<<checks<<" errors=0\n";
    return 0;
} catch(const std::exception &e){std::cerr<<e.what()<<"\n";return 1;}
