#include <stdlib.h>
#include <stdint.h>
#include <mach/mach.h>

/* Benchmark-only configuration; never linked into the application. */
int moxi_workbench_benchmark_config(int field) {
    const char *names[] = {"MOXI_WORKBENCH_REPETITIONS", "MOXI_WORKBENCH_WARMUP",
                          "MOXI_WORKBENCH_INSTRUMENTED", "MOXI_WORKBENCH_NATIVE",
                          "MOXI_WORKBENCH_SOAK_SECONDS"};
    const int defaults[] = {1, 1, 1, 0, 0};
    if (field < 0 || field > 4) return 0;
    const char *value = getenv(names[field]);
    return value ? atoi(value) : defaults[field];
}

int64_t moxi_workbench_resident_bytes(void) {
    mach_task_basic_info_data_t info;
    mach_msg_type_number_t count = MACH_TASK_BASIC_INFO_COUNT;
    if (task_info(mach_task_self(), MACH_TASK_BASIC_INFO,
                  (task_info_t)&info, &count) != KERN_SUCCESS) return -1;
    return (int64_t)info.resident_size;
}
