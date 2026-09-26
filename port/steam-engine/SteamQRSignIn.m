#import "SteamQRSignIn.h"
#import <CoreImage/CoreImage.h>
#import <ImageIO/ImageIO.h>
#import <Security/Security.h>

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
        // Repeated fields: every value, in order, under "*<field>".
        NSString *all=[NSString stringWithFormat:@"*%@",field];
        if (!fields[all]) fields[all]=[NSMutableArray array];
        [fields[all] addObject:fields[field]];
    }
    return fields;
}
static NSString *String(id value) { return [value isKindOfClass:NSData.class]?[[NSString alloc] initWithData:value encoding:NSUTF8StringEncoding]:nil; }

static NSDictionary *Call(NSString *method,NSData *body,int *eresult,NSString **error) {
    NSString *encoded=[[body base64EncodedStringWithOptions:0] stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.alphanumericCharacterSet];
    BOOL get=[method isEqualToString:@"GetPasswordRSAPublicKey"]; // a GET method in Steam's Web API
    NSString *address=[NSString stringWithFormat:@"https://api.steampowered.com/IAuthenticationService/%@/v1/",method];
    if (get) address=[address stringByAppendingFormat:@"?input_protobuf_encoded=%@",encoded];
    NSMutableURLRequest *request=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:address]];
    request.timeoutInterval=20;
    if (!get) {
        request.HTTPMethod=@"POST";
        [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
        request.HTTPBody=[[@"input_protobuf_encoded=" stringByAppendingString:encoded] dataUsingEncoding:NSUTF8StringEncoding];
    }
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

// Waits for an approved auth session and returns its Steam-client token.
static NSDictionary *PollForToken(uint64_t clientID,NSData *requestID,double interval,NSTimeInterval timeout,
                                  NSString *challenge,AgePadSteamChallengeHandler onChallenge,NSString **error) {
    int eresult=0;
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
        if (onChallenge && next.length && ![next isEqualToString:challenge]) { challenge=next;onChallenge(challenge); }
        NSString *token=String(status[@3]);
        if (token.length) {
            NSString *account=String(status[@6])?:@"";
            NSString *steamID=SteamIDFromToken(token);
            if (!steamID) { if (error) *error=@"Steam token did not name an account";return nil; }
            return @{AgePadSteamRefreshToken:token,AgePadSteamAccountName:account,AgePadSteamID64:steamID};
        }
    }
    if (error) *error=@"Sign-in timed out";
    return nil;
}
static NSData *DeviceDetails(NSString *deviceName) {
    // k_EAuthTokenPlatformType_SteamClient = 1: the token audience Valve's client engine logs on with.
    NSMutableData *details=[NSMutableData data];
    PutString(details,1,deviceName);PutInt(details,2,1);
    return details;
}

NSDictionary *AgePadSteamQRSignIn(NSString *deviceName,NSTimeInterval timeout,AgePadSteamChallengeHandler onChallenge,NSString **error) {
    NSMutableData *begin=[NSMutableData data];
    PutString(begin,1,deviceName);PutInt(begin,2,1);PutBytes(begin,3,DeviceDetails(deviceName));PutString(begin,4,@"Client");
    int eresult=0;
    NSDictionary *session=Call(@"BeginAuthSessionViaQR",begin,&eresult,error);
    if (!session || eresult!=1) { if (error && !*error) *error=[NSString stringWithFormat:@"BeginAuthSessionViaQR eresult %d",eresult];return nil; }
    uint64_t clientID=[session[@1] unsignedLongLongValue];
    NSData *requestID=session[@3];
    NSString *challenge=String(session[@2]);
    if (!clientID || !requestID || !challenge) { if (error) *error=@"Steam returned an incomplete QR session";return nil; }
    onChallenge(challenge);
    return PollForToken(clientID,requestID,MAX(1.0,[session[@4] doubleValue]?:5.0),timeout,challenge,onChallenge,error);
}

// DER RSAPublicKey { modulus, exponent } from Steam's hex strings.
static NSData *DERInteger(NSString *hex) {
    NSMutableData *value=[NSMutableData data];
    for (NSUInteger i=0;i+1<hex.length;i+=2) { unsigned byte;sscanf([hex substringWithRange:NSMakeRange(i,2)].UTF8String,"%2x",&byte);uint8_t b=byte;[value appendBytes:&b length:1]; }
    while (value.length>1 && ((uint8_t *)value.bytes)[0]==0) [value replaceBytesInRange:NSMakeRange(0,1) withBytes:NULL length:0];
    if (value.length && ((uint8_t *)value.bytes)[0]&0x80) [value replaceBytesInRange:NSMakeRange(0,0) withBytes:"\0" length:1]; // stays positive
    return value;
}
static void PutDER(NSMutableData *out,uint8_t tag,NSData *content) {
    [out appendBytes:&tag length:1];
    NSUInteger length=content.length;
    if (length<128) { uint8_t b=length;[out appendBytes:&b length:1]; }
    else { uint8_t lengthBytes[4];int count=0;for (NSUInteger l=length;l;l>>=8) lengthBytes[count++]=l&0xff;
           uint8_t b=0x80|count;[out appendBytes:&b length:1];for (int i=count-1;i>=0;i--) [out appendBytes:&lengthBytes[i] length:1]; }
    [out appendData:content];
}

