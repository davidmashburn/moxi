// Standalone Kiwi layout reference fixtures.
//
// This executable is intentionally self-contained and is not a Moxi runtime
// dependency.  It includes Kiwi's public C++ header directly and emits one
// JSON document on stdout.  Any failed assertion makes the document's `ok`
// member false and returns a non-zero status; diagnostics are sent in-band so
// a failed run is still machine-readable.

#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstdint>
#include <cstdlib>
#include <iomanip>
#include <iostream>
#include <limits>
#include <memory>
#include <sstream>
#include <string>
#include <utility>
#include <vector>

#include <kiwi/kiwi.h>

namespace {

using Clock = std::chrono::steady_clock;
using Nanoseconds = std::chrono::nanoseconds;

constexpr double kEpsilon = 0.01;
constexpr double kPadding = 10.0;
constexpr double kGap = 8.0;
constexpr double kChartMinimum = 160.0;
constexpr double kAdvanceFactor = 0.56;
constexpr double kLineHeightFactor = 1.25;

uint64_t elapsed_ns(const Clock::time_point started) {
    const auto duration = std::chrono::duration_cast<Nanoseconds>(Clock::now() - started);
    const auto count = duration.count();
    return static_cast<uint64_t>(std::max<int64_t>(1, count));
}

std::string number(double value) {
    if (!std::isfinite(value)) {
        return "null";
    }
    if (std::abs(value) < 0.0000005) {
        value = 0.0;
    }
    std::ostringstream out;
    out << std::setprecision(9) << std::defaultfloat << value;
    return out.str();
}

std::string json_string(const std::string& value) {
    std::ostringstream out;
    out << '"';
    for (const unsigned char ch : value) {
        switch (ch) {
        case '"': out << "\\\""; break;
        case '\\': out << "\\\\"; break;
        case '\b': out << "\\b"; break;
        case '\f': out << "\\f"; break;
        case '\n': out << "\\n"; break;
        case '\r': out << "\\r"; break;
        case '\t': out << "\\t"; break;
        default:
            if (ch < 0x20) {
                out << "\\u00" << std::hex << std::setw(2) << std::setfill('0')
                    << static_cast<unsigned int>(ch) << std::dec << std::setfill(' ');
            } else {
                out << static_cast<char>(ch);
            }
        }
    }
    out << '"';
    return out.str();
}

std::string bool_json(bool value) {
    return value ? "true" : "false";
}

struct Diagnostic {
    std::string fixture;
    std::string code;
    std::string severity;
    std::string message;
    std::vector<std::string> author_ids;
};

struct Report {
    int assertions = 0;
    int failures = 0;
    std::vector<Diagnostic> diagnostics;

    void diagnostic(
        const std::string& fixture,
        const std::string& code,
        const std::string& severity,
        const std::string& message,
        std::vector<std::string> author_ids = {}) {
        diagnostics.push_back(Diagnostic{fixture, code, severity, message, std::move(author_ids)});
    }

    void check(
        const std::string& fixture,
        const std::string& check_name,
        bool condition,
        const std::string& expected,
        const std::string& actual,
        std::vector<std::string> author_ids = {}) {
        ++assertions;
        if (condition) {
            return;
        }
        ++failures;
        diagnostic(
            fixture,
            "assertion_failed",
            "error",
            check_name + ": expected " + expected + ", got " + actual,
            std::move(author_ids));
    }

    void close(
        const std::string& fixture,
        const std::string& check_name,
        double actual,
        double expected,
        std::vector<std::string> author_ids = {}) {
        check(
            fixture,
            check_name,
            std::isfinite(actual) && std::abs(actual - expected) <= kEpsilon,
            number(expected),
            number(actual),
            std::move(author_ids));
    }
};

std::string author_ids_json(const std::vector<std::string>& ids) {
    std::ostringstream out;
    out << '[';
    for (size_t index = 0; index < ids.size(); ++index) {
        if (index != 0) out << ',';
        out << json_string(ids[index]);
    }
    out << ']';
    return out.str();
}

std::string diagnostics_json(const std::vector<Diagnostic>& diagnostics) {
    std::ostringstream out;
    out << '[';
    for (size_t index = 0; index < diagnostics.size(); ++index) {
        if (index != 0) out << ',';
        const Diagnostic& diagnostic = diagnostics[index];
        out << "{\"fixture\":" << json_string(diagnostic.fixture)
            << ",\"code\":" << json_string(diagnostic.code)
            << ",\"severity\":" << json_string(diagnostic.severity)
            << ",\"message\":" << json_string(diagnostic.message)
            << ",\"author_ids\":" << author_ids_json(diagnostic.author_ids) << '}';
    }
    out << ']';
    return out.str();
}

kiwi::Constraint equality(const kiwi::Variable& variable, double value, double strength) {
    return kiwi::Constraint(variable - value, kiwi::OP_EQ, strength);
}

kiwi::Constraint equality(const kiwi::Expression& expression, double value, double strength) {
    return kiwi::Constraint(expression - value, kiwi::OP_EQ, strength);
}

kiwi::Constraint minimum(const kiwi::Variable& variable, double value, double strength) {
    return kiwi::Constraint(variable - value, kiwi::OP_GE, strength);
}

struct Rect {
    double x = 0.0;
    double y = 0.0;
    double width = 0.0;
    double height = 0.0;
};

struct RectVars {
    kiwi::Variable x;
    kiwi::Variable y;
    kiwi::Variable width;
    kiwi::Variable height;

