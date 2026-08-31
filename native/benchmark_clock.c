#include <stdint.h>
#include <time.h>

int64_t moxi_benchmark_time_ns(void) {
    struct timespec now;
    if (clock_gettime(CLOCK_MONOTONIC, &now) != 0) {
        return 0;
    }
    return (int64_t)now.tv_sec * 1000000000LL + (int64_t)now.tv_nsec;
}
