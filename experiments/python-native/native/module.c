#define PY_SSIZE_T_CLEAN
#include <Python.h>
#include <math.h>
#include <stdint.h>
#include <string.h>

/* Private, host ABI. All pointers are owned/pinned by this frame. GIL held. */
enum { MAX_COLUMNS = 8, MAX_ROWS = 4096, MAX_SPEC = 16384, MAX_SIDE = 1024 };
typedef enum { OUTPUT_RGBA = 0, OUTPUT_SVG = 1 } Output;
typedef enum { STATUS_OK = 0, STATUS_INVALID_SPEC = 1, STATUS_INVALID_COLUMNS = 2,
               STATUS_OUTPUT_LIMIT = 3, STATUS_RENDER_FAILED = 4 } Status;
extern int32_t moxi_e04_abi_version(void);
extern int32_t moxi_e04_render(int64_t, int64_t, int64_t, int64_t, int64_t,
                             int64_t, int64_t, int64_t, int32_t, int32_t,
                             int32_t, int64_t, int64_t, int64_t);
_Static_assert(sizeof(void *) == sizeof(int64_t), "64-bit host ABI required");
#define ADDRESS(p) ((int64_t)(intptr_t)(p))

static PyObject *version(PyObject *self, PyObject *unused) {
    (void)self; (void)unused;
    return PyLong_FromLong(moxi_e04_abi_version());
}
static int name_valid(const char *name, Py_ssize_t n) {
    if (n < 1 || n > 64) return 0;
    for (Py_ssize_t i = 0; i < n; i++) {
        char c = name[i];
        if (!((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_' ||
              (i > 0 && c >= '0' && c <= '9'))) return 0;
    }
    return 1;
}
static PyObject *render(PyObject *self, PyObject *args) {
    (void)self;
    PyObject *spec, *columns, *result = NULL;
    int width, height, kind;
    double *copies[MAX_COLUMNS] = {0};
    int64_t names[MAX_COLUMNS], lengths[MAX_COLUMNS], values[MAX_COLUMNS], valid[MAX_COLUMNS];
    char *output = NULL;
    Py_ssize_t count = 0, rows = -1;
    if (!PyArg_ParseTuple(args, "O!O!iii:render", &PyBytes_Type, &spec,
                          &PyTuple_Type, &columns, &width, &height, &kind)) return NULL;
    count = PyTuple_GET_SIZE(columns);
    if (count < 1 || count > MAX_COLUMNS || PyBytes_GET_SIZE(spec) < 2 ||
        PyBytes_GET_SIZE(spec) > MAX_SPEC || width < 64 || height < 64 ||
        width > MAX_SIDE || height > MAX_SIDE || (kind != OUTPUT_RGBA && kind != OUTPUT_SVG))
        goto invalid;
    for (Py_ssize_t c = 0; c < count; c++) {
        PyObject *item = PyTuple_GET_ITEM(columns, c);
        if (!PyTuple_CheckExact(item) || PyTuple_GET_SIZE(item) != 3) goto invalid;
        PyObject *name = PyTuple_GET_ITEM(item, 0), *data = PyTuple_GET_ITEM(item, 1);
        PyObject *mask = PyTuple_GET_ITEM(item, 2);
        if (!PyBytes_CheckExact(name) || !PyBytes_CheckExact(data) || !PyBytes_CheckExact(mask)) goto invalid;
        lengths[c] = PyBytes_GET_SIZE(name);
        names[c] = ADDRESS(PyBytes_AS_STRING(name));
        if (!name_valid(PyBytes_AS_STRING(name), lengths[c])) goto invalid;
        for (Py_ssize_t previous = 0; previous < c; previous++)
            if (lengths[c] == lengths[previous] &&
                memcmp((void *)(intptr_t)names[c], (void *)(intptr_t)names[previous], lengths[c]) == 0)
                goto invalid;
        Py_ssize_t n = PyBytes_GET_SIZE(mask);
        if (rows < 0) rows = n;
        if (n < 1 || n > MAX_ROWS || n != rows || PyBytes_GET_SIZE(data) != n * (Py_ssize_t)sizeof(double)) goto invalid;
        copies[c] = PyMem_Malloc((size_t)n * sizeof(double));
        if (!copies[c]) { PyErr_NoMemory(); goto cleanup; }
        memcpy(copies[c], PyBytes_AS_STRING(data), (size_t)n * sizeof(double));
        values[c] = ADDRESS(copies[c]);
        valid[c] = ADDRESS(PyBytes_AS_STRING(mask));
        for (Py_ssize_t r = 0; r < n; r++) {
            unsigned char v = (unsigned char)PyBytes_AS_STRING(mask)[r];
            if (v > 1 || !isfinite(copies[c][r]) || fabs(copies[c][r]) > 1000000.0) goto invalid;
        }
    }
    int64_t capacity = kind == OUTPUT_RGBA ? (int64_t)width * height * 4 : 16 * 1024 * 1024;
    output = PyMem_Malloc((size_t)capacity);
    if (!output) { PyErr_NoMemory(); goto cleanup; }
    int64_t written = 0;
    Status status = (Status)moxi_e04_render(ADDRESS(PyBytes_AS_STRING(spec)), PyBytes_GET_SIZE(spec),
        ADDRESS(names), ADDRESS(lengths), ADDRESS(values), ADDRESS(valid), count, rows,
        width, height, kind, ADDRESS(output), capacity, ADDRESS(&written));
    if (written < 0 || written > capacity) {
        PyErr_SetString(PyExc_RuntimeError, "native boundary: invalid output length");
        goto cleanup;
    }
    /* Return status plus Python-owned bytes; no Mojo address escapes. */
    result = Py_BuildValue("iy#", (int)status, output, (Py_ssize_t)written);
    goto cleanup;
invalid:
    PyErr_SetString(PyExc_ValueError, "native boundary: invalid argument");
cleanup:
    for (int c = 0; c < MAX_COLUMNS; c++) PyMem_Free(copies[c]);
    PyMem_Free(output);
    return result;
}
static PyMethodDef methods[] = {
    {"abi_version", version, METH_NOARGS, "Compiled Mojo C ABI version."},
    {"render", render, METH_VARARGS, "Private validated buffer boundary."},
    {NULL, NULL, 0, NULL}
};
static struct PyModuleDef module = {PyModuleDef_HEAD_INIT, "_core", NULL, -1, methods,
                                  NULL, NULL, NULL, NULL};
PyMODINIT_FUNC PyInit__core(void) { return PyModule_Create(&module); }
