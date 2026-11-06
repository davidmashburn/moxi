#ifndef MOXI_MINDMAP_STORAGE_H
#define MOXI_MINDMAP_STORAGE_H
#include <stdint.h>
// Each returned result owns immutable payload/report strings. No ambient document.
uint64_t moxi_mm_read(const char *path);
uint64_t moxi_mm_destination(const char *path);
uint64_t moxi_mm_write(const char *path, const char *text, const char *expected, int recovery);
uint64_t moxi_mm_recover(const char *path);
uint64_t moxi_mm_import(const char *path);
uint64_t moxi_mm_choose(int save);
uint64_t moxi_mm_draft_path(void);
int moxi_mm_result_ok(uint64_t result);
int moxi_mm_result_length(uint64_t result, int field);
int moxi_mm_result_codepoint(uint64_t result, int field, int offset);
void moxi_mm_result_free(uint64_t result);
#endif

int moxi_mm_reduced_motion(void);
