#ifndef MOXI_E04_GRAPHICS_H
#define MOXI_E04_GRAPHICS_H
#include <stdint.h>

typedef enum { OUTPUT_RGBA = 0, OUTPUT_SVG = 1, OUTPUT_PDF = 2 } Output;
typedef enum { STATUS_OK = 0, STATUS_INVALID_SPEC = 1, STATUS_INVALID_COLUMNS = 2,
               STATUS_OUTPUT_LIMIT = 3, STATUS_RENDER_FAILED = 4 } Status;
enum { MOXI_E04_ABI_VERSION = 2 };
typedef struct MoxiGraphics MoxiGraphics;

MoxiGraphics *moxi_e04_graphics_create(Output kind, int width, int height, void *pixels);
Status moxi_e04_graphics_finish(MoxiGraphics *, void *output, int64_t capacity, int64_t *written);
void moxi_e04_graphics_destroy(MoxiGraphics *);

/* Called only by the compiled Mojo renderer during the owning C frame. */
void moxi_e04_rect(int64_t, double, double, double, double, double,
                   double, double, double, double);
void moxi_e04_line(int64_t, double, double, double, double, double,
                   double, double, double, double);
int32_t moxi_e04_text(int64_t, const char *, double, double, double,
                      double, double, double, double);
void moxi_e04_clip(int64_t, double, double, double, double);
int32_t moxi_e04_pop_clip(int64_t);
#endif
