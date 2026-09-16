#pragma once
#import <Foundation/Foundation.h>
// AppKit owns queued button interactions. Raw UIKit observation must not
// overwrite the logical pointer before those events reach the original window.
FOUNDATION_EXPORT BOOL DEOrderedMousePointerIsHeld(void);
