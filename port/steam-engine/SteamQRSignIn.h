// Steam QR sign-in through Steam's public IAuthenticationService (the same
// service the Steam client and phone app use). Produces a Steam-client refresh
// token for Valve's own engine. AgePad never sees or stores a password here.
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

typedef void (^AgePadSteamChallengeHandler)(NSString *challengeURL);

#ifdef __cplusplus
extern "C" {
#endif

// Blocking; call off the main thread in apps. onChallenge runs whenever a new
// QR must be shown. Returns nil and sets error on failure or timeout.
NSDictionary *AgePadSteamQRSignIn(NSString *deviceName,NSTimeInterval timeout,
    AgePadSteamChallengeHandler onChallenge,NSString **error);
// Keys in the result.
extern NSString *const AgePadSteamRefreshToken,*const AgePadSteamAccountName,*const AgePadSteamID64;

// Renders a QR code PNG for a challenge URL (CoreImage).
NSData *AgePadSteamQRPNG(NSString *challengeURL,CGFloat pixels);

#ifdef __cplusplus
}
#endif
