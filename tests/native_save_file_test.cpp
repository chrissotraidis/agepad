#include "core/SaveFile.h"
#include "core/CampaignProgress.h"
#include <filesystem>
#include <fstream>
#include <iostream>
#include <sys/stat.h>
#include <unistd.h>

using namespace agepad;
int main() {
    int checks = 0, failures = 0;
    auto check = [&](bool ok, const char *name) {
        ++checks;
        if (!ok) { ++failures; std::cerr << "FAIL " << name << '\n'; }
    };
    auto rejected = [&](auto action) {
        try { action(); return false; } catch (const SaveError &) { return true; }
    };
    SaveIdentity identity{"test-input-sha", "test-classic-rules", 1};
    SaveDocument first{identity, {0,1,2,255,0,73}};
    auto encoded = encodeSave(first);
    check(decodeSave(encoded, identity).payload == first.payload, "binary payload round trip");
    check(encoded[8] == 1 && encoded[9] == 0, "little endian envelope version");
    bool allTruncated = true;
    for (std::size_t n = 0; n < encoded.size(); ++n)
        allTruncated &= rejected([&] { decodeSave(SaveBytes(encoded.begin(), encoded.begin()+n), identity); });
    check(allTruncated, "every truncation rejected");
    bool allCorrupt = true;
    for (std::size_t n = 0; n < encoded.size(); ++n) {
        auto bad = encoded; bad[n] ^= 1;
        allCorrupt &= rejected([&] { decodeSave(bad, identity); });
    }
    check(allCorrupt, "single bit corruption at every byte rejected");
    SaveDocument empty{identity, {}};
    check(decodeSave(encodeSave(empty), identity).payload.empty(), "empty payload storage round trip");
    auto hugeLength = encoded;
    for (int i = 16; i < 20; ++i) hugeLength[i] = 255;
    check(rejected([&] { decodeSave(hugeLength, identity); }), "oversized identity length refused");
    auto trailing = encoded; trailing.push_back(0);
    check(rejected([&] { decodeSave(trailing, identity); }), "trailing data rejected");
    for (int kind = 0; kind < 3; ++kind) {
        auto mismatch = identity;
        if (kind == 0) mismatch.input += "-changed";
        if (kind == 1) mismatch.rules += "-changed";
        if (kind == 2) ++mismatch.schema;
        check(rejected([&] { decodeSave(encoded, mismatch); }), "compatibility mismatch rejected");
    }
    auto badIdentity = first; badIdentity.identity.schema = 0;
    check(rejected([&] { encodeSave(badIdentity); }), "zero schema refused");
    badIdentity = first; badIdentity.identity.input = "";
    check(rejected([&] { encodeSave(badIdentity); }), "empty identity refused");
    char temp[] = "/tmp/agepad-save-test-XXXXXX";
    const auto directory = ::mkdtemp(temp);
    if (!directory) return 2;
    const std::filesystem::path root(directory), destination = root / "game.agepad";
    try {
        const auto progressPath = root / "Progress" / "completed.agepad";
        const std::string missionA(64, 'a'), missionB(64, 'b');
        CampaignProgress progress(progressPath, identity);
        check(progress.size() == 0 && !std::filesystem::exists(progressPath), "fresh progress does not invent completion");
        check(progress.markCompleted(missionB), "victory writes a separate completion record");
        CampaignProgress reopened(progressPath, identity);
        check(reopened.completed(missionB) && !reopened.completed(missionA), "completion survives a new store instance");
        check(!reopened.markCompleted(missionB) && reopened.size() == 1, "replaying a victory is idempotent");
        check(reopened.markCompleted(missionA), "another mission preserves previous completion");
        CampaignProgress ordered(progressPath, identity);
        check(ordered.size() == 2 && ordered.completed(missionA) && ordered.completed(missionB), "sorted completion set reloads");
        check(rejected([&] { ordered.markCompleted("unverified"); }), "invalid scenario identity cannot be recorded");
        auto otherInputs = identity; otherInputs.input += "changed";
        check(rejected([&] { CampaignProgress wrong(progressPath, otherInputs); }), "different input set cannot inherit victories");
        auto otherRules = identity; otherRules.rules += "changed";
        check(rejected([&] { CampaignProgress wrong(progressPath, otherRules); }), "different rules cannot inherit victories");
        auto progressIdentity = identity; progressIdentity.rules += "/campaign-progress-v1"; progressIdentity.schema = 1;
        const auto validProgress = readSave(progressPath, progressIdentity);
        auto malformedProgress = validProgress; malformedProgress.payload.push_back(0);
        writeSaveAtomic(progressPath, malformedProgress);
        check(rejected([&] { CampaignProgress bad(progressPath, identity); }), "malformed progress is reported instead of reset");
        check(readSave(progressPath, progressIdentity).payload == malformedProgress.payload, "rejected progress load preserves evidence");
        writeSaveAtomic(progressPath, validProgress);
        const auto blockedPath = root / "blocked-progress";
        CampaignProgress blocked(blockedPath, identity);
        std::filesystem::create_directory(blockedPath); std::ofstream(blockedPath / "keep") << "preserve";
        check(rejected([&] { blocked.markCompleted(missionA); }) && blocked.size() == 0,
            "failed completion write does not claim success in memory");
        check(std::filesystem::exists(blockedPath / "keep"), "failed completion write preserves destination");
        writeSaveAtomic(destination, first);
        check(readSave(destination, identity).payload == first.payload, "disk round trip");
        struct stat info{}; ::stat(destination.c_str(), &info);
        check((info.st_mode & 0777) == 0600, "private file permissions");
        auto second = first; second.payload = {9,8,7};
        writeSaveAtomic(destination, second);
        check(readSave(destination, identity).payload == second.payload, "atomic replacement visible");
        check(CampaignProgress(progressPath, identity).size() == 2, "world-save replacement cannot erase completion");
        check(rejected([&] { writeSaveAtomic(destination, badIdentity); }), "invalid write refused");
        check(readSave(destination, identity).payload == second.payload, "invalid write preserves existing save");
        std::filesystem::create_directory(root / "occupied");
        std::ofstream(root / "occupied" / "keep") << "old data";
        check(rejected([&] { writeSaveAtomic(root / "occupied", first); }), "rename failure reported");
        check(std::filesystem::exists(root / "occupied" / "keep"), "rename failure preserves destination");
        bool noTemps = true;
        for (const auto &entry : std::filesystem::directory_iterator(root))
            noTemps &= entry.path().filename().string().find(".tmp.") == std::string::npos;
        check(noTemps, "failed transaction cleans its temporary file");
        std::ofstream(root / "game.agepad.tmp.interrupted") << "partial interrupted save";
        check(readSave(destination, identity).payload == second.payload, "orphan temporary file cannot replace committed save");
        std::filesystem::create_symlink(destination, root / "link");
        check(rejected([&] { readSave(root / "link", identity); }), "symlink load refused");
        ::mkfifo((root / "fifo").c_str(), 0600);
        check(rejected([&] { readSave(root / "fifo", identity); }), "FIFO refused without blocking");
        check(rejected([&] { readSave(root / "missing", identity); }), "missing file reported");
        std::ofstream(root / "oversized", std::ios::binary).put('x');
        std::filesystem::resize_file(root / "oversized", maxSaveBytes + 1);
        check(rejected([&] { readSave(root / "oversized", identity); }), "oversized disk file refused before allocation");
        std::ofstream(destination, std::ios::binary | std::ios::trunc) << "broken";
        check(rejected([&] { readSave(destination, identity); }), "corrupt committed save reported");
    } catch (const std::exception &error) {
        ++failures; std::cerr << "Unexpected exception: " << error.what() << '\n';
    }
    std::filesystem::remove_all(root);
    std::cout << checks << " checks, " << failures << " failures\n";
    return failures ? 1 : 0;
}
