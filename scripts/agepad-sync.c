// Copy the Mac's Steam game data into AgePad on a USB-connected iPad, sending
// only what is new or changed since the last copy, and removing files a game
// update deleted. Resumable: each file is written under a temporary name and
// renamed when complete, and the record of what the iPad holds
// (/Documents/.agepad-sync-manifest.tsv: size, Mac modification time, path) is
// saved as it goes. The first run over a copy made before this tool existed
// checks sizes on the iPad and adopts matching files (--verify does that again).
// Reads the Mac folder only. Build and usage: scripts/agepad-ipad.sh sync.
#include <libimobiledevice/libimobiledevice.h>
#include <libimobiledevice/house_arrest.h>
#include <libimobiledevice/afc.h>
#include <plist/plist.h>
#include <sys/stat.h>
#include <dirent.h>
#include <fcntl.h>
#include <limits.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

#define MANIFEST "/Documents/.agepad-sync-manifest.tsv"
#define MARKER ".agepad-import-inventory-checked"
#define TABLE (1u<<17)

static afc_client_t afc;
static const char *source, *remote_root="/Documents/AgeOfEmpires2Data", *build="unknown";
static int verify_all, dry_run;

typedef struct { char *path; uint64_t size; int64_t mtime; int used; } Entry;
static Entry table[TABLE];
static unsigned entries;

static unsigned slot(const char *path) {
    uint32_t h=2166136261u;
    for (const char *p=path;*p;p++) h=(h^(unsigned char)*p)*16777619u;
    unsigned i=h&(TABLE-1);
    while (table[i].path && strcmp(table[i].path,path)) i=(i+1)&(TABLE-1);
    return i;
}
static Entry *find(const char *path) { Entry *e=&table[slot(path)];return e->path&&e->used?e:NULL; }
static void record(const char *path,uint64_t size,int64_t mtime) {
    Entry *e=&table[slot(path)];
    if (!e->path) { e->path=strdup(path);entries++; }
    e->size=size;e->mtime=mtime;e->used=1;
}
static void forget(const char *path) { Entry *e=&table[slot(path)];if (e->path) e->used=0; }

static int load_manifest(void) {
    uint64_t handle=0;
    if (afc_file_open(afc,MANIFEST,AFC_FOPEN_RDONLY,&handle)!=AFC_E_SUCCESS) return 0;
    size_t capacity=1<<20,length=0;char *text=malloc(capacity);uint32_t got=0;
    for (;;) {
        if (capacity-length<65536) text=realloc(text,capacity*=2);
        if (afc_file_read(afc,handle,text+length,65536,&got)!=AFC_E_SUCCESS || !got) break;
        length+=got;
    }
    afc_file_close(afc,handle);text[length]=0;
    int loaded=0;
    for (char *line=strtok(text,"\n");line;line=strtok(NULL,"\n")) {
        if (*line=='#') continue;
        char *a=strchr(line,'\t'),*b=a?strchr(a+1,'\t'):NULL;
        if (!b) continue;
        *a=*b=0;record(b+1,strtoull(line,NULL,10),strtoll(a+1,NULL,10));loaded=1;
    }
    free(text);
    return loaded;
}
static int write_remote(const char *path,const char *data,size_t length) {
    char part[PATH_MAX];snprintf(part,sizeof part,"%s.agepad-part",path);
    uint64_t handle=0;uint32_t written=0;
    if (afc_file_open(afc,part,AFC_FOPEN_WRONLY,&handle)!=AFC_E_SUCCESS) return -1;
    for (size_t done=0;done<length;done+=written)
        if (afc_file_write(afc,handle,data+done,(uint32_t)(length-done>(1<<20)?(1<<20):length-done),&written)!=AFC_E_SUCCESS || !written) {
            afc_file_close(afc,handle);return -1;
        }
    afc_file_close(afc,handle);
    afc_remove_path(afc,path);
    return afc_rename_path(afc,part,path)==AFC_E_SUCCESS?0:-1;
}
static int save_manifest(void) {
    if (dry_run || strcmp(remote_root,"/Documents/AgeOfEmpires2Data")) return 0; // test folders keep no record
    size_t capacity=4<<20,length=0;char *text=malloc(capacity);
    length+=snprintf(text,capacity,"#agepad-sync 1\tbuild=%s\n",build);
    for (unsigned i=0;i<TABLE;i++) if (table[i].path && table[i].used) {
        size_t need=strlen(table[i].path)+64;
        if (capacity-length<need) text=realloc(text,capacity=capacity*2+need);
        length+=snprintf(text+length,capacity-length,"%llu\t%lld\t%s\n",
            (unsigned long long)table[i].size,(long long)table[i].mtime,table[i].path);
    }
    int result=write_remote(MANIFEST,text,length);free(text);return result;
}

