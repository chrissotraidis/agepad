// Physical iPad build unit. The Mac engine calls CFCalendarDecompose/Compose
// AbsoluteTime continuously. On current iPadOS each call autoreleases an
// NSDateComponents plus calendar/identifier objects; the calling engine
// thread never drains a pool, so ~40 MB/min accumulated at an idle menu
// (heap census: 5.9M __NSCFType + 5.9M NSDateComponents + 4.5M Swift
// strings). These replacements perform the same calendar computation through
// the toll-free-bridged NSCalendar inside a local @autoreleasepool.
#include <TargetConditionals.h>
#if !TARGET_OS_SIMULATOR
#import <Foundation/Foundation.h>
#include <stdarg.h>
#include <stdatomic.h>
#include <stdio.h>
#include <unistd.h>
static NSCalendarUnit DECalendarUnit(char c) {
    switch (c) {
        case 'G': return NSCalendarUnitEra; case 'y': return NSCalendarUnitYear;
        case 'M': return NSCalendarUnitMonth; case 'd': return NSCalendarUnitDay;
        case 'H': return NSCalendarUnitHour; case 'm': return NSCalendarUnitMinute;
        case 's': return NSCalendarUnitSecond; case 'W': return NSCalendarUnitWeekOfMonth;
        case 'w': return NSCalendarUnitWeekOfYear; case 'Y': return NSCalendarUnitYearForWeekOfYear;
        case 'E': return NSCalendarUnitWeekday; case 'F': return NSCalendarUnitWeekdayOrdinal;
        case 'Q': return NSCalendarUnitQuarter; default: return 0;
    }
}
static NSInteger DECalendarGet(NSDateComponents *c,char u) {
    switch (u) {
        case 'G': return c.era; case 'y': return c.year; case 'M': return c.month; case 'd': return c.day;
        case 'H': return c.hour; case 'm': return c.minute; case 's': return c.second;
        case 'W': return c.weekOfMonth; case 'w': return c.weekOfYear; case 'Y': return c.yearForWeekOfYear;
        case 'E': return c.weekday; case 'F': return c.weekdayOrdinal; default: return c.quarter;
    }
}
static void DECalendarSet(NSDateComponents *c,char u,NSInteger v) {
    switch (u) {
        case 'G': c.era=v;break; case 'y': c.year=v;break; case 'M': c.month=v;break; case 'd': c.day=v;break;
        case 'H': c.hour=v;break; case 'm': c.minute=v;break; case 's': c.second=v;break;
        case 'W': c.weekOfMonth=v;break; case 'w': c.weekOfYear=v;break; case 'Y': c.yearForWeekOfYear=v;break;
        case 'E': c.weekday=v;break; case 'F': c.weekdayOrdinal=v;break; default: c.quarter=v;break;
    }
}
#include <dlfcn.h>
static void DECalendarReportCaller(const char *op,const char *desc,unsigned long long calls,const char *note,const void *caller) {
    Dl_info info={0};
    if (caller) dladdr(caller,&info);
    const char *image=info.dli_fname?strrchr(info.dli_fname,'/')+1:"?";
    char line[300];
    int length=snprintf(line,sizeof line,"DE_CALENDAR_CALL op=%s desc=%s calls=%llu caller=%s+0x%lx%s\n",op,desc?desc:"(null)",calls,
        image,(unsigned long)((uintptr_t)caller-(uintptr_t)info.dli_fbase),note);
    if (length>0) write(STDERR_FILENO,line,(size_t)length);
}
static void DECalendarReport(const char *op,const char *desc,unsigned long long calls,const char *note) {
    DECalendarReportCaller(op,desc,calls,note,NULL);
}
static BOOL DECalendarUnits(const char *op,const char *desc,NSCalendarUnit *units) {
    *units=0;
    for (const char *p=desc;p && *p;p++) {
        NSCalendarUnit unit=DECalendarUnit(*p);
        if (!unit) { DECalendarReport(op,desc,0," unsupported"); return NO; }
        *units|=unit;
    }
    return desc!=NULL;
}
static Boolean DECalendarDecompose(CFCalendarRef calendar,CFAbsoluteTime at,const char *desc,...) {
    static _Atomic unsigned long long calls;
    unsigned long long n=++calls;
    if (n==1 || n%1000000==0) DECalendarReportCaller("decompose",desc,n,"",__builtin_return_address(0));
    NSCalendarUnit units;
    if (!calendar || !DECalendarUnits("decompose",desc,&units)) return false;
    va_list args;va_start(args,desc);
    @autoreleasepool {
        NSDateComponents *parts=[(__bridge NSCalendar *)calendar components:units fromDate:[NSDate dateWithTimeIntervalSinceReferenceDate:at]];
        for (const char *p=desc;*p;p++) { int *out=va_arg(args,int *); if (out) *out=(int)DECalendarGet(parts,*p); }
    }
    va_end(args);
    return true;
}
static Boolean DECalendarCompose(CFCalendarRef calendar,CFAbsoluteTime *at,const char *desc,...) {
    static _Atomic unsigned long long calls;
    unsigned long long n=++calls;
    if (n==1 || n%1000000==0) DECalendarReportCaller("compose",desc,n,"",__builtin_return_address(0));
    NSCalendarUnit units;
    if (!calendar || !at || !DECalendarUnits("compose",desc,&units)) return false;
    Boolean ok=false;
    va_list args;va_start(args,desc);
    @autoreleasepool {
        NSDateComponents *parts=[NSDateComponents new];
        for (const char *p=desc;*p;p++) DECalendarSet(parts,*p,va_arg(args,int));
        NSDate *date=[(__bridge NSCalendar *)calendar dateFromComponents:parts];
        if (date) { *at=date.timeIntervalSinceReferenceDate;ok=true; }
    }
    va_end(args);
    return ok;
}
__attribute__((used, section("__DATA,__interpose")))
static const struct { const void *replacement; const void *original; } DECalendarInterpose[] = {
    {(const void *)DECalendarDecompose, (const void *)CFCalendarDecomposeAbsoluteTime},
    {(const void *)DECalendarCompose, (const void *)CFCalendarComposeAbsoluteTime},
};
#endif
