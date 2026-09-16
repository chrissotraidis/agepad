#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

// Registry IDs are boot-local. Query the actual backing GPU for every run.
int main(void) {
    @autoreleasepool {
        NSMutableArray *rows = [NSMutableArray array];
        for (id<MTLDevice> device in MTLCopyAllDevices()) {
            [rows addObject:@{@"registry_id": @(device.registryID),
                              @"name": device.name,
                              @"unified": @(device.hasUnifiedMemory),
                              @"recommended_working_set": @(device.recommendedMaxWorkingSetSize),
                              @"location": @(device.location),
                              @"location_number": @(device.locationNumber),
                              @"transfer_rate": @(device.maxTransferRate)}];
        }
        if (!rows.count) return 1;
        NSData *data = [NSJSONSerialization dataWithJSONObject:rows options:0 error:NULL];
        if (!data) return 2;
        return fwrite(data.bytes, 1, data.length, stdout) == data.length ? 0 : 3;
    }
}
