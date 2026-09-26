// iPadOS has no DiskArbitration. Valve's Steam engine asks it for the boot
// disk's UUID (one input to its machine identity) and handles "unavailable"
// (a NULL session) by leaving that field empty, so that is the answer here.
#import <Foundation/Foundation.h>
void *DASessionCreate(CFAllocatorRef allocator) { (void)allocator; return NULL; }
void *DADiskCreateFromBSDName(CFAllocatorRef allocator,void *session,const char *name) { (void)allocator;(void)session;(void)name; return NULL; }
CFDictionaryRef DADiskCopyDescription(void *disk) { (void)disk; return NULL; }
