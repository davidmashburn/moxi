#include "layout_kiwi.h"

#include <cassert>
#include <cmath>
#include <cstring>

namespace {

constexpr double kRequired = 1001001000.0;
constexpr double kStrong = 1000000.0;

void expect_value(layout_kiwi_solver *solver, int32_t id, double expected)
{
    double value = 0.0;
    assert(layout_kiwi_get_value(solver, id, &value) == LAYOUT_KIWI_OK);
    assert(std::fabs(value - expected) < 1.0e-9);
}

} // namespace

int main()
{
    assert(layout_kiwi_add_variable(nullptr, 1) == LAYOUT_KIWI_INVALID_ARGUMENT);
    assert(std::strstr(layout_kiwi_last_error(nullptr), "null solver") != nullptr);
    assert(layout_kiwi_last_error_id(nullptr) == LAYOUT_KIWI_NO_ID);

    layout_kiwi_solver *solver = layout_kiwi_create();
    assert(solver != nullptr);
    assert(std::strcmp(layout_kiwi_last_error(solver), "") == 0);

    assert(layout_kiwi_add_variable(solver, 0) == LAYOUT_KIWI_INVALID_ARGUMENT);
    assert(layout_kiwi_last_error_id(solver) == 0);
    assert(layout_kiwi_add_variable(solver, 1) == LAYOUT_KIWI_OK);
    assert(layout_kiwi_add_variable(solver, 2) == LAYOUT_KIWI_OK);
    assert(layout_kiwi_add_variable(solver, 1) == LAYOUT_KIWI_DUPLICATE_ID);

    const int32_t x_id[] = {1};
    const double x_coefficient[] = {1.0};
    assert(layout_kiwi_add_constraint(solver,
                                      100,
                                      x_id,
                                      x_coefficient,
                                      1,
                                      10.0,
                                      LAYOUT_KIWI_RELATION_EQ,
                                      kRequired) == LAYOUT_KIWI_OK);
    assert(layout_kiwi_update(solver) == LAYOUT_KIWI_OK);
    expect_value(solver, 1, -10.0);

    /* A rejected required constraint must leave the valid model usable. */
    assert(layout_kiwi_add_constraint(solver,
                                      101,
                                      x_id,
                                      x_coefficient,
                                      1,
                                      20.0,
                                      LAYOUT_KIWI_RELATION_EQ,
                                      kRequired) == LAYOUT_KIWI_CONFLICT);
    assert(layout_kiwi_last_error_id(solver) == 101);
    assert(std::strstr(layout_kiwi_last_error(solver), "id=101") != nullptr);
    assert(layout_kiwi_update(solver) == LAYOUT_KIWI_OK);
    expect_value(solver, 1, -10.0);

    /* Also exercise rejection through an inequality/artificial-row path. */
    assert(layout_kiwi_add_constraint(solver, 108, x_id, x_coefficient, 1,
                                      0.0, LAYOUT_KIWI_RELATION_GE,
                                      kRequired) == LAYOUT_KIWI_CONFLICT);
    assert(layout_kiwi_last_error_id(solver) == 108);
    assert(layout_kiwi_update(solver) == LAYOUT_KIWI_OK);
    expect_value(solver, 1, -10.0);

    /* A rejected id remains consumed until reset. */
    assert(layout_kiwi_add_constraint(solver,
                                      101,
                                      x_id,
                                      x_coefficient,
                                      1,
                                      10.0,
                                      LAYOUT_KIWI_RELATION_EQ,
                                      kRequired) == LAYOUT_KIWI_DUPLICATE_ID);

    const int32_t x_y_ids[] = {1, 2};
    const double x_y_coefficients[] = {1.0, 1.0};
    assert(layout_kiwi_add_constraint(solver,
                                      102,
                                      x_y_ids,
                                      x_y_coefficients,
                                      2,
                                      -30.0,
                                      LAYOUT_KIWI_RELATION_EQ,
                                      kRequired) == LAYOUT_KIWI_OK);
    assert(layout_kiwi_add_constraint(solver,
                                      102,
                                      x_y_ids,
                                      x_y_coefficients,
                                      2,
                                      -30.0,
                                      LAYOUT_KIWI_RELATION_EQ,
                                      kRequired) == LAYOUT_KIWI_DUPLICATE_ID);
    assert(layout_kiwi_update(solver) == LAYOUT_KIWI_OK);
    expect_value(solver, 1, -10.0);
    expect_value(solver, 2, 40.0);

    assert(layout_kiwi_remove_constraint(solver, 100) == LAYOUT_KIWI_OK);
    assert(layout_kiwi_remove_constraint(solver, 100) == LAYOUT_KIWI_UNKNOWN_ID);
    assert(layout_kiwi_add_edit_variable(solver, 1, kRequired) ==
           LAYOUT_KIWI_BAD_STRENGTH);
    assert(layout_kiwi_add_edit_variable(solver, 1, kStrong) == LAYOUT_KIWI_OK);
    assert(layout_kiwi_add_edit_variable(solver, 1, kStrong) ==
           LAYOUT_KIWI_DUPLICATE_ID);
    assert(layout_kiwi_suggest_value(solver, 1, 8.0) == LAYOUT_KIWI_OK);
    assert(layout_kiwi_update(solver) == LAYOUT_KIWI_OK);
    expect_value(solver, 1, 8.0);
    expect_value(solver, 2, 22.0);

    assert(layout_kiwi_suggest_value(solver, 2, 1.0) == LAYOUT_KIWI_UNKNOWN_ID);
    assert(layout_kiwi_suggest_value(solver, 1, NAN) == LAYOUT_KIWI_INVALID_ARGUMENT);
    assert(layout_kiwi_get_value(solver, 999, nullptr) == LAYOUT_KIWI_INVALID_ARGUMENT);
    double unused_value = 0.0;
    assert(layout_kiwi_get_value(solver, 999, &unused_value) == LAYOUT_KIWI_UNKNOWN_ID);

    assert(layout_kiwi_add_constraint(solver,
                                      103,
                                      nullptr,
                                      nullptr,
                                      1,
                                      0.0,
                                      LAYOUT_KIWI_RELATION_EQ,
                                      kRequired) == LAYOUT_KIWI_INVALID_ARGUMENT);
    assert(layout_kiwi_add_constraint(solver,
                                      104,
                                      x_id,
                                      x_coefficient,
                                      1,
                                      0.0,
                                      99,
                                      kRequired) == LAYOUT_KIWI_INVALID_ARGUMENT);
    const int32_t unknown_id[] = {999};
    assert(layout_kiwi_add_constraint(solver,
                                      105,
                                      unknown_id,
                                      x_coefficient,
                                      1,
                                      0.0,
                                      LAYOUT_KIWI_RELATION_EQ,
                                      kRequired) == LAYOUT_KIWI_UNKNOWN_ID);
    const double infinity[] = {INFINITY};
    assert(layout_kiwi_add_constraint(solver,
                                      106,
                                      x_id,
                                      infinity,
                                      1,
                                      0.0,
                                      LAYOUT_KIWI_RELATION_EQ,
                                      kRequired) == LAYOUT_KIWI_INVALID_ARGUMENT);
    assert(layout_kiwi_add_constraint(solver,
                                      107,
                                      x_id,
                                      x_coefficient,
                                      1,
                                      0.0,
                                      LAYOUT_KIWI_RELATION_EQ,
                                      NAN) == LAYOUT_KIWI_INVALID_ARGUMENT);

    assert(layout_kiwi_reset(solver) == LAYOUT_KIWI_OK);
    assert(layout_kiwi_add_variable(solver, 1) == LAYOUT_KIWI_OK);
    assert(layout_kiwi_add_constraint(solver,
                                      100,
                                      x_id,
                                      x_coefficient,
                                      1,
                                      -4.0,
                                      LAYOUT_KIWI_RELATION_EQ,
                                      kRequired) == LAYOUT_KIWI_OK);
    assert(layout_kiwi_update(solver) == LAYOUT_KIWI_OK);
    expect_value(solver, 1, 4.0);

    layout_kiwi_destroy(solver);
    return 0;
}
