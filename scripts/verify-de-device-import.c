// Compare a private Steam data tree with its in-place iPad app-container copy.
// Build: cc -O2 scripts/verify-de-device-import.c $(pkg-config --cflags --libs libimobiledevice-1.0) -o /tmp/agepad-verify-import
// Usage: agepad-verify-import UDID BUNDLE_ID LOCAL_DATA_ROOT
#include <libimobiledevice/libimobiledevice.h>
#include <libimobiledevice/house_arrest.h>
#include <libimobiledevice/afc.h>
#include <plist/plist.h>
#include <sys/stat.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <limits.h>
#include <dirent.h>

static afc_client_t afc;
static const char *source;
static uint64_t files, bytes, directories, differences;
static uint64_t source_files, source_bytes, source_directories;

static const char *field(char **info, const char *key) {
    for (size_t i=0;info && info[i] && info[i+1];i+=2)
        if (!strcmp(info[i],key)) return info[i+1];
    return NULL;
}

static void mismatch(const char *reason, const char *path) {
    differences++;
    if (differences<=30) fprintf(stderr,"%s: %s\n",reason,path);
}

static int verify_directory(const char *remote, const char *relative) {
    char **entries=NULL;
    if (afc_read_directory(afc,remote,&entries)!=AFC_E_SUCCESS) {
        mismatch("Cannot read iPad directory",remote);
        return -1;
    }
    directories++;
    for (size_t i=0;entries && entries[i] && *entries[i];i++) {
        const char *name=entries[i];
        if (!strcmp(name,".") || !strcmp(name,"..")) continue;
        if (!*relative && !strcmp(name,".agepad-import-inventory-checked")) continue;
        char remote_child[PATH_MAX], relative_child[PATH_MAX], local_child[PATH_MAX];
        int remote_length=snprintf(remote_child,sizeof(remote_child),"%s/%s",remote,name);
        int relative_length=snprintf(relative_child,sizeof(relative_child),"%s%s%s",relative,*relative?"/":"",name);
        int local_length=snprintf(local_child,sizeof(local_child),"%s/%s",source,relative_child);
        if (remote_length<0 || (size_t)remote_length>=sizeof(remote_child) ||
            relative_length<0 || (size_t)relative_length>=sizeof(relative_child) ||
            local_length<0 || (size_t)local_length>=sizeof(local_child)) {
            mismatch("Path too long",name);
            continue;
        }
        char **info=NULL;
        if (afc_get_file_info(afc,remote_child,&info)!=AFC_E_SUCCESS) {
            mismatch("Cannot stat iPad item",remote_child);
            continue;
        }
        const char *kind=field(info,"st_ifmt"), *size_text=field(info,"st_size");
        struct stat local;
        if (lstat(local_child,&local)) mismatch("Missing Mac source item",relative_child);
        else if (kind && !strcmp(kind,"S_IFDIR")) {
            if (!S_ISDIR(local.st_mode)) mismatch("Type differs",relative_child);
            else verify_directory(remote_child,relative_child);
        } else if (kind && !strcmp(kind,"S_IFREG")) {
            files++;
            uint64_t remote_size=size_text?strtoull(size_text,NULL,10):UINT64_MAX;
            bytes+=remote_size==UINT64_MAX?0:remote_size;
            if (!S_ISREG(local.st_mode) || remote_size!=(uint64_t)local.st_size)
                mismatch("File size differs",relative_child);
        } else mismatch("Unexpected iPad item type",relative_child);
        afc_dictionary_free(info);
    }
    afc_dictionary_free(entries);
    return 0;
}

static void summarize_source(const char *path) {
    DIR *directory=opendir(path);
    if (!directory) { mismatch("Cannot read Mac source directory",path); return; }
    source_directories++;
    struct dirent *entry;
    while ((entry=readdir(directory))) {
        if (!strcmp(entry->d_name,".") || !strcmp(entry->d_name,"..")) continue;
        char child[PATH_MAX];
        int length=snprintf(child,sizeof(child),"%s/%s",path,entry->d_name);
        if (length<0 || (size_t)length>=sizeof(child)) { mismatch("Mac source path too long",path); continue; }
        struct stat value;
        if (lstat(child,&value)) mismatch("Cannot stat Mac source item",child);
        else if (S_ISDIR(value.st_mode)) summarize_source(child);
        else if (S_ISREG(value.st_mode)) { source_files++; source_bytes+=(uint64_t)value.st_size; }
        else mismatch("Unexpected Mac source item type",child);
    }
    closedir(directory);
}

int main(int argc,char **argv) {
    if (argc!=4) {
        fprintf(stderr,"Usage: %s UDID BUNDLE_ID LOCAL_DATA_ROOT\n",argv[0]);
        return 64;
    }
    source=argv[3];
    idevice_t device=NULL;
    house_arrest_client_t house=NULL;
    plist_t reply=NULL;
    if (idevice_new_with_options(&device,argv[1],IDEVICE_LOOKUP_USBMUX)!=IDEVICE_E_SUCCESS ||
        house_arrest_client_start_service(device,&house,"AgePad import verification")!=HOUSE_ARREST_E_SUCCESS ||
        house_arrest_send_command(house,"VendContainer",argv[2])!=HOUSE_ARREST_E_SUCCESS ||
        house_arrest_get_result(house,&reply)!=HOUSE_ARREST_E_SUCCESS) {
        fprintf(stderr,"Cannot open the iPad app container\n");
        return 2;
    }
    plist_t status=plist_dict_get_item(reply,"Status");
    char *status_text=NULL;
    if (status) plist_get_string_val(status,&status_text);
    if (!status_text || strcmp(status_text,"Complete") ||
        afc_client_new_from_house_arrest_client(house,&afc)!=AFC_E_SUCCESS) {
        fprintf(stderr,"iPad app container request failed\n");
        return 2;
    }
    free(status_text);
    plist_free(reply);
    summarize_source(source);
    verify_directory("/Documents/AgeOfEmpires2Data","");
    if (files!=source_files || bytes!=source_bytes || directories!=source_directories)
        mismatch("Tree totals differ","AgeOfEmpires2Data");
    printf("Mac files=%llu directories=%llu bytes=%llu\n",
        (unsigned long long)source_files,(unsigned long long)source_directories,
        (unsigned long long)source_bytes);
    printf("iPad files=%llu directories=%llu bytes=%llu differences=%llu\n",
        (unsigned long long)files,(unsigned long long)directories,
        (unsigned long long)bytes,(unsigned long long)differences);
    afc_client_free(afc);
    house_arrest_client_free(house);
    idevice_free(device);
    return differences?1:0;
}