NSDictionary *AgePadSteamPasswordSignIn(NSString *accountName,NSString *password,NSString *deviceName,
        NSString *(^askCode)(int codeType),void (^waitingForApproval)(void),NSString **error) {
    int eresult=0;
    NSMutableData *keyRequest=[NSMutableData data];PutString(keyRequest,1,accountName);
    NSDictionary *rsa=Call(@"GetPasswordRSAPublicKey",keyRequest,&eresult,error);
    NSString *modulus=String(rsa[@1]),*exponent=String(rsa[@2]);
    if (!modulus.length || !exponent.length) { if (error && !*error) *error=@"Steam didn't return its sign-in key";return nil; }
    NSMutableData *integers=[NSMutableData data],*der=[NSMutableData data];
    PutDER(integers,0x02,DERInteger(modulus));PutDER(integers,0x02,DERInteger(exponent));PutDER(der,0x30,integers);
    SecKeyRef key=SecKeyCreateWithData((__bridge CFDataRef)der,(__bridge CFDictionaryRef)@{
        (__bridge id)kSecAttrKeyType:(__bridge id)kSecAttrKeyTypeRSA,(__bridge id)kSecAttrKeyClass:(__bridge id)kSecAttrKeyClassPublic},NULL);
    // The password exists only here, in memory, and only its encrypted form is sent.
    NSData *encrypted=key?(__bridge_transfer NSData *)SecKeyCreateEncryptedData(key,kSecKeyAlgorithmRSAEncryptionPKCS1,
        (__bridge CFDataRef)[password dataUsingEncoding:NSUTF8StringEncoding],NULL):nil;
    if (key) CFRelease(key);
    if (!encrypted) { if (error) *error=@"Couldn't encrypt the password with Steam's key";return nil; }
    NSMutableData *begin=[NSMutableData data];
    PutString(begin,1,deviceName);PutString(begin,2,accountName);
    PutString(begin,3,[encrypted base64EncodedStringWithOptions:0]);PutInt(begin,4,[rsa[@3] unsignedLongLongValue]);
    PutInt(begin,5,1);PutInt(begin,6,1);PutInt(begin,7,1);PutString(begin,8,@"Client");PutBytes(begin,9,DeviceDetails(deviceName));
    NSDictionary *session=Call(@"BeginAuthSessionViaCredentials",begin,&eresult,error);
    if (!session || eresult!=1) {
        if (error) *error=eresult==5?@"Wrong account name or password.":eresult==84?@"Too many attempts. Wait a while and try again.":
            (*error?:[NSString stringWithFormat:@"Steam refused the sign-in (error %d).",eresult]);
        return nil;
    }
    uint64_t clientID=[session[@1] unsignedLongLongValue],steamID=[session[@5] unsignedLongLongValue];
    NSData *requestID=session[@2];
    // Steam Guard: 2 email code, 3 authenticator code, 4 approve in the Steam app, 1 none.
    int codeType=0;BOOL approval=NO;
    for (NSData *confirmation in session[@"*4"]) {
        int type=[Parse(confirmation)[@1] intValue];
        if ((type==3 || type==2) && !codeType) codeType=type;
        if (type==4) approval=YES;
    }
    if (approval && waitingForApproval) waitingForApproval();
    if (codeType) {
        NSString *code=askCode(codeType);
        if (!code.length) { if (error) *error=@"Sign-in cancelled.";return nil; }
        NSMutableData *update=[NSMutableData data];
        PutInt(update,1,clientID);
        PutVarint(update,2<<3|1);[update appendBytes:&steamID length:8]; // fixed64 steamid
        PutString(update,3,code);PutInt(update,4,codeType);
        Call(@"UpdateAuthSessionWithSteamGuardCode",update,&eresult,error);
        if (eresult!=1) { if (error) *error=eresult==65?@"That Steam Guard code didn't work.":[NSString stringWithFormat:@"Steam Guard code rejected (error %d).",eresult];return nil; }
    }
    return PollForToken(clientID,requestID,MAX(1.0,[session[@3] doubleValue]?:5.0),300,nil,nil,error);
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
