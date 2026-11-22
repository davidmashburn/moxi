#ifndef MOXI_BUTTON_STATE_H
#define MOXI_BUTTON_STATE_H

typedef struct { float r, g, b, a; } MoxiButtonColor;

/* Overlay the button's own ink, including on transparent ghost buttons. */
static inline MoxiButtonColor moxi_button_state_fill(
    MoxiButtonColor fill, MoxiButtonColor ink, int enabled, int hovered, int pressed
) {
    if (!enabled) {
        fill.a *= 0.55f;
        return fill;
    }
    float overlay = ink.a * (pressed ? 0.20f : hovered ? 0.10f : 0.0f);
    if (overlay == 0.0f) return fill;
    float base = fill.a * (1.0f - overlay);
    float alpha = base + overlay;
    return (MoxiButtonColor){
        (fill.r * base + ink.r * overlay) / alpha,
        (fill.g * base + ink.g * overlay) / alpha,
        (fill.b * base + ink.b * overlay) / alpha, alpha
    };
}
#endif
