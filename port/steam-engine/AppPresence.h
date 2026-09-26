// Whether AgePad is the active foreground app, for the Steam engine's
// "computer in use" and front-process questions (CSteamEngine::CheckForComputerUse).
// iPadOS has no system-wide input-idle or process-manager API; while AgePad is
// active the player is using it, which is what Steam asks.
#pragma once
#import <UIKit/UIKit.h>
#include <stdatomic.h>
static _Atomic int AgePadAppActive=1;
static _Atomic double AgePadInactiveSince;
__attribute__((constructor)) static void AgePadWatchPresence(void) {
    NSNotificationCenter *center=NSNotificationCenter.defaultCenter;
    [center addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:nil usingBlock:^(NSNotification *n) {
        atomic_store(&AgePadAppActive,1);
    }];
    [center addObserverForName:UIApplicationWillResignActiveNotification object:nil queue:nil usingBlock:^(NSNotification *n) {
        atomic_store(&AgePadInactiveSince,NSProcessInfo.processInfo.systemUptime);atomic_store(&AgePadAppActive,0);
    }];
}