typedef struct { char *path; uint64_t size; int64_t mtime; } Want;
static Want *wanted;static size_t wanted_count,wanted_capacity;
static uint64_t wanted_bytes,replaced_bytes,largest,adopted,unchanged,local_files;

static int remote_size(const char *relative,uint64_t *size) {
    char path[PATH_MAX];snprintf(path,sizeof path,"%s/%s",remote_root,relative);
    char **info=NULL;
    if (afc_get_file_info(afc,path,&info)!=AFC_E_SUCCESS) return 0;
    int regular=0;
    for (size_t i=0;info && info[i] && info[i+1];i+=2) {
        if (!strcmp(info[i],"st_ifmt")) regular=!strcmp(info[i+1],"S_IFREG");
        if (!strcmp(info[i],"st_size")) *size=strtoull(info[i+1],NULL,10);
    }
    afc_dictionary_free(info);
    return regular;
}
static void plan(const char *relative,int adopt) {
    char local[PATH_MAX];snprintf(local,sizeof local,"%s%s%s",source,*relative?"/":"",relative);
    DIR *directory=opendir(local);
    if (!directory) { fprintf(stderr,"Cannot read %s\n",local);exit(3); }
    struct dirent *item;
    while ((item=readdir(directory))) {
        if (item->d_name[0]=='.' && (!item->d_name[1] || !strcmp(item->d_name,".."))) continue;
        char child[PATH_MAX],path[PATH_MAX];struct stat value;
        snprintf(child,sizeof child,"%s%s%s",relative,*relative?"/":"",item->d_name);
        snprintf(path,sizeof path,"%s/%s",source,child);
        if (lstat(path,&value)) continue;
        if (S_ISDIR(value.st_mode)) { plan(child,adopt);continue; }
        if (!S_ISREG(value.st_mode)) continue;
        local_files++;
        Entry *known=find(child);
        if (known && known->size==(uint64_t)value.st_size && known->mtime==value.st_mtime && !verify_all) { unchanged++;continue; }
        uint64_t there=0;
        if ((adopt || verify_all) && remote_size(child,&there) && there==(uint64_t)value.st_size) {
            record(child,value.st_size,value.st_mtime);adopted++;continue;
        }
        if (wanted_count==wanted_capacity) wanted=realloc(wanted,(wanted_capacity=wanted_capacity*2+1024)*sizeof *wanted);
        wanted[wanted_count++]=(Want){strdup(child),(uint64_t)value.st_size,value.st_mtime};
        wanted_bytes+=value.st_size;
        if (known) replaced_bytes+=known->size;
        if ((uint64_t)value.st_size>largest) largest=value.st_size;
    }
    closedir(directory);
}
static uint64_t removed;
static void remove_stale(const char *relative) {
    char remote[PATH_MAX];snprintf(remote,sizeof remote,"%s%s%s",remote_root,*relative?"/":"",relative);
    char **names=NULL;
    if (afc_read_directory(afc,remote,&names)!=AFC_E_SUCCESS) return;
    for (size_t i=0;names && names[i];i++) {
        const char *name=names[i];
        if (!strcmp(name,".") || !strcmp(name,"..") || (!*relative && !strcmp(name,MARKER))) continue;
        char child[PATH_MAX],local[PATH_MAX],target[PATH_MAX];struct stat value;
        snprintf(child,sizeof child,"%s%s%s",relative,*relative?"/":"",name);
        snprintf(local,sizeof local,"%s/%s",source,child);
        snprintf(target,sizeof target,"%s/%s",remote_root,child);
        size_t n=strlen(name);
        int part=n>13 && !strcmp(name+n-13,".agepad-part");
        if (!part && !lstat(local,&value)) { if (S_ISDIR(value.st_mode)) remove_stale(child);continue; }
        // Steam's engine drops this cache file wherever the game's working
        // folder is; it is not game data. Remove it without a report.
        if (strcmp(name,"update_hosts_cached.vdf")) { printf("  remove %s\n",child);removed++; }
        forget(child);
        if (!dry_run) afc_remove_path_and_contents(afc,target);
    }
    afc_dictionary_free(names);
}
static int make_parents(const char *relative) {
    static char made[PATH_MAX];
    char directory[PATH_MAX];snprintf(directory,sizeof directory,"%s/%s",remote_root,relative);
    char *slash=strrchr(directory,'/');*slash=0;
    if (!strcmp(directory,made)) return 0;
    for (char *p=directory+1;;p++) if (*p=='/' || !*p) {
        char keep=*p;*p=0;afc_make_directory(afc,directory);*p=keep;
        if (!keep) break;
    }
    snprintf(made,sizeof made,"%s",directory);
    return 0;
}
static int send_file(const Want *want) {
    char local[PATH_MAX],remote[PATH_MAX],part[PATH_MAX];
    snprintf(local,sizeof local,"%s/%s",source,want->path);
    snprintf(remote,sizeof remote,"%s/%s",remote_root,want->path);
    snprintf(part,sizeof part,"%s.agepad-part",remote);
    make_parents(want->path);
    int fd=open(local,O_RDONLY);if (fd<0) return -1;
    uint64_t handle=0;
    if (afc_file_open(afc,part,AFC_FOPEN_WRONLY,&handle)!=AFC_E_SUCCESS) { close(fd);return -1; }
    static char buffer[4<<20];ssize_t got;int failed=0;
    while (!failed && (got=read(fd,buffer,sizeof buffer))>0)
        for (ssize_t done=0;done<got;) {
            uint32_t written=0;
            if (afc_file_write(afc,handle,buffer+done,(uint32_t)(got-done),&written)!=AFC_E_SUCCESS || !written) { failed=1;break; }
            done+=written;
        }
    afc_file_close(afc,handle);close(fd);
    // The finished temporary file must have the Mac file's size before it replaces anything.
    char **info=NULL;uint64_t part_size=0;
    if (afc_get_file_info(afc,part,&info)==AFC_E_SUCCESS) {
        for (size_t i=0;info[i] && info[i+1];i+=2) if (!strcmp(info[i],"st_size")) part_size=strtoull(info[i+1],NULL,10);
        afc_dictionary_free(info);
    }
    if (failed || part_size!=want->size) return -1;
    afc_remove_path(afc,remote);
    return afc_rename_path(afc,part,remote)==AFC_E_SUCCESS?0:-1;
}

