/* Keep the shared C ABI test unchanged; check its actual process before calling it. */
#define _WIN32_WINNT 0x0A00
#include <windows.h>
#include <stdio.h>

int moxi_counter_check(void);

int main(void) {
    USHORT process_machine = IMAGE_FILE_MACHINE_UNKNOWN;
    USHORT native_machine = IMAGE_FILE_MACHINE_UNKNOWN;
#if defined(_M_ARM64)
    const USHORT target_machine = IMAGE_FILE_MACHINE_ARM64;
    const char *target_name = "ARM64";
#elif defined(_M_X64)
    const USHORT target_machine = IMAGE_FILE_MACHINE_AMD64;
    const char *target_name = "AMD64";
#else
#error This probe requires an AMD64 or ARM64 MSVC target
#endif

    if (!IsWow64Process2(GetCurrentProcess(), &process_machine, &native_machine)) {
        fprintf(stderr, "FAIL: IsWow64Process2 error=%lu\n", GetLastError());
        return 1;
    }
    printf("ARCH: target=%s process=0x%04X native=0x%04X pointer_bits=%u\n",
           target_name, (unsigned)process_machine, (unsigned)native_machine,
           (unsigned)(sizeof(void *) * 8));
    if (process_machine != IMAGE_FILE_MACHINE_UNKNOWN ||
        native_machine != target_machine || sizeof(void *) != 8) {
        fputs("FAIL: caller must run natively on the matching Windows architecture\n", stderr);
        return 1;
    }
    return moxi_counter_check();
}
