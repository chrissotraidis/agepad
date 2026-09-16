#import <Foundation/Foundation.h>
#include <assert.h>
#include "../port/de/HardwareKeyMapping.h"
int main(void){@autoreleasepool{
 unsigned short mac;NSString *plain,*text;
 assert(DEMapHardwareKey(4,NO,&mac,&plain,&text)&&mac==0&&[text isEqual:@"a"]);
 assert(DEMapHardwareKey(4,YES,&mac,&plain,&text)&&[plain isEqual:@"a"]&&[text isEqual:@"A"]);
 assert(DEMapHardwareKey(45,YES,&mac,&plain,&text)&&mac==27&&[text isEqual:@"_"]);
 assert(DEMapHardwareKey(39,NO,&mac,&plain,&text)&&mac==29&&[text isEqual:@"0"]);
 assert(DEMapHardwareKey(40,NO,&mac,&plain,&text)&&mac==36&&[text isEqual:@"\r"]);
 assert(DEMapHardwareKey(42,NO,&mac,&plain,&text)&&mac==51);
 assert(DEMapHardwareKey(79,NO,&mac,&plain,&text)&&mac==124&&[text characterAtIndex:0]==0xF703);
 assert(DEMapHardwareKey(67,NO,&mac,&plain,&text)&&mac==109&&[text characterAtIndex:0]==0xF70D);
 assert(DEHardwareUsageForMac(0)==4 && DEHardwareUsageForMac(56)==225 && DEHardwareUsageForMac(109)==67 && DEHardwareUsageForMac(200)==-1);
 assert(!DEMapHardwareKey(225,NO,&mac,&plain,&text));
 NSMutableSet *keys=[NSMutableSet set];for(int hid=4;hid<=29;hid++){assert(DEMapHardwareKey(hid,NO,&mac,&plain,&text));[keys addObject:@(mac)];}assert(keys.count==26);
 puts("PASS US HID letters/digits/punctuation/navigation/function keys; shifted text and base characters; unsupported usage rejected");
}}