int main(int argc,char **argv) {
    if (argc<4) { fprintf(stderr,"Usage: %s UDID BUNDLE_ID MAC_DATA_FOLDER [--build ID] [--remote PATH] [--verify] [--dry-run]\n",argv[0]);return 64; }
    source=argv[3];
    for (int i=4;i<argc;i++) {
        if (!strcmp(argv[i],"--build") && i+1<argc) build=argv[++i];
        else if (!strcmp(argv[i],"--remote") && i+1<argc) remote_root=argv[++i];
        else if (!strcmp(argv[i],"--verify")) verify_all=1;
        else if (!strcmp(argv[i],"--dry-run")) dry_run=1;
    }
    idevice_t device=NULL;house_arrest_client_t house=NULL;plist_t reply=NULL;char *status=NULL;
    if (idevice_new_with_options(&device,argv[1],IDEVICE_LOOKUP_USBMUX)!=IDEVICE_E_SUCCESS ||
        house_arrest_client_start_service(device,&house,"AgePad game files")!=HOUSE_ARREST_E_SUCCESS ||
        house_arrest_send_command(house,"VendContainer",argv[2])!=HOUSE_ARREST_E_SUCCESS ||
        house_arrest_get_result(house,&reply)!=HOUSE_ARREST_E_SUCCESS) {
        fprintf(stderr,"Can't open AgePad's storage on the iPad. Is it connected by USB, unlocked, and is AgePad installed?\n");return 2;
    }
    plist_t item=plist_dict_get_item(reply,"Status");if (item) plist_get_string_val(item,&status);
    if (!status || strcmp(status,"Complete") || afc_client_new_from_house_arrest_client(house,&afc)!=AFC_E_SUCCESS) {
        fprintf(stderr,"The iPad refused access to AgePad's storage.\n");return 2;
    }
    int had_manifest=strcmp(remote_root,"/Documents/AgeOfEmpires2Data")?0:load_manifest();
    if (strcmp(remote_root,"/Documents/AgeOfEmpires2Data")) verify_all=1; // test folders: no saved record
    printf("Comparing your Mac's game files with the iPad%s…\n",had_manifest?"":" (first run: checking every file on the iPad)");
    fflush(stdout);
    plan("",!had_manifest);
    remove_stale("");
    uint64_t free_bytes=0;char *value=NULL;
    if (afc_get_device_info_key(afc,"FSFreeBytes",&value)==AFC_E_SUCCESS && value) { free_bytes=strtoull(value,NULL,10);free(value); }
    uint64_t need=wanted_bytes>replaced_bytes?wanted_bytes-replaced_bytes:0;need+=largest+(1ull<<30);
    printf("Mac: %llu files. Up to date: %llu. Recognised on the iPad: %llu. To copy: %zu (%.2f GB). Removed: %llu. iPad free: %.1f GB.\n",
        (unsigned long long)local_files,(unsigned long long)unchanged,(unsigned long long)adopted,wanted_count,wanted_bytes/1e9,
        (unsigned long long)removed,free_bytes/1e9);
    fflush(stdout);
    if (dry_run) return 0;
    if (wanted_count && free_bytes && free_bytes<need) {
        save_manifest();
        fprintf(stderr,"Not enough space on the iPad: about %.1f GB more is needed. Free some space and run this again (it continues where it stopped).\n",(need-free_bytes)/1e9);
        return 4;
    }
    char marker[PATH_MAX];snprintf(marker,sizeof marker,"%s/%s",remote_root,MARKER);
    if (wanted_count || removed) afc_remove_path(afc,marker); // "incomplete" until this run finishes
    uint64_t sent=0,since_save=0;time_t shown=0;int failures=0;
    for (size_t i=0;i<wanted_count;i++) {
        if (send_file(&wanted[i])) { fprintf(stderr,"\nCould not copy %s\n",wanted[i].path);if (++failures>5) break;continue; }
        record(wanted[i].path,wanted[i].size,wanted[i].mtime);sent+=wanted[i].size;since_save+=wanted[i].size;
        if (since_save>(512ull<<20) || (i+1)%200==0) { save_manifest();since_save=0; }
        if (time(NULL)!=shown || i+1==wanted_count) {
            shown=time(NULL);
            printf("\r  copied %zu of %zu files, %.2f of %.2f GB   ",i+1,wanted_count,sent/1e9,wanted_bytes/1e9);fflush(stdout);
        }
    }
    if (wanted_count) printf("\n");
    if (save_manifest()) { fprintf(stderr,"Could not save the copy record on the iPad.\n");return 5; }
    if (failures) { fprintf(stderr,"%d file(s) failed. Run this again; it continues where it stopped.\n",failures);return 1; }
    char stamp[64];snprintf(stamp,sizeof stamp,"agepad-sync build=%s\n",build);
    write_remote(marker,stamp,strlen(stamp));
    printf("The iPad's game files match your Mac.\n");
    afc_client_free(afc);house_arrest_client_free(house);idevice_free(device);
    return 0;
}
