#import "SteamQRSignIn.h"
#import <CoreImage/CoreImage.h>
#import <ImageIO/ImageIO.h>

NSString *const AgePadSteamRefreshToken=@"refresh_token";
NSString *const AgePadSteamAccountName=@"account_name";
NSString *const AgePadSteamID64=@"steam_id";

// Minimal protobuf writer/reader for the handful of fields used.
static void PutVarint(NSMutableData *out,uint64_t value) {
    do { uint8_t byte=value&0x7f;value>>=7;if (value) byte|=0x80;[out appendBytes:&byte length:1]; } while (value);
}
static void PutInt(NSMutableData *out,int field,uint64_t value) { PutVarint(out,(uint64_t)field<<3);PutVarint(out,value); }
static void PutBytes(NSMutableData *out,int field,NSData *value) { PutVarint(out,(uint64_t)field<<3|2);PutVarint(out,value.length);[out appendData:value]; }
static void PutString(NSMutableData *out,int field,NSString *value) { PutBytes(out,field,[value dataUsingEncoding:NSUTF8StringEncoding]); }
static BOOL GetVarint(const uint8_t *bytes,NSUInteger length,NSUInteger *at,uint64_t *value) {
    *value=0;
    for (int shift=0;*at<length && shift<64;shift+=7) { uint8_t byte=bytes[(*at)++];*value|=(uint64_t)(byte&0x7f)<<shift;if (!(byte&0x80)) return YES; }
    return NO;
}
// Field number -> NSNumber (varint/fixed) or NSData (length-delimited); last value wins.
static NSDictionary *Parse(NSData *data) {
    NSMutableDictionary *fields=[NSMutableDictionary dictionary];
    const uint8_t *bytes=data.bytes;NSUInteger length=data.length,at=0;
    while (at<length) {
        uint64_t key,value;if (!GetVarint(bytes,length,&at,&key)) break;
        int type=key&7;NSNumber *field=@(key>>3);
        if (type==0) { if (!GetVarint(bytes,length,&at,&value)) break;fields[field]=@(value); }
        else if (type==2) { if (!GetVarint(bytes,length,&at,&value) || at+value>length) break;fields[field]=[data subdataWithRange:NSMakeRange(at,value)];at+=value; }
        else if (type==5) { if (at+4>length) break;float f;memcpy(&f,bytes+at,4);fields[field]=@(f);at+=4; }
        else if (type==1) { if (at+8>length) break;uint64_t v;memcpy(&v,bytes+at,8);fields[field]=@(v);at+=8; }
        else break;
    }
    return fields;
}
static NSString *String(id value) { return [value isKindOfClass:NSData.class]?[[NSString alloc] initWithData:value encoding:NSUTF8StringEncoding]:nil; }