    explicit RectVars(const std::string& prefix)
        : x(prefix + ".x"),
          y(prefix + ".y"),
          width(prefix + ".width"),
          height(prefix + ".height") {}
};

Rect read_rect(const RectVars& rect) {
    return Rect{rect.x.value(), rect.y.value(), rect.width.value(), rect.height.value()};
}

std::string rect_json(const Rect& rect) {
    std::ostringstream out;
    out << "{\"x\":" << number(rect.x)
        << ",\"y\":" << number(rect.y)
        << ",\"width\":" << number(rect.width)
        << ",\"height\":" << number(rect.height) << '}';
    return out.str();
}

std::string rect_array_json(const std::vector<Rect>& rects) {
    std::ostringstream out;
    out << '[';
    for (size_t index = 0; index < rects.size(); ++index) {
        if (index != 0) out << ',';
        out << rect_json(rects[index]);
    }
    out << ']';
    return out.str();
}

// Count the external variable entries in Solver::dumps().  This is a solver
// retention characterization, deliberately not an estimate of heap bytes.
size_t dump_variable_count(const kiwi::Solver& solver) {
    // Solver::dumps() is non-const in Kiwi 1.5.0, while this helper only reads
    // it.  The cast keeps the call isolated and avoids changing the upstream
    // API contract in this reference runner.
    kiwi::Solver& mutable_solver = const_cast<kiwi::Solver&>(solver);
    const std::string dump = mutable_solver.dumps();
    const std::string marker = "Variables\n---------\n";
    const size_t begin = dump.find(marker);
    if (begin == std::string::npos) return 0;
    const size_t end = dump.find("Edit Variables", begin + marker.size());
    const size_t stop = end == std::string::npos ? dump.size() : end;
    size_t count = 0;
    size_t line_start = begin + marker.size();
    while (line_start < stop) {
        const size_t line_end = dump.find('\n', line_start);
        const size_t actual_end = line_end == std::string::npos ? stop : line_end;
        const std::string line = dump.substr(line_start, actual_end - line_start);
        if (line.find(" = ") != std::string::npos) ++count;
        if (line_end == std::string::npos) break;
        line_start = line_end + 1;
    }
    return count;
}

struct CsvState {
    kiwi::Solver solver;
    kiwi::Variable viewport_width{"csv.viewport.width"};
    kiwi::Variable viewport_height{"csv.viewport.height"};
    RectVars header{"csv.header"};
    RectVars summary{"csv.summary"};
    RectVars chart{"csv.chart"};
    kiwi::Constraint chart_y = equality(chart.y, 0.0, kiwi::strength::required);
    std::vector<kiwi::Constraint> summary_constraints;
    bool has_summary = false;

    void add_base() {
        solver.addEditVariable(viewport_height, kiwi::strength::strong);
        solver.addConstraint(equality(viewport_width, 800.0, kiwi::strength::required));
        solver.addConstraint(minimum(viewport_height, 0.0, kiwi::strength::required));
        solver.addConstraint(equality(header.x, kPadding, kiwi::strength::required));
        solver.addConstraint(equality(header.y, kPadding, kiwi::strength::required));
        solver.addConstraint(equality(header.width, 800.0 - 2.0 * kPadding, kiwi::strength::required));
        solver.addConstraint(equality(header.height, 40.0, kiwi::strength::required));
        solver.addConstraint(equality(chart.x, kPadding, kiwi::strength::required));
        solver.addConstraint(equality(chart.width, 800.0 - 2.0 * kPadding, kiwi::strength::required));
        solver.addConstraint(minimum(chart.height, kChartMinimum, kiwi::strength::required));
        solver.addConstraint(
            equality(chart.y + chart.height - viewport_height + kPadding, 0.0, kiwi::strength::medium));
        chart_y = equality(chart.y - header.y - header.height - kGap, 0.0, kiwi::strength::required);
        solver.addConstraint(chart_y);
    }

    void insert_summary() {
        if (has_summary) return;
        solver.removeConstraint(chart_y);
        summary_constraints.push_back(equality(summary.x, kPadding, kiwi::strength::required));
        summary_constraints.push_back(equality(summary.width, 800.0 - 2.0 * kPadding, kiwi::strength::required));
        summary_constraints.push_back(equality(summary.height, 40.0, kiwi::strength::required));
        summary_constraints.push_back(
            equality(summary.y - header.y - header.height - kGap, 0.0, kiwi::strength::required));
        for (const kiwi::Constraint& constraint : summary_constraints) solver.addConstraint(constraint);
        chart_y = equality(chart.y - summary.y - summary.height - kGap, 0.0, kiwi::strength::required);
        solver.addConstraint(chart_y);
        has_summary = true;
    }

    void remove_summary() {
        if (!has_summary) return;
        solver.removeConstraint(chart_y);
        for (const kiwi::Constraint& constraint : summary_constraints) solver.removeConstraint(constraint);
        summary_constraints.clear();
        chart_y = equality(chart.y - header.y - header.height - kGap, 0.0, kiwi::strength::required);
        solver.addConstraint(chart_y);
        has_summary = false;
    }

    void suggest_height(double height) {
        solver.suggestValue(viewport_height, height);
    }

