#!/usr/bin/env python3
"""Exercise the actual NtClose critical section with server-exit injection.

Native harness, not guest execution: substitutes the server transport with
pthread_exit to model the observed read-reply EOF path. Also builds a negative
control removing only the added cleanup registration.
"""
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
source = (root / 'worktrees/madeira/build/ntdll-unix/server_ios.c').read_text()
a = source.index('struct ios_fd_request_cleanup\n')
b = source.index('\n}\n', source.index('static void ios_fd_request_aborted', a)) + 3
helper = source[a:b]
a = source.index('NTSTATUS WINAPI NtClose(')
b = source.index('    if (ret != STATUS_INVALID_HANDLE', a)
body = source[a:b]
body = body[body.index('    server_enter_uninterrupted_section'):]
for name in ['server_queue_process_apc', 'server_get_unix_fd', 'NtDuplicateObject', 'NtClose']:
    prefix_name = 'unsigned int ' if name == 'server_queue_process_apc' else 'int ' if name == 'server_get_unix_fd' else 'NTSTATUS WINAPI '
    a = source.index(prefix_name + name + '(')
    b = source.index('\n}\n', a)
    section = source[a:b]
    assert 'pthread_cleanup_push( ios_fd_request_aborted, &fd_cleanup );' in section, name
    assert 'pthread_cleanup_pop( 0 );' in section, name

prefix = r'''
#include <pthread.h>
#include <signal.h>
#include <unistd.h>
#include <fcntl.h>
#include <assert.h>
#include <errno.h>
#include <stdio.h>
#include <stdint.h>
static pthread_mutex_t fd_cache_mutex = PTHREAD_MUTEX_INITIALIZER;
static int descriptor, mode, removed, invalidated;
static void mutex_unlock(pthread_mutex_t *m) { assert(!pthread_mutex_unlock(m)); }
static void server_enter_uninterrupted_section(pthread_mutex_t *m, sigset_t *s)
{ (void)s; assert(!pthread_mutex_lock(m)); }
static void server_leave_uninterrupted_section(pthread_mutex_t *m, sigset_t *s)
{ (void)s; mutex_unlock(m); }
static int remove_fd_from_cache(int h) { assert(h == 42); removed++; return descriptor; }
static void close_inproc_sync(int h) { assert(h == 42 && removed == 1); invalidated++; }
static int wine_server_obj_handle(int h) { return h; }
struct request { int handle; };
#define SERVER_START_REQ(name) { struct request data, *req = &data;
#define SERVER_END_REQ }
static unsigned wine_server_call(struct request *r)
{
    assert(r->handle == 42 && removed == 1 && invalidated == 1);
    if (!mode) pthread_exit((void *)73);
    return mode == 1 ? 0 : 0xc0000008u;
}
'''
suffix = r'''
    return (void *)(uintptr_t)ret;
}
int main(int argc, char **argv)
{
    (void)argv;
    int negative = argc > 1;
    for (mode = 0; mode < 3; ++mode)
    {
        pthread_t worker;
        void *result;
        descriptor = open("/dev/null", O_RDONLY);
        assert(descriptor >= 0);
        removed = invalidated = 0;
        assert(!pthread_create(&worker, NULL, run_request, NULL));
        assert(!pthread_join(worker, &result));
        assert((uintptr_t)result == (mode == 0 ? 73u : mode == 1 ? 0u : 0xc0000008u));
        int lock_status = pthread_mutex_trylock(&fd_cache_mutex);
        if (negative && mode == 0)
        {
            assert(lock_status == EBUSY);
            assert(fcntl(descriptor, F_GETFD) >= 0);
            close(descriptor);
            puts("NEGATIVE_CONTROL: orphaned mutex and removed fd reproduced");
            return 0;
        }
        assert(lock_status == 0);
        assert(fcntl(descriptor, F_GETFD) == -1 && errno == EBADF);
        mutex_unlock(&fd_cache_mutex);
    }
    puts("PASS: exit, success, and failed request release mutex and removed fd");
}
'''
with tempfile.TemporaryDirectory(prefix='agepad-fd-exit-') as tmp:
    for negative in [True, False]:
        fragment = body
        if negative:
            fragment = '\n'.join(line for line in fragment.splitlines()
                                 if 'pthread_cleanup_' not in line)
        code = prefix + helper + '\nstatic void *run_request(void *unused)\n{\n' + \
            '    (void)unused; sigset_t sigset; int handle = 42, fd = -1; unsigned ret;\n' + fragment + suffix
        c = Path(tmp) / 'probe.c'
        exe = Path(tmp) / 'probe'
        c.write_text(code)
        subprocess.run(['xcrun', 'clang', '-Wall', '-Wextra', '-fsanitize=address,undefined',
                        '-g', '-pthread', str(c), '-o', str(exe)], check=True)
        subprocess.run([str(exe)] + (['negative'] if negative else []), check=True, timeout=10)
