#!/usr/bin/env python3
"""Test the actual signal routine against real host Mach ports (not guest APCs)."""
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
source = (root / 'worktrees/madeira/build/wineserver/mach_ios.c').read_text()
a = source.index('int send_thread_signal( struct thread *thread, int sig )')
b = source.index('\n#ifdef WINE_IOS\n/* iOS cross-thread context', a)
body = source[a:b]
pre = r'''
#include <mach/mach.h>
#include <pthread.h>
#include <signal.h>
#include <stdatomic.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <errno.h>
#include <assert.h>
#define WINE_IOS 1
struct process { mach_port_t trace_data; };
struct thread { struct process *process; int unix_pid, unix_tid; unsigned id; };
static int debug_level;
static int agepad_server_startup_trace;
static mach_port_t get_process_port(struct process *p) { return p->trace_data; }
extern int __pthread_kill(mach_port_t, int);
static atomic_int ready, done;
static volatile sig_atomic_t received;
static void handler(int sig) { if (sig == SIGUSR1) received = 1; }
static void *worker(void *arg) {
    (void)arg;
    sigset_t mask; sigemptyset(&mask); sigaddset(&mask, SIGUSR1);
    pthread_sigmask(SIG_UNBLOCK, &mask, NULL);
    atomic_store(&ready, 1);
    while (!atomic_load(&done)) usleep(1000);
    return NULL;
}
'''
post = r'''
int main(void) {
    struct sigaction sa = {0}; sa.sa_handler = handler; sigemptyset(&sa.sa_mask);
    assert(sigaction(SIGUSR1, &sa, NULL) == 0);
    pthread_t worker_thread; assert(pthread_create(&worker_thread, NULL, worker, NULL) == 0);
    while (!atomic_load(&ready)) usleep(1000);
    struct process process = {0};
    struct thread target = {&process, getpid(), pthread_mach_thread_np(worker_thread), 1};
    /* This is the previously failing case: real target, no launchd trace port. */
    int sent = send_thread_signal(&target, SIGUSR1);
    for (int i = 0; i < 1000 && !received; ++i) usleep(1000);
    int delivered = received;
    atomic_store(&done, 1); pthread_join(worker_thread, NULL);
    if (!sent || !delivered) { puts("FAIL: embedded thread signal was not delivered"); return 2; }
    assert(process.trace_data == 0); /* Must not enable memory operations globally. */
    target.unix_pid = getpid() + 100000; target.unix_tid = mach_thread_self();
    assert(!send_thread_signal(&target, 0)); /* Foreign PID must not use our task. */
    mach_port_deallocate(mach_task_self(), target.unix_tid);
    target.unix_pid = -1; assert(!send_thread_signal(&target, 0));
    target.unix_pid = getpid(); target.unix_tid = MACH_PORT_NULL;
    assert(!send_thread_signal(&target, 0));
    assert(target.unix_pid == -1 && target.unix_tid == -1);
    /* Existing registered-port route remains usable. */
    process.trace_data = mach_task_self(); target.unix_pid = getpid(); target.unix_tid = mach_thread_self();
    assert(send_thread_signal(&target, 0));
    mach_port_deallocate(mach_task_self(), target.unix_tid);
    puts("PASS: actual delivery, foreign/dead/invalid guards, unchanged trace port, registered route");
    return 0;
}
'''
with tempfile.TemporaryDirectory(prefix='agepad-thread-signal-') as directory:
    c = Path(directory) / 'test.c'
    exe = Path(directory) / 'test'
    def build(text):
        c.write_text(pre + text + post)
        subprocess.run(['xcrun', 'clang', '-std=c11', '-Wall', '-Wextra', '-pthread', str(c), '-o', str(exe)], check=True)
    build(body)
    subprocess.run([str(exe)], check=True, timeout=10)
    old = body.replace('    if (!process_port && thread->unix_pid == getpid())\n        process_port = mach_task_self();', '')
    assert old != body
    build(old)
    result = subprocess.run([str(exe)], capture_output=True, timeout=10)
    assert result.returncode == 2 and b'embedded thread signal was not delivered' in result.stdout
    print('PASS: negative control reproduces missing-port failure')
