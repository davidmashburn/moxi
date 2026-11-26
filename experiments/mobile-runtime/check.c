#include <stdint.h>
#include <stdio.h>

extern int32_t moxi_mobile_increment(int32_t value);

int main(void) {
    int32_t first = moxi_mobile_increment(0);
    int32_t second = moxi_mobile_increment(first);
    if (first != 1 || second != 2 || moxi_mobile_increment(-3) != -2)
        return 1;
    puts("PASS: C called the Mojo Counter increment for three transitions");
    return 0;
}
