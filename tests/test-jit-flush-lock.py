#!/usr/bin/env python3
"""Test the actual native flush helper's lock and signal ordering contract.

Cache maintenance and write protection are instrumented; this is not a test of
ARM cache coherence, mapping lifetime, or complete Wine concurrency.
"""
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
source = (root / 'worktrees/madeira/build/ntdll-unix/virtual_ios.c').read_text()
start = source.index('static void agepad_jit_flush_extent(')
helper = source[start:source.index('\nstatic NTSTATUS agepad_jit_service(void *opaque)', start)]
helper = helper.replace('__builtin___clear_cache', 'instrumented_clear_cache')
pre = r'''
#include <assert.h>
#include <errno.h>
#include <pthread.h>
#include <signal.h>
#include <stdio.h>
#include <stddef.h>
typedef size_t SIZE_T;
typedef int BOOL;
static pthread_mutex_t virtual_mutex = PTHREAD_MUTEX_INITIALIZER;
static char pool[8192];
static int expect_unlocked, flushes, protected;
static void mutex_lock(pthread_mutex_t *m) { assert(!pthread_mutex_lock(m)); }
static void mutex_unlock(pthread_mutex_t *m) { assert(!pthread_mutex_unlock(m)); }
static void assert_blocked(void) {
    sigset_t current;
    assert(!pthread_sigmask(SIG_SETMASK, NULL, &current));
    assert(sigismember(&current, SIGUSR1) == 1);
}
static void *contender(void *unused) {
    (void)unused;
    int result = pthread_mutex_trylock(&virtual_mutex);
    if (expect_unlocked) {
        assert(result == 0);
        mutex_unlock(&virtual_mutex);
    } else assert(result == EBUSY);
    return NULL;
}
static void check_concurrent_access(void) {
    pthread_t thread;
    assert(!pthread_create(&thread, NULL, contender, NULL));
    assert(!pthread_join(thread, NULL));
}
static void instrumented_clear_cache(void *begin, void *end) {
    assert_blocked();
    assert(!protected);
    assert(begin == pool && end == pool + sizeof(pool));
    check_concurrent_access();
    ++flushes;
}
static void protect(int enabled) {
    assert(enabled == 1 && !protected);
    assert_blocked();
    check_concurrent_access();
    protected = 1;
}
static void (*agepad_jit_protect)(int) = protect;
'''
post = r'''
int main(void) {
    sigset_t block, old;
    sigemptyset(&block); sigaddset(&block, SIGUSR1);
    for (int mode = 0; mode < 2; ++mode) {
        expect_unlocked = mode;
        flushes = protected = 0;
        assert(!pthread_sigmask(SIG_BLOCK, &block, &old));
        mutex_lock(&virtual_mutex);
        agepad_jit_flush_extent(pool, sizeof(pool), mode);
        assert(flushes == 1 && protected);
        assert_blocked();
        /* The helper must return with the caller's lock reacquired. */
        expect_unlocked = 0;
        check_concurrent_access();
        mutex_unlock(&virtual_mutex);
        assert(!pthread_sigmask(SIG_SETMASK, &old, NULL));
    }
    puts("JIT_FLUSH_LOCK_PASS: same extent; concurrent metadata access only when enabled; signals blocked through protection restore; lock reacquired");
}
'''
with tempfile.TemporaryDirectory(prefix='agepad-flush-lock-') as temporary:
    directory = Path(temporary)
    c_file = directory / 'test.c'
    c_file.write_text(pre + helper + post)
    executable = directory / 'test'
    subprocess.run(['clang', '-O1', '-g', '-pthread', '-fsanitize=address,undefined',
                    str(c_file), '-o', str(executable)], check=True)
    subprocess.run([str(executable)], check=True, timeout=15)
