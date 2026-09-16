// Calls real source-built ARM64EC FEX code in a signed Mach-O container.
// This does not initialize Wine, imports, TLS, or a Windows process.
#import <UIKit/UIKit.h>
#include <cstring>
#include <mach/mach.h>
#include "pe-layout.h"
extern "C" unsigned char agepad_pe_base[], agepad_pe_data[];

template<typename T> static T read_at(size_t offset) {
    T value; memcpy(&value, agepad_pe_base + offset, sizeof(value)); return value;
}
static NSString *probe() {
    uint8_t *base = agepad_pe_base;
    if ((uintptr_t)agepad_pe_data - (uintptr_t)base != PE_DATA_SPLIT)
        return @"FAIL: Mach-O did not preserve PE section spacing";
    vm_address_t address=(vm_address_t)base;
    vm_size_t regionSize=0;
    vm_region_basic_info_data_64_t info{};
    mach_msg_type_number_t count=VM_REGION_BASIC_INFO_COUNT_64;
    mach_port_t object=MACH_PORT_NULL;
    kern_return_t kr=vm_region_64(mach_task_self(),&address,&regionSize,VM_REGION_BASIC_INFO_64,(vm_region_info_t)&info,&count,&object);
    if (object) mach_port_deallocate(mach_task_self(),object);
    if (kr || !(info.protection&VM_PROT_EXECUTE) || (info.protection&VM_PROT_WRITE)) return @"FAIL: PE code is not immutable executable memory";
    address=(vm_address_t)agepad_pe_data; count=VM_REGION_BASIC_INFO_COUNT_64; object=MACH_PORT_NULL;
    kr=vm_region_64(mach_task_self(),&address,&regionSize,VM_REGION_BASIC_INFO_64,(vm_region_info_t)&info,&count,&object);
    if (object) mach_port_deallocate(mach_task_self(),object);
    if (kr || !(info.protection&VM_PROT_WRITE) || (info.protection&VM_PROT_EXECUTE)) return @"FAIL: PE data is not writable non-executable memory";
    const uint32_t nt = read_at<uint32_t>(0x3c), optional = nt + 24;
    const uint64_t oldBase = read_at<uint64_t>(optional + 24);
    const uint32_t imageSize = read_at<uint32_t>(optional + 56);
    uint32_t reloc = read_at<uint32_t>(optional + 112 + 5*8);
    const uint32_t relocSize = read_at<uint32_t>(optional + 116 + 5*8);
    if (reloc > imageSize || relocSize > imageSize - reloc) return @"FAIL: relocation directory bounds";
    const uint32_t end = reloc + relocSize;
    unsigned fixed = 0;
    while (reloc < end) {
        if (end - reloc < 8) return @"FAIL: relocation block header";
        const uint32_t page = read_at<uint32_t>(reloc), size = read_at<uint32_t>(reloc+4);
        if (size < 8 || size > end-reloc || size % 2) return @"FAIL: relocation block size";
        for (uint32_t o=8; o<size; o+=2) {
            const uint16_t entry = read_at<uint16_t>(reloc+o);
            const unsigned type=entry>>12;
            if (!type) continue;
            const uint64_t site=(uint64_t)page+(entry&4095);
            if (type != 10 || site < PE_DATA_SPLIT || site+8 > imageSize)
                return @"FAIL: relocation requires unsupported type or executable-page write";
            uint64_t value=read_at<uint64_t>(site)+(uintptr_t)base-oldBase;
            memcpy(base+site,&value,8); ++fixed;
        }
        reloc+=size;
    }
#ifdef PE_NTDLL_PROBE
    struct UnicodeString { uint16_t length, maximum; uint32_t padding; const uint16_t *buffer; };
    auto init=(void (*)(UnicodeString*,const uint16_t*))(base+PE_INITUNICODE_RVA);
    const uint16_t input[]={'A','g','e','P','a','d',0};
    UnicodeString value{}; init(&value,input);
    bool ascii=value.length==12 && value.maximum==14 && value.buffer==input;
    const uint16_t pair[]={0xd83d,0xde00,0}; init(&value,pair);
    bool utf16=value.length==4 && value.maximum==6 && value.buffer==pair;
    init(&value,nullptr);
    bool empty=value.length==0 && value.maximum==0 && value.buffer==nullptr;
    return [NSString stringWithFormat:@"%@: actual Windows ntdll RtlInitUnicodeString executed from signed code.\n%u data relocations; ASCII=%d UTF16=%d NULL=%d.\nThis is a Windows API function test, not Wine process startup or DE gameplay.",ascii&&utf16&&empty?@"PASS":@"FAIL",fixed,ascii,utf16,empty];
#else
    auto add = (void (*)(uint64_t,uint64_t,uint64_t))(base+PE_ADD_ALIAS_RVA);
    auto translate = (uint64_t (*)(uint64_t))(base+PE_TRANSLATE_RVA);
    uint64_t before=translate(0x10020);
    add(0x10000,0x20000,0x100);
    uint64_t first=translate(0x10020);
    add(0x10000,0x20000,0x100);
    uint32_t count1=read_at<uint32_t>(PE_ALIAS_COUNT_RVA);
    add(0x10000,0x30000,0x100);
    uint64_t replaced=translate(0x10020);
    uint32_t count2=read_at<uint32_t>(PE_ALIAS_COUNT_RVA);
    bool pass=before==0x10020 && first==0x20020 && replaced==0x30020 && count1==1 && count2==1;
    return [NSString stringWithFormat:@"%@: real ARM64EC FEX alias functions executed from signed code.\n%u data relocations; lookup %llx → %llx → %llx; counts %u,%u.\nNo MAP_JIT for this DLL. Windows imports/TLS/process initialization and DE remain untested.", pass?@"PASS":@"FAIL",fixed,before,first,replaced,count1,count2];
#endif
}
@interface PEDelegate : UIResponder <UIApplicationDelegate>
@property(nonatomic,strong) UIWindow *window;
@end
@implementation PEDelegate
- (BOOL)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)options {
    self.window=[[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    UIViewController *vc=[UIViewController new];
    UITextView *text=[[UITextView alloc] initWithFrame:self.window.bounds];
    text.editable=NO; text.textContainerInset=UIEdgeInsetsMake(64,20,20,20);
    text.font=[UIFont monospacedSystemFontOfSize:22 weight:UIFontWeightRegular];
    text.text=@"Testing signed PE container…"; vc.view=text;
    self.window.rootViewController=vc; [self.window makeKeyAndVisible];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0), ^{
        NSString *result=probe(); fprintf(stderr,"PE CONTAINER: %s\n",result.UTF8String);
        NSString *path=[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES).firstObject stringByAppendingPathComponent:@"result.txt"];
        [result writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
        dispatch_async(dispatch_get_main_queue(), ^{text.text=result;});
    });
    return YES;
}
@end
int main(int argc,char **argv) { @autoreleasepool {return UIApplicationMain(argc,argv,nil,NSStringFromClass(PEDelegate.class));} }
