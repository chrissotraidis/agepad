// The original Mac VFS assumes case-insensitive resource lookup. Simulator
// syscalls can reject a spelling that the host filesystem accepts. Preserve
// original names and retry only failed read/query operations inside the owned
// resource tree. The staged tree must stay unchanged for the process lifetime.
#import <Foundation/Foundation.h>
#include <limits.h>
static NSDictionary<NSString *,id> *DECaseResourceIndex;
static NSString *DECaseResourceRoot;
static _Thread_local int DECaseResolving;
static _Atomic unsigned DECaseResolveCount;
static BOOL DEResolveResourceCase(const char *path,int error,char resolved[PATH_MAX]) {
    if(DECaseResolving || !path || path[0]!='/' || (error!=ENOENT && error!=ENOTDIR))return NO;
    const char *configured=getenv("AGEPAD_CASE_INSENSITIVE_RESOURCE_ROOT");
    if(!configured || !*configured)return NO;
    size_t rootLength=strlen(configured);
    if(strncasecmp(path,configured,rootLength)!=0 || (path[rootLength] && path[rootLength]!='/'))return NO;
    DECaseResolving=1;
    BOOL found=NO;
    @autoreleasepool {
        static dispatch_once_t once;
        dispatch_once(&once,^{
            DECaseResourceRoot=[[@(configured) stringByStandardizingPath] copy];
            NSMutableDictionary<NSString *,id> *index=[NSMutableDictionary dictionary];
            index[DECaseResourceRoot.lowercaseString]=DECaseResourceRoot;
            NSDirectoryEnumerator *entries=[NSFileManager.defaultManager enumeratorAtPath:DECaseResourceRoot];
            for(NSString *relative in entries) {
                NSString *canonical=[DECaseResourceRoot stringByAppendingPathComponent:relative];
                NSString *key=canonical.lowercaseString;
                id prior=index[key];
                // Never choose arbitrarily between two colliding filenames.
                index[key]=prior && ![prior isEqual:canonical]?NSNull.null:canonical;
            }
            DECaseResourceIndex=[index copy];
            fprintf(stderr,"DE_RESOURCE_CASE_INDEX entries=%lu\n",(unsigned long)index.count);
        });
        NSString *requested=[[NSString stringWithUTF8String:path] stringByStandardizingPath];
        NSString *key=requested.lowercaseString;
        NSString *rootKey=DECaseResourceRoot.lowercaseString;
        if([key isEqualToString:rootKey] || [key hasPrefix:[rootKey stringByAppendingString:@"/"]]) {
            id canonical=DECaseResourceIndex[key];
            if([canonical isKindOfClass:NSString.class] && [canonical getFileSystemRepresentation:resolved maxLength:PATH_MAX]) {
                found=YES;
                if(atomic_fetch_add(&DECaseResolveCount,1)<32)
                    fprintf(stderr,"DE_RESOURCE_CASE_RESOLVED requested=%s actual=%s\n",path,resolved);
            }
        }
    }
    DECaseResolving=0;
    return found;
}
