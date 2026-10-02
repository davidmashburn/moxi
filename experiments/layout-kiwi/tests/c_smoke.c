/* Compile as C, then link the C++ implementation through the public ABI. */
#include "layout_kiwi.h"
#include <assert.h>
#include <math.h>
int main(void) {
    layout_kiwi_solver *solver = layout_kiwi_create();
    assert(solver != NULL);
    assert(layout_kiwi_add_variable(solver, 1) == LAYOUT_KIWI_OK);
    const int32_t ids[] = {1};
    const double coefficients[] = {1};
    assert(layout_kiwi_add_constraint(solver, 1, ids, coefficients, 1, -42,
                                    LAYOUT_KIWI_RELATION_EQ, 1001001000) == 0);
    assert(layout_kiwi_update(solver) == 0);
    double value = 0;
    assert(layout_kiwi_get_value(solver, 1, &value) == 0);
    assert(fabs(value - 42) < 1e-9);
    layout_kiwi_destroy(solver);
    return 0;
}
