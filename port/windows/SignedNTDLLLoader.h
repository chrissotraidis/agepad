/* Local, opt-in single-process experiment. Included by Wine loader_ios.c.
 * This registers an already signed PE container without remapping its text.
 * It is not a replacement for the normal PE loader or process isolation. */
/* base, size, writable split, owning PEB; zero base terminates unused slots. */
#define AGEPAD_SIGNED_IMAGE_CAPACITY 256
#define AGEPAD_CHILD_BANK_CAPACITY 16
static ULONG_PTR agepad_signed_image_table[AGEPAD_SIGNED_IMAGE_CAPACITY][4];
static pthread_mutex_t agepad_signed_load_mutex = PTHREAD_MUTEX_INITIALIZER;
static pthread_mutex_t agepad_child_bank_mutex = PTHREAD_MUTEX_INITIALIZER;
static void *agepad_child_bank_owners[AGEPAD_CHILD_BANK_CAPACITY];
/* Banks are never recycled in this prototype: exited guests may leave live
 * callbacks or native threads. Exhaustion fails instead of sharing data. */
static unsigned int agepad_child_bank(void *owner, BOOL reserve)
{
    unsigned int slot = 0;
    pthread_mutex_lock(&agepad_child_bank_mutex);
    for (unsigned int i = 0; i < AGEPAD_CHILD_BANK_CAPACITY; ++i)
        if (agepad_child_bank_owners[i] == owner) { slot = i + 1; break; }
    if (!slot && reserve)
        for (unsigned int i = 0; i < AGEPAD_CHILD_BANK_CAPACITY; ++i)
            if (!agepad_child_bank_owners[i]) { agepad_child_bank_owners[i] = owner; slot = i + 1; break; }
    pthread_mutex_unlock(&agepad_child_bank_mutex);
    return slot;
}
BOOL agepad_signed_owner_registered(void *owner)
{
    for (unsigned int i = 0; i < AGEPAD_SIGNED_IMAGE_CAPACITY; ++i)
        if (__atomic_load_n(&agepad_signed_image_table[i][0], __ATOMIC_ACQUIRE) && agepad_signed_image_table[i][3] == (ULONG_PTR)owner) return TRUE;
    return FALSE;
}

