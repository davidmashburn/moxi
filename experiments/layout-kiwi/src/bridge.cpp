#include "layout_kiwi.h"

#include <cmath>
#include <cstdio>
#include <exception>
#include <new>
#include <string>
#include <unordered_map>
#include <unordered_set>
#include <utility>
#include <vector>

#include "kiwi/kiwi.h"

struct layout_kiwi_solver {
    kiwi::Solver solver;
    std::unordered_map<int32_t, kiwi::Variable> variables;
    std::unordered_set<int32_t> used_variable_ids;
    std::unordered_map<int32_t, kiwi::Constraint> constraints;
    std::unordered_set<int32_t> used_constraint_ids;
    std::unordered_set<int32_t> edit_variable_ids;
    char error[512] = {};
    int32_t error_id = LAYOUT_KIWI_NO_ID;
};

namespace {

constexpr const char *kNullSolverError = "layout_kiwi: null solver handle (id=-1)";

bool finite(double value) noexcept
{
    return std::isfinite(value) != 0;
}

void clear_error(layout_kiwi_solver *solver) noexcept
{
    solver->error[0] = '\0';
    solver->error_id = LAYOUT_KIWI_NO_ID;
}

void set_error(layout_kiwi_solver *solver, int32_t id, const char *message) noexcept
{
    solver->error_id = id;
    (void)std::snprintf(solver->error,
                        sizeof(solver->error),
                        "layout_kiwi: %s (id=%d)",
                        message,
                        static_cast<int>(id));
    solver->error[sizeof(solver->error) - 1] = '\0';
}

int32_t fail(layout_kiwi_solver *solver,
             int32_t status,
             int32_t id,
             const char *message) noexcept
{
    set_error(solver, id, message);
    return status;
}

bool valid_id(int32_t id) noexcept
{
    return id > 0;
}

int32_t validate_solver(layout_kiwi_solver *solver) noexcept
{
    if (solver == nullptr) {
        return LAYOUT_KIWI_INVALID_ARGUMENT;
    }
    return LAYOUT_KIWI_OK;
}

template <typename Fn>
int32_t invoke(layout_kiwi_solver *solver, int32_t id, Fn &&fn) noexcept
{
    try {
        fn();
        clear_error(solver);
        return LAYOUT_KIWI_OK;
    } catch (const kiwi::UnsatisfiableConstraint &) {
        return fail(solver,
                    LAYOUT_KIWI_CONFLICT,
                    id,
                    "required constraint rejected");
    } catch (const kiwi::DuplicateConstraint &) {
        return fail(solver, LAYOUT_KIWI_DUPLICATE_ID, id, "duplicate constraint");
    } catch (const kiwi::UnknownConstraint &) {
        return fail(solver, LAYOUT_KIWI_UNKNOWN_ID, id, "unknown constraint");
    } catch (const kiwi::DuplicateEditVariable &) {
        return fail(solver, LAYOUT_KIWI_DUPLICATE_ID, id, "duplicate edit variable");
    } catch (const kiwi::UnknownEditVariable &) {
        return fail(solver, LAYOUT_KIWI_UNKNOWN_ID, id, "unknown edit variable");
    } catch (const kiwi::BadRequiredStrength &) {
        return fail(solver,
                    LAYOUT_KIWI_BAD_STRENGTH,
                    id,
                    "required strength is not allowed for an edit variable");
    } catch (const std::bad_alloc &) {
        return fail(solver,
                    LAYOUT_KIWI_OUT_OF_MEMORY,
                    id,
                    "out of memory");
    } catch (const std::exception &error) {
        return fail(solver,
                    LAYOUT_KIWI_INTERNAL_ERROR,
                    id,
                    error.what());
    } catch (...) {
        return fail(solver,
                    LAYOUT_KIWI_INTERNAL_ERROR,
                    id,
                    "unknown exception");
    }
}

bool relation_from_abi(int32_t relation, kiwi::RelationalOperator *out) noexcept
{
    switch (relation) {
    case LAYOUT_KIWI_RELATION_EQ:
        *out = kiwi::OP_EQ;
        return true;
    case LAYOUT_KIWI_RELATION_LE:
        *out = kiwi::OP_LE;
        return true;
    case LAYOUT_KIWI_RELATION_GE:
        *out = kiwi::OP_GE;
        return true;
    default:
        return false;
    }
}

} // namespace

extern "C" layout_kiwi_solver *layout_kiwi_create(void)
{
    try {
        return new layout_kiwi_solver();
    } catch (...) {
        return nullptr;
    }
}

extern "C" void layout_kiwi_destroy(layout_kiwi_solver *solver)
{
    try {
        delete solver;
    } catch (...) {
        /* Destruction cannot communicate an error through this ABI. */
    }
}

