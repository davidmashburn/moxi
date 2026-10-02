#ifndef LAYOUT_KIWI_H
#define LAYOUT_KIWI_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/*
 * C ABI experiment for the header-only Kiwi 1.5.0 constraint solver.
 *
 * Handles are opaque and caller-owned. Error-accessor calls preserve the error.
 * Any other call using a valid handle can replace/clear its error string and ID.
 * The string is handle-owned and must not be freed; copy it before another call.
 * After INTERNAL_ERROR or OUT_OF_MEMORY, reset or destroy the handle: these
 * failures contain exceptions but do not promise transactional recovery.
 */
typedef struct layout_kiwi_solver layout_kiwi_solver;

typedef enum layout_kiwi_status {
    LAYOUT_KIWI_OK = 0,
    LAYOUT_KIWI_INVALID_ARGUMENT = 1,
    LAYOUT_KIWI_UNKNOWN_ID = 2,
    LAYOUT_KIWI_DUPLICATE_ID = 3,
    LAYOUT_KIWI_CONFLICT = 4,
    LAYOUT_KIWI_BAD_STRENGTH = 5,
    LAYOUT_KIWI_INTERNAL_ERROR = 6,
    LAYOUT_KIWI_OUT_OF_MEMORY = 7
} layout_kiwi_status;

/* Relation values are part of the experiment ABI. */
enum {
    LAYOUT_KIWI_RELATION_EQ = 0,
    LAYOUT_KIWI_RELATION_LE = 1,
    LAYOUT_KIWI_RELATION_GE = 2
};

/* Returned when the last error does not identify a caller-owned id. */
enum { LAYOUT_KIWI_NO_ID = -1 };

layout_kiwi_solver *layout_kiwi_create(void);
void layout_kiwi_destroy(layout_kiwi_solver *solver);

/* Variable ids must be positive and remain unavailable until reset. */
int32_t layout_kiwi_add_variable(layout_kiwi_solver *solver,
                                 int32_t variable_id);

/*
 * Add one linear constraint:
 *
 *   sum(coefficients[i] * variable_ids[i]) + constant relation 0
 *
 * term_count may be zero, in which case both arrays may be NULL.  For a
 * nonzero term_count both arrays must be non-NULL.  Constraint ids must be
 * positive. IDs consumed by a backend add (successful or rejected) cannot be
 * reused until reset. Argument-validation failures do not consume an ID.
 * A required constraint is one whose strength is at least Kiwi's required
 * strength; Kiwi clips finite strengths to its supported range.
 */
int32_t layout_kiwi_add_constraint(layout_kiwi_solver *solver,
                                   int32_t constraint_id,
                                   const int32_t *variable_ids,
                                   const double *coefficients,
                                   size_t term_count,
                                   double constant,
                                   int32_t relation,
                                   double strength);

int32_t layout_kiwi_remove_constraint(layout_kiwi_solver *solver,
                                      int32_t constraint_id);

/* Edit variables require a non-required finite strength. */
int32_t layout_kiwi_add_edit_variable(layout_kiwi_solver *solver,
                                      int32_t variable_id,
                                      double strength);

int32_t layout_kiwi_suggest_value(layout_kiwi_solver *solver,
                                  int32_t variable_id,
                                  double value);

/* Publish current solver values to external variables after suggestions. */
int32_t layout_kiwi_update(layout_kiwi_solver *solver);

int32_t layout_kiwi_get_value(const layout_kiwi_solver *solver,
                              int32_t variable_id,
                              double *out_value);

/* Empty the solver and release all caller ids so they may be reused. */
int32_t layout_kiwi_reset(layout_kiwi_solver *solver);

/* The pointer is owned by the handle; an empty string means no error. */
const char *layout_kiwi_last_error(const layout_kiwi_solver *solver);

/* The relevant variable or constraint id, or LAYOUT_KIWI_NO_ID. */
int32_t layout_kiwi_last_error_id(const layout_kiwi_solver *solver);

#ifdef __cplusplus
}
#endif

#endif /* LAYOUT_KIWI_H */
