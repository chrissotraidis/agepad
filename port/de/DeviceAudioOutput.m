// Physical iPad build unit: the Mac engine asks for macOS's default output
// unit ('def '), which iPadOS lacks. Compiled separately into the device
// AppKit boundary; the Simulator injects the same shim as its own library.
#include <TargetConditionals.h>
#if !TARGET_OS_SIMULATOR
#include "AudioOutputCompat.m"
#endif
