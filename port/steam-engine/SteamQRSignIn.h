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

// Fallback: account name + password (+ Steam Guard). The password is only
// encrypted in memory with Steam's RSA key and sent; it is never stored or
// logged. askCode (blocking, off the main thread) returns the code for codeType
// 2 (email) or 3 (authenticator). waitingForApproval fires when Steam offers
// approval in the phone app. Returns the same keys as the QR sign-in.
NSDictionary *AgePadSteamPasswordSignIn(NSString *accountName,NSString *password,NSString *deviceName,
    NSString *(^askCode)(int codeType),void (^waitingForApproval)(void),NSString **error);

#ifdef __cplusplus
}
#endif
