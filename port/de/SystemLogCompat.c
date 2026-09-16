// macOS logging spelling routed to actual platform logging, retaining errno.
#include <stdarg.h>
#include <syslog.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
void DEGameSystemLog(int priority,const char*format,...) __asm("_syslog$DARWIN_EXTSN");
void DEGameSystemLog(int priority,const char*format,...){
 int saved=errno;va_list args;va_start(args,format);
 if(getenv("AGEPAD_SYSTEM_LOG_TRACE")){
  va_list copy;va_copy(copy,args);fprintf(stderr,"DE_SYSTEM_LOG priority=%d ",priority);errno=saved;vfprintf(stderr,format,copy);fputc('\n',stderr);va_end(copy);
 }
 errno=saved;vsyslog(priority,format,args);va_end(args);errno=saved;
}
