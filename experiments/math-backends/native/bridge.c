/* D01 opaque C ABI. No C++ layout crosses this boundary. MIT (Moxi). */
#include <symengine/cwrapper.h>
#include <stdint.h>
#include <stdlib.h>

static int64_t live_handles = 0;
static int64_t peak_handles = 0;
static int64_t live_strings = 0;

/* Single computation thread per worker process. SymEngine itself is built with
 * WITH_SYMENGINE_THREAD_SAFE=ON; counters deliberately have that narrower scope. */
int64_t moxi_math_live(void) { return live_handles + live_strings; }
int64_t moxi_math_peak(void) { return peak_handles; }
basic_struct *moxi_math_new(void) {
    basic_struct *p = basic_new_heap();
    if (p) { ++live_handles; if (live_handles > peak_handles) peak_handles = live_handles; }
    return p;
}
void moxi_math_free(basic_struct *p) { if (p) { basic_free_heap(p); --live_handles; } }
char *moxi_math_text(const basic_struct *p) { char *s = basic_str(p); if (s) ++live_strings; return s; }
void moxi_math_text_free(char *s) { if (s) { basic_str_free(s); --live_strings; } }
char *moxi_math_type(const basic_struct *p) {
    char *s = basic_get_class_from_id(basic_get_type(p)); if (s) ++live_strings; return s;
}
/* Vectors are scoped here; returned children are assigned into Mojo-owned basic
 * handles. Failure codes propagate, including before vector disposal. */
int64_t moxi_math_arg_count(const basic_struct *p) {
    CVecBasic *v = vecbasic_new();
    int err = basic_get_args(p, v);
    int64_t count = err ? -1 : (int64_t)vecbasic_size(v);
    vecbasic_free(v);
    return count;
}
int moxi_math_arg(basic_struct *out, const basic_struct *p, int64_t index) {
    CVecBasic *v = vecbasic_new();
    int err = basic_get_args(p, v);
    if (!err) {
        if (index < 0 || (size_t)index >= vecbasic_size(v)) err = 1;
        else err = vecbasic_get(v, (size_t)index, out);
    }
    vecbasic_free(v);
    return err;
}
