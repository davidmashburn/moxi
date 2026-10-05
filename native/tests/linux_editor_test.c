/* Private presenter regression checks; no test entry points in the host ABI. */
#include "../linux_window.c"
#include <assert.h>
#include <stdlib.h>

static Slot *publish_text(const char *text, int cursor, int start, int end,
                          const char *composition, int marked_start, int marked_end,
                          float width) {
    moxi_window_begin_frame();
    moxi_window_set_text_input_at(0,text,10,10,width,40,
        0,0,0,1,1,1,1,1,0,18,0,1,cursor,start,end,
        composition,marked_start,marked_end);
    return &slots[5][0];
}
static void check_preedit_replacement(void) {
    Slot *slot = publish_text("abcdef",4,2,4,"かな",1,1,256);
    EditorText preview = editor_text(slot);
    assert(strcmp(preview.display,"abかなef") == 0);
    assert(strcmp(slot->text,"abcdef") == 0); /* Preview never mutates committed text. */
    assert(preview.marked_start == 2 && preview.marked_end == 8);
    assert(preview.caret == 5 && preview.selection_start == 5 && preview.selection_end == 5);
    g_free(preview.display);

    slot = publish_text("abcdef",2,4,2,"かな",2,1,256);
    preview = editor_text(slot);
    assert(strcmp(preview.display,"abかなef") == 0);
    assert(preview.caret == 5 && preview.selection_start == 5 && preview.selection_end == 8);
    assert(slot->composition_start == 2 && slot->composition_end == 1);
    g_free(preview.display);

    slot = publish_text("A🙂日Z",3,1,3,"かな",0,2,256);
    preview = editor_text(slot);
    assert(strcmp(preview.display,"AかなZ") == 0);
    assert(preview.marked_start == 1 && preview.marked_end == 7);
    assert(preview.caret == 7 && preview.selection_start == 1 && preview.selection_end == 7);
    g_free(preview.display);

    slot = publish_text("A🙂日Z",3,1,3,"",0,0,256);
    preview = editor_text(slot);
    assert(!preview.composing && strcmp(preview.display,"A🙂日Z") == 0);
    assert(preview.caret == 8 && preview.selection_start == 1 && preview.selection_end == 8);
    g_free(preview.display);

    slot = publish_text("abcdef",4,-100,100,"かな",-100,100,256);
    preview = editor_text(slot);
    assert(strcmp(preview.display,"かな") == 0);
    assert(preview.caret == 6 && preview.selection_start == 0 && preview.selection_end == 6);
    g_free(preview.display);
    puts("Preedit replacement, reversed selection, UTF-8 caret and cancellation: pass");
}
static uint32_t pixel(cairo_surface_t *surface, int x, int y) {
    cairo_surface_flush(surface);
    unsigned char *bytes = cairo_image_surface_get_data(surface);
    return ((uint32_t *)(bytes+y*cairo_image_surface_get_stride(surface)))[x];
}
static cairo_surface_t *render_editor(Slot *slot) {
    cairo_surface_t *surface = cairo_image_surface_create(CAIRO_FORMAT_ARGB32,300,70);
    cairo_t *cr = cairo_create(surface);
    draw_editor(cr,slot);
    assert(cairo_status(cr) == CAIRO_STATUS_SUCCESS);
    cairo_destroy(cr);
    return surface;
}
static void check_selected_preedit_pixels(void) {
    Slot *slot = publish_text("abcdef",4,2,4,"かな",2,2,256);
    cairo_surface_t *actual = render_editor(slot);
    cairo_t *cr = cairo_create(actual);
    /* Independently measure the expected preview; only its caret/underline
     * differ from an unfocused plain-text drawing of the same glyphs. */
    PangoLayout *layout = text_layout(cr,"abかなef",18,-1);
    PangoRectangle caret;
    pango_layout_get_cursor_pos(layout,(int)strlen("abかな"),&caret,NULL);
    float caret_x = 18+(float)caret.x/PANGO_SCALE;
    g_object_unref(layout); cairo_destroy(cr);
    slot = publish_text("abかなef",4,4,4,"",0,0,256);
    slot->focused = 0;
    cairo_surface_t *expected = render_editor(slot);
    int glyph_pixels = 0, mismatches = 0;
    for (int y=15;y<43;++y) for (int x=18;x<266;++x) {
        if (fabsf((float)x-caret_x) <= 2) continue;
        uint32_t reference = pixel(expected,x,y);
        glyph_pixels += reference != 0;
        mismatches += pixel(actual,x,y) != reference;
    }
    assert(glyph_pixels > 0);
    if (mismatches) fprintf(stderr,"Selected preedit glyph mismatch count: %d\n",mismatches);
    assert(mismatches == 0);
    cairo_surface_destroy(actual); cairo_surface_destroy(expected);
    puts("Selected preedit renders replacement glyphs: pass");
}
static void check_preedit_caret_scroll(void) {
    Slot *slot = publish_text("AZ",1,1,1,"abcdefghijklmnopqrstuvwxyz",26,26,70);
    cairo_surface_t *surface = render_editor(slot);
    cairo_t *cr = cairo_create(surface);
    EditorText preview = editor_text(slot);
    PangoLayout *layout = text_layout(cr,preview.display,slot->font,-1);
    EditorGeometry end = editor_geometry(slot,layout,&preview);
    assert(end.origin < end.inset.x);
    float caret_x = end.origin+end.caret_x;
    assert(caret_x >= end.inset.x && caret_x <= end.inset.x+end.inset.width-1);
    assert(pixel(surface,(int)floorf(caret_x),42) != 0 ||
           pixel(surface,(int)ceilf(caret_x),42) != 0);
    g_free(preview.display);
    slot->composition_start = slot->composition_end = 1;
    preview = editor_text(slot);
    EditorGeometry beginning = editor_geometry(slot,layout,&preview);
    assert(beginning.origin == beginning.inset.x);
    assert(beginning.caret_x < end.caret_x);
    g_free(preview.display); g_object_unref(layout); cairo_destroy(cr);
    cairo_surface_destroy(surface);
    puts("Preedit caret follows marked cursor and remains visible when scrolled: pass");
}
static void check_keypad_navigation(void) {
    const guint native[] = {GDK_KEY_KP_Left,GDK_KEY_KP_Right,GDK_KEY_KP_Up,
        GDK_KEY_KP_Down,GDK_KEY_KP_Home,GDK_KEY_KP_End,GDK_KEY_KP_Delete,GDK_KEY_KP_Enter,
        GDK_KEY_KP_Tab,GDK_KEY_KP_Space};
    const int portable[] = {1000,1001,1002,1003,1004,1005,127,13,9,32};
    for (size_t i=0;i<G_N_ELEMENTS(native);++i) assert(key_code(native[i]) == portable[i]);
    puts("Keypad navigation uses portable key values: pass");
}
static void drain_events(void) { while (moxi_window_poll_event()) { } }
static void publish_active_editor(int id) {
    publish_text("x",1,1,1,"",0,0,100);
    moxi_window_begin_accessibility();
    moxi_window_text_editor_key(id);
    moxi_window_set_accessibility_at(0,id,-1,3,"editor","x","",10,10,100,40,
        1,1,0,0,0,0,0,0,0,0);
    moxi_window_end_frame();
}
static void check_same_editor_reopen(void) {
    for (int cycle=0;cycle<2;++cycle) {
        moxi_window_open("Moxi lifecycle regression",200,100,0,0,0,0,1,0);
        publish_active_editor(13);
        drain_events();
        g_signal_emit_by_name(im,"commit","reopen");
        assert(moxi_window_poll_event() == 3);
        assert(moxi_window_event_target() == 13);
        assert(moxi_window_event_codepoint() == 'r');
        drain_events();
        gtk_window_close(GTK_WINDOW(window));
        moxi_window_pump();
        assert(!moxi_window_is_open() && !window && !im);
        drain_events();
    }
    puts("Real GTK close/reopen accepts committed input for the same editor ID: pass");
}
static gboolean wake_with_event(gpointer data) {
    (void)data;
    push(new_event(6));
    return G_SOURCE_REMOVE;
}
static void check_host_lifecycle(void) {
    moxi_window_open("Moxi host regression",200,100,0,0,0,0,1,0);
    for (int i=0;i<3;++i) { moxi_window_wait(0.03f); drain_events(); }
    gint64 start = g_get_monotonic_time();
    moxi_window_pump();
    assert(g_get_monotonic_time()-start < 500000 && queue_count == 0);
    start = g_get_monotonic_time();
    moxi_window_wait(0.02f);
    assert(g_get_monotonic_time()-start >= 15000 && queue_count == 0);
    guint wake = g_timeout_add(5,wake_with_event,NULL);
    moxi_window_wait(-1);
    assert(moxi_window_poll_event() == 6);
    assert(g_main_context_find_source_by_id(NULL,wake) == NULL);
    push(new_event(6));
    start = g_get_monotonic_time();
    moxi_window_wait(1);
    assert(g_get_monotonic_time()-start < 500000 && queue_count == 1);
    drain_events();

    assert(moxi_window_scale_factor() == gtk_widget_get_scale_factor(canvas));
    const char *scale = g_getenv("GDK_SCALE");
    if (scale) assert(moxi_window_scale_factor() == atoi(scale));
    float width = moxi_window_width(), height = moxi_window_height();
    window_scale = 0; /* Simulate cached prior-display scale for notification. */
    scale_changed(G_OBJECT(canvas),NULL,NULL);
    assert(moxi_window_poll_event() == 4);
    assert(moxi_window_width() == width && moxi_window_height() == height);
    assert(window_scale == moxi_window_scale_factor());
    drain_events();

    publish_active_editor(13);
    im_has_preedit = TRUE;
    Slot *retained_editor = &slots[5][active_editor];
    moxi_window_begin_accessibility();
    moxi_window_set_accessibility_at(0,13,-1,3,"editor","x","",10,10,100,40,
        1,0,0,0,0,0,0,0,0,0);
    moxi_window_end_accessibility();
    assert(!im_focused && editor_key == -1 && !im_has_preedit);
    assert(active_editor == 0 && retained_editor->present);
    assert(moxi_window_poll_event() == 9 && moxi_window_event_target() == 13);
    g_signal_emit_by_name(im,"commit","ignored");
    assert(moxi_window_poll_event() == 0);
    moxi_window_close();
    moxi_window_close();
    assert(!opened && !window && !im && moxi_window_scale_factor() == 1);
    start = g_get_monotonic_time();
    moxi_window_wait(-1);
    assert(g_get_monotonic_time()-start < 500000);
    puts("Host nonblocking pump, timed/event wait, scale, semantics focus and idempotent close: pass");
}
int main(int argc, char **argv) {
    if (argc == 2 && strcmp(argv[1],"--display") == 0) {
        check_same_editor_reopen();
        check_host_lifecycle();
        return 0;
    }
    assert(argc == 1);
    check_preedit_replacement();
    check_selected_preedit_pixels();
    check_preedit_caret_scroll();
    check_keypad_navigation();
    moxi_window_begin_frame();
    puts("Linux native editor regressions: pass (no display)");
    return 0;
}
