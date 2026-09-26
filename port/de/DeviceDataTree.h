// Physical iPad: answers file queries inside the imported game data tree from
// one in-memory index. The Mac game checks each of its ~26,000 files dozens of
// times with case-insensitive spellings (2.2 million stat calls at startup,
// three quarters of them misses); on the iPad's case-sensitive volume each
// miss then needed a case retry. The tree is read-only while the game runs, so:
//   - a name that is not in the tree is "not found" without a system call;
//   - any spelling maps straight to the one real on-disk name;
//   - an existing entry's metadata is read from disk once and then reused.
// If the game ever writes inside the tree, the index switches itself off and
// every query goes to the file system as before. Paths outside the tree, and
// anything the index cannot classify, are never touched.
#pragma once
#include <dirent.h>
#include <errno.h>
#include <fts.h>
#include <limits.h>
#include <pthread.h>
#include <stdio.h>
#include <stdatomic.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
enum { DETreeUnknown=0,DETreePresent=1,DETreeAbsent=2 };
typedef struct { uint64_t hash; char *key,*canonical; int ambiguous; _Atomic int cached; struct stat st; } DETreeEntry;
static DETreeEntry *DETreeTable;
static size_t DETreeMask;
static char DETreeRoot[PATH_MAX],DETreeRootKey[PATH_MAX];
static size_t DETreeRootLength;
static _Atomic int DETreeDisabled;
static pthread_once_t DETreeOnce=PTHREAD_ONCE_INIT;
static pthread_mutex_t DETreeFillLock=PTHREAD_MUTEX_INITIALIZER;
// The build walks the tree with fts/realpath, whose own lstat/opendir calls
// come back through these hooks; they must go straight to the file system.
static _Thread_local int DETreeBuilding;

