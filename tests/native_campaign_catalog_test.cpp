#include "core/CampaignCatalog.h"
#include "core/SaveFingerprint.h"
#include <genie/script/ScnFile.h>
#include <iostream>
#include <sstream>
#include <set>
#include <stdexcept>

int main(int argc,char **argv) try {
    if(argc!=2)throw std::runtime_error("Expected verified input root");
    const auto catalog=agepad::campaignCatalog(argv[1],true);
    if(catalog.size()!=9)throw std::runtime_error("Incomplete baseline catalog");
    unsigned missions=0;std::set<std::string> identities;
    for(const auto &entry:catalog) {
        if(!entry.available())throw std::runtime_error("Missing baseline archive: "+entry.key);
        genie::CpxFile archive;archive.setFileName(entry.archive.string());archive.load();
        if(archive.getFilecount()!=entry.missionCount)throw std::runtime_error("Wrong mission count: "+entry.key);
        std::cout<<"campaign="<<entry.key<<" archive_name="<<archive.name<<" missions="<<archive.getFilecount()<<"\n";
        for(unsigned index=0;index<archive.getFilecount();++index) {
            const auto scenario=archive.getScnFile(index);
            if(!scenario)throw std::runtime_error("Missing scenario");
            std::ostringstream output(std::ios::binary);scenario->writeObject(output);
            const auto bytes=output.str();
            const auto identity=agepad::SaveFingerprint::bytes(agepad::SaveBytes(bytes.begin(),bytes.end()));
            if(!identities.insert(identity).second)throw std::runtime_error("Duplicate scenario identity");
            ++missions;
        }
    }
    std::cout<<"campaign_archives="<<catalog.size()<<" decoded_unique_missions="<<missions<<" errors=0\n";
    return 0;
} catch(const std::exception &error) {std::cerr<<error.what()<<"\n";return 1;}
