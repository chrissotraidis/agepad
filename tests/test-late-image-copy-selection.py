#!/usr/bin/env python3
"""Actual fallback selector: opt-in, image-only, exact fixture names, no fault-context use."""
from pathlib import Path
import subprocess,tempfile
root=Path(__file__).resolve().parents[1]
s=(root/'worktrees/madeira/build/ntdll-unix/virtual_ios.c').read_text()
a=s.index('static int agepad_test_force_late_image_copy(');b=s.index('\nstatic inline int mprotect_exec',a)
pre=r'''
#include <assert.h>
#include <stdlib.h>
#include <string.h>
#define SEC_IMAGE 0x100
static int ios_in_mach_exc,missing,queries;
static const char *image_name;
static struct file_view {void *base;size_t size;unsigned protect;} view;
static struct file_view *find_view(void *base,size_t size){queries++;return missing?NULL:&view;}
static const char *ios_pe_module_name(void *base,size_t size){return image_name;}
'''
main=r'''
int main(void) {
 image_name="agepad-late-one.dll";view.protect=SEC_IMAGE;
 unsetenv("AGEPAD_TEST_FORCE_LATE_IMAGE_COPY");assert(!agepad_test_force_late_image_copy(0,0)&&!queries);
 setenv("AGEPAD_TEST_FORCE_LATE_IMAGE_COPY","0",1);assert(!agepad_test_force_late_image_copy(0,0)&&!queries);
 setenv("AGEPAD_TEST_FORCE_LATE_IMAGE_COPY","1",1);
 ios_in_mach_exc=1;assert(!agepad_test_force_late_image_copy(0,0)&&!queries);ios_in_mach_exc=0;
 missing=1;assert(!agepad_test_force_late_image_copy(0,0));missing=0;
 view.protect=0;assert(!agepad_test_force_late_image_copy(0,0));view.protect=SEC_IMAGE;
 assert(agepad_test_force_late_image_copy(0,0));image_name="agepad-late-two.dll";assert(agepad_test_force_late_image_copy(0,0));
 image_name="agepad-late-two.dll.extra";assert(!agepad_test_force_late_image_copy(0,0));
 image_name="AoE2DE_s.exe";assert(!agepad_test_force_late_image_copy(0,0));return 0;
}
'''
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'test.c';p.write_text(pre+s[a:b]+main);exe=Path(d)/'test'
 subprocess.run(['clang','-fsanitize=address,undefined',str(p),'-o',str(exe)],check=True)
 subprocess.run([str(exe)],check=True)
print('PASS forced-copy selection excludes default, non-image, non-fixture and Mach fault contexts')