    std::vector<Rect> rects() const {
        std::vector<Rect> result;
        result.push_back(Rect{0.0, 0.0, viewport_width.value(), viewport_height.value()});
        result.push_back(read_rect(header));
        if (has_summary) result.push_back(read_rect(summary));
        result.push_back(read_rect(chart));
        return result;
    }
};

std::unique_ptr<CsvState> make_csv_state() {
    auto state = std::make_unique<CsvState>();
    state->add_base();
    return state;
}

std::string csv_fixture(Report& report) {
    const std::string fixture = "csv_column";
    auto state = make_csv_state();
    state->suggest_height(600.0);
    state->solver.updateVariables();
    const std::vector<Rect> cold = state->rects();
    report.close(fixture, "header.x", cold[1].x, 10.0);
    report.close(fixture, "header.y", cold[1].y, 10.0);
    report.close(fixture, "header.width", cold[1].width, 780.0);
    report.close(fixture, "header.height", cold[1].height, 40.0);
    report.close(fixture, "chart.y", cold[2].y, 58.0);
    report.close(fixture, "chart.height", cold[2].height, 532.0);

    state->suggest_height(800.0);
    state->solver.updateVariables();
    const std::vector<Rect> resized = state->rects();
    report.close(fixture, "resize chart growth", resized[2].height - cold[2].height, 200.0);

    state->insert_summary();
    state->suggest_height(600.0);
    state->solver.updateVariables();
    const std::vector<Rect> inserted = state->rects();
    report.close(fixture, "summary.y", inserted[2].y, 58.0);
    report.close(fixture, "summary.height", inserted[2].height, 40.0);
    report.close(fixture, "inserted chart shrink", cold[2].height - inserted[3].height, 48.0);

    state->suggest_height(150.0);
    state->solver.updateVariables();
    const std::vector<Rect> overflow = state->rects();
    const Rect& overflow_chart = overflow[3];
    const double viewport_bottom = overflow[0].y + overflow[0].height - kPadding;
    const bool overflowed = overflow_chart.y + overflow_chart.height > viewport_bottom + kEpsilon;
    report.close(fixture, "overflow viewport height", overflow[0].height, 150.0);
    report.close(fixture, "overflow chart minimum", overflow_chart.height, kChartMinimum);
    report.check(fixture, "small viewport keeps chart minimum", overflowed, "overflow=true", bool_json(overflowed));
    report.diagnostic(
        fixture,
        "explicit_overflow",
        "info",
        "chart minimum is retained when the viewport cannot contain all required content");

    const Rect before_unchanged = overflow_chart;
    state->solver.updateVariables();
    const Rect after_unchanged = read_rect(state->chart);
    report.close(fixture, "unchanged chart.x", after_unchanged.x, before_unchanged.x);
    report.close(fixture, "unchanged chart.y", after_unchanged.y, before_unchanged.y);
    report.close(fixture, "unchanged chart.height", after_unchanged.height, before_unchanged.height);

    std::ostringstream out;
    out << "{\"name\":\"" << fixture << "\",\"viewport_width\":800"
        << ",\"padding\":10,\"gap\":8,\"chart_minimum\":160"
        << ",\"phases\":["
        << "{\"name\":\"cold_h600_no_summary\",\"summary\":false,\"overflow\":false,\"rects\":{";
    out << "\"root\":" << rect_json(cold[0]) << ",\"header\":" << rect_json(cold[1])
        << ",\"chart\":" << rect_json(cold[2]) << "}},";
    out << "{\"name\":\"resize_h800_no_summary\",\"summary\":false,\"overflow\":false,\"rects\":{";
    out << "\"root\":" << rect_json(resized[0]) << ",\"header\":" << rect_json(resized[1])
        << ",\"chart\":" << rect_json(resized[2]) << "}},";
    out << "{\"name\":\"insert_summary_h600\",\"summary\":true,\"overflow\":false,\"rects\":{";
    out << "\"root\":" << rect_json(inserted[0]) << ",\"header\":" << rect_json(inserted[1])
        << ",\"summary\":" << rect_json(inserted[2]) << ",\"chart\":" << rect_json(inserted[3]) << "}},";
    out << "{\"name\":\"overflow_h150_summary\",\"summary\":true,\"overflow\":true,\"rects\":{";
    out << "\"root\":" << rect_json(overflow[0]) << ",\"header\":" << rect_json(overflow[1])
        << ",\"summary\":" << rect_json(overflow[2]) << ",\"chart\":" << rect_json(overflow[3]) << "}},";
    out << "{\"name\":\"unchanged_h150_summary\",\"summary\":true,\"overflow\":true,\"rects\":{";
    out << "\"root\":" << rect_json(overflow[0]) << ",\"header\":" << rect_json(overflow[1])
        << ",\"summary\":" << rect_json(overflow[2]) << ",\"chart\":" << rect_json(overflow[3])
        << "}}]}";
    return out.str();
}

struct FormState {
    kiwi::Solver solver;
    kiwi::Variable viewport_width{"form.viewport.width"};
    RectVars label_a{"form.label.a"};
    RectVars label_b{"form.label.b"};
    RectVars field_a{"form.field.a"};
    RectVars field_b{"form.field.b"};
    RectVars button_a{"form.button.a"};
    RectVars button_b{"form.button.b"};
    kiwi::Constraint right_bound;

    explicit FormState(double width) {
        solver.addConstraint(equality(viewport_width, width, kiwi::strength::required));
        solver.addConstraint(equality(label_a.x + label_a.width - label_b.x - label_b.width, 0.0, kiwi::strength::required));
        solver.addConstraint(equality(label_a.width, 40.0, kiwi::strength::required));
        solver.addConstraint(equality(label_b.width, 90.0, kiwi::strength::required));
        solver.addConstraint(equality(label_b.x, 0.0, kiwi::strength::required));
        solver.addConstraint(equality(label_a.y, 0.0, kiwi::strength::required));
        solver.addConstraint(equality(label_b.y, 40.0, kiwi::strength::required));
        solver.addConstraint(equality(field_a.x - label_b.x - label_b.width - 12.0, 0.0, kiwi::strength::required));
        solver.addConstraint(equality(field_b.x - field_a.x, 0.0, kiwi::strength::required));
        solver.addConstraint(equality(field_a.y, 0.0, kiwi::strength::required));
        solver.addConstraint(equality(field_b.y, 40.0, kiwi::strength::required));
        solver.addConstraint(equality(label_a.height, 20.0, kiwi::strength::required));
        solver.addConstraint(equality(label_b.height, 20.0, kiwi::strength::required));
        solver.addConstraint(equality(field_a.height, 28.0, kiwi::strength::required));
        solver.addConstraint(equality(field_b.height, 28.0, kiwi::strength::required));
        solver.addConstraint(field_a.x + field_a.width <= viewport_width);
        solver.addConstraint(field_b.x + field_b.width <= viewport_width);
        solver.addConstraint(minimum(field_a.width, 80.0, kiwi::strength::required));
        solver.addConstraint(minimum(field_b.width, 80.0, kiwi::strength::required));
        solver.addConstraint(equality(field_a.width, 180.0, kiwi::strength::strong));
        solver.addConstraint(equality(field_b.width, 180.0, kiwi::strength::strong));
        solver.addConstraint(equality(button_a.x - field_a.x - field_a.width - 12.0, 0.0, kiwi::strength::required));
        solver.addConstraint(equality(button_b.x - button_a.x - button_a.width - 12.0, 0.0, kiwi::strength::required));
        solver.addConstraint(equality(button_a.width - button_b.width, 0.0, kiwi::strength::required));
        solver.addConstraint(minimum(button_a.width, 60.0, kiwi::strength::required));
        solver.addConstraint(minimum(button_b.width, 60.0, kiwi::strength::required));
        solver.addConstraint(equality(button_a.width, 100.0, kiwi::strength::strong));
        solver.addConstraint(equality(button_b.width, 100.0, kiwi::strength::strong));
        solver.addConstraint(equality(button_a.y, 80.0, kiwi::strength::required));
        solver.addConstraint(equality(button_b.y, 80.0, kiwi::strength::required));
        solver.addConstraint(equality(button_a.height, 28.0, kiwi::strength::required));
        solver.addConstraint(equality(button_b.height, 28.0, kiwi::strength::required));
    }

