#include "MachDiscovery.h"
#include <stdio.h>
int main(void) {
    @autoreleasepool {
        NSData *data=[NSJSONSerialization dataWithJSONObject:@{@"platform":@"macOS",@"discovery":DESteamMachDiscovery()} options:NSJSONWritingPrettyPrinted error:NULL];
        fwrite(data.bytes,1,data.length,stdout);fputc('\n',stdout);
    }
}