static NTSTATUS agepad_load_signed_ntdll_locked(const char *path, UNICODE_STRING *name, void **result, BOOL ntdll_slots, struct pe_image_info *image_result)
{
    static struct { void *handle, *base, *owner; struct pe_image_info info; } retained[AGEPAD_SIGNED_IMAGE_CAPACITY];
    static unsigned int retained_count;
    unsigned char *base, *data;
    IMAGE_DOS_HEADER *dos;
    IMAGE_NT_HEADERS *nt;
    IMAGE_DATA_DIRECTORY *dir;
    struct pe_image_info info = {0};
    SIZE_T split, size, offset, end;
    unsigned int fixed = 0;
    UINT_PTR delta;
    NTSTATUS status;
    void *handle;
    handle = dlopen(path, RTLD_NOW | RTLD_LOCAL);
    if (!handle) { dprintf(2, "[signed-ntdll] dlopen: %s\n", dlerror()); return STATUS_DLL_NOT_FOUND; }
    base = dlsym(handle, "agepad_pe_base");
    data = dlsym(handle, "agepad_pe_data");
    if (!base || !data || data <= base) goto invalid;
    for (unsigned int i = 0; i < retained_count; ++i)
    {
        if (retained[i].base != base) continue;
        dlclose(handle);
        if (retained[i].owner != NtCurrentTeb()->Peb) return STATUS_NOT_SUPPORTED;
        *result = base;
        if (image_result) *image_result = retained[i].info;
        return STATUS_SUCCESS;
    }
    if (retained_count == AGEPAD_SIGNED_IMAGE_CAPACITY) { dlclose(handle); return STATUS_NOT_SUPPORTED; }
    split = data - base;
    dos = (void *)base;
    if (dos->e_magic != IMAGE_DOS_SIGNATURE || dos->e_lfanew < 0 || (SIZE_T)dos->e_lfanew + sizeof(*nt) > split) goto invalid;
    nt = (void *)(base + dos->e_lfanew);
    if (nt->Signature != IMAGE_NT_SIGNATURE || nt->OptionalHeader.Magic != IMAGE_NT_OPTIONAL_HDR64_MAGIC) goto invalid;
    size = nt->OptionalHeader.SizeOfImage;
    if (size <= split || size > 64 * 1024 * 1024) goto invalid;
    dir = &nt->OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_BASERELOC];
    offset = dir->VirtualAddress; end = offset + dir->Size;
    if (end > size || end < offset) goto invalid;
    delta = (UINT_PTR)base - nt->OptionalHeader.ImageBase;
    /* Validate every site before changing any data. */
    for (int apply = 0; apply < 2; ++apply)
    {
        offset = dir->VirtualAddress;
        while (offset < end)
        {
            IMAGE_BASE_RELOCATION *block = (void *)(base + offset);
            WORD *entries = (void *)(block + 1);
            if (end - offset < sizeof(*block) || block->SizeOfBlock < sizeof(*block) ||
                block->SizeOfBlock > end - offset || block->SizeOfBlock % 2) goto invalid;
            for (SIZE_T i = 0; i < (block->SizeOfBlock - sizeof(*block)) / 2; ++i)
            {
                SIZE_T site = (SIZE_T)block->VirtualAddress + (entries[i] & 4095);
                if (!(entries[i] >> 12)) continue;
                if ((entries[i] >> 12) != IMAGE_REL_BASED_DIR64 || site < split || site > size - 8) goto invalid;
                if (apply) { UINT64 value; memcpy(&value, base + site, 8); value += delta; memcpy(base + site, &value, 8); ++fixed; }
            }
            offset += block->SizeOfBlock;
        }
    }
    /* All slots written by load_ntdll_functions must be writable data. */
    if (ntdll_slots)
    {
        const char *slots[] = {"__wine_syscall_dispatcher", "__wine_unix_call_dispatcher",
            "__wine_unixlib_handle", "__wine_unix_call_dispatcher_arm64ec",
            "ios_teb_tsd_offset", "agepad_direct_teb_check", "p_ios_jit_translate_addr", "p_ios_jit_reverse_translate_addr", "agepad_signed_images"};
        const IMAGE_EXPORT_DIRECTORY *exports = get_module_data_dir(base, IMAGE_DIRECTORY_ENTRY_EXPORT, NULL);
        if (!exports) goto invalid;
        for (unsigned int i = 0; i < sizeof(slots)/sizeof(slots[0]); ++i)
        {
            unsigned char *slot = find_named_export(base, exports, slots[i]);
            if (!slot || slot < data || slot > base + size - sizeof(void *)) goto invalid;
        }
    }
    info.base = (UINT_PTR)base; /* actual dyld mapping, never PE preferred base */
    info.entry_point = nt->OptionalHeader.AddressOfEntryPoint;
    info.map_size = size;
    info.stack_size = nt->OptionalHeader.SizeOfStackReserve;
    info.stack_commit = nt->OptionalHeader.SizeOfStackCommit;
    info.subsystem = nt->OptionalHeader.Subsystem;
    info.subsystem_minor = nt->OptionalHeader.MinorSubsystemVersion;
    info.subsystem_major = nt->OptionalHeader.MajorSubsystemVersion;
    info.osversion_major = nt->OptionalHeader.MajorOperatingSystemVersion;
    info.osversion_minor = nt->OptionalHeader.MinorOperatingSystemVersion;
    info.image_charact = nt->FileHeader.Characteristics;
    info.dll_charact = nt->OptionalHeader.DllCharacteristics;
    info.machine = nt->FileHeader.Machine;
    info.contains_code = TRUE;
    info.wine_builtin = TRUE;
    info.header_size = nt->OptionalHeader.SizeOfHeaders;
    info.file_size = size;
    info.checksum = nt->OptionalHeader.CheckSum;
    status = virtual_create_builtin_view(base, name, &info, handle);
    dprintf(2, "[signed-ntdll] register base=%p split=%zx size=%zx relocations=%u status=%lx\n", base, split, size, fixed, (unsigned long)status);
    if (status) { dlclose(handle); return status; }
    agepad_signed_image_table[retained_count][1] = size;
    agepad_signed_image_table[retained_count][2] = split;
    agepad_signed_image_table[retained_count][3] = (ULONG_PTR)NtCurrentTeb()->Peb;
    __atomic_store_n(&agepad_signed_image_table[retained_count][0], (ULONG_PTR)base, __ATOMIC_RELEASE);
    retained[retained_count].handle = handle;
    retained[retained_count].base = base;
    retained[retained_count].owner = NtCurrentTeb()->Peb;
    retained[retained_count++].info = info;
    if (image_result) *image_result = info;
    dprintf(2, "[signed-dll] registered %s\n", path);
    *result = base;
    return STATUS_SUCCESS;