    void add_right_bound() {
        // Install the viewport-relative trailing edge explicitly: the whole
        // button group must end at or before the viewport's right edge.
        right_bound = kiwi::Constraint(button_b.x + button_b.width - viewport_width, kiwi::OP_LE, kiwi::strength::required);
        solver.addConstraint(right_bound);
    }

    std::vector<Rect> rects() const {
        return {read_rect(label_a), read_rect(label_b), read_rect(field_a), read_rect(field_b),
                read_rect(button_a), read_rect(button_b)};
    }
};

std::string form_fixture(Report& report) {
    const std::string fixture = "aligned_form";
    auto normal = std::make_unique<FormState>(520.0);
    normal->add_right_bound();
    normal->solver.updateVariables();
    const std::vector<Rect> normal_rects = normal->rects();
    report.close(fixture, "normal label A natural width", normal_rects[0].width, 40.0);
    report.close(fixture, "normal label B natural width", normal_rects[1].width, 90.0);
    report.close(fixture, "labels shared trailing edge", normal_rects[0].x + normal_rects[0].width,
                 normal_rects[1].x + normal_rects[1].width, {"form.label.trailing"});
    report.close(fixture, "fields shared leading edge", normal_rects[2].x, normal_rects[3].x,
                 {"form.field.leading"});
    report.close(fixture, "normal field A preferred width", normal_rects[2].width, 180.0);
    report.close(fixture, "normal button equality", normal_rects[4].width, normal_rects[5].width,
                 {"form.button.equal-width"});
    report.close(fixture, "normal button preferred width", normal_rects[4].width, 100.0);

    auto narrow = std::make_unique<FormState>(350.0);
    narrow->add_right_bound();
    narrow->solver.updateVariables();
    const std::vector<Rect> narrow_rects = narrow->rects();
    const bool field_compressed = narrow_rects[2].width < 180.0 - kEpsilon;
    const bool buttons_compressed = narrow_rects[4].width < 100.0 - kEpsilon;
    report.check(fixture, "narrow preferred compression", field_compressed || buttons_compressed,
                 "a preferred width below its preferred value", "field=" + number(narrow_rects[2].width)
                     + ", buttons=" + number(narrow_rects[4].width),
                 {"form.field.preferred-width", "form.button.preferred-width"});
    report.close(fixture, "narrow field A minimum", std::max(narrow_rects[2].width, 80.0),
                 narrow_rects[2].width);
    report.close(fixture, "narrow button minimum", std::max(narrow_rects[4].width, 60.0),
                 narrow_rects[4].width);
    report.close(fixture, "narrow button equality", narrow_rects[4].width, narrow_rects[5].width,
                 {"form.button.equal-width"});
    report.diagnostic(
        fixture,
        "preferred_compression",
        "info",
        "narrow viewport compresses optional field/button preferences while required minima remain active",
        {"form.field.preferred-width", "form.button.preferred-width", "form.field.minimum-width",
         "form.button.minimum-width"});

    auto conflict = std::make_unique<FormState>(280.0);
    bool rejected = false;
    std::string rejection;
    try {
        conflict->add_right_bound();
    } catch (const kiwi::UnsatisfiableConstraint& error) {
        rejected = true;
        rejection = error.what();
    } catch (const std::exception& error) {
        rejection = error.what();
    }
    report.check(fixture, "required minimum conflict is diagnosed", rejected,
                 "rejected required viewport-right constraint", rejection.empty() ? "no exception" : rejection,
                 {"form.viewport.right", "form.field.minimum-width", "form.button.minimum-width"});
    report.diagnostic(
        fixture,
        "required_minimum_conflict",
        "warning",
        "viewport width 280 cannot satisfy the shared field/button minimums and the required trailing edge",
        {"form.viewport.right", "form.field.minimum-width", "form.button.minimum-width"});

    std::ostringstream out;
    out << "{\"name\":\"" << fixture << "\",\"authoring\":{"
        << "\"label_natural_widths\":[40,90],\"field_preferred_width\":180"
        << ",\"field_minimum_width\":80,\"button_preferred_width\":100"
        << ",\"button_minimum_width\":60},\"normal\":{";
    out << "\"viewport_width\":520,\"rects\":" << rect_array_json(normal_rects) << "},\"narrow\":{";
    out << "\"viewport_width\":350,\"rects\":" << rect_array_json(narrow_rects)
        << ",\"field_compressed\":" << bool_json(field_compressed)
        << ",\"buttons_compressed\":" << bool_json(buttons_compressed)
        << "},\"minimum_conflict\":{";
    out << "\"viewport_width\":280,\"rejected\":" << bool_json(rejected)
        << ",\"rejected_author_id\":\"form.viewport.right\""
        << ",\"author_ids\":[\"form.viewport.right\",\"form.field.minimum-width\",\"form.button.minimum-width\"]"
        << "}}";
    return out.str();
}

struct SplitterState {
    kiwi::Solver solver;
    kiwi::Variable viewport_width{"splitter.viewport.width"};
    RectVars left{"splitter.left"};
    RectVars right{"splitter.right"};
    kiwi::Variable unrelated_y_a{"splitter.unrelated.a.y"};
    kiwi::Variable unrelated_y_b{"splitter.unrelated.b.y"};