extern "C" int32_t layout_kiwi_add_variable(layout_kiwi_solver *solver,
                                             int32_t variable_id)
{
    if (validate_solver(solver) != LAYOUT_KIWI_OK) {
        return LAYOUT_KIWI_INVALID_ARGUMENT;
    }
    if (!valid_id(variable_id)) {
        return fail(solver,
                    LAYOUT_KIWI_INVALID_ARGUMENT,
                    variable_id,
                    "variable id must be positive");
    }
    if (solver->used_variable_ids.find(variable_id) !=
        solver->used_variable_ids.end()) {
        return fail(solver,
                    LAYOUT_KIWI_DUPLICATE_ID,
                    variable_id,
                    "variable id is already used");
    }

    return invoke(solver, variable_id, [&] {
        solver->used_variable_ids.insert(variable_id);
        const std::string name = "layout_kiwi_v" + std::to_string(variable_id);
        solver->variables.emplace(variable_id, kiwi::Variable(name));
    });
}

extern "C" int32_t layout_kiwi_add_constraint(layout_kiwi_solver *solver,
                                               int32_t constraint_id,
                                               const int32_t *variable_ids,
                                               const double *coefficients,
                                               size_t term_count,
                                               double constant,
                                               int32_t relation,
                                               double strength)
{
    if (validate_solver(solver) != LAYOUT_KIWI_OK) {
        return LAYOUT_KIWI_INVALID_ARGUMENT;
    }
    if (!valid_id(constraint_id)) {
        return fail(solver,
                    LAYOUT_KIWI_INVALID_ARGUMENT,
                    constraint_id,
                    "constraint id must be positive");
    }
    if (solver->used_constraint_ids.find(constraint_id) !=
        solver->used_constraint_ids.end()) {
        return fail(solver,
                    LAYOUT_KIWI_DUPLICATE_ID,
                    constraint_id,
                    "constraint id is already used");
    }
    if (term_count != 0 &&
        (variable_ids == nullptr || coefficients == nullptr)) {
        return fail(solver,
                    LAYOUT_KIWI_INVALID_ARGUMENT,
                    constraint_id,
                    "term arrays must be non-null when term_count is nonzero");
    }
    if (!finite(constant) || !finite(strength)) {
        return fail(solver,
                    LAYOUT_KIWI_INVALID_ARGUMENT,
                    constraint_id,
                    "constant and strength must be finite");
    }
    kiwi::RelationalOperator kiwi_relation;
    if (!relation_from_abi(relation, &kiwi_relation)) {
        return fail(solver,
                    LAYOUT_KIWI_INVALID_ARGUMENT,
                    constraint_id,
                    "unknown relation");
    }
    for (size_t index = 0; index < term_count; ++index) {
        const int32_t variable_id = variable_ids[index];
        const double coefficient = coefficients[index];
        if (!valid_id(variable_id)) {
            return fail(solver,
                        LAYOUT_KIWI_INVALID_ARGUMENT,
                        variable_id,
                        "variable id must be positive");
        }
        if (solver->variables.find(variable_id) == solver->variables.end()) {
            return fail(solver,
                        LAYOUT_KIWI_UNKNOWN_ID,
                        variable_id,
                        "constraint references unknown variable");
        }
        if (!finite(coefficient)) {
            return fail(solver,
                        LAYOUT_KIWI_INVALID_ARGUMENT,
                        constraint_id,
                        "coefficient must be finite");
        }
    }

    return invoke(solver, constraint_id, [&] {
        solver->used_constraint_ids.insert(constraint_id);
        std::vector<kiwi::Term> terms;
        terms.reserve(term_count);
        for (size_t index = 0; index < term_count; ++index) {
            terms.emplace_back(solver->variables.at(variable_ids[index]),
                               coefficients[index]);
        }
        kiwi::Constraint constraint(
            kiwi::Expression(std::move(terms), constant), kiwi_relation, strength);

        /* Put the handle in the map before the backend call so a rejected
         * constraint can be erased transactionally without losing ownership
         * of a successfully added constraint. */
        const auto inserted = solver->constraints.emplace(constraint_id, constraint);
        if (!inserted.second) {
            throw kiwi::DuplicateConstraint(constraint);
        }
        try {
            solver->solver.addConstraint(inserted.first->second);
        } catch (...) {
            solver->constraints.erase(inserted.first);
            throw;
        }
    });
}

extern "C" int32_t layout_kiwi_remove_constraint(layout_kiwi_solver *solver,
                                                  int32_t constraint_id)
{
    if (validate_solver(solver) != LAYOUT_KIWI_OK) {
        return LAYOUT_KIWI_INVALID_ARGUMENT;
    }
    if (!valid_id(constraint_id)) {
        return fail(solver,
                    LAYOUT_KIWI_INVALID_ARGUMENT,
                    constraint_id,
                    "constraint id must be positive");
    }
    const auto found = solver->constraints.find(constraint_id);
    if (found == solver->constraints.end()) {
        return fail(solver,
                    LAYOUT_KIWI_UNKNOWN_ID,
                    constraint_id,
                    "unknown constraint");
    }

    return invoke(solver, constraint_id, [&] {
        solver->solver.removeConstraint(found->second);
        solver->constraints.erase(found);
    });
}

