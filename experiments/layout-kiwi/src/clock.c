/* Experiment-local high resolution monotonic clock, shared by both Mojo paths. */
#include <stdint.h>
#ifdef __APPLE__
#include <mach/mach_time.h>
int64_t moxi_benchmark_time_ns(void) {
    mach_timebase_info_data_t info;
    mach_timebase_info(&info);
    uint64_t tick = mach_absolute_time();
    return (int64_t)((tick / info.denom) * info.numer +
                     (tick % info.denom) * info.numer / info.denom);
}
#else
#include <time.h>
int64_t moxi_benchmark_time_ns(void) {
    struct timespec now;
    if (clock_gettime(CLOCK_MONOTONIC, &now) != 0) return 0;
    return (int64_t)now.tv_sec * 1000000000LL + now.tv_nsec;
}
#endif
