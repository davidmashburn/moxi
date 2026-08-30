#ifndef MOXI_HARFBUZZ_TEXT_H
#define MOXI_HARFBUZZ_TEXT_H

#ifdef __cplusplus
extern "C" {
#endif

int moxi_harfbuzz_available(void);
int moxi_harfbuzz_shape(const char *utf8, float font_size, int direction);
int moxi_harfbuzz_direction(void);
int moxi_harfbuzz_glyph_codepoint_at(int index);
int moxi_harfbuzz_glyph_id_at(int index);
int moxi_harfbuzz_glyph_cluster_at(int index);
float moxi_harfbuzz_glyph_advance_at(int index);
float moxi_harfbuzz_glyph_x_at(int index);
float moxi_harfbuzz_glyph_y_at(int index);
float moxi_harfbuzz_width(void);
float moxi_harfbuzz_height(void);

#ifdef __cplusplus
}
#endif

#endif
