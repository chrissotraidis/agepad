#include <signal.h>
#include <sys/ucontext.h>
#include <unistd.h>
#include <stdint.h>
#include <errno.h>
#include <stdio.h>
#include <mach-o/dyld.h>
static struct sigaction saved[NSIG];
static volatile sig_atomic_t count;
static char *literal(char *p,const char *s){while(*s)*p++=*s++;return p;}
static char *hex(char *p,uint64_t v){*p++='0';*p++='x';for(int i=60;i>=0;i-=4)*p++="0123456789abcdef"[(v>>i)&15];return p;}
static void handler(int sig,siginfo_t *info,void *context){
 int error=errno;
 if(count++<8){
  ucontext_t *u=context;char b[1600],*p=b;p=literal(p,"DE_FIRST_SIGNAL sig=");p=hex(p,sig);p=literal(p," addr=");p=hex(p,(uintptr_t)info->si_addr);
  p=literal(p," pc=");p=hex(p,u->uc_mcontext->__ss.__pc);p=literal(p," sp=");p=hex(p,u->uc_mcontext->__ss.__sp);p=literal(p," lr=");p=hex(p,u->uc_mcontext->__ss.__lr);
  for(int i=0;i<29;i++){p=literal(p," x");*p++='0'+i/10;*p++='0'+i%10;*p++='=';p=hex(p,u->uc_mcontext->__ss.__x[i]);}*p++='\n';write(2,b,p-b);
 }
 errno=error;
 if(saved[sig].sa_flags&SA_SIGINFO)saved[sig].sa_sigaction(sig,info,context);else saved[sig].sa_handler(sig);
}
static int traceSigaction(int sig,const struct sigaction *action,struct sigaction *old){
 if(sig!=SIGSEGV && sig!=SIGBUS && sig!=SIGILL && sig!=SIGABRT && sig!=SIGFPE)return sigaction(sig,action,old);
 struct sigaction previous=saved[sig];
 struct sigaction replacement;
 if(action && action->sa_handler!=SIG_DFL && action->sa_handler!=SIG_IGN){saved[sig]=*action;replacement=*action;replacement.sa_sigaction=handler;replacement.sa_flags|=SA_SIGINFO;action=&replacement;}
 int result=sigaction(sig,action,old);
 if(result==0 && old && old->sa_sigaction==handler)*old=previous;
 return result;
}
__attribute__((used,section("__DATA,__interpose")))static const struct {const void *replacement,*original;} map[]={{traceSigaction,sigaction}};
__attribute__((constructor))static void start(void){fprintf(stderr,"DE_SIGNAL_TRACE_INSTALLED chained original handlers base=%p\n",_dyld_get_image_header(0));}