invalid:
    dprintf(2, "[signed-ntdll] rejected container layout or dispatcher slots\n");
    dlclose(handle);
    return STATUS_INVALID_IMAGE_FORMAT;
}

static NTSTATUS agepad_load_signed_ntdll(const char *path, UNICODE_STRING *name, void **result, BOOL ntdll_slots, struct pe_image_info *image_result)
{
    NTSTATUS status;
    pthread_mutex_lock(&agepad_signed_load_mutex);
    status = agepad_load_signed_ntdll_locked(path, name, result, ntdll_slots, image_result);
    pthread_mutex_unlock(&agepad_signed_load_mutex);
    return status;
}

/* Prerequisite check only: no child PEB is created or registered here. */
static int agepad_check_child_ntdll_storage(void *root)
{
    const char *dir = getenv("AGEPAD_SIGNED_DLL_DIR");
    char *path;
    void *handle;
    unsigned char *child, *child_data;
    const IMAGE_EXPORT_DIRECTORY *root_exports, *child_exports;
    unsigned int *root_slot, *child_slot, before, fresh;
    IMAGE_DOS_HEADER *dos;
    IMAGE_NT_HEADERS *nt;
    SIZE_T split;
    if (!dir || asprintf(&path, "%s/ntdll-child-1.dll.dylib", dir) < 0) return -1;
    handle = dlopen(path, RTLD_NOW | RTLD_LOCAL);
    free(path);
    if (!handle) { dprintf(2, "[AgePad-child-storage] dlopen failed: %s\n", dlerror()); return -1; }
    child = dlsym(handle, "agepad_pe_base");
    child_data = dlsym(handle, "agepad_pe_data");
    if (!child || !child_data || child == root || child_data <= child) goto fail;
    split = child_data - child;
    dos = (void *)child;
    if (dos->e_magic != IMAGE_DOS_SIGNATURE || dos->e_lfanew < 0 || (SIZE_T)dos->e_lfanew + sizeof(*nt) > split) goto fail;
    nt = (void *)(child + dos->e_lfanew);
    if (nt->Signature != IMAGE_NT_SIGNATURE || split != agepad_signed_image_table[0][2] ||
        nt->OptionalHeader.SizeOfImage != agepad_signed_image_table[0][1] || memcmp(root, child, split)) goto fail;
    root_exports = get_module_data_dir(root, IMAGE_DIRECTORY_ENTRY_EXPORT, NULL);
    child_exports = get_module_data_dir(child, IMAGE_DIRECTORY_ENTRY_EXPORT, NULL);
    if (!root_exports || !child_exports) goto fail;
    root_slot = find_named_export(root, root_exports, "ios_teb_tsd_offset");
    child_slot = find_named_export(child, child_exports, "ios_teb_tsd_offset");
    if (!root_slot || !child_slot || (unsigned char *)child_slot < child_data ||
        (unsigned char *)child_slot > child + nt->OptionalHeader.SizeOfImage - sizeof(*child_slot)) goto fail;
    before = *root_slot; fresh = *child_slot;
    if (!before || fresh != 0) goto fail;
    *(volatile unsigned int *)child_slot = before ^ 0x5a5a5a5a;
    if (*(volatile unsigned int *)root_slot != before || *(volatile unsigned int *)child_slot != (before ^ 0x5a5a5a5a)) {
        *child_slot = fresh;
        goto fail;
    }
    *child_slot = fresh;
    if (*root_slot != before || memcmp(root, child, split)) goto fail;
    dprintf(2, "[AgePad-child-storage] PASS root=%p child=%p root_tsd=%x child_tsd=%x identical_native_prefix=%zx independent_data=1; no child execution\n",
            root, child, *root_slot, *child_slot, split);
    dlclose(handle);
    return 0;
fail:
    dprintf(2, "[AgePad-child-storage] FAIL distinct signed storage check\n");
    dlclose(handle);
    return -1;
}
