#include "global/Config.h"
#include "resource/DataManager.h"
#include "resource/AssetManager.h"
#include "audio/AudioPlayer.h"
#include <genie/dat/Civ.h>
#include <genie/dat/Unit.h>
#include <chrono>
#include <thread>
#include <iostream>
#include <stdexcept>

static void waitMs(int duration) {
    std::this_thread::sleep_for(std::chrono::milliseconds(duration));
}

int main(int argc, char **argv) try {
    if (argc != 2) throw std::runtime_error("Expected verified snapshot path");
    auto &config = Config::Inst();
    config.testMode = true;
    config.setValue(Config::GamePath, argv[1]);
    char program[] = "agepad-audio-test";
    char diagnostics[] = "--audio-diagnostics";
    char *options[] = {program, diagnostics};
    if (!config.parseOptions(2, options) || !config.isOptionSet(Config::AudioDiagnostics))
        throw std::runtime_error("Bare audio-diagnostics option was not enabled");
    auto &data = DataManager::Inst();
    if (!data.initialize()) throw std::runtime_error("DAT load failed");
    AssetManager::create(data.isHd());
    if (!AssetManager::Inst()->initialize(data.gameVersion())) throw std::runtime_error("Asset init failed");
    auto &audio = AudioPlayer::instance();
    size_t errors = 0;
    waitMs(300);
    const auto quiet = audio.outputStats();
    errors += quiet.callbacks == 0 || quiet.nonzeroSamples != 0;
    std::cout << "phase=silence callbacks=" << quiet.callbacks << " nonzero=" << quiet.nonzeroSamples << '\n';
    auto requireSilence = [&]() {
        const auto before = audio.outputStats();
        waitMs(300);
        const auto after = audio.outputStats();
        errors += after.nonzeroSamples != before.nonzeroSamples;
    };
    for (const char *stream : {"open.mp3", "scenario/w1a.mp3"}) {
        requireSilence();
        const auto before = audio.outputStats();
        const bool opened = audio.playStream(stream);
        waitMs(1200);
        const auto after = audio.outputStats();
        const auto nonzero = after.nonzeroSamples - before.nonzeroSamples;
        errors += !opened || nonzero == 0;
        std::cout << "phase=" << stream << " opened=" << opened << " nonzero=" << nonzero << '\n';
        if (opened) audio.stopStream(stream);
        waitMs(300);
    }
    // Verified input w1a is 6.217 seconds. Observe past EOF instead of
    // stopping at 1.2 seconds, which previously concealed endless narration.
    requireSilence();
    errors += !audio.playStream("scenario/w1a.mp3");
    waitMs(7500);
    const auto ended = audio.outputStats();
    waitMs(1500);
    const auto afterEnd = audio.outputStats();
    errors += afterEnd.nonzeroSamples != ended.nonzeroSamples;
    std::cout << "phase=narration-natural-end nonzero_after_eof="
              << afterEnd.nonzeroSamples-ended.nonzeroSamples << '\n';
    errors += !audio.playStream("scenario/w1a.mp3", true);
    waitMs(7500);
    const auto looping = audio.outputStats();
    waitMs(1500);
    const auto afterLoop = audio.outputStats();
    errors += afterLoop.nonzeroSamples == looping.nonzeroSamples;
    std::cout << "phase=explicit-loop nonzero_after_eof="
              << afterLoop.nonzeroSamples-looping.nonzeroSamples << '\n';
    audio.stopStream("scenario/w1a.mp3");
    waitMs(300);
    requireSilence();
    const auto &militia = data.civilization(1).Units.at(74);
    for (int sound : {militia.SelectionSound, militia.Action.MoveSound}) {
        requireSilence();
        const auto before = audio.outputStats();
        audio.playSound(sound, 1);
        waitMs(3000);
        const auto after = audio.outputStats();
        const auto nonzero = after.nonzeroSamples - before.nonzeroSamples;
        errors += sound < 0 || nonzero == 0;
        std::cout << "phase=unit sound=" << sound << " nonzero=" << nonzero << '\n';
    }
    config.setValue(Config::MusicVolume,"0");
    errors += !audio.playStream("scenario/w1a.mp3",true);
    waitMs(300);const auto muted=audio.outputStats();
    waitMs(500);const auto stillMuted=audio.outputStats();
    errors += stillMuted.nonzeroSamples!=muted.nonzeroSamples;
    config.setValue(Config::MusicVolume,"1");
    waitMs(1200);const auto audible=audio.outputStats();
    errors += audible.nonzeroSamples==stillMuted.nonzeroSamples;
    std::cout<<"phase=live-volume muted_samples="<<stillMuted.nonzeroSamples-muted.nonzeroSamples
             <<" resumed_samples="<<audible.nonzeroSamples-stillMuted.nonzeroSamples<<'\n';
    audio.stopStream("scenario/w1a.mp3");waitMs(300);
    config.setValue(Config::SoundVolume,"0");
    const auto effectsMuted=audio.outputStats();audio.playSound(militia.SelectionSound,1);waitMs(3000);
    errors += audio.outputStats().nonzeroSamples!=effectsMuted.nonzeroSamples;
    config.setValue(Config::SoundVolume,"1");
    errors += !audio.playStream("scenario/w1a.mp3",true);
    errors += !audio.playStream("open.mp3",true);
    audio.playSound(militia.SelectionSound,1);waitMs(250);
    audio.stopPlayback();audio.stopPlayback();waitMs(150);
    const auto stopped=audio.outputStats();waitMs(500);
    const auto afterStopped=audio.outputStats();
    errors += afterStopped.nonzeroSamples!=stopped.nonzeroSamples;
    std::cout<<"phase=world-audio-reset nonzero="<<afterStopped.nonzeroSamples-stopped.nonzeroSamples<<'\n';
    errors += !audio.playStream("scenario/w1a.mp3");waitMs(500);
    const auto restarted=audio.outputStats();errors += restarted.nonzeroSamples==afterStopped.nonzeroSamples;
    std::cout<<"phase=audio-after-world-reset nonzero="<<restarted.nonzeroSamples-afterStopped.nonzeroSamples<<'\n';
    audio.stopPlayback();
    const auto final = audio.outputStats();
    std::cout << "callbacks=" << final.callbacks << " frames=" << final.frames
              << " nonzero=" << final.nonzeroSamples << " lock_misses=" << final.lockMisses
              << " errors=" << errors << '\n';
    return errors ? 1 : 0;
} catch (const std::exception &error) {
    std::cerr << error.what() << '\n';
    return 1;
}
