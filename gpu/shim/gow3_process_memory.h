// SPDX-License-Identifier: GPL-2.0-or-later
// gow3: portable process memory readings. The pipeline warm-up report and the performance overlay
// use these instead of the Windows Process Status API directly, so they also work on Linux.
#pragma once

#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>

#ifdef _WIN32
#include <windows.h>
#include <psapi.h>
#else
#include <unistd.h>
#endif

namespace Gow3ProcessMemory {

#if defined(__linux__)
namespace Detail {
/// Reads a "<key>: <value> kB" line from /proc/self/status; 0 when it is not there.
inline std::uint64_t StatusKilobytes(const char* key) {
    std::FILE* status = std::fopen("/proc/self/status", "r");
    if (!status) {
        return 0;
    }
    const std::size_t key_length = std::strlen(key);
    char line[256];
    std::uint64_t value = 0;
    while (std::fgets(line, sizeof(line), status)) {
        if (std::strncmp(line, key, key_length) == 0) {
            value = std::strtoull(line + key_length, nullptr, 10);
            break;
        }
    }
    std::fclose(status);
    return value;
}
} // namespace Detail
#endif

/// Resident set of the process, in bytes; 0 when the platform cannot report it.
inline std::uint64_t CurrentRssBytes() {
#ifdef _WIN32
    PROCESS_MEMORY_COUNTERS memory{};
    memory.cb = sizeof(memory);
    if (K32GetProcessMemoryInfo(GetCurrentProcess(), &memory, sizeof(memory))) {
        return memory.WorkingSetSize;
    }
    return 0;
#elif defined(__linux__)
    return Detail::StatusKilobytes("VmRSS:") * 1024;
#else
    return 0;
#endif
}

/// Peak resident set of the process, in bytes; 0 when the platform cannot report it.
inline std::uint64_t PeakRssBytes() {
#ifdef _WIN32
    PROCESS_MEMORY_COUNTERS memory{};
    memory.cb = sizeof(memory);
    if (K32GetProcessMemoryInfo(GetCurrentProcess(), &memory, sizeof(memory))) {
        return memory.PeakWorkingSetSize;
    }
    return 0;
#elif defined(__linux__)
    return Detail::StatusKilobytes("VmHWM:") * 1024;
#else
    return 0;
#endif
}

/// Physical memory of the machine, in bytes; 0 when the platform cannot report it.
inline std::uint64_t TotalRamBytes() {
#ifdef _WIN32
    MEMORYSTATUSEX system{};
    system.dwLength = sizeof(system);
    if (GlobalMemoryStatusEx(&system)) {
        return system.ullTotalPhys;
    }
    return 0;
#else
    const long pages = sysconf(_SC_PHYS_PAGES);
    const long page_size = sysconf(_SC_PAGESIZE);
    if (pages > 0 && page_size > 0) {
        return std::uint64_t(pages) * std::uint64_t(page_size);
    }
    return 0;
#endif
}

} // namespace Gow3ProcessMemory
