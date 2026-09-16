#include "mechanics/EntitySaveIndex.h"
#include <iostream>
#include <stdexcept>
struct TestEntity : Entity {
    TestEntity() : Entity(Type::Decaying,"index test") {}
    Size tileSize() const override { return Size(1,1); }
};
int main() try {
    int checks=0;
    auto check=[&](bool ok,const char *name){++checks;if(!ok)throw std::runtime_error(name);};
    auto rejected=[](auto action){try{action();return false;}catch(const agepad::SaveError &){return true;}};
    using Index=agepad::EntitySaveIndex;
    Index index;
    auto first=std::make_shared<TestEntity>(), second=std::make_shared<TestEntity>();
    check(Index::reference(first)==first->id,"save reference uses runtime identity");
    check(Index::reference({})==Index::nullID,"absent reference has explicit sentinel");
    check(rejected([&]{index.entity(0);}),"resolution before registration completion refused");
    index.add(0,second);
    index.add(700,first);
    check(index.size()==2,"distinct saved records registered");
    check(rejected([&]{index.add(0,first);}),"duplicate saved ID refused");
    check(rejected([&]{index.add(701,first);}),"same object under multiple saved IDs refused");
    check(rejected([&]{index.add(Index::nullID,first);}),"sentinel record refused");
    check(rejected([&]{index.add(800,{});}),"null entity record refused");
    check(index.size()==2,"failed registration leaves index unchanged");
    index.seal();
    check(index.entity(0)==second,"saved ID zero is valid and independent of runtime order");
    check(index.entity(700)==first,"saved reference resolves to registered object");
    check(!index.entity(Index::nullID) && !index.unit(Index::nullID),"null references resolve safely");
    check(rejected([&]{index.entity(999);}),"dangling saved reference refused");
    check(rejected([&]{index.unit(700);}),"unit reference to nonunit refused");
    check(rejected([&]{index.add(900,std::make_shared<TestEntity>());}),"late registration refused");
    std::weak_ptr<Entity> retained=first;
    first.reset();
    check(!retained.expired() && index.entity(700)==retained.lock(),"staged entities retained until graph owns them");
    std::cout << "entity_index_checks=" << checks << " errors=0\n";
    return 0;
} catch(const std::exception &e){std::cerr<<e.what()<<'\n';return 1;}
