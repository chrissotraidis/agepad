// USB HID keyboard usages to macOS virtual key codes for a US keyboard.
// This supplies hardware hotkeys; international text/IME needs UIKit text input.
#import <Foundation/Foundation.h>
static BOOL DEMapHardwareKey(NSInteger hid,BOOL shift,unsigned short *mac,NSString **plain,NSString **text) {
 static const unsigned short letters[]={0,11,8,2,14,3,5,4,34,38,40,37,46,45,31,35,12,15,1,17,32,9,13,7,16,6};
 static const unsigned short digits[]={18,19,20,21,23,22,26,28,25,29};
 NSString *value=nil,*shifted=nil;
 if(hid>=4 && hid<=29){*mac=letters[hid-4];value=[NSString stringWithFormat:@"%c",(int)('a'+hid-4)];shifted=value.uppercaseString;}
 else if(hid>=30 && hid<=39){*mac=digits[hid-30];value=[@"1234567890" substringWithRange:NSMakeRange(hid-30,1)];shifted=[@"!@#$%^&*()" substringWithRange:NSMakeRange(hid-30,1)];}
 else {
  switch(hid) {
   case 40:*mac=36;value=@"\r";break; case 41:*mac=53;value=@"\033";break;
   case 42:*mac=51;value=@"\177";break;case 43:*mac=48;value=@"\t";break;case 44:*mac=49;value=@" ";break;
   case 45:*mac=27;value=@"-";shifted=@"_";break;case 46:*mac=24;value=@"=";shifted=@"+";break;
   case 47:*mac=33;value=@"[";shifted=@"{";break;case 48:*mac=30;value=@"]";shifted=@"}";break;
   case 49:*mac=42;value=@"\\";shifted=@"|";break;case 51:*mac=41;value=@";";shifted=@":";break;
   case 52:*mac=39;value=@"'";shifted=@"\"";break;case 53:*mac=50;value=@"`";shifted=@"~";break;
   case 54:*mac=43;value=@",";shifted=@"<";break;case 55:*mac=47;value=@".";shifted=@">";break;
   case 56:*mac=44;value=@"/";shifted=@"?";break;
   case 79:*mac=124;value=@"\uF703";break;case 80:*mac=123;value=@"\uF702";break;
   case 81:*mac=125;value=@"\uF701";break;case 82:*mac=126;value=@"\uF700";break;
   default:if(hid>=58 && hid<=69){static const unsigned short f[]={122,120,99,118,96,97,98,100,101,109,103,111};*mac=f[hid-58];value=[NSString stringWithFormat:@"%C",(unichar)(0xF704+hid-58)];}else return NO;
  }
 }
 *plain=value;*text=shift && shifted?shifted:value;return YES;
}
static NSInteger DEHardwareUsageForMac(unsigned short mac) {
 static NSInteger inverse[128];static dispatch_once_t once;
 dispatch_once(&once,^{
  for(unsigned i=0;i<128;i++)inverse[i]=-1;
  for(NSInteger hid=4;hid<=82;hid++){unsigned short key;NSString *plain,*text;if(DEMapHardwareKey(hid,NO,&key,&plain,&text))inverse[key]=hid;}
  inverse[59]=224;inverse[56]=225;inverse[58]=226;inverse[55]=227;
  inverse[62]=228;inverse[60]=229;inverse[61]=230;inverse[54]=231;inverse[57]=57;
 });
 return mac<128?inverse[mac]:-1;
}