static NSDictionary *Call(NSString *method,NSData *body,int *eresult,NSString **error) {
    NSURL *url=[NSURL URLWithString:[NSString stringWithFormat:@"https://api.steampowered.com/IAuthenticationService/%@/v1/",method]];
    NSMutableURLRequest *request=[NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod=@"POST";request.timeoutInterval=20;
    [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    NSString *encoded=[[body base64EncodedStringWithOptions:0] stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.alphanumericCharacterSet];
    request.HTTPBody=[[@"input_protobuf_encoded=" stringByAppendingString:encoded] dataUsingEncoding:NSUTF8StringEncoding];
    __block NSData *reply=nil;__block NSHTTPURLResponse *response=nil;__block NSError *failure=nil;
    dispatch_semaphore_t done=dispatch_semaphore_create(0);
    [[NSURLSession.sharedSession dataTaskWithRequest:request completionHandler:^(NSData *d,NSURLResponse *r,NSError *e) {
        reply=d;response=(NSHTTPURLResponse *)r;failure=e;dispatch_semaphore_signal(done);
    }] resume];
    dispatch_semaphore_wait(done,DISPATCH_TIME_FOREVER);
    NSString *header=[response valueForHTTPHeaderField:@"x-eresult"];
    *eresult=header?header.intValue:(response.statusCode==200?1:0);
    if (failure || response.statusCode!=200) {
        if (error) *error=failure?failure.localizedDescription:[NSString stringWithFormat:@"%@ HTTP %ld eresult %d",method,(long)response.statusCode,*eresult];
        return nil;
    }
    return Parse(reply?:[NSData data]);
}

static NSString *SteamIDFromToken(NSString *token) {
    NSArray *parts=[token componentsSeparatedByString:@"."];
    if (parts.count<2) return nil;
    NSString *payload=[[parts[1] stringByReplacingOccurrencesOfString:@"-" withString:@"+"] stringByReplacingOccurrencesOfString:@"_" withString:@"/"];
    while (payload.length%4) payload=[payload stringByAppendingString:@"="];
    NSData *json=[[NSData alloc] initWithBase64EncodedString:payload options:0];
    NSDictionary *claims=json?[NSJSONSerialization JSONObjectWithData:json options:0 error:nil]:nil;
    id subject=[claims isKindOfClass:NSDictionary.class]?claims[@"sub"]:nil;
    return [subject isKindOfClass:NSString.class]?subject:nil;
}

NSDictionary *AgePadSteamQRSignIn(NSString *deviceName,NSTimeInterval timeout,AgePadSteamChallengeHandler onChallenge,NSString **error) {
    // k_EAuthTokenPlatformType_SteamClient = 1: the token audience Valve's client engine logs on with.
    NSMutableData *details=[NSMutableData data],*begin=[NSMutableData data];
    PutString(details,1,deviceName);PutInt(details,2,1);
    PutString(begin,1,deviceName);PutInt(begin,2,1);PutBytes(begin,3,details);PutString(begin,4,@"Client");
    int eresult=0;
    NSDictionary *session=Call(@"BeginAuthSessionViaQR",begin,&eresult,error);
    if (!session || eresult!=1) { if (error && !*error) *error=[NSString stringWithFormat:@"BeginAuthSessionViaQR eresult %d",eresult];return nil; }
    uint64_t clientID=[session[@1] unsignedLongLongValue];
    NSData *requestID=session[@3];
    double interval=MAX(1.0,[session[@4] doubleValue]?:5.0);
    NSString *challenge=String(session[@2]);
    if (!clientID || !requestID || !challenge) { if (error) *error=@"Steam returned an incomplete QR session";return nil; }
    onChallenge(challenge);
    NSDate *deadline=[NSDate dateWithTimeIntervalSinceNow:timeout];
    while (deadline.timeIntervalSinceNow>0) {
        [NSThread sleepForTimeInterval:interval];
        NSMutableData *poll=[NSMutableData data];
        PutInt(poll,1,clientID);PutBytes(poll,2,requestID);
        NSString *pollError=nil;
        NSDictionary *status=Call(@"PollAuthSessionStatus",poll,&eresult,&pollError);
        if (!status) { if (error) *error=pollError;return nil; } // expired or rejected
        if (status[@1]) clientID=[status[@1] unsignedLongLongValue];
        NSString *next=String(status[@2]);
        if (next.length && ![next isEqualToString:challenge]) { challenge=next;onChallenge(challenge); }
        NSString *token=String(status[@3]);
        if (token.length) {
            NSString *account=String(status[@6])?:@"";
            NSString *steamID=SteamIDFromToken(token);
            if (!steamID) { if (error) *error=@"Steam token did not name an account";return nil; }
            return @{AgePadSteamRefreshToken:token,AgePadSteamAccountName:account,AgePadSteamID64:steamID};
        }
    }
    if (error) *error=@"QR sign-in timed out";
    return nil;
}

NSData *AgePadSteamQRPNG(NSString *challengeURL,CGFloat pixels) {
    CIFilter *filter=[CIFilter filterWithName:@"CIQRCodeGenerator"];
    [filter setValue:[challengeURL dataUsingEncoding:NSUTF8StringEncoding] forKey:@"inputMessage"];
    [filter setValue:@"M" forKey:@"inputCorrectionLevel"];
    CIImage *code=filter.outputImage;
    // Four-module white quiet zone so phone cameras lock on reliably.
    CGFloat modules=code.extent.size.width+8,scale=MAX(1,floor(pixels/modules));
    code=[code imageByApplyingTransform:CGAffineTransformMakeScale(scale,scale)];
    CGRect frame=CGRectInset(code.extent,-4*scale,-4*scale);
    code=[code imageByCompositingOverImage:[[CIImage imageWithColor:CIColor.whiteColor] imageByCroppingToRect:frame]];
    CGImageRef image=[[CIContext context] createCGImage:code fromRect:frame];
    NSMutableData *png=[NSMutableData data];
    CGImageDestinationRef destination=CGImageDestinationCreateWithData((__bridge CFMutableDataRef)png,CFSTR("public.png"),1,NULL);
    CGImageDestinationAddImage(destination,image,NULL);CGImageDestinationFinalize(destination);
    CFRelease(destination);CGImageRelease(image);
    return png;
}