    SplitterState() {
        solver.addConstraint(equality(viewport_width, 600.0, kiwi::strength::required));
        solver.addConstraint(equality(left.x, 0.0, kiwi::strength::required));
        solver.addConstraint(equality(left.y, 0.0, kiwi::strength::required));
        solver.addConstraint(equality(left.height, 240.0, kiwi::strength::required));
        solver.addConstraint(minimum(left.width, 100.0, kiwi::strength::required));
        solver.addConstraint(equality(right.x - left.x - left.width - 8.0, 0.0, kiwi::strength::required));
        solver.addConstraint(equality(right.y, 0.0, kiwi::strength::required));
        solver.addConstraint(equality(right.height, 240.0, kiwi::strength::required));
        solver.addConstraint(minimum(right.width, 120.0, kiwi::strength::required));
        solver.addConstraint(equality(right.x + right.width - viewport_width, 0.0, kiwi::strength::required));
        solver.addConstraint(equality(unrelated_y_a, 42.0, kiwi::strength::required));
        solver.addConstraint(equality(unrelated_y_b, 117.0, kiwi::strength::required));
        solver.addEditVariable(left.width, kiwi::strength::strong);
    }

    void suggest(double value) {
        solver.suggestValue(left.width, value);
        solver.updateVariables();
    }
};

std::string splitter_fixture(Report& report) {
    const std::string fixture = "splitter";
    auto state = std::make_unique<SplitterState>();
    state->suggest(300.0);
    const double stable_y_a = state->unrelated_y_a.value();
    const double stable_y_b = state->unrelated_y_b.value();
    struct Drag {
        double requested;
        double actual_left;
        double actual_right;
    };
    const double requests[] = {300.0, 50.0, 700.0, 100.0, 472.0};
    std::vector<Drag> drags;
    for (const double request : requests) {
        state->suggest(request);
        drags.push_back(Drag{request, state->left.width.value(), state->right.width.value()});
    }
    report.close(fixture, "left lower bound", drags[1].actual_left, 100.0);
    report.close(fixture, "right lower bound after low drag", drags[1].actual_right, 492.0);
    report.close(fixture, "left upper bound", drags[2].actual_left, 472.0);
    report.close(fixture, "right lower bound after high drag", drags[2].actual_right, 120.0);
    report.close(fixture, "splitter gap", state->right.x.value() - state->left.width.value(), 8.0);
    report.close(fixture, "unrelated y A stable", state->unrelated_y_a.value(), stable_y_a);
    report.close(fixture, "unrelated y B stable", state->unrelated_y_b.value(), stable_y_b);
    report.diagnostic(
        fixture,
        "bounded_drag",
        "info",
        "strong edit suggestions are clamped by required left/right minimums and viewport width");

    const auto churn_started = Clock::now();
    for (int cycle = 0; cycle < 64; ++cycle) {
        kiwi::Constraint transient = equality(state->left.width, 180.0 + (cycle % 7), kiwi::strength::weak);
        state->solver.addConstraint(transient);
        state->solver.removeConstraint(transient);
    }
    state->solver.updateVariables();
    const uint64_t churn_ns = elapsed_ns(churn_started);
    report.close(fixture, "post churn left width", state->left.width.value(), 472.0);

    kiwi::Variable weak_vs_medium_x{"splitter.weak_vs_medium.x"};
    kiwi::Solver priority_solver;
    priority_solver.addConstraint(equality(weak_vs_medium_x, 0.0, kiwi::strength::medium));
    for (int index = 0; index < 1001; ++index) {
        priority_solver.addConstraint(equality(weak_vs_medium_x, 1.0, kiwi::strength::weak));
    }
    priority_solver.updateVariables();
    report.close(fixture, "1001 weak constraints outweigh medium", weak_vs_medium_x.value(), 1.0);
    report.diagnostic(
        fixture,
        "numeric_strength_priority",
        "warning",
        "Kiwi numeric strengths allow 1001 weak preferences to outweigh one medium preference",
        {"splitter.weak-preference-1001", "splitter.medium-preference"});

    std::ostringstream out;
    out << "{\"name\":\"" << fixture << "\",\"viewport_width\":600,\"gap\":8"
        << ",\"minimums\":{";
    out << "\"left\":100,\"right\":120},\"drag_suggestions\":[";
    for (size_t index = 0; index < drags.size(); ++index) {
        if (index != 0) out << ',';
        out << "{\"requested_left_width\":" << number(drags[index].requested)
            << ",\"actual_left_width\":" << number(drags[index].actual_left)
            << ",\"actual_right_width\":" << number(drags[index].actual_right) << '}';
    }
    out << "],\"unrelated_y\":[" << number(state->unrelated_y_a.value()) << ','
        << number(state->unrelated_y_b.value()) << "],\"add_remove_cycles\":64"
        << ",\"churn_ns\":" << churn_ns << ",\"priority_probe\":{";
    out << "\"weak_count\":1001,\"medium_target\":0,\"weak_target\":1"
        << ",\"actual\":" << number(weak_vs_medium_x.value()) << "}}";
    return out.str();
}

struct TextMeasure {
    int scalar_count = 0;
    double font_size = 0.0;
    double advance = 0.0;
    double line_height = 0.0;
    double natural_width = 0.0;
    double offered_width = 0.0;
    int scalars_per_line = 1;
    int line_count = 1;
    double width = 0.0;
    double height = 0.0;
};

TextMeasure measure_ascii(int scalar_count, double font_size, double offered_width) {
    TextMeasure result;
    result.scalar_count = scalar_count;
    result.font_size = font_size;
    result.advance = font_size * kAdvanceFactor;
    result.line_height = std::max(16.0, font_size * kLineHeightFactor);
    result.natural_width = scalar_count * result.advance;
    result.offered_width = offered_width;
    if (offered_width > 0.0 && result.advance > 0.0) {
        result.scalars_per_line = std::max(1, static_cast<int>(std::floor((offered_width + 1e-9) / result.advance)));
    } else {
        result.scalars_per_line = std::max(1, scalar_count);
    }
    result.line_count = std::max(1, (scalar_count + result.scalars_per_line - 1) / result.scalars_per_line);
    result.width = std::min(offered_width, result.natural_width);
    result.height = result.line_count * result.line_height;
    return result;
}

struct TextCaseResult {
    TextMeasure measure;
    Rect rect;
    int convergence_iterations = 0;
    bool overflow = false;
};

TextCaseResult run_text_case(
    const std::string& fixture,
    Report& report,
    const std::string& case_name,
    int scalar_count,
    double font_size,
    double offered_width,
    double viewport_height,
    bool assert_case) {
    kiwi::Solver solver;
    RectVars text("text." + case_name);
    solver.addConstraint(equality(text.x, 0.0, kiwi::strength::required));
    solver.addConstraint(equality(text.y, 0.0, kiwi::strength::required));
    solver.addConstraint(equality(text.width, offered_width, kiwi::strength::required));
    solver.addConstraint(minimum(text.height, std::max(16.0, font_size * kLineHeightFactor), kiwi::strength::required));

    TextMeasure measured;
    kiwi::Constraint height_constraint = equality(text.height, 0.0, kiwi::strength::required);
    bool has_height_constraint = false;
    int iterations = 0;
    bool converged = false;
    while (iterations < 4) {
        ++iterations;
        solver.updateVariables();
        measured = measure_ascii(scalar_count, font_size, text.width.value());
        if (has_height_constraint && std::abs(text.height.value() - measured.height) <= kEpsilon) {
            converged = true;
            break;
        }
        if (has_height_constraint) solver.removeConstraint(height_constraint);
        height_constraint = equality(text.height, measured.height, kiwi::strength::required);
        solver.addConstraint(height_constraint);
        has_height_constraint = true;
    }
    solver.updateVariables();
    const bool overflow = measured.height > viewport_height + kEpsilon;
    TextCaseResult result{measured, read_rect(text), iterations, overflow};

    if (assert_case) {
        report.check(fixture, case_name + " bounded convergence", converged && iterations <= 4,
                     "measurement stabilized within four iterations", std::to_string(iterations));
        report.check(fixture, case_name + " finite geometry",
                     std::isfinite(result.rect.width) && std::isfinite(result.rect.height),
                     "finite final geometry", rect_json(result.rect));
    }
    return result;
}

std::string text_measure_json(const TextMeasure& measure) {
    std::ostringstream out;
    out << "{\"scalar_count\":" << measure.scalar_count
        << ",\"font_size\":" << number(measure.font_size)
        << ",\"advance\":" << number(measure.advance)
        << ",\"line_height\":" << number(measure.line_height)
        << ",\"natural_width\":" << number(measure.natural_width)
        << ",\"offered_width\":" << number(measure.offered_width)
        << ",\"scalars_per_line\":" << measure.scalars_per_line
        << ",\"line_count\":" << measure.line_count
        << ",\"width\":" << number(measure.width)
        << ",\"height\":" << number(measure.height) << '}';
    return out.str();
}

std::string text_fixture(Report& report) {
    const std::string fixture = "wrapped_text";
    const TextCaseResult ascii20 = run_text_case(fixture, report, "ascii20_width95", 20, 16.0, 95.0, 40.0, true);
    const TextCaseResult ascii30 = run_text_case(fixture, report, "ascii30_width95", 30, 16.0, 95.0, 40.0, true);
    const TextCaseResult below_threshold = run_text_case(
        fixture, report, "ascii20_width89_59", 20, 16.0, 89.59, 40.0, true);
    const TextCaseResult above_threshold = run_text_case(
        fixture, report, "ascii20_width89_61", 20, 16.0, 89.61, 40.0, true);
    const TextCaseResult font_change = run_text_case(fixture, report, "ascii20_font24_width95", 20, 24.0, 95.0, 40.0, true);
    const TextCaseResult small_font = run_text_case(fixture, report, "ascii20_font12_width95", 20, 12.0, 95.0, 40.0, true);

    report.close(fixture, "ASCII 20 advance", ascii20.measure.advance, 16.0 * 0.56);
    report.close(fixture, "ASCII 20 width 95 lines", ascii20.measure.line_count, 2.0);
    report.close(fixture, "ASCII 20 width 95 height", ascii20.measure.height, 40.0);
    report.close(fixture, "ASCII 30 width 95 lines", ascii30.measure.line_count, 3.0);
    report.close(fixture, "ASCII 30 width 95 height", ascii30.measure.height, 60.0);
    report.close(fixture, "threshold below lines", below_threshold.measure.line_count, 3.0);
    report.close(fixture, "threshold above lines", above_threshold.measure.line_count, 2.0);
    report.close(fixture, "font change line height", font_change.measure.line_height, 30.0);
    report.close(fixture, "font change height", font_change.measure.height, 90.0);
    report.close(fixture, "font minimum line height", small_font.measure.line_height, 16.0);
    report.check(fixture, "explicit overflow", ascii30.overflow, "overflow=true", bool_json(ascii30.overflow));
    report.diagnostic(
        fixture,
        "allocation_measurement_refresh",
        "info",
        "the fixture allocates width, measures wrapped text, refreshes the height constraint, and converges in a bounded pass count");

    std::vector<TextCaseResult> cases = {ascii20, ascii30, below_threshold, above_threshold, font_change, small_font};
    std::ostringstream out;
    out << "{\"name\":\"" << fixture << "\",\"model\":{";
    out << "\"advance_factor\":0.56,\"line_height_factor\":1.25,\"minimum_line_height\":16"
        << "},\"pass_order\":[\"allocation\",\"measurement\",\"height_constraint_refresh\",\"publication\"]"
        << ",\"cases\":[";
    for (size_t index = 0; index < cases.size(); ++index) {
        if (index != 0) out << ',';
        const TextCaseResult& result = cases[index];
        out << "{\"name\":";
        const char* names[] = {"ascii20_width95", "ascii30_width95", "ascii20_width89_59",
                               "ascii20_width89_61", "ascii20_font24_width95", "ascii20_font12_width95"};
        out << json_string(names[index]) << ",\"measurement\":" << text_measure_json(result.measure)
            << ",\"convergence_iterations\":" << result.convergence_iterations
            << ",\"overflow\":" << bool_json(result.overflow)
            << ",\"final_geometry\":" << rect_json(result.rect) << '}';
    }
    out << "]}";
    return out.str();
}

struct WeightedResult {
    std::vector<Rect> rects;
    double ratio_error = 0.0;
};

std::pair<double, double> allocate_weighted_with_cap(
    double width,
    double gap,
    double first_weight,
    double second_weight,
    double first_max) {
    const double available = std::max(0.0, width - gap);
    double first = available * first_weight / (first_weight + second_weight);
    double second = available - first;
    if (first > first_max) {
        first = first_max;
        second = available - first;
    }
    return {first, second};
}

WeightedResult weighted_once(Report& report, const std::string& fixture, bool assert_values) {
    const auto allocation = allocate_weighted_with_cap(300.0, 10.0, 1.0, 2.0, 60.0);
    kiwi::Solver solver;
    RectVars root("weighted.root");
    RectVars first("weighted.first");
    RectVars second("weighted.second");
    solver.addConstraint(equality(root.x, 0.0, kiwi::strength::required));
    solver.addConstraint(equality(root.y, 0.0, kiwi::strength::required));
    solver.addConstraint(equality(root.width, 300.0, kiwi::strength::required));
    solver.addConstraint(equality(root.height, 40.0, kiwi::strength::required));
    solver.addConstraint(equality(first.x, 0.0, kiwi::strength::required));
    solver.addConstraint(equality(first.y, 0.0, kiwi::strength::required));
    solver.addConstraint(equality(first.width, allocation.first, kiwi::strength::required));
    solver.addConstraint(equality(first.height, 40.0, kiwi::strength::required));
    solver.addConstraint(equality(second.x - first.x - first.width - 10.0, 0.0, kiwi::strength::required));
    solver.addConstraint(equality(second.y, 0.0, kiwi::strength::required));
    solver.addConstraint(equality(second.width, allocation.second, kiwi::strength::required));
    solver.addConstraint(equality(second.height, 40.0, kiwi::strength::required));
    // The ratio is retained as an observable preference, but the explicit
    // clamp/redistribute policy owns the final allocation.
    solver.addConstraint(equality(second.width - 2.0 * first.width, 0.0, kiwi::strength::weak));
    solver.updateVariables();
    std::vector<Rect> rects = {read_rect(root), read_rect(first), read_rect(second)};
    const double ratio_error = second.width.value() - 2.0 * first.width.value();
    if (assert_values) {
        report.close(fixture, "weighted first capped width", first.width.value(), 60.0);
        report.close(fixture, "weighted second redistributed width", second.width.value(), 230.0);
        report.close(fixture, "weighted second x", second.x.value(), 70.0);
        report.close(fixture, "weighted root width", root.width.value(), 300.0);
    }
    return WeightedResult{std::move(rects), ratio_error};
}

std::string weighted_fixture(Report& report) {
    const std::string fixture = "weighted_row";
    const WeightedResult result = weighted_once(report, fixture, true);
    report.diagnostic(
        fixture,
        "explicit_clamp_redistribute",
        "info",
        "the 1:2 row computes the capped first allocation and redistributes the remainder; a soft ratio does not own geometry");

    std::ostringstream out;
    out << "{\"name\":\"" << fixture << "\",\"width\":300,\"gap\":10"
        << ",\"weights\":[1,2],\"first_maximum\":60,\"allocation_policy\":\"clamp_then_redistribute\""
        << ",\"rects\":" << rect_array_json(result.rects)
        << ",\"ratio_preference_error\":" << number(result.ratio_error) << '}';
    return out.str();
}

struct RetentionResult {
    size_t before_churn = 0;
    size_t after_remove = 0;
    size_t after_reset = 0;
    int churn_constraints = 0;
};

std::string retention_fixture(Report& report) {
    const std::string fixture = "retention";
    kiwi::Solver solver;
    kiwi::Variable base("retention.base");
    solver.addConstraint(equality(base, 0.0, kiwi::strength::required));
    solver.updateVariables();
    RetentionResult result;
    result.before_churn = dump_variable_count(solver);
    std::vector<kiwi::Variable> churn_variables;
    std::vector<kiwi::Constraint> churn_constraints;
    constexpr int churn_count = 64;
    churn_variables.reserve(churn_count);
    churn_constraints.reserve(churn_count);
    for (int index = 0; index < churn_count; ++index) {
        churn_variables.emplace_back("retention.churn." + std::to_string(index));
        churn_constraints.push_back(equality(churn_variables.back(), static_cast<double>(index), kiwi::strength::weak));
        solver.addConstraint(churn_constraints.back());
        solver.removeConstraint(churn_constraints.back());
    }
    solver.updateVariables();
    result.after_remove = dump_variable_count(solver);
    result.churn_constraints = churn_count;
    solver.reset();
    result.after_reset = dump_variable_count(solver);
    report.check(fixture, "solver dump has a baseline variable", result.before_churn >= 1,
                 "at least one variable", std::to_string(result.before_churn));
    report.check(fixture, "removed churn variables are characterized", result.after_remove == result.before_churn + churn_count,
                 "baseline plus 64 removed variables", std::to_string(result.after_remove));
    report.check(fixture, "solver reset clears variable entries", result.after_reset == 0,
                 "0", std::to_string(result.after_reset));
    report.diagnostic(
        fixture,
        "solver_dump_retention",
        "info",
        "counts come from Kiwi Solver::dumps() variable entries and are not exact heap-byte measurements");

    std::ostringstream out;
    out << "{\"name\":\"" << fixture << "\",\"variable_entry_counts\":{";
    out << "\"before_churn\":" << result.before_churn
        << ",\"after_remove\":" << result.after_remove
        << ",\"after_reset\":" << result.after_reset << "},\"churn_constraints\":"
        << result.churn_constraints
        << ",\"process_rss_collected\":false"
        << ",\"process_rss_note\":\"not collected; solver dump counts do not claim heap bytes\"}";
    return out.str();
}

struct ParityResult {
    std::vector<Rect> rects;
};

ParityResult column_parity_once(Report& report, bool assert_values) {
    kiwi::Solver solver;
    RectVars root("parity.column.root"), header("parity.column.header"), body("parity.column.body");
    solver.addConstraint(root.x == 0.0);
    solver.addConstraint(root.y == 0.0);
    solver.addConstraint(root.width == 300.0);
    solver.addConstraint(root.height == 200.0);
    solver.addConstraint(header.x == root.x + 10.0);
    solver.addConstraint(header.y == root.y + 10.0);
    solver.addConstraint(header.width == root.width - 20.0);
    solver.addConstraint(header.height == 20.0);
    solver.addConstraint(body.x == header.x);
    solver.addConstraint(body.y == header.y + header.height + 5.0);
    solver.addConstraint(body.width == header.width);
    solver.addConstraint(body.height >= 40.0);
    solver.addConstraint((body.y + body.height == root.height - 10.0) | kiwi::strength::medium);
    solver.updateVariables();
    std::vector<Rect> rects = {read_rect(root), read_rect(header), read_rect(body)};
    if (assert_values) {
        report.close("column-content-header-fill-body", "body y", rects[2].y, 35.0);
        report.close("column-content-header-fill-body", "body height", rects[2].height, 155.0);
    }
    return ParityResult{std::move(rects)};
}

ParityResult wrapped_parity_once(Report& report, bool assert_values) {
    kiwi::Solver solver;
    RectVars root("parity.wrapped.root"), first("parity.wrapped.first"), second("parity.wrapped.second");
    solver.addConstraint(root.x == 0.0);
    solver.addConstraint(root.y == 0.0);
    solver.addConstraint(root.width == 200.0);
    solver.addConstraint((root.height == 0.0) | kiwi::strength::weak);
    solver.addConstraint(first.x == root.x);
    solver.addConstraint(first.y == root.y);
    solver.addConstraint(first.width == (root.width - 10.0) / 2.0);
    solver.addConstraint(second.x == first.x + first.width + 10.0);
    solver.addConstraint(second.y == first.y);
    solver.addConstraint(second.width == first.width);
    solver.updateVariables();
    solver.addConstraint(first.height == measure_ascii(20, 16.0, first.width.value()).height);
    solver.addConstraint(second.height == measure_ascii(30, 16.0, second.width.value()).height);
    solver.addConstraint(root.height >= first.height);
    solver.addConstraint(root.height >= second.height);
    solver.updateVariables();
    std::vector<Rect> rects = {read_rect(root), read_rect(first), read_rect(second)};
    if (assert_values) {
        report.close("wrapped-text-at-offered-width", "first width", rects[1].width, 95.0);
        report.close("wrapped-text-at-offered-width", "first height", rects[1].height, 40.0);
        report.close("wrapped-text-at-offered-width", "second height", rects[2].height, 60.0);
    }
    return ParityResult{std::move(rects)};
}

std::string parity_fixture_json(const std::string& name, const std::vector<Rect>& rects) {
    std::ostringstream out;
    out << "{\"name\":" << json_string(name) << ",\"rects\":" << rect_array_json(rects) << '}';
    return out.str();
}

std::string all_json(Report& report) {
    const std::string csv = csv_fixture(report);
    const std::string form = form_fixture(report);
    const std::string splitter = splitter_fixture(report);
    const std::string text = text_fixture(report);
    const std::string weighted = weighted_fixture(report);
    const std::string retention = retention_fixture(report);

    const WeightedResult weighted_parity = weighted_once(report, "row-weighted-fill-min-max", true);
    const ParityResult column_parity = column_parity_once(report, true);
    const ParityResult wrapped_parity = wrapped_parity_once(report, true);

    std::ostringstream out;
    out << "{\"schema\":\"moxi.layout.kiwi-fixtures.v1\""
        << ",\"backend\":\"kiwi-cpp\",\"kiwi_header\":\"kiwi/kiwi.h\",\"kiwi_requested_version\":\"1.5.0\""
        << ",\"ok\":" << bool_json(report.failures == 0)
        << ",\"assertions\":{";
    out << "\"passed\":" << (report.assertions - report.failures)
        << ",\"failed\":" << report.failures << ",\"total\":" << report.assertions << "}"
        << ",\"fixtures\":[" << csv << ',' << form << ',' << splitter << ',' << text << ',' << weighted << ',' << retention << ']'
        << ",\"parity_fixtures\":{"
        << "\"row-weighted-fill-min-max\":" << parity_fixture_json("row-weighted-fill-min-max", weighted_parity.rects)
        << ",\"column-content-header-fill-body\":" << parity_fixture_json("column-content-header-fill-body", column_parity.rects)
        << ",\"wrapped-text-at-offered-width\":" << parity_fixture_json("wrapped-text-at-offered-width", wrapped_parity.rects)
        << "},\"rect_arrays\":{"
        << "\"row-weighted-fill-min-max\":" << rect_array_json(weighted_parity.rects)
        << ",\"column-content-header-fill-body\":" << rect_array_json(column_parity.rects)
        << ",\"wrapped-text-at-offered-width\":" << rect_array_json(wrapped_parity.rects)
        << "},\"diagnostics\":" << diagnostics_json(report.diagnostics) << '}';
    return out.str();
}

} // namespace

int main(int argc, char** argv) {
    if (argc > 1 && std::string(argv[1]) != "--json") {
        std::cerr << "usage: layout-kiwi [--json]\n";
        return 64;
    }
    Report report;
    try {
        std::cout << all_json(report) << '\n';
    } catch (const std::exception& error) {
        report.failures += 1;
        report.diagnostic("runner", "exception", "error", error.what());
        std::cout << "{\"schema\":\"moxi.layout.kiwi-fixtures.v1\",\"backend\":\"kiwi-cpp\",\"ok\":false"
                  << ",\"assertions\":{\"passed\":0,\"failed\":1,\"total\":0}"
                  << ",\"fixtures\":[],\"diagnostics\":" << diagnostics_json(report.diagnostics) << "}\n";
        return 1;
    }
    return report.failures == 0 ? 0 : 1;
}
