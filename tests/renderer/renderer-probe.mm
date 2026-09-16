#include <SFML/Main.hpp>
#include <SFML/Graphics.hpp>
#import <Foundation/Foundation.h>
#include <cstdio>
int main(int,char**) {
    sf::RenderWindow window(sf::VideoMode(800,600),"Renderer probe",sf::Style::Resize);
    sf::Image source; source.create(8,8);
    for(unsigned y=0;y<8;++y)for(unsigned x=0;x<8;++x)
        source.setPixel(x,y,sf::Color(x*31,y*31,255-x*17,(x+y)%4*85));
    sf::Texture texture;if(!texture.loadFromImage(source))return 2;
    sf::RenderTexture first,second;if(!first.create(64,64)||!second.create(64,64))return 3;
    NSString* documents=NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES).firstObject;
    const sf::BlendMode modes[]={sf::BlendAlpha,sf::BlendNone,sf::BlendAdd,sf::BlendMultiply,
        sf::BlendMode(sf::BlendMode::Zero,sf::BlendMode::SrcAlpha),
        sf::BlendMode(sf::BlendMode::DstColor,sf::BlendMode::OneMinusSrcAlpha)};
    int count=0;
    for(int scale=0;scale<2;++scale)for(int mode=0;mode<6;++mode)for(int background=0;background<2;++background) {
        first.clear(background?sf::Color(47,83,29,255):sf::Color::Transparent);
        sf::Sprite sprite(texture);sprite.setPosition(4,5);sprite.setScale(scale?6.f:6.25f,scale?6.f:5.5f);
        first.draw(sprite,modes[mode]);first.display();
        sf::Image pixels=first.getTexture().copyToImage();
        NSString* path=[documents stringByAppendingPathComponent:[NSString stringWithFormat:@"renderer-%d-%d-%d.png",scale,mode,background]];
        if(!pixels.saveToFile(path.UTF8String))return 4;
        second.clear(sf::Color(23,57,99));sf::Sprite composite(first.getTexture());second.draw(composite);second.display();
        path=[documents stringByAppendingPathComponent:[NSString stringWithFormat:@"composite-%d-%d-%d.png",scale,mode,background]];
        if(!second.getTexture().copyToImage().saveToFile(path.UTF8String))return 5;
        ++count;
    }
    using GetError=unsigned (*)();
    using BlendSeparate=void (*)(unsigned,unsigned,unsigned,unsigned);
    using EquationSeparate=void (*)(unsigned,unsigned);
    using GetInteger=void (*)(unsigned,int*);
    auto error=reinterpret_cast<GetError>(sf::Context::getFunction("glGetError"));
    auto blend=reinterpret_cast<BlendSeparate>(sf::Context::getFunction("glBlendFuncSeparateOES"));
    auto equation=reinterpret_cast<EquationSeparate>(sf::Context::getFunction("glBlendEquationSeparateOES"));
    auto getInteger=reinterpret_cast<GetInteger>(sf::Context::getFunction("glGetIntegerv"));
    if(!error||!blend||!equation||!getInteger)return 6;
    error();blend(0xffff,0,1,0);unsigned blendError=error();
    equation(0xffff,0x8006);unsigned equationError=error();
    int sourceRGB=0,sourceAlpha=0;getInteger(0x80c9,&sourceRGB);getInteger(0x80cb,&sourceAlpha);unsigned queryError=error();
    printf("BLEND_VALIDATION=%x,%x QUERY_ERROR=%x SOURCE_FACTORS=%x,%x\n",blendError,equationError,queryError,sourceRGB,sourceAlpha);
    if(blendError!=0x500||equationError!=0x500||queryError!=0)return 7;
    window.clear(sf::Color(23,57,99));sf::Sprite shown(second.getTexture());shown.setScale(8,8);shown.setPosition(40,40);window.draw(shown);window.display();
    printf("AGEPAD_SFML_RENDER_CASES=%d snapshots=48 directory=%s\n",count,documents.UTF8String);fflush(stdout);
    sf::Clock clock;while(window.isOpen()&&clock.getElapsedTime().asSeconds()<12) {sf::Event e;while(window.pollEvent(e)){if(e.type==sf::Event::Closed)window.close();}sf::sleep(sf::milliseconds(20));}
    printf("AGEPAD_SFML_RENDER_RESULT=0\n");fflush(stdout);return 0;
}
