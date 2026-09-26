// iPadOS forbids System V semaphores: semget() makes the kernel stop the app
// ("Bad system call"). Valve's libtier0 uses them for named locks shared
// between Steam processes. Inside AgePad everything (Steam engine, game) is one
// process, so the same semantics are provided here as in-process semaphore
// sets: a named set is shared by every caller in the app, exactly as the
// system-wide set would be when only one process uses it.
#pragma once
#include <errno.h>
#include <pthread.h>
#include <stdarg.h>
#include <stdlib.h>
#include <sys/types.h>
#include <unistd.h>

struct DESemOperation { unsigned short sem_num; short sem_op; short sem_flg; }; // struct sembuf
#define DE_IPC_CREAT 001000
#define DE_IPC_EXCL 002000
#define DE_IPC_NOWAIT 004000
#define DE_IPC_PRIVATE ((key_t)0)
#define DE_IPC_RMID 0
#define DE_IPC_SET 1
#define DE_IPC_STAT 2
enum { DE_GETNCNT=3,DE_GETPID=4,DE_GETVAL=5,DE_GETALL=6,DE_GETZCNT=7,DE_SETVAL=8,DE_SETALL=9 };
enum { DESemSetLimit=256,DESemIDBase=0x5000 };
static struct { key_t key; int count,used,removed; int *values; pid_t lastPID; } DESemSets[DESemSetLimit];
static pthread_mutex_t DESemLock=PTHREAD_MUTEX_INITIALIZER;
static pthread_cond_t DESemChanged=PTHREAD_COND_INITIALIZER;

static int DESemIndex(int id) {
    int index=id-DESemIDBase;
    return index>=0 && index<DESemSetLimit && DESemSets[index].used && !DESemSets[index].removed?index:-1;
}
int semget(key_t key,int count,int flags) {
    pthread_mutex_lock(&DESemLock);
    int found=-1,slot=-1;
    for (int i=0;i<DESemSetLimit;i++) {
        if (DESemSets[i].used && !DESemSets[i].removed && key!=DE_IPC_PRIVATE && DESemSets[i].key==key) { found=i;break; }
        if (!DESemSets[i].used && slot<0) slot=i;
    }
    int result=-1;
    if (found>=0) {
        if ((flags&DE_IPC_CREAT) && (flags&DE_IPC_EXCL)) errno=EEXIST;
        else if (count>DESemSets[found].count) errno=EINVAL;
        else result=DESemIDBase+found;
    } else if (!(flags&DE_IPC_CREAT) && key!=DE_IPC_PRIVATE) errno=ENOENT;
    else if (count<=0 || slot<0) errno=count<=0?EINVAL:ENOSPC;
    else {
        DESemSets[slot].values=calloc((size_t)count,sizeof(int));
        if (!DESemSets[slot].values) errno=ENOMEM;
        else {
            DESemSets[slot].key=key;DESemSets[slot].count=count;
            DESemSets[slot].used=1;DESemSets[slot].removed=0;
            result=DESemIDBase+slot;
        }
    }
    pthread_mutex_unlock(&DESemLock);
    return result;
}
int semop(int id,struct DESemOperation *operations,size_t count) {
    pthread_mutex_lock(&DESemLock);
    int result=-1;
    for (;;) {
        int index=DESemIndex(id);
        if (index<0) { errno=id-DESemIDBase>=0 && id-DESemIDBase<DESemSetLimit && DESemSets[id-DESemIDBase].removed?EIDRM:EINVAL;break; }
        int ready=1,nowait=0;
        for (size_t i=0;i<count;i++) {
            if (operations[i].sem_num>=DESemSets[index].count) { errno=EFBIG;ready=-1;break; }
            int value=DESemSets[index].values[operations[i].sem_num];
            if ((operations[i].sem_op<0 && value<-operations[i].sem_op) || (operations[i].sem_op==0 && value!=0)) {
                ready=0;nowait|=operations[i].sem_flg&DE_IPC_NOWAIT;
            }
        }
        if (ready<0) break;
        if (ready) { // all or nothing, as the kernel does
            for (size_t i=0;i<count;i++) DESemSets[index].values[operations[i].sem_num]+=operations[i].sem_op;
            DESemSets[index].lastPID=getpid();
            pthread_cond_broadcast(&DESemChanged);
            result=0;break;
        }
        if (nowait) { errno=EAGAIN;break; }
        pthread_cond_wait(&DESemChanged,&DESemLock);
    }
    pthread_mutex_unlock(&DESemLock);
    return result;
}
int semctl(int id,int number,int command,...) {
    va_list arguments;va_start(arguments,command);
    union { int val; void *buf; unsigned short *array; } argument; // union semun
    argument.buf=(command==DE_SETVAL)?(void *)(intptr_t)va_arg(arguments,int):
                 (command==DE_SETALL || command==DE_GETALL || command==DE_IPC_STAT || command==DE_IPC_SET)?va_arg(arguments,void *):NULL;
    if (command==DE_SETVAL) argument.val=(int)(intptr_t)argument.buf;
    va_end(arguments);
    pthread_mutex_lock(&DESemLock);
    int index=DESemIndex(id),result=-1;
    if (index<0) errno=EINVAL;
    else if (number<0 || (number>=DESemSets[index].count && (command==DE_GETVAL || command==DE_SETVAL || command==DE_GETNCNT || command==DE_GETZCNT || command==DE_GETPID))) errno=EINVAL;
    else switch (command) {
        case DE_GETVAL: result=DESemSets[index].values[number];break;
        case DE_SETVAL: DESemSets[index].values[number]=argument.val;pthread_cond_broadcast(&DESemChanged);result=0;break;
        case DE_GETALL: for (int i=0;i<DESemSets[index].count;i++) { argument.array[i]=(unsigned short)DESemSets[index].values[i]; } result=0;break;
        case DE_SETALL: for (int i=0;i<DESemSets[index].count;i++) { DESemSets[index].values[i]=argument.array[i]; } pthread_cond_broadcast(&DESemChanged);result=0;break;
        case DE_GETPID: result=DESemSets[index].lastPID;break;
        case DE_GETNCNT: case DE_GETZCNT: result=0;break;
        case DE_IPC_RMID: DESemSets[index].removed=1;free(DESemSets[index].values);DESemSets[index].values=NULL;DESemSets[index].used=0;
                          pthread_cond_broadcast(&DESemChanged);result=0;break;
        case DE_IPC_SET: result=0;break;
        default: errno=EINVAL;break; // IPC_STAT is not used by Valve's libtier0
    }
    pthread_mutex_unlock(&DESemLock);
    return result;
}
