// Physical iPad build unit. The Mac engine constructs named C++ locales such
// as "en_US.UTF-8" (observed while starting a match, for telemetry timestamp
// text). iPadOS ships no named POSIX locale database, so libc++ throws and the
// uncaught exception aborts the game. Try the requested locale first; only if
// libc++ rejects it, use the classic "C" locale and log the substitution.
#include <TargetConditionals.h>
#if !TARGET_OS_SIMULATOR
#include <locale>
#include <new>
#include <stdexcept>
#include <atomic>
#include <cstdio>
#include <cstring>
#include <unistd.h>
extern "C" void DEOriginalLocaleFromName(void *, const char *) __asm__("__ZNSt3__16localeC1EPKc");
extern "C" void DEOriginalLocaleCategory(void *, const std::locale &, const char *, int) __asm__("__ZNSt3__16localeC1ERKS0_PKci");
static void DEReportLocale(const char *name) {
    static std::atomic<unsigned> reports;
    if (reports++ < 8) {
        char line[200];
        int length = snprintf(line, sizeof(line), "DE_LOCALE_UNAVAILABLE name=%s using=C\n", name ? name : "(null)");
        if (length > 0) write(STDERR_FILENO, line, (size_t)length);
    }
}
static void DELocaleFromName(std::locale *self, const char *name) {
    try {
        new (self) std::locale(name);
        return;
    } catch (const std::runtime_error &) {
    }
    DEReportLocale(name);
    new (self) std::locale(std::locale::classic());
}
static void DELocaleCategory(std::locale *self, const std::locale &other, const char *name, int category) {
    try {
        new (self) std::locale(other, name, category);
        return;
    } catch (const std::runtime_error &) {
    }
    DEReportLocale(name);
    new (self) std::locale(other);
}
__attribute__((used, section("__DATA,__interpose")))
static const struct { const void *replacement; const void *original; } DELocaleInterpose[] = {
    {(const void *)DELocaleFromName, (const void *)DEOriginalLocaleFromName},
    {(const void *)DELocaleCategory, (const void *)DEOriginalLocaleCategory},
};
#endif