extern "C" int32_t layout_kiwi_add_edit_variable(layout_kiwi_solver *solver,
                                                  int32_t variable_id,
                                                  double strength)
{
    if (validate_solver(solver) != LAYOUT_KIWI_OK) {
        return LAYOUT_KIWI_INVALID_ARGUMENT;
    }
    if (!valid_id(variable_id)) {
        return fail(solver,
                    LAYOUT_KIWI_INVALID_ARGUMENT,
                    variable_id,
                    "variable id must be positive");
    }
    if (!finite(strength)) {
        return fail(solver,
                    LAYOUT_KIWI_INVALID_ARGUMENT,
                    variable_id,
                    "strength must be finite");
    }
    const auto variable = solver->variables.find(variable_id);
    if (variable == solver->variables.end()) {
        return fail(solver,
                    LAYOUT_KIWI_UNKNOWN_ID,
                    variable_id,
                    "unknown variable");
    }
    if (solver->edit_variable_ids.find(variable_id) !=
        solver->edit_variable_ids.end()) {
        return fail(solver,
                    LAYOUT_KIWI_DUPLICATE_ID,
                    variable_id,
                    "edit variable is already used");
    }

    const int32_t status = invoke(solver, variable_id, [&] {
        solver->solver.addEditVariable(variable->second, strength);
        solver->edit_variable_ids.insert(variable_id);
    });
    return status;
}

extern "C" int32_t layout_kiwi_suggest_value(layout_kiwi_solver *solver,
                                        int32_t variable_id,
                                        double value)
{
    if (validate_solver(solver) != LAYOUT_KIWI_OK) {
        return LAYOUT_KIWI_INVALID_ARGUMENT;
    }
    if (!valid_id(variable_id)) {
        return fail(solver,
                    LAYOUT_KIWI_INVALID_ARGUMENT,
                    variable_id,
                    "variable id must be positive");
    }
    if (!finite(value)) {
        return fail(solver,
                    LAYOUT_KIWI_INVALID_ARGUMENT,
                    variable_id,
                    "suggested value must be finite");
    }
    const auto variable = solver->variables.find(variable_id);
    if (variable == solver->variables.end()) {
        return fail(solver,
                    LAYOUT_KIWI_UNKNOWN_ID,
                    variable_id,
                    "unknown variable");
    }
    if (solver->edit_variable_ids.find(variable_id) ==
        solver->edit_variable_ids.end()) {
        return fail(solver,
                    LAYOUT_KIWI_UNKNOWN_ID,
                    variable_id,
                    "variable is not an edit variable");
    }
    return invoke(solver, variable_id, [&] {
        solver->solver.suggestValue(variable->second, value);
    });
}

extern "C" int32_t layout_kiwi_update(layout_kiwi_solver *solver)
{
    if (validate_solver(solver) != LAYOUT_KIWI_OK) {
        return LAYOUT_KIWI_INVALID_ARGUMENT;
    }
    return invoke(solver, LAYOUT_KIWI_NO_ID, [&] {
        solver->solver.updateVariables();
    });
}

extern "C" int32_t layout_kiwi_get_value(const layout_kiwi_solver *solver,
                                          int32_t variable_id,
                                          double *out_value)
{
    if (solver == nullptr || out_value == nullptr) {
        layout_kiwi_solver *mutable_solver = const_cast<layout_kiwi_solver *>(solver);
        if (mutable_solver != nullptr) {
            return fail(mutable_solver,
                        LAYOUT_KIWI_INVALID_ARGUMENT,
                        variable_id,
                        "solver and output value must be non-null");
        }
        return LAYOUT_KIWI_INVALID_ARGUMENT;
    }
    if (!valid_id(variable_id)) {
        return fail(const_cast<layout_kiwi_solver *>(solver),
                    LAYOUT_KIWI_INVALID_ARGUMENT,
                    variable_id,
                    "variable id must be positive");
    }
    const auto variable = solver->variables.find(variable_id);
    if (variable == solver->variables.end()) {
        return fail(const_cast<layout_kiwi_solver *>(solver),
                    LAYOUT_KIWI_UNKNOWN_ID,
                    variable_id,
                    "unknown variable");
    }
    *out_value = variable->second.value();
    clear_error(const_cast<layout_kiwi_solver *>(solver));
    return LAYOUT_KIWI_OK;
}

extern "C" int32_t layout_kiwi_reset(layout_kiwi_solver *solver)
{
    if (validate_solver(solver) != LAYOUT_KIWI_OK) {
        return LAYOUT_KIWI_INVALID_ARGUMENT;
    }
    return invoke(solver, LAYOUT_KIWI_NO_ID, [&] {
        solver->solver.reset();
        solver->variables.clear();
        solver->used_variable_ids.clear();
        solver->constraints.clear();
        solver->used_constraint_ids.clear();
        solver->edit_variable_ids.clear();
    });
}

extern "C" const char *layout_kiwi_last_error(const layout_kiwi_solver *solver)
{
    if (solver == nullptr) {
        return kNullSolverError;
    }
    return solver->error;
}

extern "C" int32_t layout_kiwi_last_error_id(const layout_kiwi_solver *solver)
{
    if (solver == nullptr) {
        return LAYOUT_KIWI_NO_ID;
    }
    return solver->error_id;
}