static uint64_t DETreeHash(const char *key) {
    uint64_t hash=1469598103934665603ULL;
    for (;*key;key++) hash=(hash^(unsigned char)*key)*1099511628211ULL;
    return hash;
}
static void DETreeLower(char *text) { for (;*text;text++) if (*text>='A' && *text<='Z') *text+=32; }
// "/private/var/…" and "/var/…" name the same place; drop "/private".
static const char *DETreeStripPrivate(const char *path) {
    return strncmp(path,"/private/var/",13)==0?path+8:path;
}
static DETreeEntry *DETreeSlot(const char *key,uint64_t hash) {
    for (size_t i=hash&DETreeMask;;i=(i+1)&DETreeMask) {
        DETreeEntry *entry=&DETreeTable[i];
        if (!entry->key || (entry->hash==hash && strcmp(entry->key,key)==0)) return entry;
    }
}
static void DETreeInsert(const char *canonical) {
    char key[PATH_MAX];
    strlcpy(key,canonical,sizeof key);DETreeLower(key);
    uint64_t hash=DETreeHash(key);
    DETreeEntry *entry=DETreeSlot(key,hash);
    if (entry->key) {
        // Two real names differing only in case: never choose between them.
        if (strcmp(entry->canonical?entry->canonical:"",canonical)!=0) entry->ambiguous=1;
        return;
    }
    entry->hash=hash;entry->key=strdup(key);entry->canonical=strdup(canonical);
}
static void DETreeBuildIndex(void) {
    const char *configured=getenv("AGEPAD_CASE_INSENSITIVE_RESOURCE_ROOT");
    if (!configured || !*configured || !getenv("AGEPAD_DEVICE_DATA_ROOT")) { atomic_store(&DETreeDisabled,1);return; }
    strlcpy(DETreeRoot,DETreeStripPrivate(configured),sizeof DETreeRoot);
    DETreeRootLength=strlen(DETreeRoot);
    while (DETreeRootLength>1 && DETreeRoot[DETreeRootLength-1]=='/') DETreeRoot[--DETreeRootLength]=0;
    strlcpy(DETreeRootKey,DETreeRoot,sizeof DETreeRootKey);DETreeLower(DETreeRootKey);
    char target[PATH_MAX];
    if (!realpath(configured,target)) { atomic_store(&DETreeDisabled,1);return; }
    // Count entries, then size the table at a load factor below one half.
    size_t count=1;
    char *roots[]={target,NULL};
    FTS *walk=fts_open(roots,FTS_PHYSICAL|FTS_NOSTAT,NULL);
    if (!walk) { atomic_store(&DETreeDisabled,1);return; }
    for (FTSENT *node;(node=fts_read(walk));) if (node->fts_info!=FTS_DP && node->fts_level>0) count++;
    fts_close(walk);
    size_t capacity=1;while (capacity<count*2+16) capacity<<=1;
    DETreeTable=calloc(capacity,sizeof *DETreeTable);DETreeMask=capacity-1;
    if (!DETreeTable) { atomic_store(&DETreeDisabled,1);return; }
    DETreeInsert(DETreeRoot);
    size_t targetLength=strlen(target);
    walk=fts_open(roots,FTS_PHYSICAL|FTS_NOSTAT,NULL);
    for (FTSENT *node;walk && (node=fts_read(walk));) {
        if (node->fts_info==FTS_DP || node->fts_level==0) continue;
        char canonical[PATH_MAX];
        snprintf(canonical,sizeof canonical,"%s%s",DETreeRoot,node->fts_path+targetLength);
        DETreeInsert(canonical);
    }
    if (walk) fts_close(walk);
    fprintf(stderr,"DE_DATA_TREE_INDEX entries=%zu root=%s\n",count,DETreeRoot);
}
static void DETreeBuild(void) {
    DETreeBuilding=1;
    DETreeBuildIndex();
    DETreeBuilding=0;
}
// Classifies a path. On DETreePresent, *found is its entry (unique real name).
static int DETreeLookup(const char *path,DETreeEntry **found) {
    if (!path || path[0]!='/' || DETreeBuilding || atomic_load(&DETreeDisabled)) return DETreeUnknown;
    // The launcher names the data root just before the game starts; queries
    // made before that (app and Steam start-up) are not about the tree.
    static _Atomic int configured;
    if (!atomic_load(&configured)) {
        if (!getenv("AGEPAD_DEVICE_DATA_ROOT") || !getenv("AGEPAD_CASE_INSENSITIVE_RESOURCE_ROOT")) return DETreeUnknown;
        atomic_store(&configured,1);
    }
    pthread_once(&DETreeOnce,DETreeBuild);
    if (atomic_load(&DETreeDisabled)) return DETreeUnknown;
    const char *stripped=DETreeStripPrivate(path);
    if (strncasecmp(stripped,DETreeRoot,DETreeRootLength)!=0 ||
        (stripped[DETreeRootLength] && stripped[DETreeRootLength]!='/')) return DETreeUnknown;
    if (strstr(stripped,"//") || strstr(stripped,"/./") || strstr(stripped,"/../")) return DETreeUnknown;
    char key[PATH_MAX];
    if (strlcpy(key,stripped,sizeof key)>=sizeof key) return DETreeUnknown;
    size_t length=strlen(key);
    while (length>1 && key[length-1]=='/') key[--length]=0;
    if ((length>=2 && strcmp(key+length-2,"/.")==0) || (length>=3 && strcmp(key+length-3,"/..")==0)) return DETreeUnknown;
    DETreeLower(key);
    DETreeEntry *entry=DETreeSlot(key,DETreeHash(key));
    if (!entry->key) return DETreeAbsent;
    if (entry->ambiguous) return DETreeUnknown;
    *found=entry;
    return DETreePresent;
}
// Writes inside the tree end the read-only assumption for this session.
static void DETreeNoteWrite(const char *path) {
    DETreeEntry *entry=NULL;
    if (DETreeLookup(path,&entry)!=DETreeUnknown) {
        atomic_store(&DETreeDisabled,1);
        fprintf(stderr,"DE_DATA_TREE_INDEX disabled after a write inside the tree\n");
    }
}
// stat/lstat answer, or -2 when the index does not apply. Existing entries are
// read from disk once; the root itself (a link) always goes to the file system.
static int DETreeStat(const char *path,struct stat *buffer,int *error) {
    DETreeEntry *entry=NULL;
    int kind=DETreeLookup(path,&entry);
    if (kind==DETreeAbsent) { *error=ENOENT;return -1; }
    if (kind!=DETreePresent || strcmp(entry->canonical,DETreeRoot)==0) return -2;
    if (atomic_load_explicit(&entry->cached,memory_order_acquire)) { *buffer=entry->st;return 0; }
    struct stat fresh;
    if (stat(entry->canonical,&fresh)!=0) return -2;
    pthread_mutex_lock(&DETreeFillLock);
    entry->st=fresh;atomic_store_explicit(&entry->cached,1,memory_order_release);
    pthread_mutex_unlock(&DETreeFillLock);
    *buffer=fresh;
    return 0;
}
